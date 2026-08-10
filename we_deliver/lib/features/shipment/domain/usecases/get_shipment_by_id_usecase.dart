import '../entities/shipment.dart';
import '../repositories/shipment_repository.dart';

class GetShipmentByIdUseCase {
  final ShipmentRepository repository;

  GetShipmentByIdUseCase(this.repository);

  Future<Shipment> call(String shipmentId) async {
    return await repository.getShipmentById(shipmentId);
  }
}
