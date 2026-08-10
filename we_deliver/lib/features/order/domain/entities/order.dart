class OrderEntity {
  final String id;
  final String orderNumber;
  final String details;
  final String storeDescription;
  final String? notes;
  final String deliveryAddress;
  final String phone;
  final String clientName;
  final double orderPrice;
  final double deliveryFee;
  final double? latitude;
  final double? longitude;
  final double? merchantLatitude;
  final double? merchantLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final double? startLatitude;
  final double? startLongitude;
  final String status;
  final DateTime createdAt;
  final String? captainId;
  final String? captainName;
  final String? captainAvatar;
  final String? captainPhone;
  final String? merchantId;
  final String? merchantName;
  final String? merchantPhone;
  final String? merchantAvatar;
  final String? merchantAddress;
  final String? captainApprovalStatus;
  final bool isPaid;
  final Map<String, dynamic>? directPayment;
  final String? couponCode;

  String get pickupAddress {
    if (merchantAddress != null && merchantAddress!.trim().isNotEmpty) {
      return merchantAddress!;
    }
    if (merchantName != null && merchantName!.trim().isNotEmpty) {
      if (storeDescription.trim().isNotEmpty) {
        return '$merchantName ($storeDescription)';
      }
      return merchantName!;
    }
    if (storeDescription.trim().isNotEmpty) {
      return storeDescription;
    }
    return 'عنوان التاجر / الاستلام';
  }

  const OrderEntity({
    required this.id,
    required this.orderNumber,
    required this.details,
    required this.storeDescription,
    this.notes,
    required this.deliveryAddress,
    required this.phone,
    required this.clientName,
    required this.orderPrice,
    required this.deliveryFee,
    this.latitude,
    this.longitude,
    this.merchantLatitude,
    this.merchantLongitude,
    this.driverLatitude,
    this.driverLongitude,
    this.startLatitude,
    this.startLongitude,
    required this.status,
    required this.createdAt,
    this.captainId,
    this.captainName,
    this.captainAvatar,
    this.captainPhone,
    this.merchantId,
    this.merchantName,
    this.merchantPhone,
    this.merchantAvatar,
    this.merchantAddress,
    this.captainApprovalStatus,
    this.isPaid = false,
    this.directPayment,
    this.couponCode,
  });

  OrderEntity copyWith({
    String? id,
    String? orderNumber,
    String? details,
    String? storeDescription,
    String? notes,
    String? deliveryAddress,
    String? phone,
    String? clientName,
    double? orderPrice,
    double? deliveryFee,
    double? latitude,
    double? longitude,
    double? merchantLatitude,
    double? merchantLongitude,
    double? driverLatitude,
    double? driverLongitude,
    double? startLatitude,
    double? startLongitude,
    String? status,
    DateTime? createdAt,
    String? captainId,
    String? captainName,
    String? captainAvatar,
    String? captainPhone,
    String? merchantId,
    String? merchantName,
    String? merchantPhone,
    String? merchantAvatar,
    String? captainApprovalStatus,
    bool? isPaid,
    Map<String, dynamic>? directPayment,
    String? couponCode,
  }) {
    return OrderEntity(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      details: details ?? this.details,
      storeDescription: storeDescription ?? this.storeDescription,
      notes: notes ?? this.notes,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      phone: phone ?? this.phone,
      clientName: clientName ?? this.clientName,
      orderPrice: orderPrice ?? this.orderPrice,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      merchantLatitude: merchantLatitude ?? this.merchantLatitude,
      merchantLongitude: merchantLongitude ?? this.merchantLongitude,
      driverLatitude: driverLatitude ?? this.driverLatitude,
      driverLongitude: driverLongitude ?? this.driverLongitude,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      captainId: captainId ?? this.captainId,
      captainName: captainName ?? this.captainName,
      captainAvatar: captainAvatar ?? this.captainAvatar,
      captainPhone: captainPhone ?? this.captainPhone,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      merchantPhone: merchantPhone ?? this.merchantPhone,
      merchantAvatar: merchantAvatar ?? this.merchantAvatar,
      captainApprovalStatus:
          captainApprovalStatus ?? this.captainApprovalStatus,
      isPaid: isPaid ?? this.isPaid,
      directPayment: directPayment ?? this.directPayment,
      couponCode: couponCode ?? this.couponCode,
    );
  }
}

class OrderStatus {
  static const String pending = 'Pending Review';
  static const String negotiation = 'Negotiation';
  static const String awaitingPayment = 'Awaiting Payment';
  static const String readyForAssignment = 'Ready For Assignment';
  static const String assignedToCaptain = 'Assigned To Captain';
  static const String captainArrived = 'Captain Arrived';
  static const String pickedUp = 'Picked Up';
  static const String inTransit = 'In Transit';
  static const String delivered = 'Delivered';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const String rejected = 'Rejected';

  // Compatibility with old code references
  static const String accepted = 'Ready For Assignment';
  static const String purchased = 'Picked Up';
  static const String inProgress = 'In Transit';
  static const String finished = 'Completed';

  // الحالات المرئية في الـ UI (بدون Captain Arrived لأنه يُعامل كـ Assigned To Captain)
  static const List<String> allStatuses = [
    pending,
    negotiation,
    awaitingPayment,
    readyForAssignment,
    assignedToCaptain,
    pickedUp,
    inTransit,
    delivered,
    completed,
    rejected,
    cancelled,
  ];

  static String getArabicStatus(String status) {
    switch (status) {
      case 'Pending Review':
        return 'قيد المراجعة';
      case 'Negotiation':
        return 'قيد التفاوض';
      case 'Awaiting Payment':
        return 'بانتظار تعيين مندوب';
      case 'Ready For Assignment':
        return 'بانتظار تعيين مندوب';
      case 'Assigned To Captain':
      case 'Captain Arrived': // يُعرض نفس مرحلة "تم تعيين مندوب"
        return 'تم تعيين مندوب';
      case 'Picked Up':
        return 'تم شراء الطلب';
      case 'In Transit':
        return 'جارٍ التوصيل إليك';
      case 'Delivered':
        return 'تم التوصيل';
      case 'Completed':
        return 'مكتمل';
      case 'Cancelled':
        return 'ملغاة';
      case 'Rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }
}
