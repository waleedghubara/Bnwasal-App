import '../models/order_model.dart';

abstract class OrderLocalDataSource {
  Future<List<OrderModel>> getOrders();
  Future<void> saveOrder(OrderModel order);
}

class OrderLocalDataSourceImpl implements OrderLocalDataSource {
  final List<OrderModel> _orders = [];

  @override
  Future<List<OrderModel>> getOrders() async {
    return _orders;
  }

  @override
  Future<void> saveOrder(OrderModel order) async {
    _orders.insert(0, order);
  }
}
