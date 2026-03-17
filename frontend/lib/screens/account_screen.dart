import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _phone;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<UserProvider>().profile;
    _name  = TextEditingController(text: u?.name  ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final u = context.read<UserProvider>().profile;
    final updated = (u ?? const UserProfile(name: '', email: '', phone: '')).copyWith(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
    );
    await context.read<UserProvider>().saveProfile(updated);
    setState(() => _editing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile saved!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null && mounted) {
      await context.read<UserProvider>().updateAvatar(img.path);
    }
  }

  void _copyKey(String key) {
    Clipboard.setData(ClipboardData(text: key));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Crypto key copied!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final user   = context.watch<UserProvider>().profile;
    final bg     = isDark ? kDarkBg     : kLightBg;
    final card   = isDark ? kDarkCard   : kLightCard;
    final text   = isDark ? kDarkText   : kLightText;
    final sub    = isDark ? kDarkSubText : kLightSubText;

    final walletHash = user?.walletHash ?? '—';

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
            Text('ACCOUNT', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _editing = !_editing),
              icon: Icon(_editing ? Icons.close_rounded : Icons.edit_rounded, size: 16, color: kSeaBlue),
              label: Text(_editing ? 'CANCEL' : 'EDIT', style: const TextStyle(color: kSeaBlue, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ]),
        ),

        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ─── AVATAR ─────────────────────────────────────────────
            Center(child: Stack(children: [
              _buildAvatar(user),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(color: kSeaBlue, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 8),
            Center(
              child: Text(user?.name.isNotEmpty == true ? user!.name : 'Trader',
                style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 28),

            // ─── PERSONAL INFO ──────────────────────────────────────
            _sectionLabel('PERSONAL INFO', sub),
            const SizedBox(height: 10),
            _infoField(label: 'Name', icon: Icons.person_outline_rounded, ctrl: _name, enabled: _editing, isDark: isDark, text: text),
            const SizedBox(height: 10),
            _infoField(label: 'Email', icon: Icons.email_outlined, ctrl: _email, enabled: _editing, isDark: isDark, text: text, type: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _infoField(label: 'Mobile Number', icon: Icons.phone_outlined, ctrl: _phone, enabled: _editing, isDark: isDark, text: text, type: TextInputType.phone),
            const SizedBox(height: 24),

            // ─── CRYPTO KEY ─────────────────────────────────────────
            _sectionLabel('CRYPTO KEY', sub),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _copyKey(walletHash),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kSeaBlue.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.key_rounded, color: kSeaBlue, size: 18),
                    const SizedBox(width: 8),
                    Text('Wallet Hash (SHA-256)', style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const Spacer(),
                    Icon(Icons.copy_rounded, color: kSeaBlue.withValues(alpha: 0.7), size: 15),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    walletHash,
                    style: const TextStyle(
                      color: kSeaBlue,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Tap to copy · Deterministic key derived from your profile',
                    style: TextStyle(color: sub, fontSize: 10)),
                ]),
              ),
            ),
            const SizedBox(height: 28),

            // ─── SAVE BUTTON (only when editing) ────────────────────
            if (_editing)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSeaBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 8,
                    shadowColor: kSeaBlue.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ]),
        )),
      ])),
    );
  }

  Widget _buildAvatar(UserProfile? user) {
    final path = user?.avatarPath ?? '';
    if (path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(radius: 48, backgroundImage: FileImage(File(path)));
    }
    return Container(
      width: 96, height: 96,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        user?.initials ?? 'QC',
        style: const TextStyle(color: Colors.black, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }

  Widget _sectionLabel(String t, Color c) => Text(t,
    style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5));

  Widget _infoField({required String label, required IconData icon, required TextEditingController ctrl,
      required bool enabled, required bool isDark, required Color text, TextInputType? type}) =>
    TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: type,
      style: TextStyle(color: text, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kSeaBlue, size: 20),
        labelStyle: TextStyle(color: enabled ? kSeaBlue : text.withValues(alpha: 0.5), fontSize: 12),
      ),
    );
}
