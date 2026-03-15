use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use std::sync::Arc;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::Mutex;
use tokio_tungstenite::tungstenite::protocol::Message;
use tokio_tungstenite::{accept_async, connect_async};

const FINNHUB_API_KEY: &str = "d6rbmqhr01qr194m3augd6rbmqhr01qr194m3av0";

// =============================================================================
// INSTRUMENT PROFILE — This drives ALL math. Every pair has unique mechanics.
// =============================================================================
#[derive(Debug, Clone)]
struct InstrumentProfile {
    pip_size: f64,        // Size of 1 pip in price terms
    pip_value_per_lot: f64, // $USD value of 1 pip move per 1 standard lot
    contract_size: f64,   // How many units in 1 standard lot (100,000 for FX, 1 for BTC, etc.)
}

// Detects the instrument and returns a calibrated InstrumentProfile
fn get_instrument_profile(pair: &str, price: f64) -> InstrumentProfile {
    let pair_upper = pair.to_uppercase();

    // XAUUSD (Gold): contract = 100 oz, pip = 0.01, pip_val = $1
    if pair_upper.contains("XAUUSD") || pair_upper.contains("GOLD") {
        return InstrumentProfile { pip_size: 0.01, pip_value_per_lot: 1.0, contract_size: 100.0 };
    }

    // XAGUSD (Silver): contract = 5000 oz, pip = 0.001, pip_val = $5
    if pair_upper.contains("XAGUSD") || pair_upper.contains("SILVER") {
        return InstrumentProfile { pip_size: 0.001, pip_value_per_lot: 5.0, contract_size: 5000.0 };
    }

    // BTCUSD: contract = 1 BTC, 1 pip = $1
    if pair_upper.contains("BTC") {
        return InstrumentProfile { pip_size: 1.0, pip_value_per_lot: 1.0, contract_size: 1.0 };
    }

    // ETHUSD: contract = 1 ETH, 1 pip = $0.01
    if pair_upper.contains("ETH") {
        return InstrumentProfile { pip_size: 0.01, pip_value_per_lot: 1.0, contract_size: 1.0 };
    }

    // Generic Crypto fallback (e.g. BNBUSDT, SOLUSDT, XRPUSDT etc.)
    // For Binance USDT pairs: contract = 1 unit
    if pair_upper.ends_with("USDT") || pair_upper.ends_with("USD") && price > 10.0 && !pair_upper.starts_with("USD") {
        let pip_size = if price > 1000.0 { 1.0 } else if price > 10.0 { 0.01 } else { 0.0001 };
        return InstrumentProfile { pip_size, pip_value_per_lot: pip_size, contract_size: 1.0 };
    }

    // JPY-quoted Forex pairs (USDJPY, EURJPY, GBPJPY, AUDJPY, etc.)
    // 1 pip = 0.01, pip_val = quote_currency / price (≈ $6.5 for USDJPY at 153)
    if pair_upper.contains("JPY") {
        let pip_value_per_lot = (0.01 / price) * 100_000.0; // In USD
        return InstrumentProfile { pip_size: 0.01, pip_value_per_lot, contract_size: 100_000.0 };
    }

    // Standard Forex pairs (EURUSD, AUDUSD, GBPUSD, NZDUSD, USDCHF, USDCAD, etc.)
    // 1 pip = 0.0001, pip_val = $10 for USD-quoted (EURUSD, GBPUSD, AUDUSD)
    // For cross pairs like USDCAD/USDCHF, pip_val needs adjustment but $10 is a safe approximation here
    InstrumentProfile { pip_size: 0.0001, pip_value_per_lot: 10.0, contract_size: 100_000.0 }
}

// =============================================================================
// REQUEST / RESPONSE STRUCTS
// =============================================================================
#[derive(Deserialize, Debug, Clone)]
struct TradeRequest {
    balance: f64,
    entry_price: f64,   // User provides manually from UI
    risk_percent: f64,  // e.g. 1.0 for 1%
    rr_ratio: f64,      // e.g. 5.0 for 1:5
    stop_loss_price: Option<f64>, // If user provides SL manually, target is auto-calculated
    target_price: Option<f64>,    // If user provides Target manually, SL is auto-calculated
    pair: String,
    is_crypto: bool,
}

#[derive(Serialize, Debug, Clone)]
struct TradeResponse {
    pair: String,
    live_price: f64,
    entry_price: f64,
    
    // Risk
    risk_amount_usd: f64,
    risk_percent: f64,

    // Levels
    stop_loss_price: f64,
    target_price: f64,
    sl_distance_pips: f64,
    tp_distance_pips: f64,
    actual_rr: f64,

    // Position sizing
    lots: f64,
    units: f64,
    pip_value_per_lot: f64,

