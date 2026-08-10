import 'package:equatable/equatable.dart';

enum AppPage { dashboard, merchants, orders, users, captains, trips, todayOrdersShipments, allOrdersShipments, todayTrips, pendingAccounts, complaints, notifications, sendNotification, employees, profile, settings, withdrawals, wallet, userMessages, directPayments, coupons }


class NavigationState extends Equatable {
  final AppPage currentPage;
  final bool isMenuOpen;

  const NavigationState({
    this.currentPage = AppPage.dashboard,
    this.isMenuOpen = false,
  });

  NavigationState copyWith({AppPage? currentPage, bool? isMenuOpen}) {
    return NavigationState(
      currentPage: currentPage ?? this.currentPage,
      isMenuOpen: isMenuOpen ?? this.isMenuOpen,
    );
  }

  @override
  List<Object?> get props => [currentPage, isMenuOpen];
}
