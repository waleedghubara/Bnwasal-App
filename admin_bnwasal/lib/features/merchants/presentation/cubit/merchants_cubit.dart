import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/merchants_api.dart';
import 'merchants_state.dart';

class MerchantsCubit extends Cubit<MerchantsState> {
  final MerchantsApi _api;
  MerchantsCubit(this._api) : super(const MerchantsState());

  Future<void> loadMerchants({bool refresh = false, int? page}) async {
    final targetPage = page ?? (refresh ? 1 : state.page);
    emit(state.copyWith(isLoading: true, error: null, page: targetPage));
    try {
      final response = await _api.getMerchants(
        page: targetPage,
        limit: state.limit,
        search: state.search,
        status: state.status,
      );
      final data = response['data'] as Map<String, dynamic>;
      final merchants = data['merchants'] as List<dynamic>;
      emit(
        state.copyWith(
          isLoading: false,
          merchants: (refresh || page != null) ? merchants : [...state.merchants, ...merchants],
          total: data['total'] as int,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void changePage(int page) {
    loadMerchants(page: page);
  }

  void searchMerchants(String query) {
    emit(state.copyWith(search: query, page: 1));
    loadMerchants(refresh: true);
  }

  void changeStatusFilter(String status) {
    emit(state.copyWith(status: status, page: 1));
    loadMerchants(refresh: true);
  }

  void loadMore() {
    if (state.merchants.length >= state.total) return;
    emit(state.copyWith(page: state.page + 1));
    loadMerchants();
  }

  Future<void> loadMerchantDetail(int id) async {
    emit(
      MerchantsState(
        isLoading: state.isLoading,
        error: state.error,
        merchants: state.merchants,
        total: state.total,
        page: state.page,
        limit: state.limit,
        search: state.search,
        isLoadingDetail: true,
      ),
    );
    try {
      final response = await _api.getMerchantDetail(id);
      final data = response['data'] as Map<String, dynamic>;
      emit(
        MerchantsState(
          isLoading: state.isLoading,
          error: state.error,
          merchants: state.merchants,
          total: state.total,
          page: state.page,
          limit: state.limit,
          search: state.search,
          isLoadingDetail: false,
          merchant: data['merchant'] as Map<String, dynamic>,
          stats: data['stats'] as Map<String, dynamic>,
          recentActivity: data['recentActivity'] as List<dynamic>,
          analysis: data['analysis'] as Map<String, dynamic>,
          documents: data['documents'] as Map<String, dynamic>?,
        ),
      );
    } catch (e) {
      emit(
        MerchantsState(
          isLoading: state.isLoading,
          error: state.error,
          merchants: state.merchants,
          total: state.total,
          page: state.page,
          limit: state.limit,
          search: state.search,
          isLoadingDetail: false,
          detailError: e.toString(),
        ),
      );
    }
  }

  void clearDetail() {
    emit(
      MerchantsState(
        isLoading: state.isLoading,
        error: state.error,
        merchants: state.merchants,
        total: state.total,
        page: state.page,
        limit: state.limit,
        search: state.search,
      ),
    );
  }

  Future<String> deleteMerchant(int id) async {
    try {
      await _api.deleteMerchant(id);
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> updateMerchantStatus(int id, String status) async {
    try {
      await _api.updateMerchantStatus(id, status);
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> sendWarning(int id, String title, String body) async {
    try {
      await _api.sendWarning(id, title, body);
      return '';
    } catch (e) {
      return e.toString();
    }
  }
}
