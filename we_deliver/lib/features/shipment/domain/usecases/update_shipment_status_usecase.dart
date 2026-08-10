import '../repositories/shipment_repository.dart';

class UpdateShipmentStatusUseCase {
  final ShipmentRepository repository;

  UpdateShipmentStatusUseCase(this.repository);

  Future<void> call(
    String shipmentId,
    String status, {
    double? negotiatedPrice,
    double? latitude,
    double? longitude,
  }) async {
    return await repository.updateShipmentStatus(
      shipmentId,
      status,
      negotiatedPrice: negotiatedPrice,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
