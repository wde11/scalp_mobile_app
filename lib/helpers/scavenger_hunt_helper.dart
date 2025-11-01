// Helper function to add scavenger hunt items to Firestore
// Run this once to populate your database with test items

import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> addScavengerHuntItems() async {
  final firestore = FirebaseFirestore.instance;
  
  final items = [
    {
      'title': 'RTX 4060 Graphics Card',
      'price': 12000,
      'description': 'Brand new RTX 4060, first come first serve! Be fast!',
      'imageUrl': 'https://via.placeholder.com/300x300?text=RTX+4060',
      'latitude': 10.3160,
      'longitude': 123.8850,
      'quantity': 1,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'title': '16GB DDR5 RAM',
      'price': 4500,
      'description': 'High-speed DDR5 memory, perfect for gaming and work',
      'imageUrl': 'https://via.placeholder.com/300x300?text=DDR5+RAM',
      'latitude': 10.3170,
      'longitude': 123.8900,
      'quantity': 1,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'title': 'Gaming Monitor 27" 144Hz',
      'price': 8500,
      'description': 'Ultra-fast 27 inch 144Hz gaming monitor',
      'imageUrl': 'https://via.placeholder.com/300x300?text=Gaming+Monitor',
      'latitude': 10.3155,
      'longitude': 123.8880,
      'quantity': 1,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'title': 'Mechanical Keyboard RGB',
      'price': 3500,
      'description': 'Premium mechanical gaming keyboard with RGB lighting',
      'imageUrl': 'https://via.placeholder.com/300x300?text=Mechanical+Keyboard',
      'latitude': 10.3165,
      'longitude': 123.8870,
      'quantity': 1,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'title': 'Gaming Mouse Pro',
      'price': 2500,
      'description': 'High precision gaming mouse with 16000 DPI',
      'imageUrl': 'https://via.placeholder.com/300x300?text=Gaming+Mouse',
      'latitude': 10.3175,
      'longitude': 123.8895,
      'quantity': 1,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    },
  ];
  
  try {
    for (var item in items) {
      await firestore.collection('scavenger_hunt_items').add(item);
      print('Added: ${item['title']}');
    }
    print('All items added successfully!');
  } catch (e) {
    print('Error adding items: $e');
  }
}

// Call this function from your Firebase Cloud Functions or run it manually
// Example: addScavengerHuntItems();
