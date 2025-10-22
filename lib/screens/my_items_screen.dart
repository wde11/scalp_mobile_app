import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// PC-related categories for the dropdown menu (re-using from listing_screen.dart)
const List<String> pcCategories = [
  'CPU/Processors',
  'Motherboards',
  'RAM/Memory',
  'Graphics Cards',
  'Storage (SSD/HDD)',
  'Power Supplies',
  'Cases/Chassis',
  'Cooling Systems',
  'Monitors',
  'Keyboards',
  'Mouse/Pointing Devices',
  'Audio Equipment',
  'Networking Components',
  'Cables & Adapters',
  'PC Peripherals',
  'Gaming Accessories',
  'Software',
  'Pre-built PCs',
  'Laptop Components',
  'Other PC Parts'
];

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> _deleteListing(String listingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text('Are you sure you want to delete this listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('listings').doc(listingId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting listing: $e')),
        );
      }
    }
  }

  void _showEditListingDialog(DocumentSnapshot listing) {
    final data = listing.data() as Map<String, dynamic>;
    final titleController = TextEditingController(text: data['title']);
    final categoryController = TextEditingController(text: data['category']);
    final descriptionController = TextEditingController(text: data['description']);
    final priceController = TextEditingController(text: data['price'].toString());
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Listing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '₱',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          try {
                            await _firestore
                                .collection('listings')
                                .doc(listing.id)
                                .update({
                              'title': titleController.text.trim(),
                              'category': categoryController.text.trim(),
                              'description': descriptionController.text.trim(),
                              'price':
                                  double.parse(priceController.text.trim()),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Listing updated successfully')),
                              );
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Error updating listing: $e')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Listing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Items')),
        body: const Center(
          child: Text('Please log in to view your items.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Items'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('listings')
            .where('userId', isEqualTo: currentUser!.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('You have no items listed.'));
          }

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final listing = snapshot.data!.docs[index];
              final data = listing.data() as Map<String, dynamic>;
              return _buildListItem(
                context,
                data['title'] ?? 'No Title',
                data['category'] ?? 'No Category',
                '₱${data['price']?.toString() ?? '0'}',
                data['imageUrl'] ?? 'assets/images/placeholder.png',
                isOwner: true, // Always true for My Items screen
                onEdit: () => _showEditListingDialog(listing),
                onDelete: () => _deleteListing(listing.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    String name,
    String category,
    String price,
    String imagePath, {
    bool isOwner = false,
    VoidCallback? onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      image: DecorationImage(
                        image: imagePath.startsWith('assets/')
                            ? AssetImage(imagePath.replaceFirst('assets/', ''))
                            : NetworkImage(imagePath) as ImageProvider<Object>,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isOwner)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 8)],
                      ),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 8)],
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
