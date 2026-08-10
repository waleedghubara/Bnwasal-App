import '../repositories/shipment_repository.dart';
import '../entities/message_entity.dart';

class SendMessageUseCase {
  final ShipmentRepository repository;

  SendMessageUseCase(this.repository);

  Future<MessageEntity> call(String shipmentId, String text) async {
    return await repository.sendMessage(shipmentId, text);
  }
}
