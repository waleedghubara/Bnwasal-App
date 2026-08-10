import '../repositories/shipment_repository.dart';
import '../entities/message_entity.dart';

class GetMessagesUseCase {
  final ShipmentRepository repository;

  GetMessagesUseCase(this.repository);

  Future<List<MessageEntity>> call(String shipmentId) async {
    return await repository.getMessages(shipmentId);
  }
}
