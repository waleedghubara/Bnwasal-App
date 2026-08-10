import 'package:equatable/equatable.dart';
import '../../data/models/referral_summary_model.dart';

abstract class ReferralState extends Equatable {
  const ReferralState();

  @override
  List<Object?> get props => [];
}

class ReferralInitial extends ReferralState {}

class ReferralLoading extends ReferralState {}

class ReferralLoaded extends ReferralState {
  final ReferralSummaryModel summary;

  const ReferralLoaded(this.summary);

  @override
  List<Object?> get props => [summary];
}

class ReferralError extends ReferralState {
  final String message;

  const ReferralError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReferralConvertingPoints extends ReferralState {}

class ReferralConvertSuccess extends ReferralState {
  final String message;

  const ReferralConvertSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ReferralConvertError extends ReferralState {
  final String message;

  const ReferralConvertError(this.message);

  @override
  List<Object?> get props => [message];
}
