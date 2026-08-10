import 'dart:io';

class Shipment {
  final String id;
  final String shipmentNumber;
  final String? title;
  final String fromAddress;
  final String toAddress;
  final String? fromGovernorate;
  final String? fromArea;
  final String? toGovernorate;
  final String? toArea;
  final String status;
  final String? clientName;
  final String? clientAvatar;
  final String? clientPhone;
  final String? driverName;
  final String? driverAvatar;
  final String? driverPhone;
  final String? driverId;
  final String? merchantId;
  final String? estimatedTime;
  final double price;
  final double? weight;
  final String? notes;
  final bool isFragile;
  final bool isWithoutAdvance;
  final List<File>? images;
  final List<String>? imageUrls;
  final double? toLatitude;
  final double? toLongitude;
  final double? merchantLatitude;
  final double? merchantLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final double? negotiatedPrice;
  final double? startLatitude;
  final double? startLongitude;
  final String? captainApprovalStatus;
  final DateTime createdAt;
  final bool isPaid;
  final Map<String, dynamic>? directPayment;
  final String? couponCode;

  const Shipment({
    required this.id,
    required this.shipmentNumber,
    this.title,
    required this.fromAddress,
    required this.toAddress,
    this.fromGovernorate,
    this.fromArea,
    this.toGovernorate,
    this.toArea,
    required this.status,
    this.clientName,
    this.clientAvatar,
    this.clientPhone,
    this.driverName,
    this.driverAvatar,
    this.driverPhone,
    this.driverId,
    this.merchantId,
    this.estimatedTime,
    required this.price,
    this.negotiatedPrice,
    this.weight,
    this.notes,
    this.isFragile = false,
    this.isWithoutAdvance = false,
    this.images,
    this.imageUrls,
    this.toLatitude,
    this.toLongitude,
    this.merchantLatitude,
    this.merchantLongitude,
    this.driverLatitude,
    this.driverLongitude,
    this.startLatitude,
    this.startLongitude,
    this.captainApprovalStatus,
    required this.createdAt,
    this.isPaid = false,
    this.directPayment,
    this.couponCode,
  });

  Shipment copyWith({
    String? id,
    String? shipmentNumber,
    String? title,
    String? fromAddress,
    String? toAddress,
    String? fromGovernorate,
    String? fromArea,
    String? toGovernorate,
    String? toArea,
    String? status,
    String? clientName,
    String? clientAvatar,
    String? clientPhone,
    String? driverName,
    String? driverAvatar,
    String? driverPhone,
    String? driverId,
    String? merchantId,
    String? estimatedTime,
    double? price,
    double? negotiatedPrice,
    double? weight,
    String? notes,
    bool? isFragile,
    bool? isWithoutAdvance,
    List<File>? images,
    List<String>? imageUrls,
    double? toLatitude,
    double? toLongitude,
    double? merchantLatitude,
    double? merchantLongitude,
    double? driverLatitude,
    double? driverLongitude,
    double? startLatitude,
    double? startLongitude,
    String? captainApprovalStatus,
    DateTime? createdAt,
    bool? isPaid,
    Map<String, dynamic>? directPayment,
    String? couponCode,
  }) {
    return Shipment(
      id: id ?? this.id,
      shipmentNumber: shipmentNumber ?? this.shipmentNumber,
      title: title ?? this.title,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      fromGovernorate: fromGovernorate ?? this.fromGovernorate,
      fromArea: fromArea ?? this.fromArea,
      toGovernorate: toGovernorate ?? this.toGovernorate,
      toArea: toArea ?? this.toArea,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      clientAvatar: clientAvatar ?? this.clientAvatar,
      clientPhone: clientPhone ?? this.clientPhone,
      driverName: driverName ?? this.driverName,
      driverAvatar: driverAvatar ?? this.driverAvatar,
      driverPhone: driverPhone ?? this.driverPhone,
      driverId: driverId ?? this.driverId,
      merchantId: merchantId ?? this.merchantId,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      price: price ?? this.price,
      negotiatedPrice: negotiatedPrice ?? this.negotiatedPrice,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      isFragile: isFragile ?? this.isFragile,
      isWithoutAdvance: isWithoutAdvance ?? this.isWithoutAdvance,
      images: images ?? this.images,
      imageUrls: imageUrls ?? this.imageUrls,
      toLatitude: toLatitude ?? this.toLatitude,
      toLongitude: toLongitude ?? this.toLongitude,
      merchantLatitude: merchantLatitude ?? this.merchantLatitude,
      merchantLongitude: merchantLongitude ?? this.merchantLongitude,
      driverLatitude: driverLatitude ?? this.driverLatitude,
      driverLongitude: driverLongitude ?? this.driverLongitude,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      captainApprovalStatus: captainApprovalStatus ?? this.captainApprovalStatus,
      createdAt: createdAt ?? this.createdAt,
      isPaid: isPaid ?? this.isPaid,
      directPayment: directPayment ?? this.directPayment,
      couponCode: couponCode ?? this.couponCode,
    );
  }
}

class ShipmentStatus {
  static const String all = 'الكل';
  static const String newShipment = 'Pending Review';
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

  // Compatibility with old code references
  static const String pending = 'Pending Review';
  static const String offerAccepted = 'Assigned To Captain';
  static const String inExecution = 'Picked Up';
  static const String finished = 'Completed';

  static const List<String> userFilters = [
    all,
    newShipment,
    awaitingPayment,
    readyForAssignment,
    assignedToCaptain,
    captainArrived,
    pickedUp,
    inTransit,
    delivered,
    completed,
    cancelled,
  ];

  static const List<String> allStatuses = [
    all,
    newShipment,
    negotiation,
    awaitingPayment,
    readyForAssignment,
    assignedToCaptain,
    captainArrived,
    pickedUp,
    inTransit,
    delivered,
    completed,
    cancelled,
  ];

  static String getArabicStatus(String status) {
    final String s = status.trim().toLowerCase();
    switch (s) {
      case 'pending review':
      case 'pending_review':
        return 'قيد المراجعة';
      case 'negotiation':
        return 'قيد التفاوض';
      case 'awaiting payment':
      case 'awaiting_payment':
        return 'بانتظار تعيين مندوب';
      case 'ready for assignment':
      case 'ready_for_assignment':
        return 'جاهز للتوجيه';
      case 'assigned to captain':
      case 'assigned_to_captain':
        return 'تم تعيين المندوب';
      case 'captain arrived':
      case 'captain_arrived':
        return 'وصل المندوب للتاجر';
      case 'picked up':
      case 'picked_up':
        return 'تم استلام الشحنة';
      case 'in transit':
      case 'in_transit':
        return 'جاري التوصيل';
      case 'delivered':
        return 'تم التوصيل';
      case 'completed':
      case 'finished':
      case 'منتهية':
      case 'منتهي':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  static String getStatusColor(String status) => status;
}
