import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/trips_api.dart';
import 'trips_state.dart';

class TripsCubit extends Cubit<TripsState> {
  final TripsApi _api;
  TripsCubit(this._api) : super(const TripsState());

  Future<void> loadTrips({bool refresh = false}) async {
    if (refresh) {
      emit(state.copyWith(isLoading: true, error: null, page: 1, isToday: false));
    } else {
      emit(state.copyWith(isLoading: true, error: null));
    }
    try {
      final response = await _api.getTrips(
        page: state.page,
        limit: 20,
        search: state.search,
        date: state.dateFilter,
        dateFrom: state.dateFromFilter,
        dateTo: state.dateToFilter,
        status: state.statusFilter,
      );
      final data = response['data'] as Map<String, dynamic>;
      final trips = data['trips'] as List<dynamic>;
      emit(state.copyWith(
        isLoading: false,
        trips: refresh ? trips : [...state.trips, ...trips],
        total: data['total'] as int,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> loadTodayTrips() async {
    // Save current cached trips before emitting loading state
    final cachedTrips = List<dynamic>.from(state.trips);
    emit(state.copyWith(isLoading: true, error: null, page: 1, isToday: true));
    try {
      final response = await _api.getTodayTrips(search: state.search);
      final data = response['data'] as Map<String, dynamic>;
      final newTrips = data['trips'] as List<dynamic>;

      // Collect IDs returned by the API
      final newIds = newTrips
          .map((t) => (t as Map<String, dynamic>)['id'])
          .toSet();

      // Safety net: keep any in_progress trips from the cache that the API
      // may have missed (e.g. backend not yet restarted, or cross-midnight trips)
      final missedActive = cachedTrips.where((t) {
        final trip = t as Map<String, dynamic>;
        final s = trip['status'] as String? ?? '';
        final eff = trip['effectiveStatus'] as String? ?? s;
        final isActive = s == 'in_progress' || eff == 'in_progress';
        return isActive && !newIds.contains(trip['id']);
      }).toList();

      final merged = [...newTrips, ...missedActive];

      emit(state.copyWith(
        isLoading: false,
        trips: merged,
        total: merged.length,
        dateFilter: '',
        dateFromFilter: '',
        dateToFilter: '',
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void search(String query) {
    emit(state.copyWith(search: query, page: 1));
    if (state.isToday) {
      loadTodayTrips();
    } else {
      loadTrips(refresh: true);
    }
  }

  void filterByDate(String date) {
    emit(state.copyWith(dateFilter: date, dateFromFilter: '', dateToFilter: '', page: 1, isToday: false));
    loadTrips(refresh: true);
  }

  void filterByDateRange(String dateFrom, String dateTo) {
    emit(state.copyWith(dateFilter: '', dateFromFilter: dateFrom, dateToFilter: dateTo, page: 1, isToday: false));
    loadTrips(refresh: true);
  }

  void filterByStatus(String status) {
    emit(state.copyWith(statusFilter: status, page: 1, isToday: false));
    loadTrips(refresh: true);
  }

  void loadMore() {
    if (state.trips.length >= state.total) return;
    emit(state.copyWith(page: state.page + 1));
    loadTrips();
  }
}
