import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/pending_accounts_api.dart';
import 'pending_accounts_state.dart';

class PendingAccountsCubit extends Cubit<PendingAccountsState> {
  final PendingAccountsApi _api;
  PendingAccountsCubit(this._api) : super(const PendingAccountsState());

  Future<void> loadAccounts({bool refresh = false, int? page}) async {
    final targetPage = page ?? (refresh ? 1 : state.page);
    emit(state.copyWith(isLoading: true, error: null, page: targetPage));
    try {
      final response = await _api.getPendingAccounts(
        page: targetPage,
        limit: state.limit,
        role: state.roleFilter,
      );
      final data = response['data'] as Map<String, dynamic>;
      final accounts = data['accounts'] as List<dynamic>;
      emit(
        state.copyWith(
          isLoading: false,
          accounts: (refresh || page != null) ? accounts : [...state.accounts, ...accounts],
          total: data['total'] as int,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void changePage(int page) {
    loadAccounts(page: page);
  }

  void filterByRole(String role) {
    emit(state.copyWith(roleFilter: role, page: 1));
    loadAccounts(refresh: true);
  }

  void loadMore() {
    if (state.accounts.length >= state.total) return;
    emit(state.copyWith(page: state.page + 1));
    loadAccounts();
  }

  Future<void> loadAccountDetail(int id) async {
    emit(PendingAccountsState(
      isLoading: state.isLoading,
      error: state.error,
      accounts: state.accounts,
      total: state.total,
      page: state.page,
      limit: state.limit,
      roleFilter: state.roleFilter,
      isLoadingDetail: true,
    ));
    try {
      final response = await _api.getPendingAccountDetail(id);
      final data = response['data'] as Map<String, dynamic>;
      debugPrint('PendingAccountDetail response keys: ${data.keys}');
      debugPrint('documents: ${data['documents']}');
      debugPrint('account keys: ${(data['account'] as Map?)?.keys}');
      emit(PendingAccountsState(
        isLoading: state.isLoading,
        error: state.error,
        accounts: state.accounts,
        total: state.total,
        page: state.page,
        limit: state.limit,
        roleFilter: state.roleFilter,
        isLoadingDetail: false,
        account: data['account'] as Map<String, dynamic>,
        stats: data['stats'] as Map<String, dynamic>,
        documents: data['documents'] as Map<String, dynamic>?,
        driverDocuments: data['driverDocuments'] as Map<String, dynamic>?,
      ));
    } catch (e) {
      emit(PendingAccountsState(
        isLoading: state.isLoading,
        error: state.error,
        accounts: state.accounts,
        total: state.total,
        page: state.page,
        limit: state.limit,
        roleFilter: state.roleFilter,
        isLoadingDetail: false,
        detailError: e.toString(),
      ));
    }
  }

  void clearDetail() {
    emit(PendingAccountsState(
      isLoading: state.isLoading,
      error: state.error,
      accounts: state.accounts,
      total: state.total,
      page: state.page,
      limit: state.limit,
      roleFilter: state.roleFilter,
    ));
  }

  Future<String> approveAccount(int id) async {
    emit(state.copyWith(isProcessing: true, processingError: null));
    try {
      await _api.approveAccount(id);
      emit(state.copyWith(isProcessing: false));
      return '';
    } catch (e) {
      emit(state.copyWith(isProcessing: false, processingError: e.toString()));
      return e.toString();
    }
  }

  Future<String> rejectAccount(int id) async {
    emit(state.copyWith(isProcessing: true, processingError: null));
    try {
      await _api.rejectAccount(id);
      emit(state.copyWith(isProcessing: false));
      return '';
    } catch (e) {
      emit(state.copyWith(isProcessing: false, processingError: e.toString()));
      return e.toString();
    }
  }
}
