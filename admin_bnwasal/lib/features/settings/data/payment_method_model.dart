class PaymentMethodModel {
  final String name;
  final String phone; // transfer number / account number
  final String? imageUrl; // uploaded icon URL from backend

  const PaymentMethodModel({
    required this.name,
    required this.phone,
    this.imageUrl,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
    };
  }

  PaymentMethodModel copyWith({
    String? name,
    String? phone,
    String? imageUrl,
  }) {
    return PaymentMethodModel(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
