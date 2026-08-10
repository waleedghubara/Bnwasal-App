import 'package:equatable/equatable.dart';

class AuthState extends Equatable {
  final bool isLoading;
  final bool isAuthenticated;
  final String? errorMessage;
  final String? token;
  final Map<String, dynamic>? user;
  final bool isLoadingProfile;
  final String? profileSuccess;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.errorMessage,
    this.token,
    this.user,
    this.isLoadingProfile = false,
    this.profileSuccess,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? errorMessage,
    String? token,
    Map<String, dynamic>? user,
    bool? isLoadingProfile,
    String? profileSuccess,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
      token: token ?? this.token,
      user: user ?? this.user,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      profileSuccess: profileSuccess,
    );
  }

  @override
  List<Object?> get props => [isLoading, isAuthenticated, errorMessage, token, user, isLoadingProfile, profileSuccess];
}
