import '../../../../core/utils/text_sanitizer.dart';
import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.shipmentId,
    required super.senderId,
    required super.receiverId,
    required super.senderName,
    required super.text,
    required super.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      shipmentId: json['shipmentId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? '',
      senderName: sanitizeText(json['senderName'] as String?),
      text: sanitizeText(json['text'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shipmentId': shipmentId,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
