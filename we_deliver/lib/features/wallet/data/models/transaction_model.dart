import '../../domain/entities/transaction_entity.dart';

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.title,
    required super.date,
    required super.amount,
    required super.type,
    required super.status,
    super.reference,
    super.category,
    super.createdAt,
    super.paymentMethod,
    super.accountDetails,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      reference: json['reference']?.toString(),
      category: json['category']?.toString(),
      createdAt: json['createdAt'],
      paymentMethod: json['paymentMethod'],
      accountDetails: json['accountDetails'] is Map
          ? json['accountDetails'].toString()
          : json['accountDetails']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'amount': amount,
      'type': type,
      'status': status,
      'reference': reference,
      'category': category,
      'createdAt': createdAt,
      'paymentMethod': paymentMethod,
      'accountDetails': accountDetails,
    };
  }
}
