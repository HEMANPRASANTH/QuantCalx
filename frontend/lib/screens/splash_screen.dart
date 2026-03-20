import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/user_provider.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override void initState() {
    super.initState();
    // Quant style smooth endless scaling pulse
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.94, end: 1.04).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine));

    // Futuristic slide and opacity reveal
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _slideCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));
    _slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(CurvedAnimation(parent: _slideCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));

    _slideCtrl.forward();

    // Trigger router securely after magnificent 3.5s intro delay
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (!mounted) return;
      final up = context.read<UserProvider>();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 900),
          pageBuilder: (_, __, ___) => up.onboarded ? const HomeScreen() : const OnboardingScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02070D), // Ultra deep abyss
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Matrix Institutional Hex/Data Grid feeling
          CustomPaint(painter: _GridPainter()),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.4), blurRadius: 50, spreadRadius: 12),
                        BoxShadow(color: const Color(0xFF29B6F6).withValues(alpha: 0.25), blurRadius: 80, spreadRadius: 30),
                      ]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.asset('assets/icon.png', width: 150, height: 150, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _opacity,
                    child: Column(
                      children: [
                        const Text(
                          'QuantCalx',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.5,
                            shadows: [Shadow(color: Color(0xFF00E676), blurRadius: 20)],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Text('INSTITUTIONAL TRADER', 
                            style: TextStyle(color: Color(0xFF29B6F6), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 4.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.04)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Abstract quant analytics background mesh
    for (double i = 0; i < size.width; i += 35) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 35) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
