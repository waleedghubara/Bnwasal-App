import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state — nothing loaded yet
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// Loading state — fetching or updating
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// Profile loaded successfully
class ProfileLoaded extends ProfileState {
  final UserEntity user;
  const ProfileLoaded(this.user);

  @override
  List<Object?> get props => [user];
}

/// Update in progress while showing existing data
class ProfileUpdating extends ProfileState {
  final UserEntity user;
  const ProfileUpdating(this.user);

  @override
  List<Object?> get props => [user];
}

/// Profile updated successfully
class ProfileUpdateSuccess extends ProfileState {
  final UserEntity user;
  const ProfileUpdateSuccess(this.user);

  @override
  List<Object?> get props => [user];
}

/// Error state
class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

class ChangePasswordLoading extends ProfileState {
  const ChangePasswordLoading();
}

class ChangePasswordSuccess extends ProfileState {
  final String message;
  const ChangePasswordSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ChangePasswordError extends ProfileState {
  final String message;
  const ChangePasswordError(this.message);

  @override
  List<Object?> get props => [message];
}

