import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const UltraProTradingApp());
}

// ─── CONSTANTS ────────────────────────────────────────────────────────────────
const kBg     = Color(0xFF07090F);
const kSurface = Color(0xFF0E1420);
const kCard   = Color(0xFF131C2B);
const kGreen  = Color(0xFF00E676);
const kBlue   = Color(0xFF29B6F6);
const kAmber  = Color(0xFFFFC107);
const kRed    = Color(0xFFEF5350);
const kOrange = Color(0xFFFF7043);

// ─── PAIR DATA ────────────────────────────────────────────────────────────────
class PairInfo {
  final String symbol;
  final String label;
  final String category; // FOREX / METAL / CRYPTO
  final Color  accent;
  const PairInfo(this.symbol, this.label, this.category, this.accent);
}

const _pairs = [
  PairInfo('AUDUSD', 'AUD/USD', 'FOREX',  Color(0xFF4CAF50)),
  PairInfo('EURUSD', 'EUR/USD', 'FOREX',  Color(0xFF42A5F5)),
  PairInfo('GBPUSD', 'GBP/USD', 'FOREX',  Color(0xFF7C4DFF)),
  PairInfo('NZDUSD', 'NZD/USD', 'FOREX',  Color(0xFF00BCD4)),
  PairInfo('USDCAD', 'USD/CAD', 'FOREX',  Color(0xFFFF5722)),
  PairInfo('USDCHF', 'USD/CHF', 'FOREX',  Color(0xFFE91E63)),
  PairInfo('USDJPY', 'USD/JPY', 'FOREX',  Color(0xFFFF9800)),
  PairInfo('XAUUSD', 'XAU/USD', 'METAL',  Color(0xFFFFD700)),
  PairInfo('BTCUSD', 'BTC/USD', 'CRYPTO', Color(0xFFF7931A)),
  PairInfo('ETHUSD', 'ETH/USD', 'CRYPTO', Color(0xFF627EEA)),
];

// ─── INSTRUMENT PROFILE ────────────────────────────────────────────────────────
class _Profile {
  final double pipSize, pipValuePerLot, contractSize;
  const _Profile(this.pipSize, this.pipValuePerLot, this.contractSize);
}

_Profile _getProfile(String pair, double price) {
  if (pair == 'XAUUSD') return const _Profile(0.01,   1.0,    100.0);
  if (pair == 'BTCUSD' || pair == 'BTCUSDT') return const _Profile(1.0, 1.0, 1.0);
  if (pair == 'ETHUSD' || pair == 'ETHUSD')  return const _Profile(0.01, 1.0, 1.0);
  if (pair.contains('JPY')) {
    final pv = (0.01 / price) * 100000;
    return _Profile(0.01, pv, 100000.0);
  }
  return const _Profile(0.0001, 10.0, 100000.0);
}

String _speedTag(String pair) {
  if (pair == 'BTCUSD') return '⚡ ULTRA FAST — BTC moves \$1000s/day';
  if (pair == 'ETHUSD') return '⚡ FAST — ETH moves \$100s/day';
  if (pair == 'XAUUSD') return '🔥 FAST — Gold ~1500 pips/day';
  if (pair == 'USDJPY') return '⚡ FAST — JPY 80–150 pips/day (high pip \$)';
  if (pair == 'GBPUSD') return '🔥 MODERATE-FAST — GBP 80–120 pips/day';
  if (pair == 'EURUSD') return '🟡 MODERATE — EUR 60–100 pips/day';
  if (pair == 'AUDUSD' || pair == 'NZDUSD') return '🟢 SLOW — AUD/NZD 40–70 pips/day, need patience';
  return '🟡 MODERATE — Check ATR for this pair';
}

// ─── CALCULATION RESULT ────────────────────────────────────────────────────────
class _Result {
  final double entry, sl, tp, slPips, tpPips, rr;
  final double riskUsd, lots, units, pipVal;
  final double notional, lev;
  final double profitUsd, profitPct, lossUsd, lossPct;
  final String speed;
  const _Result({
    required this.entry, required this.sl, required this.tp,
    required this.slPips, required this.tpPips, required this.rr,
    required this.riskUsd, required this.lots, required this.units, required this.pipVal,
    required this.notional, required this.lev,
    required this.profitUsd, required this.profitPct,
    required this.lossUsd, required this.lossPct, required this.speed,
  });
}

