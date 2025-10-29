import 'package:go_router/go_router.dart';
import 'package:scalp_mobile_app/screens/chat_screen.dart';
import 'package:scalp_mobile_app/screens/dashboard_screen.dart';
import 'package:scalp_mobile_app/screens/home_screen.dart';
import 'package:scalp_mobile_app/screens/listing_screen.dart';
import 'package:scalp_mobile_app/screens/login_screen.dart';
import 'package:scalp_mobile_app/screens/map_screen.dart';
import 'package:scalp_mobile_app/screens/profile_screen.dart';
import 'package:scalp_mobile_app/screens/signup_screen.dart';
import 'package:scalp_mobile_app/screens/my_cart_screen.dart';
import 'package:scalp_mobile_app/screens/my_items_screen.dart';
import 'package:scalp_mobile_app/screens/splash_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final chatId = state.uri.queryParameters['chatId'];
          final userId = state.uri.queryParameters['userId'];
          final listingId = state.uri.queryParameters['listingId'];
          final listingTitle = state.uri.queryParameters['listingTitle'];
          final listingPrice = state.uri.queryParameters['listingPrice'];
          final listingImage = state.uri.queryParameters['listingImage'];
          return HomeScreen(
            initialChatId: chatId,
            initialUserId: userId,
            listingId: listingId,
            listingTitle: listingTitle,
            listingPrice: listingPrice,
            listingImage: listingImage,
          );
        },
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
      GoRoute(
        path: '/my-cart',
        builder: (context, state) => const MyCartScreen(),
      ),
      GoRoute(
        path: '/my-items',
        builder: (context, state) => const MyItemsScreen(),
      ),
    ],
  );
}