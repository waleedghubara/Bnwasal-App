import '../entities/order.dart';
import '../repositories/order_repository.dart';

class GetOrderByIdUseCase {
  final OrderRepository repository;

  GetOrderByIdUseCase(this.repository);

  Future<OrderEntity> call(String orderId) async {
    return await repository.getOrderById(orderId);
  }
}
