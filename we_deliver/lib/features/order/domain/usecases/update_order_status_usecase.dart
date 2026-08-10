import '../repositories/order_repository.dart';

class UpdateOrderStatusUseCase {
  final OrderRepository repository;

  UpdateOrderStatusUseCase(this.repository);

  Future<void> call(String orderId, String status, {double? latitude, double? longitude}) async {
    return await repository.updateOrderStatus(orderId, status, latitude: latitude, longitude: longitude);
  }
}
