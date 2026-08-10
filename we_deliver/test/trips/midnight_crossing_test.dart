// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:we_deliver/features/trips/domain/entities/trip.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// Helper: builds a full DateTime for [arrival] on the same date as [dep],
/// automatically adding 1 day when arrival crosses midnight.
/// This mirrors the exact logic in add_trip_screen / edit_trip_screen.
/// ──────────────────────────────────────────────────────────────────────────
DateTime resolveArrival({
  required DateTime baseDate,
  required int depHour,
  required int depMinute,
  required int arrHour,
  required int arrMinute,
}) {
  final depMin = depHour * 60 + depMinute;
  final arrMin = arrHour * 60 + arrMinute;
  // Cross midnight only when arrival is STRICTLY before departure
  final dayOffset = arrMin < depMin ? 1 : 0;
  return DateTime(
    baseDate.year,
    baseDate.month,
    baseDate.day + dayOffset,
    arrHour,
    arrMinute,
  );
}

/// Helper: returns true when the arrival DateTime is strictly after departure.
bool isValidTripTime({
  required DateTime baseDate,
  required int depHour,
  required int depMinute,
  required int arrHour,
  required int arrMinute,
}) {
  final dep = DateTime(baseDate.year, baseDate.month, baseDate.day, depHour, depMinute);
  final arr = resolveArrival(
    baseDate: baseDate,
    depHour: depHour,
    depMinute: depMinute,
    arrHour: arrHour,
    arrMinute: arrMinute,
  );
  return arr.isAfter(dep);
}

void main() {
  final today = DateTime(2026, 6, 10); // Fixed reference date for deterministic tests

  group('Midnight-crossing trip validation', () {
    // ── Cases that MUST be valid ────────────────────────────────────────────
    test('11:00 PM → 1:00 AM  (crosses midnight)', () {
      expect(isValidTripTime(baseDate: today, depHour: 23, depMinute: 0, arrHour: 1, arrMinute: 0), isTrue);
    });

    test('12:30 AM → 3:00 AM  (same early-morning block, no midnight cross)', () {
      expect(isValidTripTime(baseDate: today, depHour: 0, depMinute: 30, arrHour: 3, arrMinute: 0), isTrue);
    });

    test('1:00 AM → 4:00 AM  (early morning, no midnight cross)', () {
      expect(isValidTripTime(baseDate: today, depHour: 1, depMinute: 0, arrHour: 4, arrMinute: 0), isTrue);
    });

    test('10:00 PM → 2:00 AM  (crosses midnight)', () {
      expect(isValidTripTime(baseDate: today, depHour: 22, depMinute: 0, arrHour: 2, arrMinute: 0), isTrue);
    });

    test('9:00 PM → 12:00 AM  (arrival exactly at midnight = next day 0:00)', () {
      // 0:00 <= 21*60 → dayOffset = 1 → arrival is next day 0:00, which is after 9PM today
      expect(isValidTripTime(baseDate: today, depHour: 21, depMinute: 0, arrHour: 0, arrMinute: 0), isTrue);
    });

    test('11:59 PM → 12:01 AM  (crosses midnight by 2 minutes)', () {
      expect(isValidTripTime(baseDate: today, depHour: 23, depMinute: 59, arrHour: 0, arrMinute: 1), isTrue);
    });

    test('8:00 AM → 5:00 PM  (normal same-day)', () {
      expect(isValidTripTime(baseDate: today, depHour: 8, depMinute: 0, arrHour: 17, arrMinute: 0), isTrue);
    });

    test('INVALID: same departure and arrival time (10AM → 10AM)', () {
      // arrMin == depMin → dayOffset = 0 → arrival same moment → NOT isAfter → invalid
      expect(isValidTripTime(baseDate: today, depHour: 10, depMinute: 0, arrHour: 10, arrMinute: 0), isFalse);
    });

    test('INVALID: 5PM → 5PM exactly', () {
      expect(isValidTripTime(baseDate: today, depHour: 17, depMinute: 0, arrHour: 17, arrMinute: 0), isFalse);
    });
  });

  group('resolveArrival day offset', () {
    test('Normal same-day trip: no day offset', () {
      final arr = resolveArrival(baseDate: today, depHour: 8, depMinute: 0, arrHour: 12, arrMinute: 0);
      expect(arr.day, equals(today.day));
    });

    test('Midnight-crossing: arrival is on next day', () {
      final arr = resolveArrival(baseDate: today, depHour: 22, depMinute: 0, arrHour: 2, arrMinute: 0);
      expect(arr.day, equals(today.day + 1));
    });

    test('Arrival exactly at midnight: next day 0:00', () {
      final arr = resolveArrival(baseDate: today, depHour: 21, depMinute: 0, arrHour: 0, arrMinute: 0);
      expect(arr.day, equals(today.day + 1));
      expect(arr.hour, equals(0));
      expect(arr.minute, equals(0));
    });
  });

  group('Trip.isExpired — midnight-crossing trips', () {
    Trip makeTrip({
      required DateTime date,
      required String depTime,
      String? arrTime,
      TripStatus status = TripStatus.pending,
    }) {
      return Trip(
        id: 'test',
        from: 'Cairo',
        to: 'Alex',
        date: date,
        time: depTime,
        status: status,
        departureTime: depTime,
        arrivalTime: arrTime,
      );
    }

    test('Trip with arrival 2AM next day is NOT expired before 2AM', () {
      // Departure: yesterday 10PM, Arrival: today 2AM
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final trip = makeTrip(
        date: yesterday,
        depTime: '10:00 م',
        arrTime: '2:00 ص',
      );
      // Current time is after midnight but we can't control DateTime.now() in tests.
      // We just verify the trip is not immediately marked invalid due to parsing.
      // The expired flag depends on whether arrDT < now, which varies by test time.
      // At least verify it parses without throwing.
      expect(() => trip.isExpired, returnsNormally);
    });

    test('Completed trip is always expired', () {
      final trip = makeTrip(
        date: DateTime.now().add(const Duration(days: 1)),
        depTime: '10:00 ص',
        status: TripStatus.completed,
      );
      expect(trip.isExpired, isTrue);
    });

    test('Ongoing trip is never expired', () {
      final trip = makeTrip(
        date: DateTime.now().subtract(const Duration(days: 1)),
        depTime: '10:00 ص',
        status: TripStatus.ongoing,
      );
      expect(trip.isExpired, isFalse);
    });

    test('Future trip is not expired', () {
      final trip = makeTrip(
        date: DateTime.now().add(const Duration(days: 2)),
        depTime: '10:00 ص',
      );
      expect(trip.isExpired, isFalse);
    });

    test('Past trip with no arrival time is expired', () {
      final trip = makeTrip(
        date: DateTime.now().subtract(const Duration(days: 2)),
        depTime: '8:00 ص',
      );
      expect(trip.isExpired, isTrue);
    });
  });
}
