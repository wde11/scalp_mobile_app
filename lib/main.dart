import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:scalp_mobile_app/router/app_router.dart';
import 'package:scalp_mobile_app/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Load environment variables (API keys)
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print('Warning: Could not load .env file: $e');
      // Continue without .env file
    }
    
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    print('Firebase initialized successfully');

    runApp(const MyApp());
  } catch (e) {
    print('Error initializing app: $e');
    // Run app anyway with error message
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