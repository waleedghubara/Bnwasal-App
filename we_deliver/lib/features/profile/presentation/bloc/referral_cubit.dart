import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/referral_usecases.dart';
import 'referral_state.dart';

class ReferralCubit extends Cubit<ReferralState> {
  final GetReferralSummaryUseCase _getReferralSummary;
  final ConvertPointsUseCase _convertPoints;

  ReferralCubit({
    required GetReferralSummaryUseCase getReferralSummary,
    required ConvertPointsUseCase convertPoints,
  })  : _getReferralSummary = getReferralSummary,
        _convertPoints = convertPoints,
        super(ReferralInitial());

  Future<void> loadReferralSummary() async {
    emit(ReferralLoading());
    final result = await _getReferralSummary();
    result.fold(
      (failure) => emit(ReferralError(failure.message)),
      (summary) => emit(ReferralLoaded(summary)),
    );
  }

  Future<void> convertPoints() async {
    emit(ReferralConvertingPoints());
    final result = await _convertPoints();
    result.fold(
      (failure) => emit(ReferralConvertError(failure.message)),
      (message) {
        emit(ReferralConvertSuccess(message));
        loadReferralSummary();
      },
    );
  }
}
