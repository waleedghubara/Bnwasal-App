import 'package:flutter/material.dart';
import '../../domain/entities/order.dart';
import '../../domain/usecases/create_order_usecase.dart';
import '../../domain/usecases/get_orders_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/repositories/order_repository.dart';

class OrderCubit extends ChangeNotifier {
  final CreateOrderUseCase createOrderUseCase;
  final GetOrdersUseCase getOrdersUseCase;
  final UpdateOrderStatusUseCase updateOrderStatusUseCase;
  final GetOrderByIdUseCase getOrderByIdUseCase;
  final OrderRepository orderRepository;

  OrderCubit({
    required this.createOrderUseCase,
    required this.getOrdersUseCase,
    required this.updateOrderStatusUseCase,
    required this.getOrderByIdUseCase,
    required this.orderRepository,
  }) {
    loadOrders();
  }

  List<OrderEntity> _allOrders = [];
  String _selectedFilter = 'الكل';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<OrderEntity> get allOrders => _allOrders;
  String get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadOrders({String? filter}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allOrders = await getOrdersUseCase(filter: filter);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<OrderEntity> get filteredOrders {
    Iterable<OrderEntity> filtered = _allOrders;

    // Filter by status
    if (_selectedFilter != 'الكل') {
      filtered = filtered.where((o) => o.status == _selectedFilter);
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        return o.details.toLowerCase().contains(q) ||
            o.deliveryAddress.toLowerCase().contains(q) ||
            o.phone.contains(q) ||
            o.orderNumber.toLowerCase().contains(q) ||
            o.id.contains(q);
      });
    }

    return filtered.toList();
  }

  void selectFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<bool> createOrder(OrderEntity order) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await createOrderUseCase(order);
      await loadOrders();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOrderStatus(String id, String status) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await updateOrderStatusUseCase(id, status);
      // Update local state status if the order is currently in _allOrders
      final index = _allOrders.indexWhere((o) => o.id == id);
      if (index != -1) {
        _allOrders[index] = _allOrders[index].copyWith(status: status);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<OrderEntity?> getOrderById(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await getOrderByIdUseCase(id);
      _isLoading = false;
      notifyListeners();
      return order;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteOrder(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await orderRepository.deleteOrder(orderId);
      await loadOrders();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateOrder(OrderEntity order) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await orderRepository.updateOrder(order);
      await loadOrders();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Captain responds to an auto-assigned order using the dedicated endpoint.
  /// response = 'accept' or 'reject'
  /// This properly clears captainId on reject and triggers auto-assignment for next captain.
  Future<void> captainRespondToAssignment(String orderId, String response) async {
    try {
      await orderRepository.captainResponse(orderId, response);
      await loadOrders();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }
}
