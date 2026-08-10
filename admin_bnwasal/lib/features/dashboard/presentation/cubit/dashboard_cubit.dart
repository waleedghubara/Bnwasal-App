import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/dashboard_api.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardApi _api;
  DashboardCubit(this._api) : super(const DashboardState());

  Future<void> loadDashboard() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final response = await _api.getDashboard();
      final data = response['data'] as Map<String, dynamic>;
      emit(state.copyWith(
        isLoading: false,
        stats: data['stats'] as Map<String, dynamic>?,
        lifecycleBreakdown: data['lifecycleBreakdown'] as Map<String, dynamic>?,
        recentNotifications: data['recentNotifications'] as List<dynamic>?,
        areaDistribution: data['areaDistribution'] as List<dynamic>?,
        platformCommissions: data['platformCommissions'] as Map<String, dynamic>?,
        withdrawalSummary: data['withdrawalSummary'] as Map<String, dynamic>?,
        topCaptains: data['topCaptains'] as List<dynamic>?,
        mapItems: data['mapItems'] as List<dynamic>?,
        activeCaptainsNow: data['activeCaptainsNow'] as Map<String, dynamic>?,
        walletChart: data['walletChart'] as List<dynamic>?,
        revenueChart: data['revenueChart'] as List<dynamic>?,
        usersByRole: data['usersByRole'] as List<dynamic>?,
        todayTrips: data['todayTrips'] as List<dynamic>?,
        todayTripStats: data['todayTripStats'] as Map<String, dynamic>?,
        todayOrders: data['todayOrders'] as List<dynamic>?,
        todayShipments: data['todayShipments'] as List<dynamic>?,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void insertTodayOrder(Map<String, dynamic> order) {
    final orders = List<Map<String, dynamic>>.from(state.todayOrders ?? []);
    orders.removeWhere((o) => o['id'].toString() == order['id'].toString());
    orders.insert(0, order);
    emit(state.copyWith(todayOrders: orders));
  }

  void updateTodayOrder(Map<String, dynamic> order) {
    final orders = List<Map<String, dynamic>>.from(state.todayOrders ?? []);
    final idx = orders.indexWhere((o) => o['id'].toString() == order['id'].toString());
    if (idx >= 0) {
      orders[idx] = order;
      emit(state.copyWith(todayOrders: orders));
    }
  }

  void insertTodayShipment(Map<String, dynamic> shipment) {
    final shipments = List<Map<String, dynamic>>.from(state.todayShipments ?? []);
    shipments.removeWhere((s) => s['id'].toString() == shipment['id'].toString());
    shipments.insert(0, shipment);
    emit(state.copyWith(todayShipments: shipments));
  }

  void updateTodayShipment(Map<String, dynamic> shipment) {
    final shipments = List<Map<String, dynamic>>.from(state.todayShipments ?? []);
    final idx = shipments.indexWhere((s) => s['id'].toString() == shipment['id'].toString());
    if (idx >= 0) {
      shipments[idx] = shipment;
      emit(state.copyWith(todayShipments: shipments));
    }
  }
}
