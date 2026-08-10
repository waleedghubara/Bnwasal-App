import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final int id;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;
  final String status;
  final String? profileImage;
  final String? vehicleType;
  final bool? isProfileComplete;
  final List<String>? missingDetails;

  const UserEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    required this.status,
    this.profileImage,
    this.vehicleType,
    this.isProfileComplete,
    this.missingDetails,
  });

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        phone,
        role,
        status,
        profileImage,
        vehicleType,
        isProfileComplete,
        missingDetails,
      ];
}