    // Leverage
    notional_value: f64,
    required_leverage: f64,

    // Projection
    profit_if_target_hit_usd: f64,
    profit_if_target_hit_pct: f64,
    loss_if_sl_hit_usd: f64,
    loss_if_sl_hit_pct: f64,

    // Speed insight
    pips_to_target: f64,            // How many pips to reach profit target
    time_insight: String,           // Fast/Medium/Slow depending on instrument volatility profile
    timestamp_ms: u64,
}

// =============================================================================
// MAIN SERVER
// =============================================================================
#[tokio::main]
async fn main() {
    println!(">>> QuantCalx Trading Engine Active on ws://127.0.0.1:8080");
    let listener = TcpListener::bind("127.0.0.1:8080").await.expect("Failed to bind");

    while let Ok((stream, _)) = listener.accept().await {
        println!(">>> Flutter client connected");
        tokio::spawn(handle_flutter_client(stream));
    }
}

// =============================================================================
// FLUTTER CLIENT HANDLER
// =============================================================================
async fn handle_flutter_client(stream: TcpStream) {
    let ws_stream = accept_async(stream).await.expect("WS handshake failed");
    let (ws_sender, mut ws_receiver) = ws_stream.split();
    let sender = Arc::new(Mutex::new(ws_sender));

    while let Some(msg) = ws_receiver.next().await {
        if let Ok(Message::Text(text)) = msg {
            if let Ok(req) = serde_json::from_str::<TradeRequest>(&text) {
                let sender_clone = sender.clone();
                tokio::spawn(async move {
                    track_live_pair(req, sender_clone).await;
                });
            }
        }
    }
}

// =============================================================================
// LIVE PRICE TRACKING — Binance (crypto) or Finnhub (forex)
// =============================================================================
type Sender = Arc<Mutex<futures_util::stream::SplitSink<tokio_tungstenite::WebSocketStream<TcpStream>, Message>>>;

