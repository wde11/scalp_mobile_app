import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class MyWishlistScreen extends StatefulWidget {
  const MyWishlistScreen({super.key});

  @override
  State<MyWishlistScreen> createState() => _MyWishlistScreenState();
}

class _MyWishlistScreenState extends State<MyWishlistScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> _removeWishlistItem(String listingId) async {
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('wishlists')
          .doc(currentUser!.uid)
          .collection('items')
          .doc(listingId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed from wishlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
    }
  }

  Future<void> _contactSeller(BuildContext context, String sellerId) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to contact the seller'),
        ),
      );
      return;
    }

    if (sellerId == currentUser!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is your own listing'),
        ),
      );
      return;
    }

    try {
      // Create chat ID
      final sortedIds = [currentUser!.uid, sellerId]..sort();
      final chatId = '${sortedIds[0]}_${sortedIds[1]}';

      // Check if chat exists, if not create it
      final chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        await _firestore
            .collection('chats')
            .doc(chatId)
            .set({
          'participants': [currentUser!.uid, sellerId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }

      // Navigate to home with chat parameters
      if (mounted) {
        context.replace('/?chatId=$chatId&userId=$sellerId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      print('Wishlist: User not authenticated');
      return Scaffold(
        appBar: AppBar(title: const Text('My Wishlist')),
        body: const Center(
          child: Text('Please log in to view your wishlist.'),
        ),
      );
    }

    print('Wishlist: Loading for user ${currentUser!.uid}');
    print('Wishlist path: wishlists/${currentUser!.uid}/items');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Wishlist'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('wishlists')
            .doc(currentUser!.uid)
            .collection('items')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Wishlist ERROR: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print('Wishlist: Empty or no data');
            return const Center(child: Text('Your wishlist is empty.'));
          }

          print('Wishlist: Found ${snapshot.data!.docs.length} items');
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final wishlistItem = snapshot.data!.docs[index];
              final data = wishlistItem.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'No Title';
              final price = data['price']?.toString() ?? '0';
              final imageUrl = data['imageUrl'] ?? 'assets/images/placeholder.png';
              final listingId = wishlistItem.id;
              final sellerId = data['sellerId'];

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: imageUrl.startsWith('assets/')
                                ? Image.asset(
                                    imageUrl.replaceFirst('assets/', ''),
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₱$price',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeWishlistItem(listingId),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _contactSeller(context, sellerId),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Contact Seller'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
