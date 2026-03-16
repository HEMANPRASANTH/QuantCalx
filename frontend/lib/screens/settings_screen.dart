import 'dart:ui';
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
          // ─── APPEARANCE ─────────────────────────────────────────────
          _sectionLabel('APPEARANCE', subColor),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: isDark ? 0.35 : 0.6),
                  borderRadius: BorderRadius.circular(16),
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

                    ]),
              ),
            ),
          ),
        ],
      ),
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
}
