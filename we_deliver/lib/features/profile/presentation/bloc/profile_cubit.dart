import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../domain/usecases/change_password_usecase.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final GetProfileUseCase _getProfile;
  final UpdateProfileUseCase _updateProfile;
  final ChangePasswordUseCase _changePassword;

  ProfileCubit({
    required GetProfileUseCase getProfile,
    required UpdateProfileUseCase updateProfile,
    required ChangePasswordUseCase changePassword,
  })  : _getProfile = getProfile,
        _updateProfile = updateProfile,
        _changePassword = changePassword,
        super(const ProfileInitial());

  /// Fetch the current user's profile from the server
  Future<void> loadProfile() async {
    emit(const ProfileLoading());
    final result = await _getProfile();
    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (user) => emit(ProfileLoaded(user)),
    );
  }

  /// Update profile fields — keeps the old data visible while updating
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? storeName,
    String? city,
    double? latitude,
    double? longitude,
    File? profileImage,
    String? vehicleType,
  }) async {
    // Keep showing current user while request is in flight
    final currentUser = state is ProfileLoaded
        ? (state as ProfileLoaded).user
        : state is ProfileUpdateSuccess
            ? (state as ProfileUpdateSuccess).user
            : null;

    if (currentUser != null) {
      emit(ProfileUpdating(currentUser));
    } else {
      emit(const ProfileLoading());
    }

    final result = await _updateProfile(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      storeName: storeName,
      city: city,
      latitude: latitude,
      longitude: longitude,
      profileImage: profileImage,
      vehicleType: vehicleType,
    );

    result.fold(
      (failure) => emit(
        // On error: go back to loaded state so user still sees their data
        currentUser != null
            ? ProfileError(failure.message)
            : ProfileError(failure.message),
      ),
      (user) => emit(ProfileUpdateSuccess(user)),
    );
  }

  /// After successful update, transition to loaded state
  void resetToLoaded() {
    if (state is ProfileUpdateSuccess) {
      emit(ProfileLoaded((state as ProfileUpdateSuccess).user));
    }
  }

  /// Change password of the authenticated user
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    emit(const ChangePasswordLoading());

    final result = await _changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    result.fold(
      (failure) => emit(ChangePasswordError(failure.message)),
      (_) => emit(const ChangePasswordSuccess('تم تغيير كلمة المرور بنجاح')),
    );
  }

  @override
  void emit(ProfileState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
