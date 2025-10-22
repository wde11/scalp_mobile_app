import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scalp_mobile_app/router/app_router.dart';
import 'package:scalp_mobile_app/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Listen for auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        AppRouter.router.go('/');
      }
    });

    runApp(const MyApp());
  } catch (e) {
    print('Error initializing Firebase: $e');
    // Initialize without Firebase if there's an error
    runApp(const MyApp());
  }
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