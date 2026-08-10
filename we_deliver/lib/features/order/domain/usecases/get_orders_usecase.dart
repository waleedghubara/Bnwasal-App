import '../entities/order.dart';
import '../repositories/order_repository.dart';

class GetOrdersUseCase {
  final OrderRepository repository;

  GetOrdersUseCase(this.repository);

  Future<List<OrderEntity>> call({String? filter, String? status}) async {
    return await repository.getOrders(filter: filter, status: status);
  }
}
