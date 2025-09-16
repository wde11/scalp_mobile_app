import 'package:flutter/material.dart';
import 'package:scalp_mobile_app/router/app_router.dart';
import 'package:scalp_mobile_app/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
      title: 'Scalp Mobile App',
      theme: AppTheme.theme,
    );
  }
}
