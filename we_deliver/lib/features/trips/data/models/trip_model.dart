import '../../domain/entities/trip.dart';

class TripModel extends Trip {
  const TripModel({
    required super.id,
    required super.from,
    required super.to,
    required super.date,
    required super.time,
    required super.status,
    super.price,
    super.distance,
    super.fromCity,
    super.toCity,
    super.passingCities,
    super.departureTime,
    super.arrivalTime,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'].toString(),
      from: json['from'],
      to: json['to'],
      date: DateTime.parse(json['date']),
      time: json['time'],
      status: json['status'] == 'in_progress'
          ? TripStatus.ongoing
          : TripStatus.values.firstWhere(
              (e) => e.name == json['status'],
              orElse: () => TripStatus.pending,
            ),
      price: json['price']?.toDouble(),
      distance: json['distance']?.toDouble(),
      fromCity: json['fromCity'],
      toCity: json['toCity'],
      passingCities: json['passingCities'],
      departureTime: json['departureTime'],
      arrivalTime: json['arrivalTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from,
      'to': to,
      'date': date.toIso8601String(),
      'time': time,
      'status': status == TripStatus.ongoing ? 'in_progress' : status.name,
      'price': price,
      'distance': distance,
      'fromCity': fromCity,
      'toCity': toCity,
      'passingCities': passingCities,
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
    };
  }
}
