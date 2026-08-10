import '../../domain/entities/shipment.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/shipment_repository.dart';
import '../datasources/shipment_remote_data_source.dart';

class ShipmentRepositoryImpl implements ShipmentRepository {
  final ShipmentRemoteDataSource remoteDataSource;

  ShipmentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Shipment>> getShipments({
    String? status,
    String? filter,
    String? query,
  }) async {
    return await remoteDataSource.getShipments(
      status: status,
      filter: filter,
      query: query,
    );
  }

  @override
  Future<void> addShipment(Shipment shipment) async {
    await remoteDataSource.addShipment(shipment);
  }

  @override
  Future<void> updateShipment(Shipment shipment) async {
    await remoteDataSource.updateShipment(shipment);
  }

  @override
  Future<void> deleteShipment(String shipmentId) async {
    await remoteDataSource.deleteShipment(shipmentId);
  }

  @override
  Future<void> updateShipmentStatus(
    String shipmentId,
    String status, {
    double? negotiatedPrice,
    double? latitude,
    double? longitude,
  }) async {
    await remoteDataSource.updateShipmentStatus(
      shipmentId,
      status,
      negotiatedPrice: negotiatedPrice,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<Shipment> getShipmentById(String shipmentId) async {
    return await remoteDataSource.getShipmentById(shipmentId);
  }

  @override
  Future<List<MessageEntity>> getMessages(String shipmentId) async {
    return await remoteDataSource.getMessages(shipmentId);
  }

  @override
  Future<MessageEntity> sendMessage(String shipmentId, String text) async {
    return await remoteDataSource.sendMessage(shipmentId, text);
  }

  @override
  Future<void> updateFcmToken(String fcmToken) async {
    await remoteDataSource.updateFcmToken(fcmToken);
  }

  @override
  Future<void> captainResponse(String shipmentId, String response) async {
    await remoteDataSource.captainResponse(shipmentId, response);
  }
}
