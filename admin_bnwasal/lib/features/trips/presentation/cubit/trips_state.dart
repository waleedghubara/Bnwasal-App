import 'package:equatable/equatable.dart';

class TripsState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<dynamic> trips;
  final int total;
  final int page;
  final String search;
  final String dateFilter;
  final String dateFromFilter;
  final String dateToFilter;
  final String statusFilter;
  final bool isToday;

  const TripsState({
    this.isLoading = false,
    this.error,
    this.trips = const [],
    this.total = 0,
    this.page = 1,
    this.search = '',
    this.dateFilter = '',
    this.dateFromFilter = '',
    this.dateToFilter = '',
    this.statusFilter = '',
    this.isToday = false,
  });

  TripsState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? trips,
    int? total,
    int? page,
    String? search,
    String? dateFilter,
    String? dateFromFilter,
    String? dateToFilter,
    String? statusFilter,
    bool? isToday,
  }) {
    return TripsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      trips: trips ?? this.trips,
      total: total ?? this.total,
      page: page ?? this.page,
      search: search ?? this.search,
      dateFilter: dateFilter ?? this.dateFilter,
      dateFromFilter: dateFromFilter ?? this.dateFromFilter,
      dateToFilter: dateToFilter ?? this.dateToFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      isToday: isToday ?? this.isToday,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        error,
        trips,
        total,
        page,
        search,
        dateFilter,
        dateFromFilter,
        dateToFilter,
        statusFilter,
        isToday,
      ];
}
