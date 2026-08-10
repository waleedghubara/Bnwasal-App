import '../entities/shipment.dart';
import '../repositories/shipment_repository.dart';

class AddShipmentUseCase {
  final ShipmentRepository repository;

  AddShipmentUseCase(this.repository);

  Future<void> call(Shipment shipment) async {
    return await repository.addShipment(shipment);
  }
}
