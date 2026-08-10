import '../../../../core/utils/text_sanitizer.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String category; // 'order', 'wallet', 'offer', 'system'
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'].toString(),
      title: sanitizeText(json['title'] as String?),
      body: sanitizeText(json['body'] as String?),
      category: json['category'] ?? 'system',
      timestamp: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
      isRead: json['isRead'] == 1 || json['isRead'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'createdAt': timestamp.toIso8601String(),
      'isRead': isRead ? 1 : 0,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