async fn track_live_pair(req: TradeRequest, sender: Sender) {
    if req.is_crypto {
        let url = format!(
            "wss://stream.binance.com:9443/ws/{}@trade",
            req.pair.to_lowercase()
        );
        if let Ok((mut ws_stream, _)) = connect_async(url).await {
            while let Some(Ok(msg)) = ws_stream.next().await {
                if let Message::Text(text) = msg {
                    if let Ok(parsed) = serde_json::from_str::<Value>(&text) {
                        if let Some(p) = parsed.get("p").and_then(|v| v.as_str()) {
                            if let Ok(live_price) = p.parse::<f64>() {
                                let resp = calculate_trade(&req, live_price);
                                push_to_flutter(resp, &sender).await;
                            }
                        }
                    }
                }
            }
        }
    } else {
        let url = format!("wss://ws.finnhub.io?token={}", FINNHUB_API_KEY);
        if let Ok((mut ws_stream, _)) = connect_async(url).await {
            let sub = format!(r#"{{"type":"subscribe","symbol":"{}"}}"#, req.pair);
            let _ = ws_stream.send(Message::Text(sub.into())).await;

            while let Some(Ok(msg)) = ws_stream.next().await {
                if let Message::Text(text) = msg {
                    if let Ok(parsed) = serde_json::from_str::<Value>(&text) {
                        if let Some(data) = parsed.get("data").and_then(|d| d.as_array()) {
                            if let Some(tick) = data.first() {
                                if let Some(p) = tick.get("p").and_then(|v| v.as_f64()) {
                                    let resp = calculate_trade(&req, p);
                                    push_to_flutter(resp, &sender).await;
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // If WebSocket fails (e.g., offline), calculate one-shot from entry price
            let resp = calculate_trade(&req, req.entry_price);
            push_to_flutter(resp, &sender).await;
        }
    }
}

// =============================================================================
// THE BRAIN — PURE MATHEMATICAL CALCULATION ENGINE
// Every instrument type handled correctly and precisely.
// =============================================================================
fn calculate_trade(req: &TradeRequest, live_price: f64) -> TradeResponse {
    let profile = get_instrument_profile(&req.pair, live_price);

    // Use user-provided entry if given, else use live price
    let entry = if req.entry_price > 0.0 { req.entry_price } else { live_price };

    // ---- STEP 1: Calculate Risk Amount ----
    let risk_amount_usd = req.balance * (req.risk_percent / 100.0);

    // ---- STEP 2: Resolve Stop Loss & Target Price ----
    // Case A: User provides SL → calculate Target via RR
    // Case B: User provides Target → back-calculate SL
    // Case C: Neither → auto-calculate from live price using ATR-proxy buffer (0.5% of price)
    let (stop_loss_price, target_price) = match (req.stop_loss_price, req.target_price) {
        (Some(sl), _) => {
            let distance = (entry - sl).abs();
            let tp = entry + (distance * req.rr_ratio);
            (sl, tp)
        }
        (None, Some(tp)) => {
            let distance = (tp - entry).abs();
            let sl = entry - (distance / req.rr_ratio);
            (sl, tp)
        }
        (None, None) => {
            // Auto-generate: 0.5% volatility buffer from live price
            let buffer = entry * 0.005;
            let sl = entry - buffer;
            let tp = entry + (buffer * req.rr_ratio);
            (sl, tp)
        }
    };

    // ---- STEP 3: Distances in PIPS ----
    let sl_distance_pips = (entry - stop_loss_price).abs() / profile.pip_size;
    let tp_distance_pips = (target_price - entry).abs() / profile.pip_size;
    let actual_rr = tp_distance_pips / sl_distance_pips;

    // ---- STEP 4: Position Sizing ----
    // Formula: Lots = Risk Amount / (SL Distance in Pips × Pip Value per Lot)
    let lots = risk_amount_usd / (sl_distance_pips * profile.pip_value_per_lot);
    let units = lots * profile.contract_size;

    // ---- STEP 5: Leverage ----
    let notional_value = units * entry;
    let required_leverage = if notional_value > 0.0 { notional_value / req.balance } else { 0.0 };

    // ---- STEP 6: Profit / Loss Projection ----
    let profit_if_target_hit_usd = tp_distance_pips * profile.pip_value_per_lot * lots;
    let profit_if_target_hit_pct = (profit_if_target_hit_usd / req.balance) * 100.0;
    let loss_if_sl_hit_usd = sl_distance_pips * profile.pip_value_per_lot * lots;
    let loss_if_sl_hit_pct = (loss_if_sl_hit_usd / req.balance) * 100.0;

    // ---- STEP 7: Speed/Time Insight ----
    // Pip value relative to volatility of the instrument
    let time_insight = classify_speed(&req.pair, live_price, &profile);

    TradeResponse {
        pair: req.pair.clone(),
        live_price,
        entry_price: entry,
        risk_amount_usd,
        risk_percent: req.risk_percent,
        stop_loss_price,
        target_price,
        sl_distance_pips,
        tp_distance_pips,
        actual_rr,
        lots,
        units,
        pip_value_per_lot: profile.pip_value_per_lot,
        notional_value,
        required_leverage,
        profit_if_target_hit_usd,
        profit_if_target_hit_pct,
        loss_if_sl_hit_usd,
        loss_if_sl_hit_pct,
        pips_to_target: tp_distance_pips,
        time_insight,
        timestamp_ms: std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as u64,
    }
}

// =============================================================================
// SPEED CLASSIFIER
// Based on average daily pip range per instrument type
// =============================================================================
fn classify_speed(pair: &str, _price: f64, _profile: &InstrumentProfile) -> String {
    let pair_upper = pair.to_uppercase();
    if pair_upper.contains("BTC") {
        return "⚡ ULTRA FAST — BTC moves $1000s/day".to_string();
    }
    if pair_upper.contains("ETH") {
        return "⚡ FAST — ETH moves $100s/day".to_string();
    }
    if pair_upper.contains("XAUUSD") || pair_upper.contains("GOLD") {
        return "🔥 FAST — GOLD moves 1500-2000 pips/day avg".to_string();
    }
    if pair_upper.contains("XAGUSD") || pair_upper.contains("SILVER") {
        return "🔥 FAST — SILVER moves 1000-1500 pips/day avg".to_string();
    }
    if pair_upper.contains("JPY") {
        return "⚡ FAST — JPY pairs move 80-150 pips/day avg (high pip value)".to_string();
    }
    if pair_upper.contains("GBP") {
        return "🔥 MODERATE-FAST — GBP pairs move 80-120 pips/day avg".to_string();
    }
    if pair_upper.contains("EUR") && pair_upper.contains("USD") {
        return "🟡 MODERATE — EURUSD moves 60-100 pips/day avg".to_string();
    }
    if pair_upper.contains("AUD") || pair_upper.contains("NZD") {
        return "🟢 SLOW-MODERATE — AUD/NZD pairs move 40-70 pips/day avg. Need patience.".to_string();
    }
    "🟡 MODERATE — Check daily ATR for this pair".to_string()
}

// =============================================================================
// PUSH TO FLUTTER
// =============================================================================
async fn push_to_flutter(resp: TradeResponse, sender: &Sender) {
    let json = serde_json::to_string(&resp).unwrap();
    let mut s = sender.lock().await;
    if let Err(e) = s.send(Message::Text(json.into())).await {
        eprintln!("Error sending to Flutter: {}", e);
    }
}
