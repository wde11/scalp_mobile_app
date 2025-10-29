import 'location_data.dart';

enum MessageType {
  text,
  location,
  image,
}

class ChatMessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final LocationData? locationData;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    this.locationData,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.toString(),
      'locationData': locationData?.toMap(),
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String,
      content: map['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => MessageType.text,
      ),
      locationData: map['locationData'] != null
          ? LocationData.fromMap(map['locationData'] as Map<String, dynamic>)
          : null,
      imageUrl: map['imageUrl'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}
