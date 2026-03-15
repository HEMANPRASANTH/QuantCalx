import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/settings_screen.dart';
import 'calculator_screen.dart';

// ─── PAIR DATA ────────────────────────────────────────────────────────────────
class PairInfo {
  final String symbol, label, category;
  final Color accent;
  const PairInfo(this.symbol, this.label, this.category, this.accent);
}

const _pairs = [
  PairInfo('AUDUSD', 'AUD/USD', 'FOREX',  Color(0xFF26A69A)),
  PairInfo('EURUSD', 'EUR/USD', 'FOREX',  Color(0xFF42A5F5)),
  PairInfo('GBPUSD', 'GBP/USD', 'FOREX',  Color(0xFF7C4DFF)),
  PairInfo('NZDUSD', 'NZD/USD', 'FOREX',  Color(0xFF00BCD4)),
  PairInfo('USDCAD', 'USD/CAD', 'FOREX',  Color(0xFFFF7043)),
  PairInfo('USDCHF', 'USD/CHF', 'FOREX',  Color(0xFFEC407A)),
  PairInfo('USDJPY', 'USD/JPY', 'FOREX',  Color(0xFFFF9800)),
  PairInfo('XAUUSD', 'XAU/USD', 'METAL',  Color(0xFFFFD700)),
  PairInfo('BTCUSD', 'BTC/USD', 'CRYPTO', Color(0xFFF7931A)),
  PairInfo('ETHUSD', 'ETH/USD', 'CRYPTO', Color(0xFF627EEA)),
];

// =============================================================================
// HOME SCREEN — pair grid with swipe drawer
// =============================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final textCol = isDark ? kDarkText    : kLightText;

    final bg     = isDark ? kDarkBg : kLightBg;

    return Scaffold(
      backgroundColor: bg,
      drawer: _AppDrawer(),
      body: SafeArea(
        child: Builder(builder: (ctx) => Column(children: [

          // ─── HEADER ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.menu_rounded, color: textCol, size: 26),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
              const Spacer(),
              Row(children: [
                const Icon(Icons.candlestick_chart_rounded, color: kSeaBlue, size: 22),
                const SizedBox(width: 8),
                Text('QUANTCALX', style: TextStyle(
                  color: textCol, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.5,
                )),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, _slide(const SettingsScreen())),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kSeaBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.settings_outlined, color: kSeaBlue, size: 20),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),

          // Sub-header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Professional Risk Calculator',
                style: TextStyle(color: isDark ? kDarkSubText : kLightSubText, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 18),

          // ─── SECTION LABEL ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('SELECT INSTRUMENT', style: TextStyle(
                color: isDark ? kDarkSubText : kLightSubText,
                fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2,
              )),
            ),
          ),
          const SizedBox(height: 12),

          // ─── PAIR GRID ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _pairs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.3,
                ),
                itemBuilder: (ctx, i) => _PairCard(pair: _pairs[i], isDark: isDark),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ])),
      ),
    );
  }

  Route _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child,
      ),
    ),
    transitionDuration: const Duration(milliseconds: 280),
  );
}

// =============================================================================
// PAIR CARD
// =============================================================================
class _PairCard extends StatefulWidget {
  final PairInfo pair;
  final bool isDark;
  const _PairCard({required this.pair, required this.isDark});
  @override State<_PairCard> createState() => _PairCardState();
}

class _PairCardState extends State<_PairCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final p = widget.pair;
    final cardColor = widget.isDark ? kDarkCard : kLightCard;

    return GestureDetector(
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) async {
        await _ac.reverse();
        if (context.mounted) {
          Navigator.push(context, PageRouteBuilder(
            pageBuilder: (_, a, __) => CalculatorScreen(pair: p),
            transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                child: child,
              ),
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ));
        }
      },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.accent.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.06), blurRadius: 14, spreadRadius: 2)],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                p.category == 'CRYPTO' ? '₿' : p.category == 'METAL' ? '⚡' : '💱',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(p.label, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(p.category, style: TextStyle(color: widget.isDark ? kDarkSubText : kLightSubText, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// DRAWER
// =============================================================================
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override Widget build(BuildContext context) {
    final isDarkNow = context.watch<ThemeProvider>().isDark;
    final user    = context.watch<UserProvider>().profile;
    final surface = isDarkNow ? kDarkSurface : kLightSurface;
    final text    = isDarkNow ? kDarkText    : kLightText;
    final sub     = isDarkNow ? kDarkSubText : kLightSubText;

    return Drawer(
      backgroundColor: surface,
      width: MediaQuery.of(context).size.width * 0.8,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ─ Profile Header ─────────────────────────────────────────
          Container(
            width: double.infinity,
            color: isDarkNow ? kDarkBg : Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Avatar + edit button
              Stack(children: [
                _Avatar(user: user),
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: () => _pickAvatar(context),
                    child: Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(color: kSeaBlue, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // Name
              Text(user?.name ?? 'Trader', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(user?.email ?? '', style: TextStyle(color: sub, fontSize: 12)),
              const SizedBox(height: 2),
              Text(user?.phone ?? '', style: TextStyle(color: sub, fontSize: 12)),

              const SizedBox(height: 12),

              // Wallet hash (blockchain feel)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kSeaBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kSeaBlue.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.link_rounded, color: kSeaBlue, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    user?.walletHash ?? '—',
                    style: const TextStyle(color: kSeaBlue, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 8),

          // ─── Menu Items ────────────────────────────────────────────
          _drawerItem(Icons.calculate_outlined,  'Calculator',    text, sub, () { Navigator.pop(context); }),
          _drawerItem(Icons.settings_outlined,    'Settings',     text, sub, () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),

          const Spacer(),

          // App version at bottom
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('QuantCalx v1.0 · Offline Calculator',
              style: TextStyle(color: sub.withValues(alpha: 0.5), fontSize: 11)),
          ),
        ]),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, Color text, Color sub, VoidCallback onTap) =>
    ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: kSeaBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Icon(icon, color: kSeaBlue, size: 20),
      ),
      title: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 14)),
      onTap: onTap,
    );

  Future<void> _pickAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null && context.mounted) {
      await context.read<UserProvider>().updateAvatar(img.path);
    }
  }
}

// Avatar widget
class _Avatar extends StatelessWidget {
  final UserProfile? user;
  const _Avatar({this.user});

  @override Widget build(BuildContext context) {
    final path = user?.avatarPath ?? '';
    if (path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(radius: 40, backgroundImage: FileImage(File(path)));
    }
    return Container(
      width: 80, height: 80,
      decoration: const BoxDecoration(color: kSeaBlue, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        user?.initials ?? 'QC',
        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }
}
