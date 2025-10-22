import 'package:flutter/material.dart';
import 'package:scalp_mobile_app/screens/chat_screen.dart';
import 'package:scalp_mobile_app/screens/dashboard_screen.dart';
import 'package:scalp_mobile_app/screens/listing_screen.dart';
import 'package:scalp_mobile_app/screens/map_screen.dart';
import 'package:scalp_mobile_app/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? initialChatId;
  final String? initialUserId;

  const HomeScreen({
    super.key,
    this.initialChatId,
    this.initialUserId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final PageStorageBucket _bucket;

  @override
  void initState() {
    super.initState();
    _bucket = PageStorageBucket();
    // If we have a chat ID, navigate to chat tab and pass the chat info
    if (widget.initialChatId != null && widget.initialUserId != null) {
      _selectedIndex = 3; // Chat tab index
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the initial chat IDs have changed
    if ((widget.initialChatId != null && widget.initialUserId != null) &&
        (widget.initialChatId != oldWidget.initialChatId || widget.initialUserId != oldWidget.initialUserId)) {
      setState(() {
        _selectedIndex = 3; // Chat tab index
      });
    }
  }

  List<Widget> _buildScreens() {
    return [
      const DashboardScreen(),
      const ListingScreen(),
      const MapScreen(),
      ChatScreen(
        initialChatId: widget.initialChatId,
        initialUserId: widget.initialUserId,
      ),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    return Scaffold(
      body: PageStorage(
        bucket: _bucket,
        child: screens[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Listing',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}