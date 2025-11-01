class ScavengerHuntItem {
  final String id;
  final String title;
  final double price;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final int quantity;
  final bool isActive;
  final DateTime createdAt;
  final String? claimedBy;
  final DateTime? claimedAt;

  ScavengerHuntItem({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.quantity,
    required this.isActive,
    required this.createdAt,
    this.claimedBy,
    this.claimedAt,
  });

  factory ScavengerHuntItem.fromMap(String id, Map<String, dynamic> map) {
    return ScavengerHuntItem(
      id: id,
      title: map['title'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      claimedBy: map['claimedBy'],
      claimedAt: map['claimedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'quantity': quantity,
      'isActive': isActive,
      'createdAt': createdAt,
      'claimedBy': claimedBy,
      'claimedAt': claimedAt,
    };
  }

  bool get isClaimed => claimedBy != null;
  
  bool isClaimedByUser(String userId) => claimedBy == userId;
}
