import 'dart:io';
import 'dart:ui';
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
  PairInfo('XAGUSD', 'XAG/USD', 'COMMODITY',  Color(0xFFB0BEC5)),
  PairInfo('XAUUSD', 'XAU/USD', 'COMMODITY',  Color(0xFFFFD700)),
  PairInfo('BTCUSD', 'BTC/USD', 'CRYPTO', Color(0xFFF7931A)),
  PairInfo('ETHUSD', 'ETH/USD', 'CRYPTO', Color(0xFF627EEA)),
];

// =============================================================================
// HOME SCREEN — pair grid with swipe drawer
// =============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = true;
  String _sortOption = 'Default';

  List<PairInfo> get _sortedPairs {
    final list = List<PairInfo>.from(_pairs);
    switch (_sortOption) {
      case 'A-Z': list.sort((a, b) => a.symbol.compareTo(b.symbol)); break;
      case 'Z-A': list.sort((a, b) => b.symbol.compareTo(a.symbol)); break;
      case 'Forex First': list.sort((a, b) {
        if (a.category == b.category) return a.symbol.compareTo(b.symbol);
        if (a.category == 'FOREX') return -1;
        if (b.category == 'FOREX') return 1;
        return a.category.compareTo(b.category);
      }); break;
      case 'Commodity First': list.sort((a, b) {
        if (a.category == b.category) return a.symbol.compareTo(b.symbol);
        if (a.category == 'COMMODITY') return -1;
        if (b.category == 'COMMODITY') return 1;
        return a.category.compareTo(b.category);
      }); break;
      case 'Crypto First': list.sort((a, b) {
        if (a.category == b.category) return a.symbol.compareTo(b.symbol);
        if (a.category == 'CRYPTO') return -1;
        if (b.category == 'CRYPTO') return 1;
        return a.category.compareTo(b.category);
      }); break;
    }
    return list;
  }

  @override Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final textCol = isDark ? kDarkText    : kLightText;

    return Scaffold(
      drawer: _AppDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF0A0E14), const Color(0xFF001F29)]
                : [const Color(0xFFF4F6F9), const Color(0xFFE2EFF5)],
          ),
        ),
        child: SafeArea(
        child: Builder(builder: (ctx) => Column(children: [

          // ─── HEADER ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.notes_rounded, color: textCol, size: 26),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('QUANTCALX', style: TextStyle(
                    color: textCol, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.5,
                  )),
                  const SizedBox(height: 4),
                  Text('Be Professional', style: TextStyle(
                    color: isDark ? kDarkSubText : kLightSubText, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600,
                  )),
                ],
              ),
              const Spacer(),
              // ─── Toggles & Sorting Options ─────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() { _isGridView = !_isGridView; });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kSeaBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, color: kSeaBlue, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: kSeaBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.sort_rounded, color: kSeaBlue, size: 20),
                      position: PopupMenuPosition.under,
                      color: isDark ? kDarkCard : kLightCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) => setState(() { _sortOption = val; }),
                      itemBuilder: (ctx) => [
                        'Default', 'A-Z', 'Z-A', 'Forex First', 'Commodity First', 'Crypto First'
                      ].map((e) => PopupMenuItem(
                        value: e,
                        child: Text(e, style: TextStyle(
                          fontSize: 13, 
                          fontWeight: _sortOption == e ? FontWeight.w900 : FontWeight.w600,
                          color: _sortOption == e ? kSeaBlue : textCol,
                        )),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 6),

          const SizedBox(height: 12),

          // ─── PAIR GRID ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _isGridView 
                ? GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _sortedPairs.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.3,
                    ),
                    itemBuilder: (ctx, i) => _PairCard(pair: _sortedPairs[i], isDark: isDark),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _sortedPairs.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ListCard(pair: _sortedPairs[i], isDark: isDark),
                    ),
                  ),
            ),
          ),
          const SizedBox(height: 10),
        ])),
      ),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: widget.isDark ? 0.35 : 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.accent.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                p.category == 'CRYPTO' ? '₿' : p.category == 'COMMODITY' ? '⚡' : '💱',
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
        ),
      ),
    );
  }
}

// =============================================================================
// LIST CARD (for List View)
// =============================================================================
class _ListCard extends StatefulWidget {
  final PairInfo pair;
  final bool isDark;
  const _ListCard({required this.pair, required this.isDark});
  @override State<_ListCard> createState() => _ListCardState();
}

class _ListCardState extends State<_ListCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: widget.isDark ? 0.35 : 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.accent.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: p.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    p.category == 'CRYPTO' ? '₿' : p.category == 'COMMODITY' ? '⚡' : '💱',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(p.label, style: TextStyle(color: p.accent, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(p.category, style: TextStyle(color: widget.isDark ? kDarkSubText : kLightSubText, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ]),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: p.accent.withValues(alpha: 0.5), size: 16),
              ]),
            ),
          ),
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.8,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: surface.withValues(alpha: isDarkNow ? 0.35 : 0.6),
            child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ─ Profile Header ─────────────────────────────────────────
          Container(
            width: double.infinity,
            color: Colors.transparent,
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
          _drawerItem(Icons.settings_outlined,    'Settings',     text, sub, () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),

          const Spacer(),
        ]),
      ),
          ),
        ),
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
