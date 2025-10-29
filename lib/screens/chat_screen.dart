import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/location_data.dart';
import '../globals.dart';

// A modern chat UI with Firestore and Cloudinary integration
class ChatScreen extends StatefulWidget {
  final String? initialChatId;
  final String? initialUserId;

  const ChatScreen({
    super.key,
    this.initialChatId,
    this.initialUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final cloudinary = CloudinaryPublic('dp5mqhd9w', 'scalp_chat', cache: false);

  String? _selectedChatId;
  String? _selectedUserId;
  String? _selectedUserName; // Store the selected user's name
  bool _isUploading = false;
  bool _locationSharingEnabled = true; // Toggle for location sharing

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    // If we have initial chat IDs, set them
    if (widget.initialChatId != null && widget.initialUserId != null) {
      _selectedChatId = widget.initialChatId;
      _selectedUserId = widget.initialUserId;
    }
  }

  // Get or create a chat between two users
  Future<String> _getOrCreateChat(String otherUserId) async {
    if (currentUser == null) throw Exception('Not logged in');
    
    final currentUserId = currentUser!.uid;
    final chatId = _generateChatId(currentUserId, otherUserId);
    
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    
    if (!chatDoc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }
    
    return chatId;
  }
  
  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }
  
  // Format timestamp for chat list
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);
    
    if (difference.inDays == 0) {
      // Today - show time
      final hour = messageTime.hour > 12 ? messageTime.hour - 12 : messageTime.hour;
      final period = messageTime.hour >= 12 ? 'PM' : 'AM';
      return '${hour == 0 ? 12 : hour}:${messageTime.minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return days[messageTime.weekday % 7];
    } else {
      // Older - show date
      return '${messageTime.month}/${messageTime.day}/${messageTime.year % 100}';
    }
  }
  
  Future<void> _sendMessage({String? imageUrl, LocationData? location}) async {
    if (currentUser == null || _selectedChatId == null) return;
    
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && imageUrl == null && location == null) return;
    
    try {
      final messageData = {
        'senderId': currentUser!.uid,
        'text': messageText,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };
      
      // Add location data if provided
      if (location != null) {
        messageData['location'] = {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': location.address,
          'timestamp': location.timestamp.toIso8601String(),
        };
      }
      
      await _firestore
          .collection('chats')
          .doc(_selectedChatId)
          .collection('messages')
          .add(messageData);
      
      // Update chat's last message
      String lastMessageText = messageText.isNotEmpty 
          ? messageText 
          : (location != null ? '📍 Location shared' : 'Image');
      
      await _firestore.collection('chats').doc(_selectedChatId).update({
        'lastMessage': lastMessageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      
      _messageController.clear();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }
  
  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return;
    
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      
      if (image == null) return;
      
      setState(() => _isUploading = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading image...')),
        );
      }
      
      // Upload to Cloudinary
      String? imageUrl;
      try {
        CloudinaryFile? cloudinaryFile;
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
          cloudinaryFile = CloudinaryFile.fromBytesData(
            bytes,
            identifier: fileName,
            resourceType: CloudinaryResourceType.Image,
          );
        } else {
          cloudinaryFile = CloudinaryFile.fromFile(
            image.path,
            folder: 'chats',
            resourceType: CloudinaryResourceType.Image,
          );
        }
        
        final response = await cloudinary.uploadFile(cloudinaryFile);
        imageUrl = response.secureUrl;
      } catch (uploadError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $uploadError')),
          );
        }
        setState(() => _isUploading = false);
        return;
      }
      
      // Send message with image
      await _sendMessage(imageUrl: imageUrl);
      
      setState(() => _isUploading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image sent successfully')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  Future<void> _shareLocation() async {
    if (_isUploading) return;
    
    // Check if location sharing is enabled
    if (!_locationSharingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sharing is currently disabled. Enable it from the top-right icon.'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF3864FF)),
            SizedBox(width: 8),
            Text('Share Your Location?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will share your real-time GPS location with this person.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'They will be able to see your exact coordinates and address.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3864FF),
            ),
            child: const Text(
              'Share Location',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    // If user cancelled, don't proceed
    if (confirmed != true) return;
    
    setState(() => _isUploading = true);
    
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || 
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          setState(() => _isUploading = false);
          return;
        }
      }
      
      // Get current location
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Getting your location...')),
        );
      }
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      // Get address from coordinates
      String address = 'Location shared';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final street = place.street ?? '';
          final locality = place.locality ?? place.subLocality ?? place.administrativeArea ?? '';
          
          if (street.isNotEmpty && locality.isNotEmpty) {
            address = '$street, $locality';
          } else if (locality.isNotEmpty) {
            address = locality;
          } else if (street.isNotEmpty) {
            address = street;
          } else {
            address = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
          }
        }
      } catch (e) {
        address = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
      }
      
      // Create LocationData object
      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        timestamp: DateTime.now(),
      );
      
      // Send message with location
      await _sendMessage(location: locationData);
      
      setState(() => _isUploading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location shared successfully')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing location: $e')),
        );
      }
    }
  }
  
  Stream<List<Map<String, dynamic>>> _getUserChatsStream() {
    if (currentUser == null) {
      print('DEBUG: No current user logged in');
      return Stream.value([]);
    }
    
    print('DEBUG: Fetching chats for user: ${currentUser!.uid}');
    
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser!.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      print('DEBUG: Received ${snapshot.docs.length} chat documents');
      List<Map<String, dynamic>> chats = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != currentUser!.uid,
          orElse: () => '',
        );
        
        if (otherUserId.isEmpty) continue;
        
        // Fetch other user's data
        final userDoc = await _firestore.collection('users').doc(otherUserId).get();
        final userData = userDoc.data() ?? {};
        
        // If no name in Firestore, try to get it from Firebase Auth or email
        String displayName = userData['name'] ?? '';
        if (displayName.isEmpty) {
          // Try to get from email (use part before @)
          final userEmail = userData['email'] ?? '';
          if (userEmail.isNotEmpty) {
            displayName = userEmail.split('@')[0];
          } else {
            displayName = 'User ${otherUserId.substring(0, 6)}';
          }
        }
        
        chats.add({
          'chatId': doc.id,
          'userId': otherUserId,
          'name': displayName,
          'username': userData['username'] ?? '',
          'avatar': userData['profilePicture'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=random',
          'lastMessage': data['lastMessage'] ?? '',
          'lastMessageTime': data['lastMessageTime'],
        });
      }
      
      // Sort by lastMessageTime on client side (most recent first)
      chats.sort((a, b) {
        final aTime = a['lastMessageTime'] as Timestamp?;
        final bTime = b['lastMessageTime'] as Timestamp?;
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1; // Put null times at the end
        if (bTime == null) return -1;
        
        return bTime.compareTo(aTime); // Descending order (most recent first)
      });
      
      print('DEBUG: Returning ${chats.length} chats after processing');
      
      return chats;
    });
  }
  
  Stream<QuerySnapshot> _getMessagesStream() {
    if (_selectedChatId == null) return Stream.value(FirebaseFirestore.instance.collection('chats').doc('empty').collection('messages').snapshots() as QuerySnapshot);
    
    return _firestore
        .collection('chats')
        .doc(_selectedChatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
  
  // Show dialog to select a user to start a new chat
  void _showNewChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _NewChatDialog(
        currentUserId: currentUser?.uid ?? '',
        onUserSelected: (userId, userName) async {
          try {
            final chatId = await _getOrCreateChat(userId);
            if (mounted) {
              setState(() {
                _selectedChatId = chatId;
                _selectedUserId = userId;
              });
              Navigator.of(context).pop();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to create chat: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Single-page chat experience: chats list OR conversation pane
    return FutureBuilder<DocumentSnapshot?>(
      future: _selectedUserId != null 
          ? _firestore.collection('users').doc(_selectedUserId).get()
          : Future.value(null),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;

        // Build AppBar content based on selection
        String titleText = 'Chats';
        String usernameText = '';
        String avatarUrl = 'https://ui-avatars.com/api/?name=User&background=random';
        if (_selectedUserId != null && userData != null) {
          titleText = (userData['name'] ?? '') as String;
          usernameText = (userData['username'] ?? '') as String;
          if (titleText.isEmpty) {
            final userEmail = (userData['email'] ?? '') as String;
            if (userEmail.isNotEmpty) {
              titleText = userEmail.split('@')[0];
              if (usernameText.isEmpty) usernameText = userEmail.split('@')[0].toLowerCase();
            } else {
              titleText = 'User';
            }
          }
          avatarUrl = (userData['profilePicture'] ?? avatarUrl) as String;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F9),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: _selectedUserId != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () {
                      setState(() {
                        _selectedChatId = null;
                        _selectedUserId = null;
                      });
                    },
                  )
                : null,
            title: _selectedUserId != null
                ? Row(
                    children: [
                      CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titleText, style: const TextStyle(color: Colors.black87, fontSize: 16)),
                          if (usernameText.isNotEmpty)
                            Text('@$usernameText', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  )
                : const Text('Chats', style: TextStyle(color: Colors.black87)),
            actions: _selectedUserId == null
                ? [
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF121330)),
                      onPressed: () => _showNewChatDialog(context),
                    ),
                  ]
                : [
                    // Location sharing toggle
                    IconButton(
                      icon: Icon(
                        _locationSharingEnabled ? Icons.location_on : Icons.location_off,
                        color: _locationSharingEnabled ? const Color(0xFF3864FF) : Colors.grey,
                      ),
                      tooltip: _locationSharingEnabled 
                        ? 'Location sharing ON' 
                        : 'Location sharing OFF',
                      onPressed: () {
                        setState(() {
                          _locationSharingEnabled = !_locationSharingEnabled;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _locationSharingEnabled
                                  ? 'Location sharing enabled'
                                  : 'Location sharing disabled',
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: _locationSharingEnabled ? Colors.green : Colors.grey,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Color(0xFF1F2030)),
                      onPressed: () {},
                    )
                  ],
          ),
          body: SafeArea(
            child: _selectedUserId == null
                ? _buildChatsListBody(context)
                : _buildChatPane(context),
          ),
        );
      },
    );
  }

  // Unified chats list body (search + recent + all chats) in a single page
  Widget _buildChatsListBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search messenger...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Recent chats
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getUserChatsStream(),
          builder: (context, recentSnapshot) {
            if (recentSnapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${recentSnapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12)),
              );
            }
            if (!recentSnapshot.hasData || recentSnapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final recentChats = recentSnapshot.data!
                .where((chat) => chat['lastMessage']?.toString().isNotEmpty ?? false)
                .take(6)
                .toList();
            if (recentChats.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text('Recent Chats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF121330))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFEEF1FF), borderRadius: BorderRadius.circular(10)),
                        child: Text('${recentChats.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3864FF))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: recentChats.length,
                    itemBuilder: (context, index) {
                      final chat = recentChats[index];
                      final isSelected = chat['chatId'] == _selectedChatId;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedChatId = chat['chatId'];
                            _selectedUserId = chat['userId'];
                            _selectedUserName = chat['name']; // Fixed: was 'userName', should be 'name'
                          });
                        },
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: isSelected ? Border.all(color: const Color(0xFF3864FF), width: 3) : null,
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: const Color(0xFF3864FF).withOpacity(0.3), blurRadius: 8, spreadRadius: 2)]
                                          : null,
                                    ),
                                    child: CircleAvatar(radius: 28, backgroundImage: NetworkImage(chat['avatar'])),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                chat['name'].toString().split(' ')[0],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF3864FF) : const Color(0xFF121330),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('All Chats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF121330))),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),

        // All chats list
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getUserChatsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('Error loading chats:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No chats yet.\nStart a conversation!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                );
              }

              final chats = snapshot.data!;
              final searchQuery = _searchController.text.toLowerCase();
              final filteredChats = searchQuery.isEmpty
                  ? chats
                  : chats.where((chat) {
                      final name = (chat['name'] ?? '').toString().toLowerCase();
                      final username = (chat['username'] ?? '').toString().toLowerCase();
                      final lastMessage = (chat['lastMessage'] ?? '').toString().toLowerCase();
                      return name.contains(searchQuery) || username.contains(searchQuery) || lastMessage.contains(searchQuery);
                    }).toList();

              if (filteredChats.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No chats match your search', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                );
              }

              return ListView.separated(
                itemCount: filteredChats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final chat = filteredChats[index];
                  final isSelected = chat['chatId'] == _selectedChatId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        setState(() {
                          _selectedChatId = chat['chatId'];
                          _selectedUserId = chat['userId'];
                          _selectedUserName = chat['name']; // Added: set selected user name
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF3864FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(backgroundImage: NetworkImage(chat['avatar'])),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chat['name'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: isSelected ? Colors.white : const Color(0xFF1E1F28),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTimestamp(chat['lastMessageTime']),
                                        style: TextStyle(fontSize: 11, color: isSelected ? Colors.white60 : Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                  if (chat['username'] != null && chat['username'].toString().isNotEmpty)
                                    Text('@${chat['username']}', style: TextStyle(fontSize: 11, color: isSelected ? Colors.white60 : Colors.grey[500])),
                                  const SizedBox(height: 2),
                                  Text(
                                    chat['lastMessage'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey[600]),
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
              );
            },
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  // Right Pane (conversation)
  Widget _buildChatPane(BuildContext context) {
    if (_selectedChatId == null || _selectedUserId == null) {
      return const Center(
        child: Text(
          'Select a chat to start messaging',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(_selectedUserId).get(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        
        // Handle missing user data gracefully
        String userName = userData?['name'] ?? '';
        String userUsername = userData?['username'] ?? '';
        
        if (userName.isEmpty) {
          final userEmail = userData?['email'] ?? '';
          if (userEmail.isNotEmpty) {
            userName = userEmail.split('@')[0];
            if (userUsername.isEmpty) {
              userUsername = userEmail.split('@')[0].toLowerCase();
            }
          } else {
            userName = 'User';
            userUsername = 'user';
          }
        }
        
        final userAvatar = userData?['profilePicture'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=random';
        
        return Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(backgroundImage: NetworkImage(userAvatar)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      if (userUsername.isNotEmpty)
                        Text(
                          '@$userUsername',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                    ],
                  ),
                  const Spacer(),
                  _headerIcon(Icons.info_outline),
                ],
              ),
            ),
            const Divider(height: 1),

            // Messages
            Expanded(
              child: Container(
                color: Colors.white,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getMessagesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No messages yet.\nSend a message to start the conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    
                    final messages = snapshot.data!.docs;
                    
                    return FutureBuilder<DocumentSnapshot?>(
                      future: currentUser != null 
                          ? _firestore.collection('users').doc(currentUser!.uid).get()
                          : Future.value(null),
                      builder: (context, userSnapshot) {
                        final currentUserData = userSnapshot.data?.data() as Map<String, dynamic>?;
                        final currentUserName = currentUserData?['name'] ?? 'Me';
                        final currentUserAvatar = currentUserData?['profilePicture'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(currentUserName)}&background=random';
                        
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index].data() as Map<String, dynamic>;
                            final isMe = message['senderId'] == currentUser?.uid;
                            final text = message['text'] ?? '';
                            final imageUrl = message['imageUrl'];
                            final locationData = message['location'];
                            final avatarUrl = isMe ? currentUserAvatar : userAvatar;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl != null)
                                    _messageImageRow(
                                      isMe: isMe,
                                      avatar: avatarUrl,
                                      imageUrl: imageUrl,
                                    ),
                                  if (locationData != null)
                                    _messageLocationRow(
                                      isMe: isMe,
                                      avatar: avatarUrl,
                                      locationData: locationData,
                                    ),
                                  if (text.isNotEmpty)
                                    _messageRow(
                                      isMe: isMe,
                                      avatar: avatarUrl,
                                      text: text,
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Input area
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  _actionCircle(Icons.more_horiz),
                  const SizedBox(width: 8),
                  _actionCircleButton(Icons.photo_outlined, _pickAndUploadImage),
                  const SizedBox(width: 8),
                  _actionCircleButton(Icons.location_on_outlined, _shareLocation),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1F5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 44,
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _sendButton(),
                ],
              ),
            )
          ],
        );
      },
    );
  }

  Widget _headerIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFF0F1F5),
        child: Icon(icon, color: const Color(0xFF1F2030)),
      ),
    );
  }

  Widget _actionCircle(IconData icon) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFF0F1F5),
      child: Icon(icon, color: Colors.black87, size: 20),
    );
  }
  
  Widget _actionCircleButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: _isUploading ? null : onPressed,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: _isUploading ? Colors.grey[300] : const Color(0xFFF0F1F5),
        child: Icon(icon, color: _isUploading ? Colors.grey : Colors.black87, size: 20),
      ),
    );
  }

  Widget _sendButton() {
    return GestureDetector(
      onTap: () => _sendMessage(),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF3864FF),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: const Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _messageRow({required bool isMe, required String avatar, required String text}) {
    final bubbleColor = isMe ? const Color(0xFF3864FF) : const Color(0xFF7B7D82);
    final textColor = Colors.white;
    final alignment = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final avatarWidget = CircleAvatar(radius: 16, backgroundImage: NetworkImage(avatar));

    return Row(
      mainAxisAlignment: alignment,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) avatarWidget,
        if (!isMe) const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
        if (isMe) const SizedBox(width: 8),
        if (isMe) avatarWidget,
      ],
    );
  }
  
  Widget _messageImageRow({required bool isMe, required String avatar, required String imageUrl}) {
    final alignment = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final avatarWidget = CircleAvatar(radius: 16, backgroundImage: NetworkImage(avatar));

    return Row(
      mainAxisAlignment: alignment,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) avatarWidget,
        if (!isMe) const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(maxWidth: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        ),
        if (isMe) const SizedBox(width: 8),
        if (isMe) avatarWidget,
      ],
    );
  }
  
  Widget _messageLocationRow({required bool isMe, required String avatar, required Map<String, dynamic> locationData}) {
    final alignment = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final avatarWidget = CircleAvatar(radius: 16, backgroundImage: NetworkImage(avatar));
    final bubbleColor = isMe ? const Color(0xFF3864FF) : const Color(0xFF7B7D82);
    
    final latitude = locationData['latitude'] as double?;
    final longitude = locationData['longitude'] as double?;
    final address = locationData['address'] as String?;

    return Row(
      mainAxisAlignment: alignment,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) avatarWidget,
        if (!isMe) const SizedBox(width: 8),
        Flexible(
          child: GestureDetector(
            onTap: () {
              print('DEBUG: Location bubble tapped!');
              if (latitude != null && longitude != null) {
                print('DEBUG: Location data - Lat: $latitude, Lng: $longitude');
                // Get sender name from the selected user
                final senderName = isMe ? 'You' : (_selectedUserName ?? 'Unknown');
                print('DEBUG: Sender name: $senderName');
                // Navigate to map tab with the location
                _navigateToMapWithLocation(
                  latitude, 
                  longitude, 
                  address,
                  userName: senderName,
                  userAvatar: avatar,
                );
              } else {
                print('DEBUG: Location data is null!');
              }
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'Location Shared',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (address != null && address.isNotEmpty && address != 'Location shared') ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to view on map',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (isMe) const SizedBox(width: 8),
        if (isMe) avatarWidget,
      ],
    );
  }

  void _navigateToMapWithLocation(double latitude, double longitude, String? address, {String? userName, String? userAvatar}) {
    print('DEBUG: Navigating to map with location...');
    
    // Set the shared location in global state (this will trigger the callback)
    SharedLocationState.setSharedLocation(
      LocationData(
        latitude: latitude,
        longitude: longitude,
        address: address ?? 'Shared Location',
        timestamp: DateTime.now(),
      ),
      userName: userName,
      userAvatar: userAvatar,
    );
    
    print('DEBUG: Shared location set - shouldNavigate: ${SharedLocationState.shouldNavigateToMap}');
    print('DEBUG: Callback registered: ${SharedLocationState.onNavigateToMap != null}');
    
    // The callback should automatically switch the tab
    // If we're in a nested route within ChatScreen, pop back to home first
    if (Navigator.of(context).canPop()) {
      print('DEBUG: Popping back to home screen...');
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

// Dialog to show all users and start a new chat
class _NewChatDialog extends StatefulWidget {
  final String currentUserId;
  final Function(String userId, String userName) onUserSelected;

  const _NewChatDialog({
    required this.currentUserId,
    required this.onUserSelected,
  });

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Start New Chat',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by name, username, or email...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            // Users list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  // Filter users
                  final allUsers = snapshot.data!.docs.where((doc) {
                    // Exclude current user
                    if (doc.id == widget.currentUserId) return false;
                    
                    // Apply search filter
                    if (_searchQuery.isNotEmpty) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final email = (data['email'] ?? '').toString().toLowerCase();
                      final username = (data['username'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || 
                             email.contains(_searchQuery) ||
                             username.contains(_searchQuery);
                    }
                    
                    return true;
                  }).toList();
                  
                  // Sort users alphabetically by name
                  allUsers.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aName = (aData['name'] ?? '').toString().toLowerCase();
                    final bName = (bData['name'] ?? '').toString().toLowerCase();
                    return aName.compareTo(bName);
                  });

                  if (allUsers.isEmpty) {
                    return const Center(
                      child: Text(
                        'No users match your search',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: allUsers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final userDoc = allUsers[index];
                      final userData = userDoc.data() as Map<String, dynamic>;
                      final userId = userDoc.id;
                      final userName = userData['name'] ?? 'Unknown User';
                      final username = userData['username'] ?? '';
                      final userEmail = userData['email'] ?? '';
                      final userAvatar = userData['profilePicture'] ?? 
                                       'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=random';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(userAvatar),
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          username.isNotEmpty ? '@$username' : userEmail,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3864FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              widget.onUserSelected(userId, userName);
                            },
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
    );
  }
}

// Placeholder for future message model if needed.


