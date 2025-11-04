import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:typed_data';

// PC-related categories for the dropdown menu
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

class ListingScreen extends StatefulWidget {
  const ListingScreen({super.key});

  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _showFreeItems = false; // Toggle between free and for-sale items
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteListing(String listingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delete_rounded,
                color: Colors.red.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Listing',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Are you sure you want to delete this listing? This action cannot be undone.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: BorderSide(color: Colors.grey.shade300, width: 2),
              foregroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('listings').doc(listingId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Listing deleted successfully')),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error deleting listing: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade400, Colors.orange.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Edit Listing',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      prefixIcon: const Icon(Icons.category_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: const Icon(Icons.description_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixText: '₱',
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 28.0),
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
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.white),
                                        SizedBox(width: 12),
                                        Text('Listing updated successfully'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error_rounded, color: Colors.white),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text('Error updating listing: $e'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => isLoading = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.save_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Update Listing',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/scalp_logo_w_v2.png',
            fit: BoxFit.contain,
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search listings...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.black, fontSize: 18),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : const Text('Listing'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(icon: const Icon(Icons.person), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _showFreeItems ? Icons.card_giftcard_rounded : Icons.store_rounded,
                        color: _showFreeItems ? Colors.orange.shade600 : Colors.blue.shade600,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _showFreeItems ? 'Free Items' : 'Items for Sale',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _showFreeItems ? Colors.orange.shade700 : Colors.blue.shade700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Toggle button with enhanced styling
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showFreeItems = !_showFreeItems;
                            });
                          },
                          icon: Icon(
                            _showFreeItems ? Icons.shopping_bag_rounded : Icons.card_giftcard_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _showFreeItems ? 'For Sale' : 'Free',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            backgroundColor: _showFreeItems ? Colors.green.shade600 : Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            context.push('/my-wishlist');
                          },
                          icon: const Icon(Icons.favorite_rounded, size: 18),
                          label: const Text(
                            'Wishlist',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            side: BorderSide(color: Colors.pink.shade300, width: 2),
                            foregroundColor: Colors.pink.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            context.push('/my-items');
                          },
                          icon: const Icon(Icons.inventory_2_rounded, size: 18),
                          label: const Text(
                            'My Items',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            side: BorderSide(color: Colors.purple.shade300, width: 2),
                            foregroundColor: Colors.purple.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('listings')
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
                    return const Center(child: Text('No listings available'));
                  }

                  final currentUserId = _auth.currentUser?.uid;
                  
                  // Filter out sold items, own items, and filter by free/for-sale
                  final availableListings = snapshot.data!.docs
                      .where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final isSold = data['isSold'] == true;
                        final isOwnItem = data['userId'] == currentUserId;
                        final price = data['price'] ?? 0.0;
                        final isFree = price == 0.0;
                        
                        // Search filter
                        bool matchesSearch = true;
                        if (_searchQuery.isNotEmpty) {
                          final title = (data['title'] ?? '').toString().toLowerCase();
                          final category = (data['category'] ?? '').toString().toLowerCase();
                          final description = (data['description'] ?? '').toString().toLowerCase();
                          
                          matchesSearch = title.contains(_searchQuery) ||
                                         category.contains(_searchQuery) ||
                                         description.contains(_searchQuery);
                        }
                        
                        // Filter logic: exclude sold items, exclude own items, match free/for-sale filter, and match search
                        return !isSold && !isOwnItem && (isFree == _showFreeItems) && matchesSearch;
                      })
                      .toList();

                  if (availableListings.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                          ? 'No results found for "$_searchQuery"'
                          : (_showFreeItems 
                              ? 'No free items available' 
                              : 'No items for sale available')
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: availableListings.length,
                    itemBuilder: (context, index) {
                      final listing = availableListings[index];
                      final data = listing.data() as Map<String, dynamic>;
                      final price = data['price'] ?? 0.0;
                      final priceText = price == 0.0 ? 'FREE' : '₱${price.toString()}';
                      
                      return _buildListItem(
                        context,
                        data['title'] ?? 'No Title',
                        data['category'] ?? 'No Category',
                        priceText,
                        data['imageUrl'] ?? 'assets/images/placeholder.png',
                        isOwner: _auth.currentUser?.uid == data['userId'],
                        isFree: price == 0.0,
                        onTap: () => _showListingDetails(context, listing),
                        onEdit: () => _showEditListingDialog(listing),
                        onDelete: () => _deleteListing(listing.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const _CreateListingModal(),
          );
        },
        label: const Text('Create Listing'),
        icon: const Icon(Icons.add),
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
    bool isFree = false,
    VoidCallback? onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced image container with gradient overlay
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: imagePath.startsWith('assets/')
                                ? AssetImage(imagePath.replaceFirst('assets/', ''))
                                : NetworkImage(imagePath) as ImageProvider<Object>,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Gradient overlay for better text readability
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Free badge
                      if (isFree)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'FREE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Enhanced info section
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFree ? Colors.orange.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          price,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isFree ? Colors.orange.shade700 : Colors.green.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Enhanced owner controls
            if (isOwner)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onEdit,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onDelete,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.delete_rounded,
                              color: Colors.red.shade300,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  void _showListingDetails(BuildContext context, QueryDocumentSnapshot listing) {
    showDialog(
      context: context,
      builder: (context) => _ListingDetailsModal(listing: listing),
    );
  }
}

class _CreateListingModal extends StatefulWidget {
  const _CreateListingModal();

  @override
  State<_CreateListingModal> createState() => _CreateListingModalState();
}

class _CreateListingModalState extends State<_CreateListingModal> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final cloudinary = CloudinaryPublic('dp5mqhd9w', 'scalp_preset', cache: false);
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategory;
  XFile? _selectedImage;
  bool _isLoading = false;
  bool _isFree = false; // New field for free items

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _createListing() async {
    // Check authentication first
    if (_auth.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to create a listing')),
        );
      }
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final price = _isFree ? 0.0 : double.tryParse(_priceController.text.trim());

    if (title.isEmpty || _selectedCategory == null || description.isEmpty || (!_isFree && price == null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFree 
                ? 'Please fill all fields correctly' 
                : 'Please fill all fields correctly and enter a valid price'
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      String imageUrl = 'assets/images/placeholder.png';

      // Try to upload image if selected, but don't fail the entire listing creation
      if (_selectedImage != null) {
        try {
          CloudinaryFile? cloudinaryFile;
          if (kIsWeb) {
            final bytes = await _selectedImage!.readAsBytes();
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name}';
            cloudinaryFile = CloudinaryFile.fromBytesData(
              bytes,
              identifier: fileName,
              resourceType: CloudinaryResourceType.Image,
            );
          } else {
            cloudinaryFile = CloudinaryFile.fromFile(
              _selectedImage!.path,
              folder: 'listings',
              resourceType: CloudinaryResourceType.Image,
            );
          }
          final response = await cloudinary.uploadFile(cloudinaryFile);
          imageUrl = response.secureUrl;
        } catch (uploadError) {
          // Log the error but continue with placeholder image
          print('Image upload failed: $uploadError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image upload failed. Using placeholder. Check Cloudinary settings.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          // Continue with placeholder image
        }
      }

      await _firestore.collection('listings').add({
        'title': title,
        'category': _selectedCategory,
        'description': description,
        'price': price ?? 0.0,
        'isFree': _isFree,
        'imageUrl': imageUrl,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing created successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating listing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_box_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Create New Listing',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 24.0),
              // Enhanced image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: _selectedImage == null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                          )
                        : null,
                    border: Border.all(
                      color: Colors.blue.shade200,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: kIsWeb
                              ? FutureBuilder<Uint8List>(
                                  future: _selectedImage!.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.6),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.edit_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      File(_selectedImage!.path),
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 56,
                              color: Colors.blue.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tap to add image',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recommended: 1024x1024',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20.0),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter item title',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'Select category',
                  prefixIcon: const Icon(Icons.category_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: pcCategories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your item',
                  prefixIcon: const Icon(Icons.description_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16.0),
              // Enhanced FREE checkbox
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isFree ? Colors.orange.shade50 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isFree ? Colors.orange.shade200 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isFree,
                      onChanged: (bool? value) {
                        setState(() {
                          _isFree = value ?? false;
                          if (_isFree) {
                            _priceController.clear();
                          }
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Icon(
                      Icons.card_giftcard_rounded,
                      color: _isFree ? Colors.orange.shade600 : Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'This item is FREE',
                      style: TextStyle(
                        fontWeight: _isFree ? FontWeight.w600 : FontWeight.normal,
                        color: _isFree ? Colors.orange.shade700 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _priceController,
                enabled: !_isFree,
                decoration: InputDecoration(
                  labelText: _isFree ? 'Price (FREE)' : 'Price',
                  hintText: _isFree ? 'Item is free' : 'Enter price',
                  prefixIcon: Icon(
                    Icons.attach_money_rounded,
                    color: _isFree ? Colors.grey : null,
                  ),
                  prefixText: '₱',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _isFree ? Colors.grey.shade200 : Colors.grey.shade50,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 28.0),
              ElevatedButton(
                onPressed: _isLoading ? null : _createListing,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Create Listing',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
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
  }
}

// Listing Details Modal
class _ListingDetailsModal extends StatelessWidget {
  final QueryDocumentSnapshot listing;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  _ListingDetailsModal({required this.listing});

  Future<void> _addToWishlist(BuildContext context) async {
    final currentUser = _auth.currentUser;
    
    print('=== ADD TO WISHLIST DEBUG ===');
    print('Current user: ${currentUser?.uid}');
    print('User email: ${currentUser?.email}');
    
    if (currentUser == null) {
      print('ERROR: User is not authenticated');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Please sign in to add items to wishlist')),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final data = listing.data() as Map<String, dynamic>;
    final listingId = listing.id;
    final title = data['title'] ?? 'No Title';
    final price = data['price'] ?? 0.0;
    final imageUrl = data['imageUrl'] ?? 'assets/images/placeholder.png';
    final sellerId = data['userId'];

    print('Listing ID: $listingId');
    print('Seller ID: $sellerId');
    print('Wishlist path: wishlists/${currentUser.uid}/items/$listingId');

    if (sellerId == currentUser.uid) {
      print('ERROR: Cannot add own listing');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('You cannot add your own listing to wishlist')),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    try {
      print('Checking if item already in wishlist...');
      // Check if the item is already in the wishlist
      final wishlistItem = await _firestore
          .collection('wishlists')
          .doc(currentUser.uid)
          .collection('items')
          .doc(listingId)
          .get();

      if (wishlistItem.exists) {
        print('Item already in wishlist');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Item already in wishlist')),
              ],
            ),
            backgroundColor: Colors.blue.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      print('Adding item to wishlist...');
      await _firestore
          .collection('wishlists')
          .doc(currentUser.uid)
          .collection('items')
          .doc(listingId)
          .set({
        'listingId': listingId,
        'title': title,
        'price': price,
        'imageUrl': imageUrl,
        'sellerId': sellerId,
        'quantity': 1, // Default quantity
        'addedAt': FieldValue.serverTimestamp(),
      });

      print('SUCCESS: Item added to wishlist');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('$title added to wishlist!')),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print('ERROR adding to wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error adding to wishlist: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = listing.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'No Title';
    final category = data['category'] ?? 'No Category';
    final price = data['price'] ?? 0.0;
    final isFree = price == 0.0;
    final description = data['description'] ?? 'No description available';
    final imageUrl = data['imageUrl'] ?? 'assets/images/placeholder.png';
    final userId = data['userId'];
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Enhanced header with gradient icon
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade400, Colors.purple.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.info_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Listing Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
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
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Enhanced title with FREE badge if applicable
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'FREE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Enhanced category with icon
                    Row(
                      children: [
                        Icon(
                          Icons.category_rounded,
                          size: 18,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade50, Colors.blue.shade100],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Enhanced price display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isFree 
                            ? [Colors.orange.shade50, Colors.orange.shade100]
                            : [Colors.green.shade50, Colors.green.shade100],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFree ? Colors.orange.shade200 : Colors.green.shade200,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isFree 
                                ? Colors.orange.shade600
                                : Colors.green.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isFree ? Icons.card_giftcard_rounded : Icons.attach_money_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            isFree ? 'FREE' : '₱$price',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isFree ? Colors.orange.shade700 : Colors.green.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Enhanced description section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description_rounded,
                                size: 20,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[700],
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Enhanced seller information
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade400),
                              ),
                            ),
                          );
                        }
                        
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }
                        
                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        final sellerName = userData['name'] ?? 'Unknown Seller';
                        final sellerEmail = userData['email'] ?? '';
                        final sellerPhoto = userData['profilePicture'] ?? '';
                        
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple.shade50, Colors.purple.shade100],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.purple.shade200,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 20,
                                    color: Colors.purple.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Seller Information',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.purple.shade300,
                                        width: 3,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.purple.shade100,
                                      backgroundImage: sellerPhoto.isNotEmpty
                                          ? NetworkImage(sellerPhoto)
                                          : null,
                                      child: sellerPhoto.isEmpty
                                          ? Icon(
                                              Icons.person,
                                              size: 32,
                                              color: Colors.purple.shade600,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sellerName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 17,
                                            color: Colors.purple.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (sellerEmail.isNotEmpty)
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.email_rounded,
                                                size: 14,
                                                color: Colors.purple.shade400,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  sellerEmail,
                                                  style: TextStyle(
                                                    color: Colors.purple.shade600,
                                                    fontSize: 14,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            // Enhanced bottom action buttons
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.warning_rounded, color: Colors.white),
                                  SizedBox(width: 12),
                                  Expanded(child: Text('Please login to contact the seller')),
                                ],
                              ),
                              backgroundColor: Colors.orange.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                          return;
                        }
                        
                        if (userId == currentUser.uid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.info_rounded, color: Colors.white),
                                  SizedBox(width: 12),
                                  Expanded(child: Text('This is your own listing')),
                                ],
                              ),
                              backgroundColor: Colors.blue.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                          return;
                        }
                        
                        try {
                          // Create chat ID
                          final sortedIds = [currentUser.uid, userId]..sort();
                          final chatId = '${sortedIds[0]}_${sortedIds[1]}';
                          
                          // Check if chat exists, if not create it
                          final chatDoc = await FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId)
                              .get();
                          
                          if (!chatDoc.exists) {
                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatId)
                                .set({
                              'participants': [currentUser.uid, userId],
                              'createdAt': FieldValue.serverTimestamp(),
                              'lastMessage': '',
                              'lastMessageTime': FieldValue.serverTimestamp(),
                            });
                          }
                          
                          // Close the modal and navigate to chat with parameters
                          if (context.mounted) {
                            Navigator.of(context).pop(); // Close listing details
                            // Navigate to home with chat parameters and listing data for quick inquiry
                            final displayPrice = isFree ? 'FREE' : price.toString();
                            context.replace(
                              '/?chatId=$chatId&userId=$userId&listingId=${listing.id}&listingTitle=${Uri.encodeComponent(title)}&listingPrice=$displayPrice&listingImage=${Uri.encodeComponent(imageUrl)}'
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.error_rounded, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text('Error opening chat: $e')),
                                  ],
                                ),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: const Text(
                        'Contact Seller',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _addToWishlist(context),
                      icon: const Icon(Icons.favorite_rounded, size: 20),
                      label: const Text(
                        'Add to Wishlist',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        backgroundColor: Colors.pink.shade600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
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
