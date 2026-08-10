import 'package:equatable/equatable.dart';

class PendingAccountsState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<dynamic> accounts;
  final int total;
  final int page;
  final int limit;
  final String roleFilter;

  final bool isLoadingDetail;
  final String? detailError;
  final Map<String, dynamic>? account;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? documents;
  final Map<String, dynamic>? driverDocuments;

  final bool isProcessing;
  final String? processingError;

  const PendingAccountsState({
    this.isLoading = false,
    this.error,
    this.accounts = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 20,
    this.roleFilter = '',
    this.isLoadingDetail = false,
    this.detailError,
    this.account,
    this.stats,
    this.documents,
    this.driverDocuments,
    this.isProcessing = false,
    this.processingError,
  });

  PendingAccountsState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? accounts,
    int? total,
    int? page,
    int? limit,
    String? roleFilter,
    bool? isLoadingDetail,
    String? detailError,
    Map<String, dynamic>? account,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? documents,
    Map<String, dynamic>? driverDocuments,
    bool? isProcessing,
    String? processingError,
  }) {
    return PendingAccountsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      accounts: accounts ?? this.accounts,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      roleFilter: roleFilter ?? this.roleFilter,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      detailError: detailError,
      account: account ?? this.account,
      stats: stats ?? this.stats,
      documents: documents ?? this.documents,
      driverDocuments: driverDocuments ?? this.driverDocuments,
      isProcessing: isProcessing ?? this.isProcessing,
      processingError: processingError,
    );
  }

  @override
  List<Object?> get props => [
    isLoading, error, accounts, total, page, limit, roleFilter,
    isLoadingDetail, detailError, account, stats, documents, driverDocuments,
    isProcessing, processingError,
  ];
}
