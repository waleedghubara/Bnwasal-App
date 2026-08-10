import 'package:dio/dio.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class CaptainsApi {
  final DioConsumer _dio;
  CaptainsApi(this._dio);

  Future<Map<String, dynamic>> getCaptains({
    int page = 1,
    int limit = 20,
    String search = '',
    String status = '',
  }) async {
    final response = await _dio.get(
      EndPoint.adminCaptains,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search.isNotEmpty) 'search': search,
        if (status.isNotEmpty) 'status': status,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCaptainDetail(int id) async {
    final response = await _dio.get('${EndPoint.adminCaptains}/$id');
    return response as Map<String, dynamic>;
  }

  Future<void> deleteCaptain(int id) async {
    await _dio.delete('${EndPoint.adminCaptains}/$id');
  }

  Future<void> updateCaptainStatus(int id, String status) async {
    await _dio.patch(
      '${EndPoint.adminCaptains}/$id/status',
      data: {'status': status},
    );
  }

  Future<void> sendWarning(int id, String title, String body) async {
    await _dio.post(
      '${EndPoint.adminCaptains}/$id/warning',
      data: {'title': title, 'body': body},
    );
  }

  Future<Map<String, dynamic>> createCaptain(Map<String, dynamic> data) async {
    final response = await _dio.post(EndPoint.register, data: data);
    return response as Map<String, dynamic>;
  }

  Future<void> uploadDocuments(
    int captainId, {
    String? profileImagePath,
    String? nationalIdFrontPath,
    String? nationalIdBackPath,
  }) async {
    final map = <String, dynamic>{};
    if (profileImagePath != null) {
      map['profileImage'] = await MultipartFile.fromFile(
        profileImagePath,
        filename: 'profile.jpg',
      );
    }
    if (nationalIdFrontPath != null) {
      map['nationalIdFront'] = await MultipartFile.fromFile(
        nationalIdFrontPath,
        filename: 'nid_front.jpg',
      );
    }
    if (nationalIdBackPath != null) {
      map['nationalIdBack'] = await MultipartFile.fromFile(
        nationalIdBackPath,
        filename: 'nid_back.jpg',
      );
    }
    if (map.isNotEmpty) {
      await _dio.post(
        '${EndPoint.adminCaptains}/$captainId/documents',
        data: FormData.fromMap(map),
      );
    }
  }
}
