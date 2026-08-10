import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/settings_api.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsApi _api;
  SettingsCubit(this._api) : super(const SettingsState());

  Future<void> loadSettings() async {
    emit(state.copyWith(isLoading: true, error: null, successMessage: null));
    try {
      final s = await _api.getSettings();
      emit(state.copyWith(
        isLoading: false,
        facebook: s['social_facebook']?.toString() ?? '',
        instagram: s['social_instagram']?.toString() ?? '',
        twitter: s['social_twitter']?.toString() ?? '',
        whatsapp: s['social_whatsapp']?.toString() ?? '',
        linkedin: s['social_linkedin']?.toString() ?? '',
        youtube: s['social_youtube']?.toString() ?? '',
        updateVersion: s['update_version']?.toString() ?? '',
        updateRequired: s['update_required'] == '1',
        hasUpdateFile: (s['update_file']?.toString() ?? '').isNotEmpty,
        maintenanceEnabled: s['maintenance_mode'] == '1',
        maintenanceMessage: s['maintenance_message']?.toString() ?? '',
        feeCollectionMode: s['fee_collection_mode']?.toString() ?? 'after_agreement',
        playStoreUrl: s['play_store_url']?.toString() ?? '',
        appStoreUrl: s['app_store_url']?.toString() ?? '',
        supportPhone: s['support_phone']?.toString() ?? '',
        supportEmail: s['support_email']?.toString() ?? '',
        merchantVideoUrl: s['merchant_video_url']?.toString() ?? '',
        captainVideoUrl: s['captain_video_url']?.toString() ?? '',
        mobileUpdateVersion: s['mobile_update_version']?.toString() ?? '1.0.0',
        mobileUpdateRequired: s['mobile_update_required'] == '1',
        enableAutoAssignment: s['enable_auto_assignment'] != '0',
        autoAssignmentTimeout: int.tryParse(s['auto_assignment_timeout']?.toString() ?? '300') ?? 300,
        maxReassignmentAttempts: int.tryParse(s['max_reassignment_attempts']?.toString() ?? '5') ?? 5,
        maxAttemptsPerCaptain: int.tryParse(s['max_attempts_per_captain']?.toString() ?? '3') ?? 3,
        allowAutoAssignmentAfterReject: s['allow_auto_assignment_after_reject'] != '0',
        allowAutoAssignmentAfterTimeout: s['allow_auto_assignment_after_timeout'] != '0',
        routeMatchingRule: s['route_matching_rule']?.toString() ?? 'flexible',
        captainAcceptanceTimeout: int.tryParse(s['captain_acceptance_timeout_seconds']?.toString() ?? '60') ?? 60,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'فشل تحميل الإعدادات'));
    }
  }

  void updateSocialField(String field, String value) {
    switch (field) {
      case 'facebook': emit(state.copyWith(facebook: value)); break;
      case 'instagram': emit(state.copyWith(instagram: value)); break;
      case 'twitter': emit(state.copyWith(twitter: value)); break;
      case 'whatsapp': emit(state.copyWith(whatsapp: value)); break;
      case 'linkedin': emit(state.copyWith(linkedin: value)); break;
      case 'youtube': emit(state.copyWith(youtube: value)); break;
    }
  }

  Future<void> saveSocialLinks() async {
    emit(state.copyWith(isSaving: true, error: null, successMessage: null));
    try {
      await _api.updateSocialLinks({
        'facebook': state.facebook,
        'instagram': state.instagram,
        'twitter': state.twitter,
        'whatsapp': state.whatsapp,
        'linkedin': state.linkedin,
        'youtube': state.youtube,
      });
      emit(state.copyWith(isSaving: false, successMessage: '✅ تم حفظ روابط التواصل الاجتماعي'));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'فشل حفظ الروابط'));
    }
  }

  Future<void> pickAndUploadUpdate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe', 'msi', 'zip'],
    );
    if (result == null || result.files.single.path == null) return;
    final filePath = result.files.single.path!;
    emit(state.copyWith(isUploading: true, error: null, successMessage: null));
    try {
      final version = state.updateVersion.isNotEmpty ? state.updateVersion : '1.0.0';
      await _api.uploadUpdate(
        filePath: filePath,
        version: version,
        required: state.updateRequired,
      );
      emit(state.copyWith(
        isUploading: false,
        hasUpdateFile: true,
        successMessage: '✅ تم رفع التحديث بنجاح',
      ));
    } catch (e) {
      emit(state.copyWith(isUploading: false, error: 'فشل رفع التحديث'));
    }
  }

  void setUpdateVersion(String v) => emit(state.copyWith(updateVersion: v));
  void setUpdateRequired(bool v) => emit(state.copyWith(updateRequired: v));

  Future<void> toggleMaintenance(bool enabled) async {
    emit(state.copyWith(isSaving: true, error: null, successMessage: null));
    try {
      await _api.toggleMaintenance(
        enabled: enabled,
        message: state.maintenanceMessage.isNotEmpty ? state.maintenanceMessage : null,
      );
      emit(state.copyWith(
        isSaving: false,
        maintenanceEnabled: enabled,
        successMessage: enabled ? '🛠️ تم تفعيل وضع الصيانة' : '✅ تم إلغاء وضع الصيانة',
      ));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'فشل تغيير حالة الصيانة'));
    }
  }

  void setMaintenanceMessage(String m) => emit(state.copyWith(maintenanceMessage: m));

  Future<void> updateFeeCollectionMode(String mode) async {
    emit(state.copyWith(isSaving: true, error: null, successMessage: null));
    try {
      await _api.updateSettingKey('fee_collection_mode', mode);
      emit(state.copyWith(
        isSaving: false,
        feeCollectionMode: mode,
        successMessage: '✅ تم حفظ إعداد تحصيل رسوم الشحن بنجاح',
      ));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'فشل حفظ إعداد تحصيل الرسوم'));
    }
  }

  void setPlayStoreUrl(String v) => emit(state.copyWith(playStoreUrl: v));
  void setAppStoreUrl(String v) => emit(state.copyWith(appStoreUrl: v));
  void setSupportPhone(String v) => emit(state.copyWith(supportPhone: v));
  void setSupportEmail(String v) => emit(state.copyWith(supportEmail: v));
  void setMerchantVideoUrl(String v) => emit(state.copyWith(merchantVideoUrl: v));
  void setCaptainVideoUrl(String v) => emit(state.copyWith(captainVideoUrl: v));
  void setMobileUpdateVersion(String v) => emit(state.copyWith(mobileUpdateVersion: v));
  void setMobileUpdateRequired(bool v) => emit(state.copyWith(mobileUpdateRequired: v));

  void setEnableAutoAssignment(bool v) => emit(state.copyWith(enableAutoAssignment: v));
  void setAutoAssignmentTimeout(int v) => emit(state.copyWith(autoAssignmentTimeout: v));
  void setMaxReassignmentAttempts(int v) => emit(state.copyWith(maxReassignmentAttempts: v));
  void setMaxAttemptsPerCaptain(int v) => emit(state.copyWith(maxAttemptsPerCaptain: v));
  void setAllowAutoAssignmentAfterReject(bool v) => emit(state.copyWith(allowAutoAssignmentAfterReject: v));
  void setAllowAutoAssignmentAfterTimeout(bool v) => emit(state.copyWith(allowAutoAssignmentAfterTimeout: v));
  void setRouteMatchingRule(String v) => emit(state.copyWith(routeMatchingRule: v));
  void setCaptainAcceptanceTimeout(int v) => emit(state.copyWith(captainAcceptanceTimeout: v));

  Future<void> saveAutoAssignmentSettings() async {
    emit(state.copyWith(isSaving: true, error: null, successMessage: null));
    try {
      await _api.updateSettingKey('enable_auto_assignment', state.enableAutoAssignment ? '1' : '0');
      await _api.updateSettingKey('auto_assignment_timeout', state.autoAssignmentTimeout.toString());
      await _api.updateSettingKey('max_reassignment_attempts', state.maxReassignmentAttempts.toString());
      await _api.updateSettingKey('max_attempts_per_captain', state.maxAttemptsPerCaptain.toString());
      await _api.updateSettingKey('allow_auto_assignment_after_reject', state.allowAutoAssignmentAfterReject ? '1' : '0');
      await _api.updateSettingKey('allow_auto_assignment_after_timeout', state.allowAutoAssignmentAfterTimeout ? '1' : '0');
      await _api.updateSettingKey('route_matching_rule', state.routeMatchingRule);
      await _api.updateSettingKey('captain_acceptance_timeout_seconds', state.captainAcceptanceTimeout.toString());
      emit(state.copyWith(
        isSaving: false,
        successMessage: '✅ تم حفظ إعدادات الإسناد التلقائي بنجاح',
      ));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'فشل حفظ إعدادات الإسناد التلقائي'));
    }
  }

  Future<void> saveStoreUrls() async {
    emit(state.copyWith(isSaving: true, error: null, successMessage: null));
    try {
      await _api.updateSettingKey('play_store_url', state.playStoreUrl);
      await _api.updateSettingKey('app_store_url', state.appStoreUrl);
      await _api.updateSettingKey('support_phone', state.supportPhone);
      await _api.updateSettingKey('support_email', state.supportEmail);
      await _api.updateSettingKey('mobile_update_version', state.mobileUpdateVersion);
      await _api.updateSettingKey('mobile_update_required', state.mobileUpdateRequired ? '1' : '0');
      emit(state.copyWith(
        isSaving: false,
        successMessage: '✅ تم حفظ روابط المتاجر وقنوات الدعم بنجاح',
      ));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'فشل حفظ روابط المتاجر وقنوات الدعم'));
    }
  }

  Future<void> saveVideoUrls() async {
    emit(state.copyWith(isSaving: true, error: null, successMessage: null));
    try {
      await _api.updateSettingKey('merchant_video_url', state.merchantVideoUrl);
      await _api.updateSettingKey('captain_video_url', state.captainVideoUrl);
      emit(state.copyWith(
        isSaving: false,
        successMessage: '✅ تم حفظ فيديوهات شرح التطبيق بنجاح',
      ));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'فشل حفظ فيديوهات شرح التطبيق'));
    }
  }

  void clearMessages() => emit(state.copyWith(error: null, successMessage: null));
}
