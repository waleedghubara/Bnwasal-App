import 'package:dio/dio.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class ComplaintsApi {
  final DioConsumer _dio;
  ComplaintsApi(this._dio);

  Future<Map<String, dynamic>> getComplaints() async {
    final response = await _dio.get(EndPoint.supportThreads);
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMessages(int userId) async {
    final response = await _dio.get(
      EndPoint.supportChat,
      queryParameters: {'userId': userId},
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> replyToComplaint(int userId, String text, {String? imagePath}) async {
    dynamic postData;
    if (imagePath != null) {
      postData = FormData.fromMap({
        'userId': userId,
        'text': text,
        'image': await MultipartFile.fromFile(imagePath, filename: imagePath.split('/').last),
      });
    } else {
      postData = {
        'userId': userId,
        'text': text,
      };
    }
    
    final response = await _dio.post(
      EndPoint.supportChat,
      data: postData,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> lookup(String query) async {
    final response = await _dio.get(
      'support/lookup',
      queryParameters: {'q': query},
    );
    return response as Map<String, dynamic>;
  }
}
