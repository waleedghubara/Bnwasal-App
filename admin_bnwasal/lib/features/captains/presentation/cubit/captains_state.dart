import 'package:equatable/equatable.dart';

class CaptainsState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<dynamic> captains;
  final int total;
  final int page;
  final int limit;
  final String search;
  final String status;

  final bool isLoadingDetail;
  final String? detailError;
  final Map<String, dynamic>? captain;
  final Map<String, dynamic>? stats;
  final List<dynamic>? recentActivity;
  final Map<String, dynamic>? analysis;
  final Map<String, dynamic>? documents;
  final List<dynamic>? captainTrips;
  final bool isLoadingCaptTrips;
  final Map<String, dynamic>? activeDelivery;
  final List<dynamic>? pastDeliveries;
  final bool isCreating;
  final String? createError;

  const CaptainsState({
    this.isLoading = false,
    this.error,
    this.captains = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 20,
    this.search = '',
    this.status = '',
    this.isLoadingDetail = false,
    this.detailError,
    this.captain,
    this.stats,
    this.recentActivity,
    this.analysis,
    this.documents,
    this.captainTrips,
    this.isLoadingCaptTrips = false,
    this.activeDelivery,
    this.pastDeliveries,
    this.isCreating = false,
    this.createError,
  });

  CaptainsState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? captains,
    int? total,
    int? page,
    int? limit,
    String? search,
    String? status,
    bool? isLoadingDetail,
    String? detailError,
    Map<String, dynamic>? captain,
    Map<String, dynamic>? stats,
    List<dynamic>? recentActivity,
    Map<String, dynamic>? analysis,
    Map<String, dynamic>? documents,
    List<dynamic>? captainTrips,
    bool? isLoadingCaptTrips,
    Map<String, dynamic>? activeDelivery,
    List<dynamic>? pastDeliveries,
    bool? isCreating,
    String? createError,
  }) {
    return CaptainsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      captains: captains ?? this.captains,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      status: status ?? this.status,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      detailError: detailError,
      captain: captain ?? this.captain,
      stats: stats ?? this.stats,
      recentActivity: recentActivity ?? this.recentActivity,
      analysis: analysis ?? this.analysis,
      documents: documents ?? this.documents,
      captainTrips: captainTrips ?? this.captainTrips,
      isLoadingCaptTrips: isLoadingCaptTrips ?? this.isLoadingCaptTrips,
      activeDelivery: activeDelivery ?? this.activeDelivery,
      pastDeliveries: pastDeliveries ?? this.pastDeliveries,
      isCreating: isCreating ?? this.isCreating,
      createError: createError,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    error,
    captains,
    total,
    page,
    limit,
    search,
    status,
    isLoadingDetail,
    detailError,
    captain,
    stats,
    recentActivity,
    analysis,
    documents,
    captainTrips,
    isLoadingCaptTrips,
    activeDelivery,
    pastDeliveries,
    isCreating,
    createError,
  ];
}
