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
}
