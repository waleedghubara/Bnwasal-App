import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.phone,
    required super.role,
    required super.status,
    super.profileImage,
    super.vehicleType,
    super.isProfileComplete,
    super.missingDetails,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      profileImage: json['profileImage'] as String?,
      vehicleType: json['vehicleType'] as String?,
      isProfileComplete: json['isProfileComplete'] as bool?,
      missingDetails: (json['missingDetails'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'role': role,
      'status': status,
      'profileImage': profileImage,
      'vehicleType': vehicleType,
      'isProfileComplete': isProfileComplete,
      'missingDetails': missingDetails,
    };
  }
}
