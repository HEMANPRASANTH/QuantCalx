import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../providers/user_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }
  @override void dispose() {
    _fadeCtrl.dispose();
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _passCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    // SHA-256 hash of password — never store plaintext
    final passHash = sha256.convert(utf8.encode(_passCtrl.text)).toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pass_hash', passHash);
    final profile = UserProfile(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );
    if (mounted) await context.read<UserProvider>().saveProfile(profile);
  }

  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? kDarkText : kLightText;
    final cardColor = isDark ? kDarkCard : kLightCard;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 20),

                // Logo
                Center(child: Column(children: [
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: kSeaBlue, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Text('QC', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 16),
                  const Text('QUANTCALX', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3, color: kSeaBlue)),
                  const SizedBox(height: 4),
                  Text('Create your secure trader profile', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 13)),
                ])),
                const SizedBox(height: 30),

                // Secure badge
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kSeaBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kSeaBlue.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.verified_user_outlined, color: kSeaBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Your profile is encrypted & stored securely on your device only. Zero external servers.',
                      style: TextStyle(color: kSeaBlue.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600),
                    )),
                  ]),
                ),
                const SizedBox(height: 24),

                _label('FULL NAME'),
                _field(_nameCtrl, 'e.g. Ravi Kumar', Icons.person_outline, textColor, cardColor,
                  type: TextInputType.name,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),

                _label('EMAIL ADDRESS'),
                _field(_emailCtrl, 'e.g. ravi@email.com', Icons.email_outlined, textColor, cardColor,
                  type: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter valid email' : null),

                _label('PHONE NUMBER'),
                _field(_phoneCtrl, 'e.g. +91 9876543210', Icons.phone_outlined, textColor, cardColor,
                  type: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 7) ? 'Enter valid phone' : null),

                _label('PASSWORD'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Create a strong password',
                      filled: true, fillColor: cardColor,
                      prefixIcon: const Icon(Icons.lock_outline, color: kSeaBlue, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: kSeaBlue.withValues(alpha: 0.6), size: 20),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kSeaBlue, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                ),

                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSeaBlue, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4, shadowColor: kSeaBlue.withValues(alpha: 0.4),
                    ),
                    child: _loading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('CREATE SECURE PROFILE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(color: kSeaBlue, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon, Color textCol, Color cardCol, {
    TextInputType? type, String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: ctrl, keyboardType: type,
      style: TextStyle(color: textCol, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint, filled: true, fillColor: cardCol,
        prefixIcon: Icon(icon, color: kSeaBlue, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kSeaBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      validator: validator,
    ),
  );
}
