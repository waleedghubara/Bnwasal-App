import '../entities/order.dart';

abstract class OrderRepository {
  Future<List<OrderEntity>> getOrders({String? filter, String? status});
  Future<void> createOrder(OrderEntity order);
  Future<void> updateOrder(OrderEntity order);
  Future<void> deleteOrder(String orderId);
  Future<OrderEntity> getOrderById(String id);
  Future<void> updateOrderStatus(String id, String status, {double? latitude, double? longitude});
  /// Captain responds to an auto-assigned order via the dedicated endpoint
  Future<void> captainResponse(String orderId, String response);
}
