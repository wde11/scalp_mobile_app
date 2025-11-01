import 'location_data.dart';

class Transaction {
  final String id;
  final String buyerId;
  final String sellerId;
  final String sellerName;
  final String productName;
  final String productImage;
  final double proposedPrice;
  final double sellingPrice;
  final LocationData? sellerLocation;
  final bool locationSharingEnabled; // Seller can toggle this
  final bool isActive;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.sellerName,
    required this.productName,
    required this.productImage,
    required this.proposedPrice,
    required this.sellingPrice,
    this.sellerLocation,
    this.locationSharingEnabled = true, // Default to true
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'productName': productName,
      'productImage': productImage,
      'proposedPrice': proposedPrice,
      'sellingPrice': sellingPrice,
      'sellerLocation': sellerLocation?.toMap(),
      'locationSharingEnabled': locationSharingEnabled,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      buyerId: map['buyerId'] as String,
      sellerId: map['sellerId'] as String,
      sellerName: map['sellerName'] as String,
      productName: map['productName'] as String,
      productImage: map['productImage'] as String,
      proposedPrice: map['proposedPrice'] as double,
      sellingPrice: map['sellingPrice'] as double,
      sellerLocation: map['sellerLocation'] != null
          ? LocationData.fromMap(map['sellerLocation'] as Map<String, dynamic>)
          : null,
      locationSharingEnabled: map['locationSharingEnabled'] as bool? ?? true,
      isActive: map['isActive'] as bool,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
  
  // Helper method to create a copy with updated location sharing
  Transaction copyWith({
    bool? locationSharingEnabled,
    LocationData? sellerLocation,
  }) {
    return Transaction(
      id: id,
      buyerId: buyerId,
      sellerId: sellerId,
      sellerName: sellerName,
      productName: productName,
      productImage: productImage,
      proposedPrice: proposedPrice,
      sellingPrice: sellingPrice,
      sellerLocation: sellerLocation ?? this.sellerLocation,
      locationSharingEnabled: locationSharingEnabled ?? this.locationSharingEnabled,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}