_Result? _calc({
  required String pair, required double balance, required double entry,
  required double riskPct, required double rrRatio,
  double? slPrice, double? tpPrice,
}) {
  if (balance <= 0 || entry <= 0 || riskPct <= 0 || rrRatio <= 0) return null;
  final prof = _getProfile(pair, entry);
  final riskUsd = balance * (riskPct / 100.0);

  double sl, tp;
  if (slPrice != null && slPrice > 0) {
    sl = slPrice;
    tp = entry + (entry - sl).abs() * rrRatio;
  } else if (tpPrice != null && tpPrice > 0) {
    tp = tpPrice;
    sl = entry - (tp - entry).abs() / rrRatio;
  } else {
    final buf = entry * 0.005;
    sl = entry - buf;
    tp = entry + buf * rrRatio;
  }

  final slPips  = (entry - sl).abs() / prof.pipSize;
  final tpPips  = (tp - entry).abs() / prof.pipSize;
  final actualRR = tpPips / slPips;
  final lots     = riskUsd / (slPips * prof.pipValuePerLot);
  final units    = lots * prof.contractSize;
  final notional = units * entry;
  final lev      = notional > 0 ? notional / balance : 0.0;
  final profitUsd = tpPips * prof.pipValuePerLot * lots;
  final lossUsd   = slPips * prof.pipValuePerLot * lots;

  return _Result(
    entry: entry, sl: sl, tp: tp,
    slPips: slPips, tpPips: tpPips, rr: actualRR,
    riskUsd: riskUsd, lots: lots, units: units, pipVal: prof.pipValuePerLot,
    notional: notional, lev: lev,
    profitUsd: profitUsd, profitPct: (profitUsd / balance) * 100,
    lossUsd:   lossUsd,  lossPct:  (lossUsd / balance) * 100,
    speed: _speedTag(pair),
  );
}

// =============================================================================
// APP
// =============================================================================
class UltraProTradingApp extends StatelessWidget {
  const UltraProTradingApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'QuantCalx',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(primary: kGreen, secondary: kBlue, surface: kSurface),
    ),
    home: const _HomePage(),
  );
}

// =============================================================================
// HOME — Pair selection
// =============================================================================
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 30),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.candlestick_chart_rounded, color: kGreen, size: 28),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('QUANTCALX', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3)),
                  Text('Professional Risk Calculator', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 8),
            ]),
          ),

          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('SELECT INSTRUMENT', style: TextStyle(color: Colors.white30, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),

          // Pair grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                itemCount: _pairs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.4,
                ),
                itemBuilder: (ctx, i) => _PairCard(pair: _pairs[i]),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _PairCard extends StatefulWidget {
  final PairInfo pair;
  const _PairCard({required this.pair});
  @override State<_PairCard> createState() => _PairCardState();
}

