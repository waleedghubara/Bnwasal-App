import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/settings_api.dart';
import '../../data/payment_method_model.dart';
import 'payment_methods_state.dart';

class PaymentMethodsCubit extends Cubit<PaymentMethodsState> {
  final SettingsApi _api;
  PaymentMethodsCubit(this._api) : super(const PaymentMethodsState());

  // ─── Load methods from backend ───────────────────────────────────────────────
  Future<void> loadMethods() async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      final methods = await _api.getPaymentMethods();
      emit(state.copyWith(isLoading: false, methods: methods));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'فشل تحميل وسائل الدفع'));
    }
  }

  // ─── Add a blank method placeholder ─────────────────────────────────────────
  void addMethod() {
    final updated = List<PaymentMethodModel>.from(state.methods)
      ..add(const PaymentMethodModel(name: '', phone: ''));
    emit(state.copyWith(methods: updated));
  }

  // ─── Update a method field ───────────────────────────────────────────────────
  void updateName(int index, String name) {
    final updated = List<PaymentMethodModel>.from(state.methods);
    updated[index] = updated[index].copyWith(name: name);
    emit(state.copyWith(methods: updated));
  }

  void updatePhone(int index, String phone) {
    final updated = List<PaymentMethodModel>.from(state.methods);
    updated[index] = updated[index].copyWith(phone: phone);
    emit(state.copyWith(methods: updated));
  }

  // ─── Remove a method ────────────────────────────────────────────────────────
  void removeMethod(int index) {
    final updated = List<PaymentMethodModel>.from(state.methods)..removeAt(index);
    emit(state.copyWith(methods: updated));
  }

  // ─── Upload icon for a specific method ──────────────────────────────────────
  Future<void> pickAndUploadIcon(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    emit(state.copyWith(
      isUploadingIcon: true,
      uploadingIndex: index,
      clearError: true,
    ));
    try {
      final imageUrl = await _api.uploadMethodIcon(filePath);
      final updated = List<PaymentMethodModel>.from(state.methods);
      updated[index] = updated[index].copyWith(imageUrl: imageUrl);
      emit(state.copyWith(
        isUploadingIcon: false,
        clearUploadingIndex: true,
        methods: updated,
      ));
    } catch (e) {
      emit(state.copyWith(
        isUploadingIcon: false,
        clearUploadingIndex: true,
        error: 'فشل رفع الأيقونة',
      ));
    }
  }

  // ─── Save all methods to backend ─────────────────────────────────────────────
  Future<void> saveMethods() async {
    // Validate
    for (final m in state.methods) {
      if (m.name.trim().isEmpty || m.phone.trim().isEmpty) {
        emit(state.copyWith(error: 'يرجى تعبئة اسم ورقم جميع وسائل الدفع'));
        return;
      }
    }
    emit(state.copyWith(isSaving: true, clearError: true, clearSuccess: true));
    try {
      await _api.savePaymentMethods(state.methods);
      emit(state.copyWith(
        isSaving: false,
        successMessage: '✅ تم حفظ وسائل الدفع بنجاح',
      ));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'فشل حفظ وسائل الدفع'));
    }
  }

  void clearMessages() =>
      emit(state.copyWith(clearError: true, clearSuccess: true));
}
