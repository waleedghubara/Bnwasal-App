import '../../domain/entities/shipment.dart';
import '../models/shipment_model.dart';

abstract class ShipmentLocalDataSource {
  Future<List<ShipmentModel>> getShipments();
  Future<void> addShipment(ShipmentModel shipment);
}

class ShipmentLocalDataSourceImpl implements ShipmentLocalDataSource {
  final List<ShipmentModel> _allShipments = [
    ShipmentModel(
      id: '1',
      shipmentNumber: 'H1234567856670678',
      fromAddress: '30 شارع الدقي , القاهرة',
      toAddress: 'مصطفي النحاس،مدينة نصر، القاهرة',
      status: ShipmentStatus.newShipment,
      driverName: 'احمد محمد عبد الرحمن',
      estimatedTime: '12 دقيقة',
      price: 250,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    ShipmentModel(
      id: '2',
      shipmentNumber: 'H1234567856670678',
      fromAddress: '30 شارع الدقي , القاهرة',
      toAddress: 'مصطفي النحاس،مدينة نصر، القاهرة',
      status: ShipmentStatus.pending,
      estimatedTime: 'بانتظار المندوب',
      price: 250,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  @override
  Future<List<ShipmentModel>> getShipments() async {
    return _allShipments;
  }

  @override
  Future<void> addShipment(ShipmentModel shipment) async {
    _allShipments.insert(0, shipment);
  }
}
