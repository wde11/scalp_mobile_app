import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/scavenger_hunt_service.dart';
import '../models/scavenger_hunt_item.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  
  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScavengerHuntService _scavengerHuntService = ScavengerHuntService();
  final cloudinary = CloudinaryPublic('dp5mqhd9w', 'scalp_preset', cache: false);
  
  int _itemsSoldCount = 0;
  int _wishlistItemsCount = 0;
  
  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
    _fetchStatistics();
  }
  
  Future<void> _fetchStatistics() async {
    if (currentUser == null) return;
    
    try {
      // Count sold items
      final soldSnapshot = await _firestore
          .collection('listings')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('isSold', isEqualTo: true)
          .get();
      
      // Count wishlist items
      final wishlistSnapshot = await _firestore
          .collection('wishlists')
          .doc(currentUser!.uid)
          .collection('items')
          .get();
      
      if (mounted) {
        setState(() {
          _itemsSoldCount = soldSnapshot.docs.length;
          _wishlistItemsCount = wishlistSnapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error fetching statistics: $e');
    }
  }
  
  void _showSoldItemsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sold Items',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: currentUser != null
                      ? _firestore
                          .collection('listings')
                          .where('userId', isEqualTo: currentUser!.uid)
                          .where('isSold', isEqualTo: true)
                          .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Error loading sold items: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'No sold items yet.\nMark items as sold to see them here!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    
                    // Sort sold items by soldAt on client side
                    final soldItems = snapshot.data!.docs.toList();
                    soldItems.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['soldAt'] as Timestamp?;
                      final bTime = bData['soldAt'] as Timestamp?;
                      
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      
                      return bTime.compareTo(aTime); // Descending order
                    });
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: soldItems.length,
                      itemBuilder: (context, index) {
                        final doc = soldItems[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final soldAt = data['soldAt'] as Timestamp?;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: data['imageUrl'] != null && !data['imageUrl'].toString().startsWith('assets/')
                                      ? NetworkImage(data['imageUrl'])
                                      : const AssetImage('images/placeholder.png') as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              data['title'] ?? 'No Title',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['category'] ?? 'No Category'),
                                if (soldAt != null)
                                  Text(
                                    'Sold: ${_formatDate(soldAt.toDate())}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              '₱${data['price']?.toString() ?? '0'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showWishlistItemsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Wishlist',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: currentUser != null
                      ? _firestore
                          .collection('wishlists')
                          .doc(currentUser!.uid)
                          .collection('items')
                          .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Error loading wishlist: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'No items in wishlist yet.\nAdd items to see them here!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    
                    // Sort by addedAt on client side
                    final wishlistItems = snapshot.data!.docs.toList();
                    wishlistItems.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['addedAt'] as Timestamp?;
                      final bTime = bData['addedAt'] as Timestamp?;
                      
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      
                      return bTime.compareTo(aTime); // Descending order
                    });
                    
                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: wishlistItems.length,
                      itemBuilder: (context, index) {
                        final doc = wishlistItems[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Unknown Item';
                        final price = data['price'] ?? 0.0;
                        final imageUrl = data['imageUrl'] ?? 'assets/images/placeholder.png';
                        final addedAt = data['addedAt'] as Timestamp?;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: imageUrl.startsWith('assets/')
                                      ? const AssetImage('assets/images/placeholder.png') as ImageProvider
                                      : NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (addedAt != null)
                                  Text(
                                    'Added: ${_formatDate(addedAt.toDate())}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₱${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Remove from Wishlist'),
                                        content: Text('Remove "$title" from your wishlist?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text(
                                              'Remove',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true && currentUser != null) {
                                      try {
                                        await _firestore
                                            .collection('wishlists')
                                            .doc(currentUser!.uid)
                                            .collection('items')
                                            .doc(doc.id)
                                            .delete();
                                        
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Item removed from wishlist'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/listing');
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hr ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/scalp_logo_w_v2.png',
            fit: BoxFit.contain,
          ),
        ),
        title: const Text('Welcome Back'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              context.push('/profile');
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _animation,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Wishlist Items',
                        _wishlistItemsCount.toString(),
                        'Updated just now',
                        Icons.favorite,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Items sold',
                        _itemsSoldCount.toString(),
                        'Updated just now',
                        Icons.sell,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: screenWidth - 32,
                  height: 250,
                  child: _buildSpecialEventCard(context),
                ),
                const SizedBox(height: 16),
                Container(
                  width: screenWidth - 32,
                  height: 350,
                  child: _buildMarketplaceCard(context),
                ),
                const SizedBox(height: 16),
                Container(
                  width: screenWidth - 32,
                  child: _buildScavengerHuntCard(context),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    String updateInfo,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Hero(
      tag: title,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            if (title == 'Items sold') {
              _showSoldItemsDialog(context);
            } else if (title == 'Wishlist Items') {
              _showWishlistItemsDialog(context);
            } else {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(title),
                  content: Text('Detailed information about $title.'),
                  actions: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }
          },
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.05),
                    theme.colorScheme.primary.withOpacity(0.1),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 24,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      updateInfo,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialEventCard(BuildContext context) {
    final theme = Theme.of(context);
    return Hero(
      tag: 'special_event',
      child: Material(
        color: Colors.transparent,
        child: StreamBuilder<List<ScavengerHuntItem>>(
          stream: _scavengerHuntService.getAllItems(),
          builder: (context, snapshot) {
            // Get the latest active event (not expired)
            ScavengerHuntItem? latestEvent;
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              // Filter out expired events
              final activeEvents = snapshot.data!
                  .where((item) => item.isAvailable && !item.isExpired)
                  .toList();
              
              // Deactivate expired events in the background
              for (var item in snapshot.data!) {
                if (item.isExpired && item.isActive) {
                  _scavengerHuntService.deactivateExpiredItem(item.id);
                }
              }
              
              if (activeEvents.isNotEmpty) {
                // Sort by creation date to get the latest
                activeEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                latestEvent = activeEvents.first;
              }
            }

            return GestureDetector(
              onTap: () {
                // Navigate to map tab (index 2)
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(2);
                } else {
                  context.push('/map');
                }
              },
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: const AssetImage('assets/images/bangkerohan.jpg'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.4),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.7),
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              latestEvent != null ? 'LIVE EVENT' : 'NO ACTIVE EVENT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (latestEvent != null) ...[
                            // Live Timer
                            StreamBuilder(
                              stream: Stream.periodic(const Duration(seconds: 1)),
                              builder: (context, snapshot) {
                                final event = latestEvent!; // Safe to use ! here because we checked != null above
                                final timeRemaining = event.timeRemaining;
                                String timerText = 'Event Ended';
                                
                                if (timeRemaining != null && timeRemaining > Duration.zero) {
                                  final hours = timeRemaining.inHours.toString().padLeft(2, '0');
                                  final minutes = (timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
                                  final seconds = (timeRemaining.inSeconds % 60).toString().padLeft(2, '0');
                                  timerText = '$hours:$minutes:$seconds';
                                } else if (timeRemaining == Duration.zero || event.isExpired) {
                                  // Deactivate the item when timer reaches zero
                                  _scavengerHuntService.deactivateExpiredItem(event.id);
                                }
                                
                                return Text(
                                  timerText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              latestEvent.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else ...[
                            const Text(
                              '--:--:--',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No active treasure hunt events at the moment',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMarketplaceCard(BuildContext context) {
    final theme = Theme.of(context);
    return Hero(
      tag: 'marketplace',
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            // Navigate to listing tab (index 1)
            if (widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(1);
            } else {
              context.push('/listing');
            }
          },
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: const AssetImage('assets/images/motherboard.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.secondary.withOpacity(0.8),
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Marketplace',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Scalp Parts Now!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Browse Marketplace',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScavengerHuntCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.withOpacity(0.8),
              Colors.deepOrange.withOpacity(0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scavenger Hunt',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Manage treasure items',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              StreamBuilder<List<ScavengerHuntItem>>(
                stream: _scavengerHuntService.getAllItems(),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? [];
                  
                  // Filter out expired items and deactivate them
                  final availableItems = items.where((item) => !item.isExpired).toList();
                  
                  // Deactivate expired items in the background
                  for (var item in items) {
                    if (item.isExpired && item.isActive) {
                      _scavengerHuntService.deactivateExpiredItem(item.id);
                    }
                  }
                  
                  final activeItems = availableItems.where((item) => item.isActive).length;
                  final claimedItems = availableItems.where((item) => item.isClaimed).length;
                  
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$activeItems',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Active Items',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$claimedItems',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Claimed',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showCreateScavengerHuntDialog(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text(
                                'Create',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepOrange,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showManageScavengerHuntDialog(context),
                              icon: const Icon(Icons.manage_search, size: 18),
                              label: const Text(
                                'Manage',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateScavengerHuntDialog(BuildContext context) {
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final eventDurationController = TextEditingController(text: '60');
    double? selectedLat;
    double? selectedLng;
    XFile? selectedImage;
    bool isFree = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.card_giftcard, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Create Scavenger Hunt Item',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Picker
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      try {
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                          maxWidth: 1024,
                        );
                        if (image != null) {
                          setState(() {
                            selectedImage = image;
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error picking image: $e')),
                          );
                        }
                      }
                    },
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: selectedImage != null
                          ? kIsWeb
                              ? FutureBuilder<Uint8List>(
                                  future: selectedImage!.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      );
                                    }
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(selectedImage!.path),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to add image',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Item Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // FREE checkbox
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isFree ? Colors.orange.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFree ? Colors.orange.shade200 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isFree,
                          onChanged: (bool? value) {
                            setState(() {
                              isFree = value ?? false;
                              if (isFree) {
                                priceController.text = '0';
                              }
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Icon(
                          Icons.card_giftcard_rounded,
                          color: isFree ? Colors.orange.shade600 : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'This is a FREE item (no prize)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isFree ? Colors.orange.shade700 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    enabled: !isFree,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isFree ? 'Prize Amount (FREE)' : 'Prize Amount (₱)',
                      border: const OutlineInputBorder(),
                      prefixText: '₱',
                      filled: true,
                      fillColor: isFree ? Colors.grey.shade200 : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: eventDurationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Event Duration (minutes)',
                      border: OutlineInputBorder(),
                      helperText: 'How long the event will last',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        LocationPermission permission = await Geolocator.checkPermission();
                        if (permission == LocationPermission.denied) {
                          permission = await Geolocator.requestPermission();
                        }
                        
                        if (permission == LocationPermission.denied || 
                            permission == LocationPermission.deniedForever) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Location permission denied')),
                            );
                          }
                          return;
                        }

                        final position = await Geolocator.getCurrentPosition();
                        setState(() {
                          selectedLat = position.latitude;
                          selectedLng = position.longitude;
                        });
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: Icon(selectedLat != null ? Icons.check_circle : Icons.my_location),
                    label: Text(
                      selectedLat != null 
                          ? 'Location Set: ${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)}'
                          : 'Set Current Location',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedLat != null ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || 
                    (!isFree && priceController.text.isEmpty) ||
                    selectedLat == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFree 
                          ? 'Please fill all required fields and set location'
                          : 'Please fill all required fields, enter a prize amount, and set location'
                      ),
                    ),
                  );
                  return;
                }

                // Save context reference before async gap
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                try {
                  // Close dialog first
                  navigator.pop();
                  
                  // Show loading message
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Creating scavenger hunt item...'),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  String imageUrl = 'https://via.placeholder.com/400x300?text=Scavenger+Hunt';

                  // Upload image if selected
                  if (selectedImage != null) {
                    try {
                      CloudinaryFile? cloudinaryFile;
                      if (kIsWeb) {
                        final bytes = await selectedImage!.readAsBytes();
                        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${selectedImage!.name}';
                        cloudinaryFile = CloudinaryFile.fromBytesData(
                          bytes,
                          identifier: fileName,
                          resourceType: CloudinaryResourceType.Image,
                        );
                      } else {
                        cloudinaryFile = CloudinaryFile.fromFile(
                          selectedImage!.path,
                          folder: 'scavenger_hunt',
                          resourceType: CloudinaryResourceType.Image,
                        );
                      }
                      final response = await cloudinary.uploadFile(cloudinaryFile);
                      imageUrl = response.secureUrl;
                      print('Image uploaded successfully: $imageUrl');
                    } catch (uploadError) {
                      print('Image upload failed: $uploadError');
                      // Continue with placeholder - don't fail the whole operation
                    }
                  }

                  final price = isFree ? 0.0 : double.parse(priceController.text);

                  await _scavengerHuntService.createScavengerHuntItem(
                    title: titleController.text,
                    price: price,
                    description: descriptionController.text,
                    imageUrl: imageUrl,
                    latitude: selectedLat!,
                    longitude: selectedLng!,
                    quantity: int.parse(quantityController.text),
                    eventDurationMinutes: int.tryParse(eventDurationController.text),
                  );

                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        isFree 
                          ? 'FREE scavenger hunt item created successfully!'
                          : 'Scavenger hunt item created successfully!'
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
                  print('Error creating scavenger hunt item: $e');
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create & Notify Users'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageScavengerHuntDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: const Text(
                        'Manage Scavenger Hunt Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<ScavengerHuntItem>>(
                  stream: _scavengerHuntService.getMyItems(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Error loading items: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'No scavenger hunt items yet.\nCreate one to get started!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    final items = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            onTap: () => _showScavengerHuntItemDetailsDialog(context, item),
                            leading: item.imageUrl.isNotEmpty
                                ? Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(item.imageUrl),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.card_giftcard, size: 26),
                                  ),
                            title: Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₱${item.price.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          item.isActive ? Icons.check_circle : Icons.cancel,
                                          size: 12,
                                          color: item.isActive ? Colors.green : Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: item.isActive ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.isClaimed)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person, size: 12, color: Colors.orange),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Claimed',
                                            style: TextStyle(fontSize: 11, color: Colors.orange),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: SizedBox(
                              width: 75,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Transform.scale(
                                    scale: 0.55,
                                    child: Switch(
                                      value: item.isActive,
                                      onChanged: (value) async {
                                        try {
                                          await _scavengerHuntService.toggleItemStatus(
                                            item.id,
                                            value,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  value ? 'Item activated' : 'Item deactivated',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 15),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Item?'),
                                        content: Text(
                                          'Are you sure you want to delete "${item.title}"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      try {
                                        await _scavengerHuntService.deleteItem(item.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Item deleted'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScavengerHuntItemDetailsDialog(BuildContext context, ScavengerHuntItem item) {
    final isEventActive = item.isEventActive;
    final timeRemaining = item.timeRemaining;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border(bottom: BorderSide(color: Colors.blue[200]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Scavenger Hunt Item Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item image
                      if (item.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item.imageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported, size: 50),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price
                      Text(
                        '₱${item.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Location',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Latitude: ${item.latitude.toStringAsFixed(6)}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                            ),
                            Text(
                              'Longitude: ${item.longitude.toStringAsFixed(6)}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Item Details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Quantity', '${item.quantity}'),
                            const Divider(),
                            _buildDetailRow('Status', item.isActive ? 'Active' : 'Inactive'),
                            const Divider(),
                            _buildDetailRow(
                              'Claim Status',
                              item.isClaimed ? 'Claimed' : 'Available',
                            ),
                            if (item.claimedBy != null) ...[
                              const Divider(),
                              _buildDetailRow('Claimed By', item.claimedBy!),
                            ],
                            if (item.eventEndTime != null) ...[
                              const Divider(),
                              _buildDetailRow(
                                'Event Status',
                                isEventActive ? 'Active' : 'Ended',
                              ),
                            ],
                            if (timeRemaining != null && isEventActive) ...[
                              const Divider(),
                              _buildDetailRow(
                                'Time Remaining',
                                _formatDuration(timeRemaining),
                              ),
                            ],
                            const Divider(),
                            _buildDetailRow(
                              'Created',
                              _formatDate(item.createdAt),
                            ),
                            if (item.claimedAt != null) ...[
                              const Divider(),
                              _buildDetailRow(
                                'Claimed At',
                                _formatDate(item.claimedAt!),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status badges
                      Row(
                        children: [
                          if (item.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cancel, size: 16, color: Colors.red[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Inactive',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (item.isClaimed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person, size: 16, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Claimed',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
