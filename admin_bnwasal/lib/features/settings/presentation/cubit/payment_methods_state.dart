import 'package:equatable/equatable.dart';
import '../../data/payment_method_model.dart';

class PaymentMethodsState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final bool isUploadingIcon; // when uploading an icon for a specific index
  final int? uploadingIndex;
  final List<PaymentMethodModel> methods;
  final String? error;
  final String? successMessage;

  const PaymentMethodsState({
    this.isLoading = false,
    this.isSaving = false,
    this.isUploadingIcon = false,
    this.uploadingIndex,
    this.methods = const [],
    this.error,
    this.successMessage,
  });

  PaymentMethodsState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isUploadingIcon,
    int? uploadingIndex,
    List<PaymentMethodModel>? methods,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearUploadingIndex = false,
  }) {
    return PaymentMethodsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isUploadingIcon: isUploadingIcon ?? this.isUploadingIcon,
      uploadingIndex:
          clearUploadingIndex ? null : (uploadingIndex ?? this.uploadingIndex),
      methods: methods ?? this.methods,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        isUploadingIcon,
        uploadingIndex,
        methods,
        error,
        successMessage,
      ];
}
