class UserEntity {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final String status;
  final String? profileImage;
  final String? storeName;
  final String? city;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final String? vehicleType;
  final bool? isProfileComplete;
  final List<String>? missingDetails;

  const UserEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.profileImage,
    this.storeName,
    this.city,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.vehicleType,
    this.isProfileComplete,
    this.missingDetails,
  });

  String get fullName => '$firstName $lastName';

  UserEntity copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? storeName,
    String? city,
    String? profileImage,
    double? latitude,
    double? longitude,
    String? vehicleType,
    bool? isProfileComplete,
    List<String>? missingDetails,
  }) {
    return UserEntity(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email,
      phone: phone ?? this.phone,
      role: role,
      status: status,
      profileImage: profileImage ?? this.profileImage,
      storeName: storeName ?? this.storeName,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt,
      vehicleType: vehicleType ?? this.vehicleType,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      missingDetails: missingDetails ?? this.missingDetails,
    );
  }
}
