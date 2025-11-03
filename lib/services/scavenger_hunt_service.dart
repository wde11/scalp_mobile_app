import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/scavenger_hunt_item.dart';

class ScavengerHuntService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all active scavenger hunt items
  Stream<List<ScavengerHuntItem>> getActiveItems() {
    return _firestore
        .collection('scavenger_hunt_items')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ScavengerHuntItem.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // Get unclaimed items count
  Stream<int> getUnclaimedItemsCount() {
    return _firestore
        .collection('scavenger_hunt_items')
        .where('isActive', isEqualTo: true)
        .where('claimedBy', isEqualTo: null)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Claim an item
  Future<bool> claimItem(String itemId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final itemRef = _firestore.collection('scavenger_hunt_items').doc(itemId);
      
      // Use a transaction to prevent race conditions
      await _firestore.runTransaction((transaction) async {
        final itemDoc = await transaction.get(itemRef);
        
        if (!itemDoc.exists) {
          throw Exception('Item not found');
        }
        
        final data = itemDoc.data()!;
        if (data['claimedBy'] != null) {
          throw Exception('Item already claimed');
        }
        
        transaction.update(itemRef, {
          'claimedBy': user.uid,
          'claimedAt': FieldValue.serverTimestamp(),
        });
      });
      
      return true;
    } catch (e) {
      print('Error claiming item: $e');
      return false;
    }
  }

  // Check if user has claimed an item
  bool isClaimedByCurrentUser(ScavengerHuntItem item) {
    final user = _auth.currentUser;
    if (user == null) return false;
    return item.claimedBy == user.uid;
  }

  // Get items claimed by current user
  Stream<List<ScavengerHuntItem>> getMyClaimedItems() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('scavenger_hunt_items')
        .where('claimedBy', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ScavengerHuntItem.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // Admin: Create a new scavenger hunt item
  Future<void> createScavengerHuntItem({
    required String title,
    required double price,
    required String description,
    required String imageUrl,
    required double latitude,
    required double longitude,
    required int quantity,
    int? eventDurationMinutes,
  }) async {
    try {
      print('=== CREATING SCAVENGER HUNT ITEM ===');
      print('Title: $title');
      print('Price: $price');
      print('Quantity: $quantity');
      print('Event Duration: $eventDurationMinutes minutes');
      
      final now = DateTime.now();
      final eventEndTime = eventDurationMinutes != null 
          ? now.add(Duration(minutes: eventDurationMinutes))
          : null;
      
      print('Event End Time: $eventEndTime');
      
      final docRef = await _firestore.collection('scavenger_hunt_items').add({
        'title': title,
        'price': price,
        'description': description,
        'imageUrl': imageUrl,
        'latitude': latitude,
        'longitude': longitude,
        'quantity': quantity,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'claimedBy': null,
        'claimedAt': null,
        'eventEndTime': eventEndTime,
      });

      print('Item created with ID: ${docRef.id}');

      // Send notification to all users
      await _notifyAllUsers(
        'New Scavenger Hunt Item!',
        'Find "$title" worth ₱${price.toStringAsFixed(0)} on the map!',
      );
      
      print('Notifications sent to all users');
    } catch (e) {
      print('Error creating scavenger hunt item: $e');
      rethrow;
    }
  }

  // Admin: Get all items (including inactive)
  Stream<List<ScavengerHuntItem>> getAllItems() {
    return _firestore
        .collection('scavenger_hunt_items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('=== SCAVENGER HUNT DEBUG ===');
      print('Total items retrieved: ${snapshot.docs.length}');
      final items = snapshot.docs
          .map((doc) {
            print('Item: ${doc.id} - ${doc.data()['title']}');
            return ScavengerHuntItem.fromMap(doc.id, doc.data());
          })
          .toList();
      print('Items mapped: ${items.length}');
      return items;
    });
  }

  // Admin: Toggle item active status
  Future<void> toggleItemStatus(String itemId, bool isActive) async {
    try {
      await _firestore.collection('scavenger_hunt_items').doc(itemId).update({
        'isActive': isActive,
      });
    } catch (e) {
      print('Error toggling item status: $e');
      rethrow;
    }
  }

  // Admin: Delete an item
  Future<void> deleteItem(String itemId) async {
    try {
      await _firestore.collection('scavenger_hunt_items').doc(itemId).delete();
    } catch (e) {
      print('Error deleting item: $e');
      rethrow;
    }
  }

  // Send notification to all users
  Future<void> _notifyAllUsers(String title, String message) async {
    try {
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      
      // Create notifications for all users
      final batch = _firestore.batch();
      for (final userDoc in usersSnapshot.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': userDoc.id,
          'title': title,
          'message': message,
          'type': 'scavenger_hunt',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error sending notifications: $e');
    }
  }
}
