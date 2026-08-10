import 'package:equatable/equatable.dart';

class MerchantsState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<dynamic> merchants;
  final int total;
  final int page;
  final int limit;
  final String search;
  final String status;

  // Detail
  final bool isLoadingDetail;
  final String? detailError;
  final Map<String, dynamic>? merchant;
  final Map<String, dynamic>? stats;
  final List<dynamic>? recentActivity;
  final Map<String, dynamic>? analysis;
  final Map<String, dynamic>? documents;

  const MerchantsState({
    this.isLoading = false,
    this.error,
    this.merchants = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 20,
    this.search = '',
    this.status = '',
    this.isLoadingDetail = false,
    this.detailError,
    this.merchant,
    this.stats,
    this.recentActivity,
    this.analysis,
    this.documents,
  });

  MerchantsState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? merchants,
    int? total,
    int? page,
    int? limit,
    String? search,
    String? status,
    bool? isLoadingDetail,
    String? detailError,
    Map<String, dynamic>? merchant,
    Map<String, dynamic>? stats,
    List<dynamic>? recentActivity,
    Map<String, dynamic>? analysis,
    Map<String, dynamic>? documents,
  }) {
    return MerchantsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      merchants: merchants ?? this.merchants,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      status: status ?? this.status,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      detailError: detailError,
      merchant: merchant ?? this.merchant,
      stats: stats ?? this.stats,
      recentActivity: recentActivity ?? this.recentActivity,
      analysis: analysis ?? this.analysis,
      documents: documents ?? this.documents,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    error,
    merchants,
    total,
    page,
    limit,
    search,
    status,
    isLoadingDetail,
    detailError,
    merchant,
    stats,
    recentActivity,
    analysis,
    documents,
  ];
}
