import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart' show PairInfo;

// ─── INSTRUMENT PROFILE ─────────────────────────────────────────────────────
class _Prof {
  final double pipSize, pipValPerLot, contractSize;
  const _Prof(this.pipSize, this.pipValPerLot, this.contractSize);
}

_Prof _getProfile(String pair, double price) {
  if (pair == 'XAUUSD') return const _Prof(0.01, 1.0, 100.0);
  if (pair == 'BTCUSD') return const _Prof(1.0,  1.0, 1.0);
  if (pair == 'ETHUSD') return const _Prof(0.01, 1.0, 1.0);
  if (pair.contains('JPY')) return _Prof(0.01, (0.01 / price) * 100000, 100000.0);
  return const _Prof(0.0001, 10.0, 100000.0);
}



class _Result {
  final double sl, tp, slPips, tpPips, rr;
  final double riskUsd, lots, units, pipVal;
  final double notional;
  final double profitUsd, profitPct, lossUsd, lossPct;
  const _Result({
    required this.sl, required this.tp, required this.slPips, required this.tpPips, required this.rr,
    required this.riskUsd, required this.lots, required this.units, required this.pipVal,
    required this.notional,
    required this.profitUsd, required this.profitPct, required this.lossUsd, required this.lossPct,
  });
}

_Result? _calc({required String pair, required double balance, required double entry,
  required double riskPct, required double rrRatio, required bool isBuy, double? slP}) {
  if (balance <= 0 || entry <= 0 || riskPct <= 0 || rrRatio <= 0) return null;
  final p = _getProfile(pair, entry);
  final riskUsd = balance * (riskPct / 100);
  
  double sl, tp;
  if (slP != null && slP > 0) { 
    sl = slP; 
    // Validation constraint: Stop Loss MUST be strictly below entry for BUY. Above entry for SELL.
    if (isBuy && sl >= entry) sl = entry - (entry * 0.005);
    if (!isBuy && sl <= entry) sl = entry + (entry * 0.005);
  } else { 
    final buf = entry * 0.005; 
    sl = isBuy ? entry - buf : entry + buf; 
  }
  
  final slDist = (entry - sl).abs();
  // Prevent divide by zero (SL identical to entry price)
  if (slDist == 0) return null;

  tp = isBuy ? entry + (slDist * rrRatio) : entry - (slDist * rrRatio);

  final slPips = slDist / p.pipSize;
  final tpPips = (tp - entry).abs() / p.pipSize;
  final lots = riskUsd / (slPips * p.pipValPerLot);
  if (lots.isInfinite || lots.isNaN) return null; // Edge case protection

  final units = lots * p.contractSize;
  final notional = units * entry;
  final profitUsd = tpPips * p.pipValPerLot * lots;
  final lossUsd   = slPips * p.pipValPerLot * lots;

  return _Result(sl: sl, tp: tp, slPips: slPips, tpPips: tpPips, rr: rrRatio,
    riskUsd: riskUsd, lots: lots, units: units, pipVal: p.pipValPerLot,
    notional: notional,
    profitUsd: profitUsd, profitPct: (profitUsd / balance) * 100,
    lossUsd: lossUsd,    lossPct:  (lossUsd / balance) * 100);
}

// =============================================================================
// SCREEN
// =============================================================================
class CalculatorScreen extends StatefulWidget {
  final PairInfo pair;
  const CalculatorScreen({super.key, required this.pair});
  @override State<CalculatorScreen> createState() => _CalcState();
}

class _CalcState extends State<CalculatorScreen> with SingleTickerProviderStateMixin {
  final _bal  = TextEditingController();
  final _ent  = TextEditingController();
  final _risk = TextEditingController(text: '1');
  final _rr   = TextEditingController(text: '1');
  final _sl   = TextEditingController();
  final _tp   = TextEditingController();
  final _lots = TextEditingController();
  final _pips = TextEditingController(); // SL Pips
  final _tPips = TextEditingController(); // TP Pips

  bool _isBuy = true;
  bool _riskInDollars = false;
  int  _rrMode = 0; // 0=Ratio, 1=Percent, 2=Dollar

  final _riskDollar   = TextEditingController();
  final _rewardPct    = TextEditingController();
  final _rewardDollar = TextEditingController();
  