class _PairCardState extends State<_PairCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final p = widget.pair;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async {
        await _ctrl.reverse();
        if (context.mounted) {
          Navigator.push(context, PageRouteBuilder(
            pageBuilder: (_, a, __) => _CalcPage(pair: p),
            transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(
                  CurvedAnimation(parent: a, curve: Curves.easeOut),
                ),
                child: child,
              ),
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ));
        }
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.accent.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.05), blurRadius: 12, spreadRadius: 2)],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(p.category == 'CRYPTO' ? '₿' : p.category == 'METAL' ? '⚡' : '💱',
                style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(p.label, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              Text(p.category, style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// CALC PAGE — per-pair calculator
// =============================================================================
class _CalcPage extends StatefulWidget {
  final PairInfo pair;
  const _CalcPage({required this.pair});
  @override State<_CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<_CalcPage> with SingleTickerProviderStateMixin {
  final _balanceCtrl = TextEditingController(text: '10000');
  final _entryCtrl   = TextEditingController();
  final _riskCtrl    = TextEditingController(text: '1.0');
  final _rrCtrl      = TextEditingController(text: '5.0');
  final _slCtrl      = TextEditingController();
  final _tpCtrl      = TextEditingController();
  _Result? _result;
  String?  _error;
  late AnimationController _resAnim;
  late Animation<double> _resFade;

  @override void initState() {
    super.initState();
    _resAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _resFade = CurvedAnimation(parent: _resAnim, curve: Curves.easeOut);
  }
  @override void dispose() {
    _resAnim.dispose();
    for (final c in [_balanceCtrl, _entryCtrl, _riskCtrl, _rrCtrl, _slCtrl, _tpCtrl]) c.dispose();
    super.dispose();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final balance = double.tryParse(_balanceCtrl.text);
    final entry   = double.tryParse(_entryCtrl.text);
    final risk    = double.tryParse(_riskCtrl.text);
    final rr      = double.tryParse(_rrCtrl.text);
    final sl      = double.tryParse(_slCtrl.text);
    final tp      = double.tryParse(_tpCtrl.text);

    if (balance == null || balance <= 0) { setState(() => _error = 'Enter a valid balance'); return; }
    if (entry == null || entry <= 0)     { setState(() => _error = 'Enter a valid entry price'); return; }
    if (risk == null || risk <= 0)       { setState(() => _error = 'Enter a valid risk % (e.g. 1.0)'); return; }
    if (rr == null || rr <= 0)           { setState(() => _error = 'Enter a valid R:R ratio (e.g. 5.0)'); return; }

    final res = _calc(
      pair: widget.pair.symbol, balance: balance, entry: entry,
      riskPct: risk, rrRatio: rr,
      slPrice: (sl != null && sl > 0) ? sl : null,
      tpPrice: (tp != null && tp > 0) ? tp : null,
    );
    setState(() => _result = res);
    _resAnim.forward(from: 0);
  }

  void _clear() {
    _resAnim.reverse();
    setState(() { _result = null; _error = null; });
    for (final c in [_entryCtrl, _slCtrl, _tpCtrl]) c.clear();
  }

  @override Widget build(BuildContext context) {
    final p = widget.pair;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(children: [
          // ─── TOP BAR ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.accent.withValues(alpha: 0.3)),
                ),
                child: Text(p.label, style: TextStyle(color: p.accent, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8)),
                child: Text(p.category, style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ]),
          ),

          // ─── SCROLLABLE BODY ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Speed insight
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kCard, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 4),
                    Expanded(child: Text(_speedTag(p.symbol),
                      style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600))),
                  ]),
                ),
                const SizedBox(height: 18),

                _sectionLabel('TRADE PARAMETERS'),
                const SizedBox(height: 10),

                Row(children: [
                  Expanded(child: _inp('BALANCE (\$)', _balanceCtrl, hint: '10000')),
                  const SizedBox(width: 10),
                  Expanded(child: _inp('ENTRY PRICE', _entryCtrl, hint: 'e.g. 1.0850')),
                ]),
                Row(children: [
                  Expanded(child: _inp('RISK %', _riskCtrl, hint: '1.0')),
                  const SizedBox(width: 10),
                  Expanded(child: _inp('REWARD RATIO (1:X)', _rrCtrl, hint: '5.0')),
                ]),

                const SizedBox(height: 6),
                _sectionLabel('OPTIONAL — Provide SL or TP (other auto-calculates)'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _inp('STOP LOSS', _slCtrl, hint: 'Optional')),
                  const SizedBox(width: 10),
                  Expanded(child: _inp('TARGET PRICE', _tpCtrl, hint: 'Optional')),
                ]),
                const SizedBox(height: 6),

                // Error
                if (_error != null) ...[
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kRed.withValues(alpha: 0.35)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                ],

                // Buttons
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: _GlowButton(
                      label: '▶  CALCULATE',
                      color: p.accent,
                      onTap: _calculate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _clear,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: const Text('CLEAR', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),

                // ─── RESULTS ──────────────────────────────────────────────
                if (_result != null)
                  FadeTransition(
                    opacity: _resFade,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 14),

                      // SL / TP
                      Row(children: [
                        _statCard('STOP LOSS', '\$${_f(_result!.sl)}', kRed,
                          sub: '${_f2(_result!.slPips)} pips', accent: p.accent),
                        const SizedBox(width: 10),
                        _statCard('TAKE PROFIT', '\$${_f(_result!.tp)}', kGreen,
                          sub: '${_f2(_result!.tpPips)} pips', accent: p.accent),
                      ]),
                      const SizedBox(height: 10),

                      // RR / Leverage
                      Row(children: [
                        _statCard('ACTUAL R:R', '1 : ${_result!.rr.toStringAsFixed(2)}', kAmber,
                          sub: 'Reward Ratio', accent: p.accent),
                        const SizedBox(width: 10),
                        _statCard('LEVERAGE', '${_result!.lev.toStringAsFixed(1)}x', kOrange,
                          sub: '\$${_fL(_result!.notional)} notional', accent: p.accent),
                      ]),
                      const SizedBox(height: 10),

                      // Lots / Pip
                      Row(children: [
                        _statCard('LOT SIZE', _result!.lots.toStringAsFixed(4), Colors.white,
                          sub: '${_fL(_result!.units)} units', accent: p.accent),
                        const SizedBox(width: 10),
                        _statCard('PIP VALUE', '\$${_f(_result!.pipVal)}', kBlue,
                          sub: 'per standard lot', accent: p.accent),
                      ]),

                      const SizedBox(height: 18),
                      _sectionLabel('PROFIT / LOSS PROJECTION'),
                      const SizedBox(height: 8),

                      // P&L
                      Row(children: [
                        _plCard(
                          '✅  TARGET HIT',
                          '+\$${_result!.profitUsd.toStringAsFixed(2)}',
                          '+${_result!.profitPct.toStringAsFixed(2)}% of account',
                          kGreen,
                        ),
                        const SizedBox(width: 10),
                        _plCard(
                          '🛑  STOP HIT',
                          '-\$${_result!.lossUsd.toStringAsFixed(2)}',
                          '-${_result!.lossPct.toStringAsFixed(2)}% of account',
                          kRed,
                        ),
                      ]),
                      const SizedBox(height: 10),

                      // Risk summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kCard, borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kOrange.withValues(alpha: 0.28)),
                        ),
                        child: Row(children: [
                          Icon(Icons.shield_outlined, color: kOrange.withValues(alpha: 0.8), size: 22),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('MAX RISK AMOUNT', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            const SizedBox(height: 4),
                            Text('\$${_result!.riskUsd.toStringAsFixed(2)}  (${_result!.lossPct.toStringAsFixed(2)}% of balance)',
                              style: const TextStyle(color: kOrange, fontSize: 17, fontWeight: FontWeight.w900)),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // Helpers
  Widget _sectionLabel(String t) => Text(t,
    style: const TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold));

  Widget _inp(String label, TextEditingController ctrl, {String hint = ''}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          filled: true, fillColor: kCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.pair.accent.withValues(alpha: 0.5)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    ]),
  );

  Widget _statCard(String title, String value, Color color, {String? sub, required Color accent}) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 7),
        FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace'))),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: color.withValues(alpha: 0.55), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ]),
    ),
  );

  Widget _plCard(String title, String value, String sub, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace'))),
        const SizedBox(height: 5),
        Text(sub, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    ),
  );

  String _f(double v) {
    if (v.abs() >= 10000) return v.toStringAsFixed(2);
    if (v.abs() >= 1)     return v.toStringAsFixed(4);
    return v.toStringAsFixed(5);
  }
  String _f2(double v) => v >= 100 ? v.toStringAsFixed(1) : v.toStringAsFixed(2);
  String _fL(double v) {
    if (v >= 1e6) return '${(v/1e6).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v/1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }
}

// =============================================================================
// GLOW BUTTON — animated press with glow shadow
// =============================================================================
class _GlowButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GlowButton({required this.label, required this.color, required this.onTap});
  @override State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 0, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Text(widget.label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
      ),
    ),
  );
}
