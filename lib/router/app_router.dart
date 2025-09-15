import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scalp_mobile_app/screens/chat_screen.dart';
import 'package:scalp_mobile_app/screens/dashboard_screen.dart';
import 'package:scalp_mobile_app/screens/home_screen.dart';
import 'package:scalp_mobile_app/screens/listing_screen.dart';
import 'package:scalp_mobile_app/screens/login_screen.dart';
import 'package:scalp_mobile_app/screens/map_screen.dart';
import 'package:scalp_mobile_app/screens/profile_screen.dart';
import 'package:scalp_mobile_app/screens/signup_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/listing',
        builder: (context, state) => const ListingScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
}