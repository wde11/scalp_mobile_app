import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scalp_mobile_app/models/location_data.dart';
import 'package:scalp_mobile_app/models/transaction.dart' as models;
import 'package:scalp_mobile_app/services/directions_service.dart';
import 'package:scalp_mobile_app/services/scavenger_hunt_service.dart';
import 'package:scalp_mobile_app/models/scavenger_hunt_item.dart';
import 'package:scalp_mobile_app/globals.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  final models.Transaction? activeTransaction;
  final LocationData? sharedLocation;
  
  const MapScreen({super.key, this.activeTransaction, this.sharedLocation});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(7.0779, 125.5997);
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _currentLocationName = '';
  String _destinationName = '';
  bool _mapReady = false;
  String? _routeDistance;
  String? _routeDuration;
  final DirectionsService _directionsService = DirectionsService();
  final ScavengerHuntService _scavengerHuntService = ScavengerHuntService();
  List<ScavengerHuntItem> _scavengerHuntItems = [];
  bool _showScavengerHunt = true; // Toggle to show/hide scavenger hunt items
  StreamSubscription<List<ScavengerHuntItem>>? _scavengerHuntSubscription;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadScavengerHuntItems();
    
    // Check if there's a shared location to show
    if (widget.sharedLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSharedLocation();
      });
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTransaction != oldWidget.activeTransaction) {
      _handleTransactionUpdate();
    }
  }

  Future<void> _handleTransactionUpdate() async {
    if (widget.activeTransaction != null && 
        widget.activeTransaction!.sellerLocation != null &&
        widget.activeTransaction!.locationSharingEnabled) {
      await _drawRoute(widget.activeTransaction!.sellerLocation!);
    } else {
      _clearRoute();
    }
  }

  void _loadScavengerHuntItems() {
    // Load ALL items (not just active ones) so users can see all scavenger hunt items
    _scavengerHuntSubscription?.cancel();
    _scavengerHuntSubscription = _scavengerHuntService.getAllItems().listen((items) {
      if (mounted && !_isDisposed) {
        setState(() {
          _scavengerHuntItems = items;
          _updateScavengerHuntMarkers();
        });
      }
    }, onError: (error) {
      print('Error loading scavenger hunt items: $error');
    });
  }

  Future<void> _handleSharedLocation() async {
    if (widget.sharedLocation == null || !_mapReady || _mapController == null) return;
    
    final sharedLoc = widget.sharedLocation!;
    final sharedLatLng = LatLng(sharedLoc.latitude, sharedLoc.longitude);
    
    // Get street address for the shared location
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        sharedLoc.latitude,
        sharedLoc.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks.first;
        final street = place.street ?? '';
        final locality = place.locality ?? place.subLocality ?? place.administrativeArea ?? '';
        
        String address;
        if (street.isNotEmpty && locality.isNotEmpty) {
          address = '$street, $locality';
        } else if (locality.isNotEmpty) {
          address = locality;
        } else if (street.isNotEmpty) {
          address = street;
        } else {
          address = sharedLoc.address;
        }
        
        if (mounted && !_isDisposed) {
          setState(() {
            _destinationName = address;
          });
        }
      }
    } catch (e) {
      // Fall back to the provided address
      if (mounted && !_isDisposed) {
        setState(() {
          _destinationName = sharedLoc.address;
        });
      }
    }
    
    // Add marker for the shared location
    if (mounted && !_isDisposed) {
      setState(() {
        _markers.removeWhere((marker) => marker.markerId.value == 'shared_location');
        _markers.add(
          Marker(
            markerId: const MarkerId('shared_location'),
            position: sharedLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'Shared Location',
              snippet: _destinationName,
            ),
          ),
        );
      });
    }
    // Animate camera to the shared location
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(sharedLatLng, 15),
    );
    
    // Clear the global state after handling
    SharedLocationState.clearSharedLocation();
  }

  void _updateScavengerHuntMarkers() async {
    if (!_showScavengerHunt || !_mapReady || _isDisposed) return;

    try {
      // Remove old scavenger hunt markers
      _markers.removeWhere((marker) => 
        marker.markerId.value.startsWith('scavenger_'));

      // Add new scavenger hunt markers for ALL items (active and inactive)
      for (var item in _scavengerHuntItems) {
        if (_isDisposed) break; // Stop if disposed during iteration
        
        final isClaimedByMe = _scavengerHuntService.isClaimedByCurrentUser(item);
        final isClaimed = item.isClaimed;
        final isEventActive = item.isEventActive;
      
      // Determine marker color based on status
      BitmapDescriptor markerIcon;
      String statusText;
      
      if (!isEventActive) {
        // Event ended - grey marker
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
        statusText = "Event Ended";
      } else if (isClaimedByMe) {
        // Claimed by current user - green marker
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        statusText = "Your Claim";
      } else if (isClaimed) {
        // Claimed by someone else - red marker
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        statusText = "Taken";
      } else {
        // Available - orange marker
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        statusText = "Available";
      }

      _markers.add(
        Marker(
          markerId: MarkerId('scavenger_${item.id}'),
          position: LatLng(item.latitude, item.longitude),
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: item.title,
            snippet: '₱${item.price.toStringAsFixed(0)} - $statusText',
          ),
          onTap: () => _showScavengerHuntItemDetails(item),
        ),
      );
    }

    if (mounted && !_isDisposed) {
      setState(() {});
    }
    } catch (e) {
      print('Error updating scavenger hunt markers: $e');
    }
  }

  void _showScavengerHuntItemDetails(ScavengerHuntItem item) {
    final isClaimedByMe = _scavengerHuntService.isClaimedByCurrentUser(item);
    final isClaimed = item.isClaimed;
    final isEventActive = item.isEventActive;
    final timeRemaining = item.timeRemaining;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

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
                      _detailRow('Quantity', '${item.quantity}'),
                      const Divider(),
                      _detailRow('Status', item.isActive ? 'Active' : 'Inactive'),
                      if (item.eventEndTime != null) ...[
                        const Divider(),
                        _detailRow(
                          'Event Status',
                          isEventActive ? 'Active' : 'Ended',
                        ),
                      ],
                      if (timeRemaining != null && isEventActive) ...[
                        const Divider(),
                        _detailRow(
                          'Time Remaining',
                          _formatDuration(timeRemaining),
                        ),
                      ],
                      const Divider(),
                      _detailRow(
                        'Created',
                        _formatDate(item.createdAt),
                      ),
                      if (item.claimedAt != null) ...[
                        const Divider(),
                        _detailRow(
                          'Claimed At',
                          _formatDate(item.claimedAt!),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Status and action button
                if (isClaimedByMe)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'You claimed this item!',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isClaimed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Already Claimed',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (item.isActive && isEventActive)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _contactSeller(item),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text(
                        'Contact Seller',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Item Not Available',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ],
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
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
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

  Future<void> _contactSeller(ScavengerHuntItem item) async {
    Navigator.pop(context); // Close bottom sheet

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to contact the seller'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (currentUser.uid == item.userId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot contact yourself!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Generate chat ID
      final chatId = _generateChatId(currentUser.uid, item.userId);
      
      // Get or create chat
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        await firestore.collection('chats').doc(chatId).set({
          'participants': [currentUser.uid, item.userId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }

      // Send scavenger hunt inquiry message
      final messageData = {
        'senderId': currentUser.uid,
        'text': 'Is this scavenger hunt item available?',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'scavengerHuntInquiry': {
          'itemId': item.id,
          'title': item.title,
          'price': item.price,
          'imageUrl': item.imageUrl,
          'status': item.status,
        },
      };

      await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      await firestore.collection('chats').doc(chatId).update({
        'lastMessage': 'Scavenger hunt inquiry: ${item.title}',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✉️ Message sent to seller! Check your chats.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Navigate to chat screen after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushNamed('/chat');
          }
        });
      }
    } catch (e) {
      print('Error contacting seller: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  void _showMyScavengerHuntItems() {
    // Show all active scavenger hunt items with countdown timers
    final activeItems = _scavengerHuntItems.where((item) => 
      item.isActive && item.isEventActive
    ).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Scavenger Hunt',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${activeItems.length} items available',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
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
            
            // Content
            Expanded(
              child: activeItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.card_giftcard_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Active Items',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Check back later for new\nscavenger hunt items!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: activeItems.length,
                      itemBuilder: (context, index) {
                        final item = activeItems[index];
                        final isClaimedByMe = _scavengerHuntService.isClaimedByCurrentUser(item);
                        final timeRemaining = item.timeRemaining;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              // Zoom to item location
                              if (_mapController != null && _mapReady) {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(item.latitude, item.longitude),
                                    17,
                                  ),
                                );
                              }
                              // Show item details
                              Future.delayed(const Duration(milliseconds: 500), () {
                                if (mounted) {
                                  _showScavengerHuntItemDetails(item);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Item Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: item.imageUrl.isNotEmpty
                                        ? Image.network(
                                            item.imageUrl,
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 70,
                                                height: 70,
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.image_not_supported, size: 30),
                                              );
                                            },
                                          )
                                        : Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.card_giftcard, size: 30),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Item Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.monetization_on, size: 16, color: Colors.green[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '₱${item.price.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.green[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // Countdown Timer
                                        if (timeRemaining != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: timeRemaining.inMinutes < 30 
                                                  ? Colors.red[100] 
                                                  : Colors.blue[100],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.timer,
                                                  size: 14,
                                                  color: timeRemaining.inMinutes < 30 
                                                      ? Colors.red[700] 
                                                      : Colors.blue[700],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatDuration(timeRemaining),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: timeRemaining.inMinutes < 30 
                                                        ? Colors.red[700] 
                                                        : Colors.blue[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isClaimedByMe 
                                          ? Colors.green[100]
                                          : item.isClaimed 
                                              ? Colors.red[100]
                                              : Colors.orange[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isClaimedByMe 
                                              ? Icons.check_circle 
                                              : item.isClaimed 
                                                  ? Icons.cancel 
                                                  : Icons.card_giftcard,
                                          size: 14,
                                          color: isClaimedByMe 
                                              ? Colors.green[700]
                                              : item.isClaimed 
                                                  ? Colors.red[700]
                                                  : Colors.orange[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isClaimedByMe 
                                              ? 'Yours'
                                              : item.isClaimed 
                                                  ? 'Taken'
                                                  : 'Open',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isClaimedByMe 
                                                ? Colors.green[700]
                                                : item.isClaimed 
                                                    ? Colors.red[700]
                                                    : Colors.orange[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scavengerHuntSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    if (!_mapReady) {
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied forever')),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted && _mapReady) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation, 15),
        );

        _getAddressFromCoordinates(position.latitude, position.longitude);
        _updateUserMarker();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    if (_isDisposed || !mounted) return;
    
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty && mounted && !_isDisposed) {
        Placemark place = placemarks.first;
        final street = place.street ?? '';
        final locality = place.locality ?? place.subLocality ?? place.administrativeArea ?? '';
        
        String address;
        if (street.isNotEmpty && locality.isNotEmpty) {
          address = '$street, $locality';
        } else if (locality.isNotEmpty) {
          address = locality;
        } else if (street.isNotEmpty) {
          address = street;
        } else {
          address = 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
        }
        
        setState(() {
          _currentLocationName = address;
        });
      }
    } catch (e) {
      // Silently fall back to coordinates if geocoding fails
      if (mounted && !_isDisposed) {
        setState(() {
          _currentLocationName = 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
        });
      }
    }
  }

  void _updateUserMarker() {
    if (!mounted || _isDisposed) return;
    
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'user_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentLocation,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  Future<void> _drawRoute(LocationData destination) async {
    final LatLng destinationLatLng = LatLng(destination.latitude, destination.longitude);
    
    try {
      // Get street address for the destination
      String destinationAddress = destination.address;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          destination.latitude,
          destination.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          final street = place.street ?? '';
          final locality = place.locality ?? place.subLocality ?? place.administrativeArea ?? '';
          
          if (street.isNotEmpty && locality.isNotEmpty) {
            destinationAddress = '$street, $locality';
          } else if (locality.isNotEmpty) {
            destinationAddress = locality;
          } else if (street.isNotEmpty) {
            destinationAddress = street;
          }
        }
      } catch (e) {
        // Use the provided address if geocoding fails
      }
      
      final directionsData = await _directionsService.getDirections(
        origin: _currentLocation,
        destination: destinationLatLng,
      );

      if (directionsData != null && mounted && !_isDisposed) {
        final polylineCoordinates = directionsData['polylineCoordinates'] as List<LatLng>?;
        
        if (polylineCoordinates != null && polylineCoordinates.isNotEmpty) {
          setState(() {
            _polylines.clear();
            
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: polylineCoordinates,
                color: Colors.blue,
                width: 5,
              ),
            );

            _routeDistance = directionsData['distance'] as String?;
            _routeDuration = directionsData['duration'] as String?;
            _destinationName = destinationAddress;

            _markers.removeWhere((marker) => marker.markerId.value == 'destination');
            _markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: destinationLatLng,
                infoWindow: InfoWindow(
                  title: 'Destination',
                  snippet: destinationAddress,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            );
          });

          _fitMapToBounds(polylineCoordinates);
        }
      }
    } catch (e) {
      print('Error drawing route: $e');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to draw route. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _fitMapToBounds(List<LatLng> coordinates) {
    if (coordinates.isEmpty || !_mapReady || _mapController == null) return;

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (var coord in coordinates) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100,
      ),
    );
  }

  void _clearRoute() {
    if (!mounted || _isDisposed) return;
    
    setState(() {
      _polylines.clear();
      _routeDistance = null;
      _routeDuration = null;
      _destinationName = '';
      _markers.removeWhere((marker) => marker.markerId.value == 'destination');
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveTransaction = widget.activeTransaction != null && 
                                      widget.activeTransaction!.sellerLocation != null &&
                                      widget.activeTransaction!.locationSharingEnabled;
    
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              if (_isDisposed) return;
              _mapController = controller;
              _mapReady = true;
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(_currentLocation, 15),
              );
              _getUserLocation().then((_) {
                if (hasActiveTransaction && !_isDisposed) {
                  _handleTransactionUpdate();
                }
                if (_showScavengerHunt && !_isDisposed) {
                  _updateScavengerHuntMarkers();
                }
                // Handle shared location if any
                if (widget.sharedLocation != null && !_isDisposed) {
                  _handleSharedLocation();
                }
              });
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          if (hasActiveTransaction)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Current Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3864FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentLocationName.isNotEmpty
                                      ? _currentLocationName
                                      : 'Getting location...',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Destination
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3864FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destination',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _destinationName.isNotEmpty
                                      ? _destinationName
                                      : widget.activeTransaction!.sellerLocation!.address,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (_routeDistance != null && _routeDuration != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.straighten, size: 18, color: Color(0xFF3864FF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _routeDistance!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: Colors.grey[300],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18, color: Color(0xFF3864FF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _routeDuration!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else if (widget.sharedLocation != null && _destinationName.isNotEmpty)
            // Shared location info card
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Current Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3864FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentLocationName.isNotEmpty
                                      ? _currentLocationName
                                      : 'Getting location...',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Destination
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3864FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destination',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _destinationName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (_routeDistance != null && _routeDuration != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.straighten, size: 18, color: Color(0xFF3864FF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _routeDistance!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: Colors.grey[300],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18, color: Color(0xFF3864FF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _routeDuration!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Only current location (no destination)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3864FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current location',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentLocationName.isNotEmpty
                                  ? _currentLocationName
                                  : 'Getting location...',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Scavenger hunt legend and active items button
          if (_showScavengerHunt && _scavengerHuntItems.isNotEmpty)
            Positioned(
              bottom: 220,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Items Button
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _showMyScavengerHuntItems,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.list_alt, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Active Items',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            const Text(
                              'Item Status',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _legendItem(Colors.orange, 'Available', 'Ready to claim'),
                        const SizedBox(height: 6),
                        _legendItem(Colors.green, 'Your Claims', 'Items you claimed'),
                        const SizedBox(height: 6),
                        _legendItem(Colors.red, 'Taken', 'Claimed by others'),
                        const SizedBox(height: 6),
                        _legendItem(Colors.grey, 'Ended', 'Event expired'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                // Scavenger hunt toggle button
                FloatingActionButton(
                  heroTag: 'toggleScavengerHunt',
                  backgroundColor: _showScavengerHunt ? const Color(0xFF3864FF) : Colors.white,
                  mini: true,
                  child: Icon(
                    Icons.card_giftcard,
                    color: _showScavengerHunt ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    if (!mounted || _isDisposed) return;
                    setState(() {
                      _showScavengerHunt = !_showScavengerHunt;
                      if (_showScavengerHunt) {
                        _updateScavengerHuntMarkers();
                      } else {
                        // Remove scavenger hunt markers
                        _markers.removeWhere((marker) => 
                          marker.markerId.value.startsWith('scavenger_'));
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  backgroundColor: Colors.white,
                  mini: true,
                  child: const Icon(Icons.add, color: Colors.black),
                  onPressed: () {
                    if (_mapController != null && _mapReady) {
                      _mapController?.animateCamera(
                        CameraUpdate.zoomIn(),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  backgroundColor: Colors.white,
                  mini: true,
                  child: const Icon(Icons.remove, color: Colors.black),
                  onPressed: () {
                    if (_mapController != null && _mapReady) {
                      _mapController?.animateCamera(
                        CameraUpdate.zoomOut(),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'centerLocation',
                  backgroundColor: Colors.white,
                  mini: true,
                  child: const Icon(Icons.my_location, color: Colors.black),
                  onPressed: _getUserLocation,
                ),
              ],
            ),
          ),
          // Scalp Logo in top-left corner
          Positioned(
            top: 40,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/scalp_logo_w_v2.png',
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, [String? description]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description != null)
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

