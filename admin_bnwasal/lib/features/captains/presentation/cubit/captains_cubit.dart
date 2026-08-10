import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/captains_api.dart';
import '../../../trips/data/trips_api.dart';
import 'captains_state.dart';

class CaptainsCubit extends Cubit<CaptainsState> {
  final CaptainsApi _api;
  final TripsApi _tripsApi;
  CaptainsCubit(this._api, this._tripsApi) : super(const CaptainsState());

  Future<void> loadCaptains({bool refresh = false, int? page}) async {
    final targetPage = page ?? (refresh ? 1 : state.page);
    emit(state.copyWith(isLoading: true, error: null, page: targetPage));
    try {
      final response = await _api.getCaptains(
        page: targetPage,
        limit: state.limit,
        search: state.search,
        status: state.status,
      );
      final data = response['data'] as Map<String, dynamic>;
      final captains = data['captains'] as List<dynamic>;
      emit(
        state.copyWith(
          isLoading: false,
          captains: (refresh || page != null) ? captains : [...state.captains, ...captains],
          total: data['total'] as int,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void changePage(int page) {
    loadCaptains(page: page);
  }

  void searchCaptains(String query) {
    emit(state.copyWith(search: query, page: 1));
    loadCaptains(refresh: true);
  }

  void changeStatusFilter(String status) {
    emit(state.copyWith(status: status, page: 1));
    loadCaptains(refresh: true);
  }

  void loadMore() {
    if (state.captains.length >= state.total) return;
    emit(state.copyWith(page: state.page + 1));
    loadCaptains();
  }

  Future<void> loadCaptainDetail(int id) async {
    emit(
      CaptainsState(
        isLoading: state.isLoading,
        error: state.error,
        captains: state.captains,
        total: state.total,
        page: state.page,
        limit: state.limit,
        search: state.search,
        isLoadingDetail: true,
      ),
    );
    try {
      final response = await _api.getCaptainDetail(id);
      final data = response['data'] as Map<String, dynamic>;
      emit(
        CaptainsState(
          isLoading: state.isLoading,
          error: state.error,
          captains: state.captains,
          total: state.total,
          page: state.page,
          limit: state.limit,
          search: state.search,
          isLoadingDetail: false,
          captain: data['captain'] as Map<String, dynamic>,
          stats: data['stats'] as Map<String, dynamic>,
          recentActivity: data['recentActivity'] as List<dynamic>,
          analysis: data['analysis'] as Map<String, dynamic>,
          documents: data['documents'] as Map<String, dynamic>?,
          activeDelivery: data['activeDelivery'] as Map<String, dynamic>?,
          pastDeliveries: data['pastDeliveries'] as List<dynamic>?,
        ),
      );
      loadCaptainTrips(id);
    } catch (e) {
      emit(
        CaptainsState(
          isLoading: state.isLoading,
          error: state.error,
          captains: state.captains,
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

  void updateCaptainLocation(double lat, double lng) {
    if (state.captain != null) {
      final updatedCaptain = Map<String, dynamic>.from(state.captain!);
      updatedCaptain['latitude'] = lat;
      updatedCaptain['longitude'] = lng;
      emit(state.copyWith(captain: updatedCaptain));
    }
  }

  Future<void> loadCaptainTrips(int captainId) async {
    emit(state.copyWith(isLoadingCaptTrips: true));
    try {
      final response = await _tripsApi.getTripsByCaptain(captainId, limit: 50);
      final data = response['data'] as Map<String, dynamic>;
      final trips = data['trips'] as List<dynamic>;
      emit(state.copyWith(isLoadingCaptTrips: false, captainTrips: trips));
    } catch (_) {
      emit(state.copyWith(isLoadingCaptTrips: false, captainTrips: []));
    }
  }

  void clearDetail() {
    emit(
      CaptainsState(
        isLoading: state.isLoading,
        error: state.error,
        captains: state.captains,
        total: state.total,
        page: state.page,
        limit: state.limit,
        search: state.search,
      ),
    );
  }

  Future<String> deleteCaptain(int id) async {
    try {
      await _api.deleteCaptain(id);
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> updateCaptainStatus(int id, String status) async {
    try {
      await _api.updateCaptainStatus(id, status);
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

  Future<String> createCaptain(
    Map<String, dynamic> data, {
    String? profileImagePath,
    String? nationalIdFrontPath,
    String? nationalIdBackPath,
  }) async {
    emit(state.copyWith(isCreating: true, createError: null));
    try {
      final response = await _api.createCaptain(data);
      final resData = response['data'] as Map<String, dynamic>;
      final int captainId = resData['userId'];

      if (profileImagePath != null ||
          nationalIdFrontPath != null ||
          nationalIdBackPath != null) {
        await _api.uploadDocuments(
          captainId,
          profileImagePath: profileImagePath,
          nationalIdFrontPath: nationalIdFrontPath,
          nationalIdBackPath: nationalIdBackPath,
        );
      }

      emit(state.copyWith(isCreating: false, createError: null));
      return '';
    } catch (e) {
      emit(state.copyWith(isCreating: false, createError: e.toString()));
      return e.toString();
    }
  }
}
