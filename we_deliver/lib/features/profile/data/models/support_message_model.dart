enum SupportMessageStatus { sent, delivered, read }

class SupportMessageModel {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isUser;
  final SupportMessageStatus status;
  final String? imagePath;
  final String senderName;
  final String? senderAvatar;
  final String senderRole;

  SupportMessageModel({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isUser,
    this.status = SupportMessageStatus.sent,
    this.imagePath,
    required this.senderName,
    this.senderAvatar,
    required this.senderRole,
  });

  SupportMessageModel copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    bool? isUser,
    SupportMessageStatus? status,
    String? imagePath,
    String? senderName,
    String? senderAvatar,
    String? senderRole,
  }) {
    return SupportMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isUser: isUser ?? this.isUser,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      senderRole: senderRole ?? this.senderRole,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isUser': isUser,
      'status': status.name,
      'imagePath': imagePath,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderRole': senderRole,
    };
  }

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id']?.toString() ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'])?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      isUser: json['isUser'] ?? false,
      status: _parseStatus(json['status']),
      imagePath: json['imagePath'],
      senderName: json['senderName'] ?? '',
      senderAvatar: json['senderAvatar'],
      senderRole: json['senderRole'] ?? '',
    );
  }

  static SupportMessageStatus _parseStatus(String? status) {
    if (status == 'read') return SupportMessageStatus.read;
    if (status == 'delivered') return SupportMessageStatus.delivered;
    return SupportMessageStatus.sent;
  }
}
