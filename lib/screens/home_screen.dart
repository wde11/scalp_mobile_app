import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Dashboard'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/listing'),
              child: const Text('Listing'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/map'),
              child: const Text('Map'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/chat'),
              child: const Text('Chat'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/profile'),
              child: const Text('Profile'),
            ),
          ],
        ),
      ),
    );
  }
}