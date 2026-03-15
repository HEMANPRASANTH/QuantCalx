import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const UltraProTradingApp(),
    ),
  );
}

class UltraProTradingApp extends StatelessWidget {
  const UltraProTradingApp({super.key});

  @override Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final up = context.watch<UserProvider>();

    return MaterialApp(
      title: 'QuantCalx',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(dark: tp.isDark),
      // Show onboarding on first launch, home after profile created
      home: up.onboarded ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
