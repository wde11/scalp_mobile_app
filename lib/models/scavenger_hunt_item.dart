class ScavengerHuntItem {
  final String id;
  final String userId; // Seller/Creator of the item
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
  final DateTime? eventEndTime; // Global event timer
  final String status; // 'available', 'taken', 'ended'

  ScavengerHuntItem({
    required this.id,
    required this.userId,
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
    this.eventEndTime,
    this.status = 'available',
  });

  factory ScavengerHuntItem.fromMap(String id, Map<String, dynamic> map) {
    return ScavengerHuntItem(
      id: id,
      userId: map['userId'] ?? '',
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
      eventEndTime: map['eventEndTime']?.toDate(),
      status: map['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
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
      'eventEndTime': eventEndTime,
      'status': status,
    };
  }

  bool get isClaimed => claimedBy != null;
  
  bool isClaimedByUser(String userId) => claimedBy == userId;
  
  bool get isEventActive {
    if (eventEndTime == null) return true;
    return DateTime.now().isBefore(eventEndTime!);
  }
  
  bool get isExpired {
    if (eventEndTime == null) return false;
    return DateTime.now().isAfter(eventEndTime!);
  }
  
  Duration? get timeRemaining {
    if (eventEndTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(eventEndTime!)) return Duration.zero;
    return eventEndTime!.difference(now);
  }
  
  // Check if item should be shown (active and not expired)
  bool get isAvailable => isActive && isEventActive && !isExpired;
}
