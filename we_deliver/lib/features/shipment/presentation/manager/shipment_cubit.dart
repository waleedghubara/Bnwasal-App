import 'package:flutter/material.dart';
import '../../domain/usecases/get_shipments_usecase.dart';
import '../../domain/usecases/add_shipment_usecase.dart';
import '../../domain/usecases/update_shipment_status_usecase.dart';
import '../../domain/usecases/get_shipment_by_id_usecase.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/repositories/shipment_repository.dart';

class ShipmentCubit extends ChangeNotifier {
  final GetShipmentsUseCase getShipmentsUseCase;
  final AddShipmentUseCase addShipmentUseCase;
  final UpdateShipmentStatusUseCase updateShipmentStatusUseCase;
  final GetShipmentByIdUseCase getShipmentByIdUseCase;
  final ShipmentRepository shipmentRepository;

  ShipmentCubit({
    required this.getShipmentsUseCase,
    required this.addShipmentUseCase,
    required this.updateShipmentStatusUseCase,
    required this.getShipmentByIdUseCase,
    required this.shipmentRepository,
  }) {
    loadShipments();
  }

  String _selectedFilter = ShipmentStatus.all;
  String _searchQuery = '';
  bool _showAddOptions = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<Shipment> _allShipments = [];

  String get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;
  bool get showAddOptions => _showAddOptions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Shipment> get allShipments => _allShipments;

  Future<void> loadShipments({String? filter}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allShipments = await getShipmentsUseCase(
        status: _selectedFilter == ShipmentStatus.all ? null : _selectedFilter,
        query: _searchQuery,
        filter: filter,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Shipment> get filteredShipments {
    // If the server-side filtering is active, we can just return _allShipments.
    // However, keeping local backup filter is safe for seamless rendering.
    var list = _allShipments;
    if (_selectedFilter != ShipmentStatus.all) {
      list = list.where((s) => s.status == _selectedFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((s) => s.shipmentNumber.contains(_searchQuery))
          .toList();
    }
    return list;
  }

  void selectFilter(String filter) {
    _selectedFilter = filter;
    loadShipments();
  }

  void updateSearch(String query) {
    _searchQuery = query;
    loadShipments();
  }

  void toggleAddOptions() {
    _showAddOptions = !_showAddOptions;
    notifyListeners();
  }

  void closeAddOptions() {
    _showAddOptions = false;
    notifyListeners();
  }

  Future<void> addShipment(Shipment shipment) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await addShipmentUseCase(shipment);
      await loadShipments();
      _showAddOptions = false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateShipmentStatus(String shipmentId, String status, {double? negotiatedPrice}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await updateShipmentStatusUseCase(shipmentId, status, negotiatedPrice: negotiatedPrice);
      await loadShipments();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Shipment?> getShipmentDetails(String shipmentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final shipment = await getShipmentByIdUseCase(shipmentId);
      return shipment;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteShipment(String shipmentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await shipmentRepository.deleteShipment(shipmentId);
      await loadShipments();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateShipment(Shipment shipment) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await shipmentRepository.updateShipment(shipment);
      await loadShipments();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Captain responds to an auto-assigned shipment using the dedicated endpoint.
  /// response = 'accept' or 'reject'
  /// This properly clears captainId on reject and triggers auto-assignment for next captain.
  Future<void> captainRespondToAssignment(String shipmentId, String response) async {
    try {
      await shipmentRepository.captainResponse(shipmentId, response);
      await loadShipments();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }
}
