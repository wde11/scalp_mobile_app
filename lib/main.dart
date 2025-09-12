import 'package:flutter/material.dart';
import 'package:scalp_mobile_app/screens/login_screen.dart';
import 'package:scalp_mobile_app/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scalp Mobile App',
      theme: AppTheme.theme,
      home: const LoginScreen(),
    );
  }
}
