import 'package:flutter/material.dart';
import 'package:scalp_mobile_app/screens/chat_screen.dart';
import 'package:scalp_mobile_app/screens/dashboard_screen.dart';
import 'package:scalp_mobile_app/screens/listing_screen.dart';
import 'package:scalp_mobile_app/screens/map_screen.dart';
import 'package:scalp_mobile_app/screens/profile_screen.dart';
import 'package:scalp_mobile_app/services/scavenger_hunt_service.dart';
import 'package:scalp_mobile_app/globals.dart';

class HomeScreen extends StatefulWidget {
  final String? initialChatId;
  final String? initialUserId;
  final String? listingId;
  final String? listingTitle;
  final String? listingPrice;
  final String? listingImage;

  const HomeScreen({
    super.key,
    this.initialChatId,
    this.initialUserId,
    this.listingId,
    this.listingTitle,
    this.listingPrice,
    this.listingImage,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final PageStorageBucket _bucket;
  final ScavengerHuntService _scavengerHuntService = ScavengerHuntService();
  int _unclaimedItemsCount = 0;

  @override
  void initState() {
    super.initState();
    _bucket = PageStorageBucket();
    
    // Register callback for navigation
    SharedLocationState.onNavigateToMap = () {
      if (mounted && SharedLocationState.shouldNavigateToMap) {
        setState(() {
          _selectedIndex = 2; // Switch to map tab
        });
      }
    };
    
    // Check if we should navigate to map with shared location
    if (SharedLocationState.shouldNavigateToMap) {
      _selectedIndex = 2; // Map tab index
    }
    // If we have a chat ID, navigate to chat tab and pass the chat info
    else if (widget.initialChatId != null && widget.initialUserId != null) {
      _selectedIndex = 3; // Chat tab index
    }

    // Listen to unclaimed items count
    _scavengerHuntService.getUnclaimedItemsCount().listen((count) {
      if (mounted) {
        setState(() {
          _unclaimedItemsCount = count;
        });
      }
    });
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

  void _switchToTab(int index) {
    if (mounted && index >= 0 && index < 5) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  List<Widget> _buildScreens() {
    return [
      DashboardScreen(onNavigateToTab: _switchToTab),
      const ListingScreen(),
      MapScreen(sharedLocation: SharedLocationState.sharedLocation),
      ChatScreen(
        initialChatId: widget.initialChatId,
        initialUserId: widget.initialUserId,
        listingId: widget.listingId,
        listingTitle: widget.listingTitle,
        listingPrice: widget.listingPrice,
        listingImage: widget.listingImage,
      ),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    // Clear the callback when HomeScreen is disposed
    SharedLocationState.onNavigateToMap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if we should navigate to map with shared location
    if (SharedLocationState.shouldNavigateToMap && _selectedIndex != 2) {
      // Use post-frame callback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = 2; // Switch to map tab
          });
        }
      });
    }
    
    final screens = _buildScreens();
    return Scaffold(
      body: PageStorage(
        bucket: _bucket,
        child: screens[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Listing',
          ),
          // Map tab with scavenger hunt notification badge
          BottomNavigationBarItem(
            icon: _unclaimedItemsCount > 0
                ? Badge(
                    label: Text('$_unclaimedItemsCount'),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.map),
                  )
                : const Icon(Icons.map),
            label: 'Map',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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