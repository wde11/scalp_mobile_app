import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class MyCartScreen extends StatefulWidget {
  const MyCartScreen({super.key});

  @override
  State<MyCartScreen> createState() => _MyCartScreenState();
}

class _MyCartScreenState extends State<MyCartScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> _removeCartItem(String listingId) async {
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('carts')
          .doc(currentUser!.uid)
          .collection('items')
          .doc(listingId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed from cart')),
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
      return Scaffold(
        appBar: AppBar(title: const Text('My Cart')),
        body: const Center(
          child: Text('Please log in to view your cart.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('carts')
            .doc(currentUser!.uid)
            .collection('items')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Your cart is empty.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final cartItem = snapshot.data!.docs[index];
              final data = cartItem.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'No Title';
              final price = data['price']?.toString() ?? '0';
              final imageUrl = data['imageUrl'] ?? 'assets/images/placeholder.png';
              final listingId = cartItem.id;
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
                            onPressed: () => _removeCartItem(listingId),
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
