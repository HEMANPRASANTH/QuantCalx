import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final isDark = tp.isDark;
    final textColor  = isDark ? kDarkText : kLightText;
    final subColor   = isDark ? kDarkSubText : kLightSubText;
    final cardColor  = isDark ? kDarkCard : kLightCard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── APPEARANCE ─────────────────────────────────────────────
          _sectionLabel('APPEARANCE', subColor),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: cardColor, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kSeaBlue.withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              // Dark mode toggle
              _settingsTile(
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                iconColor: kSeaBlue,
                title: isDark ? 'Dark Mode' : 'Light Mode',
                subtitle: isDark
                  ? 'AMOLED black · Sea Blue accents'
                  : 'Clean white · Sea Blue accents',
                textColor: textColor, subColor: subColor,
                trailing: Switch.adaptive(
                  value: isDark,
                  activeThumbColor: kSeaBlue,
                  onChanged: (_) => tp.toggle(),
                ),
              ),

                            Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1, indent: 56),

              // Mode preview chip row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(children: [
                  _modeChip('DARK', isDark, () { if (!isDark) tp.toggle(); }),
                  const SizedBox(width: 10),
                  _modeChip('LIGHT', !isDark, () { if (isDark) tp.toggle(); }),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 28),

          // ─── ABOUT ──────────────────────────────────────────────────
          _sectionLabel('ABOUT', subColor),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: cardColor, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kSeaBlue.withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              _settingsTile(icon: Icons.info_outline_rounded, iconColor: kSeaBlue,
                title: 'Version', subtitle: '1.0.0 — Build 1', textColor: textColor, subColor: subColor,
                trailing: const SizedBox.shrink()),
                            Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1, indent: 56),
              _settingsTile(icon: Icons.calculate_outlined, iconColor: kSeaBlue,
                title: 'Calculator Mode', subtitle: 'Fully Offline — No Internet Needed',
                textColor: textColor, subColor: subColor, trailing: const SizedBox.shrink()),
                            Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1, indent: 56),
              _settingsTile(icon: Icons.verified_user_outlined, iconColor: kSeaBlue,
                title: 'Data Privacy', subtitle: 'All data stored locally — Zero external servers',
                textColor: textColor, subColor: subColor, trailing: const SizedBox.shrink()),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t, Color c) => Text(t,
    style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2));

  Widget _settingsTile({required IconData icon, required Color iconColor,
    required String title, required String subtitle,
    required Color textColor, required Color subColor, required Widget trailing}) =>
    ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: subColor, fontSize: 11)),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );

  Widget _modeChip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? kSeaBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: selected ? kSeaBlue : Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(
        color: selected ? Colors.white : Colors.grey,
        fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1,
      )),
    ),
  );
}
