import 'package:equatable/equatable.dart';
import '../domain/entities/auth_response.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

class RegisterSuccess extends AuthState {
  final String email;
  final String otpCode;
  final String message;

  const RegisterSuccess({
    required this.email,
    required this.otpCode,
    required this.message,
  });

  @override
  List<Object?> get props => [email, otpCode, message];
}

class VerifyOtpSuccess extends AuthState {
  final AuthResponse authResponse;

  const VerifyOtpSuccess({required this.authResponse});

  @override
  List<Object?> get props => [authResponse];
}

class ResendOtpSuccess extends AuthState {
  final String message;
  final String newOtp;

  const ResendOtpSuccess({required this.message, required this.newOtp});

  @override
  List<Object?> get props => [message, newOtp];
}

class LoginSuccess extends AuthState {
  final AuthResponse authResponse;

  const LoginSuccess({required this.authResponse});

  @override
  List<Object?> get props => [authResponse];
}

class UploadDocsSuccess extends AuthState {
  final String message;

  const UploadDocsSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class LoginPendingApproval extends AuthState {
  final String message;

  const LoginPendingApproval({required this.message});

  @override
  List<Object?> get props => [message];
}

class LoginPendingOtp extends AuthState {
  final String email;
  final String otpCode;
  final String message;

  const LoginPendingOtp({
    required this.email,
    required this.otpCode,
    required this.message,
  });

  @override
  List<Object?> get props => [email, otpCode, message];
}

