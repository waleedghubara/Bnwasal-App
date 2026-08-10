import '../../domain/entities/user_entity.dart';

class ProfileUserModel extends UserEntity {
  const ProfileUserModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    required super.phone,
    required super.role,
    required super.status,
    super.profileImage,
    super.storeName,
    super.city,
    super.latitude,
    super.longitude,
    super.createdAt,
    super.vehicleType,
    super.isProfileComplete,
    super.missingDetails,
  });

  factory ProfileUserModel.fromJson(Map<String, dynamic> json) {
    return ProfileUserModel(
      id: json['id'] as int,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? '',
      status: json['status'] as String? ?? '',
      profileImage: json['profileImage'] as String?,
      storeName: json['storeName'] as String?,
      city: json['city'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num?)?.toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num?)?.toDouble() : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      vehicleType: json['vehicleType'] as String?,
      isProfileComplete: json['isProfileComplete'] as bool?,
      missingDetails: (json['missingDetails'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
        'profileImage': profileImage,
        'storeName': storeName,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'vehicleType': vehicleType,
        'isProfileComplete': isProfileComplete,
        'missingDetails': missingDetails,
      };
}
