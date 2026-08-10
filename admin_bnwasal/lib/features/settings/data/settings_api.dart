import 'package:dio/dio.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:path_provider/path_provider.dart';
import 'payment_method_model.dart';

class SettingsApi {
  final DioConsumer _dio;
  SettingsApi(this._dio);

  Future<Map<String, dynamic>> getSettings() async {
    final response = await _dio.get('settings');
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['settings'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateSocialLinks(Map<String, String> links) async {
    await _dio.put('settings/social', data: links);
  }

  Future<void> updateSettingKey(String key, String value) async {
    await _dio.put('settings/update-key', data: {'key': key, 'value': value});
  }

  Future<Map<String, dynamic>> uploadUpdate({
    required String filePath,
    required String version,
    required bool required,
  }) async {
    final formData = FormData.fromMap({
      'updateFile': await MultipartFile.fromFile(filePath, filename: filePath.split('\\').last.split('/').last),
      'version': version,
      'required': required ? '1' : '0',
    });
    final response = await _dio.post('settings/upload-update', data: formData);
    return response as Map<String, dynamic>;
  }

  Future<String> downloadUpdate({
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}\\bnwasal_update.exe';
    final url = '${EndPoint.baseUrl}settings/download-update';
    await _dio.download(url, savePath, onProgress: onProgress, cancelToken: cancelToken);
    return savePath;
  }

  Future<bool> checkUpdate() async {
    try {
      final response = await _dio.get('settings/check-update');
      final data = response['data'] as Map<String, dynamic>? ?? {};
      return data['hasUpdate'] == true && data['required'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> checkUpdateDetails() async {
    final response = await _dio.get('settings/check-update');
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> toggleMaintenance({required bool enabled, String? message}) async {
    final data = <String, dynamic>{'enabled': enabled ? '1' : '0'};
    if (message != null) data['message'] = message;
    await _dio.put('settings/maintenance', data: data);
  }

  // ─── Payment Methods ────────────────────────────────────────────────────────

  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final response = await _dio.get('direct-payments/methods');
    final data = (response as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
    final list = (data['methods'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map(PaymentMethodModel.fromJson).toList();
  }

  Future<void> savePaymentMethods(List<PaymentMethodModel> methods) async {
    await _dio.put(
      'direct-payments/methods',
      data: {'methods': methods.map((m) => m.toJson()).toList()},
    );
  }

  Future<String> uploadMethodIcon(String filePath) async {
    final formData = FormData.fromMap({
      'iconImage': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split(RegExp(r'[/\\]')).last,
      ),
    });
    final response = await _dio.post('direct-payments/methods/icon', data: formData);
    final data = (response as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return data['imageUrl'] as String;
  }
}
