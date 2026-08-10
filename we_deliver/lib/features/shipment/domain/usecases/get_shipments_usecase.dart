import '../entities/shipment.dart';
import '../repositories/shipment_repository.dart';

class GetShipmentsUseCase {
  final ShipmentRepository repository;

  GetShipmentsUseCase(this.repository);

  Future<List<Shipment>> call({
    String? status,
    String? filter,
    String? query,
  }) async {
    return await repository.getShipments(
      status: status,
      filter: filter,
      query: query,
    );
  }
}
