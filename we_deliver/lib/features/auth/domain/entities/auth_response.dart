import 'package:equatable/equatable.dart';
import 'user_entity.dart';

class AuthResponse extends Equatable {
  final String token;
  final String refreshToken;
  final UserEntity user;

  const AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  @override
  List<Object?> get props => [token, refreshToken, user];
}
