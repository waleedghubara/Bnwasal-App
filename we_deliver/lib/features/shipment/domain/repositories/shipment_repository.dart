import '../entities/shipment.dart';
import '../entities/message_entity.dart';

abstract class ShipmentRepository {
  Future<List<Shipment>> getShipments({
    String? status,
    String? filter,
    String? query,
  });
  Future<void> addShipment(Shipment shipment);
  Future<void> updateShipment(Shipment shipment);
  Future<void> deleteShipment(String shipmentId);
  Future<void> updateShipmentStatus(
    String shipmentId,
    String status, {
    double? negotiatedPrice,
    double? latitude,
    double? longitude,
  });
  Future<Shipment> getShipmentById(String shipmentId);
  Future<List<MessageEntity>> getMessages(String shipmentId);
  Future<MessageEntity> sendMessage(String shipmentId, String text);
  Future<void> updateFcmToken(String fcmToken);
  /// Called by captain to accept/reject an auto-assigned shipment via the dedicated endpoint
  Future<void> captainResponse(String shipmentId, String response);
}
