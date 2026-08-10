import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_data_source.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remoteDataSource;

  OrderRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<OrderEntity>> getOrders({String? filter, String? status}) async {
    final orders = await remoteDataSource.getOrders(filter: filter, status: status);
    return List<OrderEntity>.from(orders);
  }

  @override
  Future<void> createOrder(OrderEntity order) async {
    await remoteDataSource.createOrder(order);
  }

  @override
  Future<void> updateOrder(OrderEntity order) async {
    await remoteDataSource.updateOrder(order);
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    await remoteDataSource.deleteOrder(orderId);
  }

  @override
  Future<OrderEntity> getOrderById(String id) async {
    return await remoteDataSource.getOrderById(id);
  }

  @override
  Future<void> updateOrderStatus(String id, String status, {double? latitude, double? longitude}) async {
    await remoteDataSource.updateOrderStatus(id, status, latitude: latitude, longitude: longitude);
  }

  @override
  Future<void> captainResponse(String orderId, String response) async {
    await remoteDataSource.captainResponse(orderId, response);
  }
}