  final _tUsd = TextEditingController(); // Target $
  final _slUsd = TextEditingController(); // SL $

  _Result? _r;
  String?  _err;
  late AnimationController _ac;
  late Animation<double>   _fade;

  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    // Auto-mirror risk value into reward ratio (mode 0) when user types risk
    _risk.addListener(() {
      if (_rrMode == 0 && _rr.text.isEmpty) {
        _rr.text = _risk.text;
      }
    });
  }
  @override void dispose() {
    _ac.dispose();
    for (final c in [_bal, _ent, _risk, _rr, _sl, _tp, _lots, _pips, _tPips,
                     _riskDollar, _rewardPct, _rewardDollar, _tUsd, _slUsd]) c.dispose();
    super.dispose();
  }

  /// Clears all trade fields and resets results (keeps balance).
  void _clearAll() {
    FocusScope.of(context).unfocus();
    for (final c in [_ent, _sl, _tp, _lots, _pips, _tPips, _riskDollar, _rewardPct, _rewardDollar, _tUsd, _slUsd]) {
      c.clear();
    }
    _risk.text = '1';
    _rr.text   = '1';
    setState(() { _r = null; _err = null; _ac.reset(); });
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    setState(() => _err = null);

    final b = double.tryParse(_bal.text);
    double? e = double.tryParse(_ent.text);
    double? r;
    double? rr;

    // Resolve Risk from mode
    if (_rrMode == 2) {
      final rAmt = double.tryParse(_riskDollar.text);
      if (b != null && b > 0 && rAmt != null && rAmt > 0) {
        r = (rAmt / b) * 100;
        _risk.text = r.toStringAsFixed(2);
      }
    } else {
      r = double.tryParse(_risk.text);
    }

    // Resolve R:R from mode
    switch (_rrMode) {
      case 0:
        rr = double.tryParse(_rr.text);
        break;
      case 1:
        final rewardPct = double.tryParse(_rewardPct.text);
        final riskPctVal = double.tryParse(_risk.text);
        if (riskPctVal != null && riskPctVal > 0 && rewardPct != null && rewardPct > 0) {
          r = riskPctVal;
          rr = rewardPct / r;
          _rr.text = rr.toStringAsFixed(2);
        }
        break;
      case 2:
        final riskAmt   = double.tryParse(_riskDollar.text);
        final rewardAmt = double.tryParse(_rewardDollar.text);
        if (b != null && b > 0 && riskAmt != null && riskAmt > 0) {
          r = (riskAmt / b) * 100;
          _risk.text = r.toStringAsFixed(2);
          if (rewardAmt != null && rewardAmt > 0) {
            rr = rewardAmt / riskAmt;
            _rr.text = rr.toStringAsFixed(2);
          }
        }
        break;
    }

    double? sl = double.tryParse(_sl.text);
    double? tp = double.tryParse(_tp.text);
    double? slPips = double.tryParse(_pips.text);
    double? tpPips = double.tryParse(_tPips.text);
    double? lots = double.tryParse(_lots.text);

    if (b == null || b <= 0)  { setState(() => _err = 'Enter valid balance'); return; }

    // SOLVE FOR X LOGIC
    final p = _getProfile(widget.pair.symbol, e ?? 1.0);

    // 1. Missing Entry: We need Target, SL, and RR to figure it out
    if (e == null || e <= 0) {
      if (sl != null && tp != null && rr != null && rr > 0) {
         e = (tp + (rr * sl)) / (1 + rr);
         _ent.text = _fX(e);
      } else {
         setState(() => _err = 'Enter Entry Price (or provide SL, TP, & RR to auto-calculate)'); return;
      }
    }

    // Auto-calculate SL price from SL Pips if SL price is missing
    if ((sl == null || sl <= 0) && slPips != null && slPips > 0) {
      final slDist = slPips * p.pipSize;
      sl = _isBuy ? e - slDist : e + slDist;
      _sl.text = _fX(sl);
    }

    // Auto-calculate TP price from TP Pips if TP price is missing
    if ((tp == null || tp <= 0) && tpPips != null && tpPips > 0) {
      final tpDist = tpPips * p.pipSize;
      tp = _isBuy ? e + tpDist : e - tpDist;
      _tp.text = _fX(tp);
    }

    // Auto-calculate Risk % from manual Lots and SL (or SL Pips)
    if ((r == null || r <= 0) && lots != null && lots > 0) {
      if (sl != null && sl > 0) {
        final dist = (e - sl).abs();
        final actualPips = dist / p.pipSize;
        final riskUsd = lots * actualPips * p.pipValPerLot;
        r = (riskUsd / b) * 100;
        _risk.text = r.toStringAsFixed(2);
      }
    }

    // 2. We have Entry. Check Risk.
    if (r == null || r <= 0) r = 1.0; // Default risk is 1.0%

    // 3. Missing SL, Missing Target, Missing RR -> Provide Sane Defaults
    if (sl == null && tp == null && rr == null) {
      rr = 2.0; 
      _rr.text = '2.0';
    }

    // 4. Missing RR -> Figure out from SL and TP
    if ((rr == null || rr <= 0) && sl != null && tp != null) {
       final distSL = (e - sl).abs();
       final distTP = (tp - e).abs();
       if (distSL > 0) {
         rr = distTP / distSL;
         _rr.text = rr.toStringAsFixed(2);
       } else {
         setState(() => _err = 'SL cannot equal Entry'); return;
       }
    }

    // 5. Missing SL -> Figure out from TP and RR
    if ((sl == null || sl <= 0) && tp != null && rr != null && rr > 0) {
       final distTP = (tp - e).abs();
       final distSL = distTP / rr;
       sl = _isBuy ? e - distSL : e + distSL;
       _sl.text = _fX(sl);
    }

    // 6. Missing TP -> Figure out from SL and RR
    if ((tp == null || tp <= 0) && sl != null && sl > 0 && rr != null && rr > 0) {
       final distSL = (e - sl).abs();
       tp = _isBuy ? e + (distSL * rr) : e - (distSL * rr);
       _tp.text = _fX(tp);
    }

    // Final Validation after Auto-Fill
    if (rr == null || rr <= 0) { setState(() => _err = 'Enter valid R:R or SL/TP combo'); return; }

    setState(() => _r = _calc(pair: widget.pair.symbol, balance: b, entry: e!, riskPct: r!, rrRatio: rr!,
      isBuy: _isBuy, slP: sl));
    
    // Auto fill visuals
    if (_r != null) {
      _tp.text = _fX(_r!.tp);
      _sl.text = _fX(_r!.sl);
      _lots.text = _r!.lots.toStringAsFixed(2);
      _pips.text = _f2(_r!.slPips);
      _tPips.text = _f2(_r!.tpPips);
      _tUsd.text = _r!.profitUsd.toStringAsFixed(2);
      _slUsd.text = _r!.lossUsd.toStringAsFixed(2);
    }

    _ac.forward(from: 0);
  }

  String _fX(double v) {
    if (v.abs() >= 10000) return v.toStringAsFixed(2);
    if (v.abs() >= 1)     return v.toStringAsFixed(4);
    return v.toStringAsFixed(5);
  }

  @override Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg   = isDark ? kDarkBg      : kLightBg;
    final card = isDark ? kDarkCard    : kLightCard;
    final text = isDark ? kDarkText    : kLightText;
    final sub  = isDark ? kDarkSubText : kLightSubText;
    final p    = widget.pair;
    // Direction-aware accent: GREEN for BUY, RED for SELL
    final dirColor = _isBuy ? const Color(0xFF00C853) : Colors.redAccent;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: Column(children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 16, 0),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: dirColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: dirColor.withValues(alpha: 0.4)),
              ),
              child: Text(p.label, style: TextStyle(color: dirColor, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8)),
              child: Text(p.category, style: TextStyle(color: sub, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
            const Spacer(),
            // CLEAR button
            GestureDetector(
              onTap: _clearAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Text('CLEAR', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              _sec('TRADE ORDERS', sub),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_isBuy) return; // already BUY, do nothing
                      _clearAll();
                      setState(() { _isBuy = true; });
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isBuy ? Colors.green.withValues(alpha: 0.15) : card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isBuy ? Colors.green : Colors.transparent),
                      ),
                      alignment: Alignment.center,
                      child: Text('BUY', style: TextStyle(color: _isBuy ? Colors.greenAccent : text, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!_isBuy) return; // already SELL, do nothing
                      _clearAll();
                      setState(() { _isBuy = false; });
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: !_isBuy ? Colors.red.withValues(alpha: 0.15) : card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: !_isBuy ? Colors.red : Colors.transparent),
                      ),
                      alignment: Alignment.center,
                      child: Text('SELL', style: TextStyle(color: !_isBuy ? Colors.redAccent : text, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              _sec('AMOUNT & ENTRY PRICE', sub),
              const SizedBox(height: 8),
              _inpRow('Amount', _bal, '', isDark, text, dirColor),
              const SizedBox(height: 8),
              _inpRow('Entry Price', _ent, '', isDark, text, dirColor),
              const SizedBox(height: 20),

              _sec('RISK : REWARD', sub),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? kDarkCard : kLightCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  _rrTab('Ratio ( : )', 0, dirColor, isDark, text),
                  const SizedBox(width: 4),
                  _rrTab('Percent ( % )', 1, dirColor, isDark, text),
                  const SizedBox(width: 4),
                  _rrTab('USD ( \$ )', 2, dirColor, isDark, text),
                ]),
              ),
              const SizedBox(height: 20),

              _sec('RISK', sub),
              const SizedBox(height: 8),
              if (_rrMode == 0 || _rrMode == 1) _inpRow('RISK % OF BALANCE', _risk, 'e.g. 1 means 1%', isDark, text, dirColor),
              if (_rrMode == 2) _inpRow('RISK AMOUNT (USD)', _riskDollar, 'e.g. 100', isDark, text, dirColor),
              const SizedBox(height: 20),

              if (_rrMode == 0) _inpRow('REWARD RATIO   1 :', _rr, 'e.g. 3 means 1:3', isDark, text, dirColor),
              if (_rrMode == 1) _inpRow('REWARD % OF BALANCE', _rewardPct, 'e.g. 3%', isDark, text, dirColor),
              if (_rrMode == 2) _inpRow('PROFIT TARGET (USD)', _rewardDollar, 'e.g. 500', isDark, text, dirColor),
              const SizedBox(height: 20),
              
              _sec('Target & Stop Loss', sub),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _inpCol('TARGET', _tp, '', isDark, text, dirColor)),
                const SizedBox(width: 12),
                Expanded(child: _inpCol('STOP LOSS', _sl, '', isDark, text, dirColor)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _inpCol('TP PIPS', _tPips, 'Auto', isDark, text, dirColor)),
                const SizedBox(width: 12),
                Expanded(child: _inpCol('SL PIPS', _pips, 'Auto', isDark, text, dirColor)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _inpCol(r'TARGET ( $ )', _tUsd, 'Auto', isDark, text, dirColor)),
                const SizedBox(width: 12),
                Expanded(child: _inpCol(r'SL ( $ )', _slUsd, 'Auto', isDark, text, dirColor)),
              ]),
              const SizedBox(height: 20),
              _sec('Lot Size', sub),
              const SizedBox(height: 8),
              _inpRow('LOT SIZE', _lots, 'Auto calculate', isDark, text, dirColor),
              const SizedBox(height: 24),

              if (_err != null) ...[
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                  child: Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
              ],

              // CALCULATE button
              _GlowBtn(label: _isBuy ? '▲  CALCULATE BUY' : '▼  CALCULATE SELL', color: dirColor, onTap: _calculate),

              // Results
              if (_r != null)
                FadeTransition(opacity: _fade, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 22),
                  Divider(color: isDark ? Colors.white10 : Colors.black12),
                  const SizedBox(height: 14),

                  Row(children: [
                    _card('STOP LOSS', '\$${_f(_r!.sl)}', Colors.redAccent, '${_f2(_r!.slPips)} pips', card, isDark),
                    const SizedBox(width: 10),
                    _card('TAKE PROFIT', '\$${_f(_r!.tp)}', const Color(0xFF00C853), '${_f2(_r!.tpPips)} pips', card, isDark),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _card('LOT SIZE', _r!.lots.toStringAsFixed(4), text, '${_fL(_r!.units)} units', card, isDark),
                    const SizedBox(width: 10),
                    _card('PIP VALUE', '\$${_f(_r!.pipVal)}', const Color(0xFF29B6F6), 'per standard lot', card, isDark),
                  ]),

                  const SizedBox(height: 18),
                  _sec('PROFIT / LOSS PROJECTION', sub),
                  const SizedBox(height: 10),

                  Row(children: [
                    _plCard('✅ TARGET HIT', '+\$${_r!.profitUsd.toStringAsFixed(2)}',
                      '+${_r!.profitPct.toStringAsFixed(2)}% of account', const Color(0xFF00C853), card),
                    const SizedBox(width: 10),
                    _plCard('🛑 SL HIT', '-\$${_r!.lossUsd.toStringAsFixed(2)}',
                      '-${_r!.lossPct.toStringAsFixed(2)}% of account', Colors.redAccent, card),
                  ]),
                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _r!.riskUsd.toStringAsFixed(2)));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Risk Amount copied!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: card, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: 0.28)),
                      ),
                      child: Row(children: [
                        Icon(Icons.shield_outlined, color: const Color(0xFFFF7043).withValues(alpha: 0.8), size: 22),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('MAX RISK AMOUNT', style: TextStyle(color: sub, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text('\$${_r!.riskUsd.toStringAsFixed(2)}  (${_r!.lossPct.toStringAsFixed(2)}% of balance)',
                            style: const TextStyle(color: Color(0xFFFF7043), fontSize: 17, fontWeight: FontWeight.w900)),
                        ]),
                      ]),
                    ),
                  ),
                ])),
            ]),
          ),
        ),
      ])),
    );
  }

  Widget _sec(String t, Color c) => Text(t,
    style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5));

  Widget _rrTab(String label, int mode, Color accent, bool isDark, Color text) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() { _rrMode = mode; _r = null; _ac.reset(); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _rrMode == mode ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          color: _rrMode == mode ? Colors.white : (isDark ? kDarkSubText : kLightSubText),
          fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5,
        )),
      ),
    ),
  );

  Widget _inpCol(String label, TextEditingController ctrl, String hint, bool isDark, Color text, Color accent) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      const SizedBox(height: 6),
      Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : kLightCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: text),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent, width: 1.5)),
          ),
        ),
      ),
    ]);

  Widget _inpRow(String label, TextEditingController ctrl, String hint, bool isDark, Color text, Color accent) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kLightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        Expanded(
          flex: 3,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ]),
    );

  Widget _card(String title, String val, Color color, String sub, Color card, bool isDark) => Expanded(
    child: GestureDetector(
      onTap: () {
        final copyVal = val.replaceAll(RegExp(r'[^\d.\-]'), '');
        Clipboard.setData(ClipboardData(text: copyVal));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$title copied ($copyVal)!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: isDark ? kDarkSubText : kLightSubText, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 7),
          FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
            child: Text(val, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace'))),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: color.withValues(alpha: 0.55), fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      ),
    ),
  );

  Widget _plCard(String title, String val, String sub, Color color, Color card) => Expanded(
    child: GestureDetector(
      onTap: () {
        final copyVal = val.replaceAll(RegExp(r'[^\d.\-]'), '');
        Clipboard.setData(ClipboardData(text: copyVal));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$title copied ($copyVal)!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 7),
          FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
            child: Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace'))),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      ),
    ),
  );

  String _f(double v) {
    if (v.abs() >= 10000) return v.toStringAsFixed(2);
    if (v.abs() >= 1)     return v.toStringAsFixed(4);
    return v.toStringAsFixed(5);
  }
  String _f2(double v) => v >= 100 ? v.toStringAsFixed(1) : v.toStringAsFixed(2);
  String _fL(double v) {
    if (v >= 1e6)  return '${(v/1e6).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v/1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }
}

// ─── GLOW BUTTON ─────────────────────────────────────────────────────────────
class _GlowBtn extends StatefulWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _GlowBtn({required this.label, required this.color, required this.onTap});
  @override State<_GlowBtn> createState() => _GlowBtnState();
}
class _GlowBtnState extends State<_GlowBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _sc;
  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _sc = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ScaleTransition(scale: _sc,
    child: GestureDetector(
      onTapDown: (_) => _ac.forward(), onTapUp: (_) { _ac.reverse(); widget.onTap(); },
      onTapCancel: () => _ac.reverse(),
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          color: widget.color, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
      ),
    ),
  );
}
