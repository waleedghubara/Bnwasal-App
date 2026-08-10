import 'package:equatable/equatable.dart';

class MessageEntity extends Equatable {
  final String id;
  final String shipmentId;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  const MessageEntity({
    required this.id,
    required this.shipmentId,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, shipmentId, senderId, receiverId, senderName, text, createdAt];
}
