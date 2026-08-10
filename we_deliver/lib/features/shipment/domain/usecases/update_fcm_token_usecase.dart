import '../repositories/shipment_repository.dart';

class UpdateFcmTokenUseCase {
  final ShipmentRepository repository;

  UpdateFcmTokenUseCase(this.repository);

  Future<void> call(String fcmToken) async {
    await repository.updateFcmToken(fcmToken);
  }
}
