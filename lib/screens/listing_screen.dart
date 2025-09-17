import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

// Data model for a listing item
class ListingItem {
  final String name;
  final String category;
  final String price;
  final String? imagePath;
  final Uint8List? imageData;
  final String description;

  ListingItem({
    required this.name,
    required this.category,
    required this.price,
    this.imagePath,
    this.imageData,
    required this.description,
  });
}

class ListingScreen extends StatefulWidget {
  const ListingScreen({super.key});

  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  final List<ListingItem> _listings = [
    ListingItem(
      name: 'AOC Monitor 24\'',
      category: 'Gaming Monitor',
      price: '₱6000',
      imagePath: 'assets/images/monitor.jpeg',
      imageData: null,
      description: 'A great gaming monitor.',
    ),
    ListingItem(
      name: 'Nec Versapro',
      category: 'Laptop',
      price: '₱4000',
      imagePath: 'assets/images/laptop.jpeg',
      imageData: null,
      description: 'A reliable laptop.',
    ),
    ListingItem(
      name: 'RX 570 4 GB',
      category: 'Graphics Card',
      price: '₱3500',
      imagePath: 'assets/images/graphics_card.png',
      imageData: null,
      description: 'Powerful graphics card.',
    ),
    ListingItem(
      name: 'ROG Strix Keyboard',
      category: 'Gaming Keyboard',
      price: '₱2000',
      imagePath: 'assets/images/keyboard.jpg',
      imageData: null,
      description: 'Mechanical gaming keyboard.',
    ),
  ];

  void _addListing(ListingItem newItem) {
    setState(() {
      _listings.add(newItem);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.person), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(onPressed: () {}, child: const Text('Filter')),
              ],
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: _listings.map((item) {
                  return _buildListItem(
                    context,
                    item.name,
                    item.category,
                    item.price,
                    item.imagePath,
                    item.imageData,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => _CreateListingModal(onListingCreated: _addListing),
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
    String? imagePath,
    Uint8List? imageData,
  ) {
    ImageProvider imageProvider;
    if (imageData != null) {
      imageProvider = MemoryImage(imageData);
    } else if (imagePath != null && imagePath.startsWith('assets/')) {
      imageProvider = AssetImage(imagePath);
    } else if (imagePath != null && !kIsWeb) {
      imageProvider = FileImage(File(imagePath));
    } else {
      // Fallback for web if imagePath is not an asset and imageData is null
      imageProvider = const AssetImage('assets/images/scalp_logo_w_v2.png');
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                image: DecorationImage(
                  image: imageProvider,
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
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(category, style: const TextStyle(color: Colors.grey)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name added to cart.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateListingModal extends StatefulWidget {
  final Function(ListingItem) onListingCreated;

  const _CreateListingModal({super.key, required this.onListingCreated});

  @override
  State<_CreateListingModal> createState() => _CreateListingModalState();
}

class _CreateListingModalState extends State<_CreateListingModal> {
  final _categories = ['Graphics Card', 'Motherboard', 'PC Accessories'];
  String? _selectedCategory;
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<XFile>? _selectedImages;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedImages = images;
      });
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Create Listing',
        style: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: _itemNameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                value: _selectedCategory,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: _selectedImages != null && _selectedImages!.isNotEmpty ? null : 100,
                  constraints: _selectedImages != null && _selectedImages!.isNotEmpty ? BoxConstraints(maxHeight: 150) : null,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: _selectedImages != null && _selectedImages!.isNotEmpty
                        ? Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _selectedImages!.map((image) {
                              if (kIsWeb) {
                                return FutureBuilder<Uint8List>(
                                  future: image.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                      return Image.memory(
                                        snapshot.data!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    return const SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  },
                                );
                              } else {
                                return Image.file(
                                  File(image.path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                );
                              }
                            }).toList(),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.cloud_upload_outlined, color: Colors.grey, size: 40),
                              SizedBox(height: 8),
                              Text('Insert Images', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            if (_itemNameController.text.isNotEmpty &&
                _priceController.text.isNotEmpty &&
                _selectedCategory != null &&
                _descriptionController.text.isNotEmpty) {
              Uint8List? imageData;
              String? imagePath;

              if (_selectedImages != null && _selectedImages!.isNotEmpty) {
                if (kIsWeb) {
                  imageData = await _selectedImages!.first.readAsBytes();
                } else {
                  imagePath = _selectedImages!.first.path;
                }
              } else {
                imagePath = 'assets/images/scalp_logo_w_v2.png'; // Placeholder image
              }

              final newItem = ListingItem(
                name: _itemNameController.text,
                category: _selectedCategory!,
                price: '₱${_priceController.text}',
                imagePath: imagePath,
                imageData: imageData,
                description: _descriptionController.text,
              );
              widget.onListingCreated(newItem);
              context.pop();
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}