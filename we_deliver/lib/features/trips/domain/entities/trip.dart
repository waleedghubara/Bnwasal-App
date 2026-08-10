import 'package:equatable/equatable.dart';

enum TripStatus { pending, ongoing, completed, cancelled }

class Trip extends Equatable {
  final String id;
  final String from;
  final String to;
  final DateTime date;
  final String time;
  final TripStatus status;
  final double? price;
  final double? distance;
  final String? fromCity;
  final String? toCity;
  final String? passingCities;
  final String? departureTime;
  final String? arrivalTime;

  const Trip({
    required this.id,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.status,
    this.price,
    this.distance,
    this.fromCity,
    this.toCity,
    this.passingCities,
    this.departureTime,
    this.arrivalTime,
  });

  /// Parses an Arabic/English 12-hour time string (e.g. "2:30 ص" or "10:00 م")
  /// and returns the corresponding 24-hour [hour] and [minute] values, or null.
  static ({int hour, int minute})? _parseArabicTime(String timeStr) {
    try {
      String normalized = timeStr.trim().toLowerCase();
      const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      for (int i = 0; i < 10; i++) {
        normalized = normalized.replaceAll(arabicDigits[i], i.toString());
      }
      final match = RegExp(r'(\d+):(\d+)').firstMatch(normalized);
      if (match == null) return null;

      int hour = int.parse(match.group(1)!);
      final int minute = int.parse(match.group(2)!);

      final isPm = normalized.contains('م') ||
          normalized.contains('pm') ||
          normalized.contains('مساء') ||
          normalized.contains('مساءً');
      final isAm = normalized.contains('ص') ||
          normalized.contains('am') ||
          normalized.contains('صباح') ||
          normalized.contains('صباحاً');

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;

      return (hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  bool get isExpired {
    if (status == TripStatus.completed || status == TripStatus.cancelled) {
      return true;
    }
    if (status == TripStatus.ongoing) {
      return false;
    }

    final now = DateTime.now();

    try {
      // Parse departure time
      final dep = _parseArabicTime(time);
      if (dep == null) {
        // Fallback: compare date only
        final todayDate = DateTime(now.year, now.month, now.day);
        final tripDateOnly = DateTime(date.year, date.month, date.day);
        return tripDateOnly.isBefore(todayDate);
      }

      final depDT = DateTime(date.year, date.month, date.day, dep.hour, dep.minute);

      // If there is an arrival time, use it to determine expiry.
      // The arrival may be on the NEXT day (midnight-crossing trip).
      if (arrivalTime != null) {
        final arr = _parseArabicTime(arrivalTime!);
        if (arr != null) {
          final depMin = dep.hour * 60 + dep.minute;
          final arrMin = arr.hour * 60 + arr.minute;
          // Arrival on next calendar day only if its minutes-of-day is STRICTLY less than departure's
          final dayOffset = arrMin < depMin ? 1 : 0;
          final arrDT = DateTime(
              date.year, date.month, date.day + dayOffset, arr.hour, arr.minute);
          return arrDT.isBefore(now);
        }
      }

      // No arrival time: expire when the departure time has passed
      return depDT.isBefore(now);
    } catch (_) {
      final todayDate = DateTime(now.year, now.month, now.day);
      final tripDateOnly = DateTime(date.year, date.month, date.day);
      return tripDateOnly.isBefore(todayDate);
    }
  }

  @override
  List<Object?> get props => [
        id,
        from,
        to,
        date,
        time,
        status,
        price,
        distance,
        fromCity,
        toCity,
        passingCities,
        departureTime,
        arrivalTime,
      ];
}
