import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/scavenger_hunt_service.dart';

class CreateScavengerHuntScreen extends StatefulWidget {
  const CreateScavengerHuntScreen({super.key});

  @override
  State<CreateScavengerHuntScreen> createState() =>
      _CreateScavengerHuntScreenState();
}

class _CreateScavengerHuntScreenState
    extends State<CreateScavengerHuntScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScavengerHuntService _scavengerHuntService = ScavengerHuntService();
  final cloudinary =
      CloudinaryPublic('dp5mqhd9w', 'scalp_preset', cache: false);

  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final eventDurationController = TextEditingController(text: '60');

  double? selectedLat;
  double? selectedLng;
  XFile? selectedImage;
  bool isFree = false;
  bool isLoading = false;

  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    eventDurationController.dispose();
    super.dispose();
  }

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
          selectedImage = image;
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

  Future<void> _setLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _createItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String imageUrl =
          'https://via.placeholder.com/400x300?text=Scavenger+Hunt';

      // Upload image if selected
      if (selectedImage != null) {
        try {
          CloudinaryFile? cloudinaryFile;
          if (kIsWeb) {
            final bytes = await selectedImage!.readAsBytes();
            final fileName =
                '${DateTime.now().millisecondsSinceEpoch}_${selectedImage!.name}';
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFree
                  ? 'FREE scavenger hunt item created successfully!'
                  : 'Scavenger hunt item created successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        context.pop();
      }
    } catch (e) {
      print('Error creating scavenger hunt item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Scavenger Hunt Item'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: selectedImage != null
                      ? kIsWeb
                          ? FutureBuilder<Uint8List>(
                              future: selectedImage!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  );
                                }
                                return const Center(
                                    child: CircularProgressIndicator());
                              },
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(selectedImage!.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Tap to add image',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Item Title *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // FREE checkbox
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isFree ? Colors.orange.shade50 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFree
                        ? Colors.orange.shade300
                        : Colors.grey.shade300,
                    width: 2,
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
                      color: isFree
                          ? Colors.orange.shade600
                          : Colors.grey.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This is a FREE item (no prize)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isFree
                              ? Colors.orange.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Price
              TextFormField(
                controller: priceController,
                enabled: !isFree,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      isFree ? 'Prize Amount (FREE)' : 'Prize Amount (₱) *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                  filled: true,
                  fillColor: isFree ? Colors.grey.shade200 : null,
                ),
                validator: (value) {
                  if (!isFree && (value == null || value.isEmpty)) {
                    return 'Please enter a prize amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final qty = int.tryParse(value);
                  if (qty == null || qty < 1) {
                    return 'Quantity must be at least 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Event Duration
              TextFormField(
                controller: eventDurationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Event Duration (minutes) *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.timer),
                  helperText: 'How long the event will last',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter duration';
                  }
                  final duration = int.tryParse(value);
                  if (duration == null || duration < 1) {
                    return 'Duration must be at least 1 minute';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Location Button
              ElevatedButton.icon(
                onPressed: _setLocation,
                icon: Icon(
                    selectedLat != null ? Icons.check_circle : Icons.my_location),
                label: Text(
                  selectedLat != null
                      ? 'Location Set: ${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)}'
                      : 'Set Current Location',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      selectedLat != null ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Create Button
              ElevatedButton(
                onPressed: isLoading ? null : _createItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Create & Notify Users',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
