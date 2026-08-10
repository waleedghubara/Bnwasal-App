import 'package:equatable/equatable.dart';

class TransactionEntity extends Equatable {
  final String id;
  final String title;
  final String date;
  final double amount;
  final String type; // 'deposit' or 'withdraw'
  final String status;
  final String? reference;
  final String? category;
  final String? createdAt;
  final String? paymentMethod;
  final String? accountDetails;

  const TransactionEntity({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.type,
    required this.status,
    this.reference,
    this.category,
    this.createdAt,
    this.paymentMethod,
    this.accountDetails,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        date,
        amount,
        type,
        status,
        reference,
        category,
        createdAt,
        paymentMethod,
        accountDetails,
      ];
}
