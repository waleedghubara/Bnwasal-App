import 'package:flutter_bloc/flutter_bloc.dart';
import 'navigation_state.dart';

class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit() : super(const NavigationState());

  void navigateTo(AppPage page) {
    emit(state.copyWith(currentPage: page, isMenuOpen: false));
  }

  void toggleMenu() {
    emit(state.copyWith(isMenuOpen: !state.isMenuOpen));
  }

  void closeMenu() {
    emit(state.copyWith(isMenuOpen: false));
  }

  void openMenu() {
    emit(state.copyWith(isMenuOpen: true));
  }

  /// Find the first permitted page for an employee user
  AppPage initialPageForUser(Map<String, dynamic>? user) {
    if (user == null) return AppPage.dashboard;
    final role = user['role']?.toString() ?? 'admin';
    if (role == 'admin') return AppPage.dashboard;

    final permissions = _userPermissions(user);
    if (permissions.isEmpty) return AppPage.profile;

    const orderedPages = AppPage.values;
    for (final page in orderedPages) {
      final perms = _pagePermission(page);
      if (perms.isNotEmpty && perms.any((p) => permissions.contains(p))) {
        return page;
      }
    }
    return AppPage.profile;
  }

  Set<String> _userPermissions(Map<String, dynamic> user) {
    final raw = user['permissions'];
    if (raw == null) return {};
    if (raw is List) return raw.map((e) => e.toString()).toSet();
    if (raw is String && raw.isNotEmpty) {
      return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
    }
    return {};
  }

  static Set<String> _pagePermission(AppPage page) {
    switch (page) {
      case AppPage.dashboard: return {'dashboard'};
      case AppPage.merchants: return {'merchants'};
      case AppPage.captains: return {'captains'};
      case AppPage.trips: return {'trips'};
      case AppPage.orders: return {'orders'};
      case AppPage.users: return {'users'};
      case AppPage.todayOrdersShipments: return {'todayOrdersShipments'};
      case AppPage.todayTrips: return {'todayTrips'};
      case AppPage.pendingAccounts: return {'pendingAccounts'};
      case AppPage.complaints: return {'complaints'};
      case AppPage.notifications: return {'notifications'};
      case AppPage.sendNotification: return {'notifications'};
      case AppPage.withdrawals: return {'withdrawals'};
      case AppPage.wallet: return {'wallet'};
      case AppPage.userMessages: return {'userMessages'};
      case AppPage.directPayments: return {'directPayments'};
      case AppPage.coupons: return {'coupons'};
      default: return {};
    }
  }
}
