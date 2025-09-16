import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scalp_mobile_app/router/navigator_keys.dart';
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
    navigatorKey: shellNavigatorKey,
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/dashboard',
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: listingNavigatorKey,
            routes: [
              GoRoute(
                path: '/listing',
                builder: (context, state) => const ListingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: mapNavigatorKey,
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: chatNavigatorKey,
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (BuildContext context, GoRouterState state) {
          return const SignupScreen();
        },
      ),
    ],
  );
}
