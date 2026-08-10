import 'package:equatable/equatable.dart';

class DashboardState extends Equatable {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? lifecycleBreakdown;
  final List<dynamic>? recentNotifications;
  final List<dynamic>? areaDistribution;
  final Map<String, dynamic>? platformCommissions;
  final Map<String, dynamic>? withdrawalSummary;
  final List<dynamic>? topCaptains;
  final List<dynamic>? mapItems;
  final Map<String, dynamic>? activeCaptainsNow;
  final List<dynamic>? walletChart;
  final List<dynamic>? revenueChart;
  final List<dynamic>? usersByRole;
  final List<dynamic>? todayTrips;
  final Map<String, dynamic>? todayTripStats;
  final List<dynamic>? todayOrders;
  final List<dynamic>? todayShipments;

  const DashboardState({
    this.isLoading = false,
    this.error,
    this.stats,
    this.lifecycleBreakdown,
    this.recentNotifications,
    this.areaDistribution,
    this.platformCommissions,
    this.withdrawalSummary,
    this.topCaptains,
    this.mapItems,
    this.activeCaptainsNow,
    this.walletChart,
    this.revenueChart,
    this.usersByRole,
    this.todayTrips,
    this.todayTripStats,
    this.todayOrders,
    this.todayShipments,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? lifecycleBreakdown,
    List<dynamic>? recentNotifications,
    List<dynamic>? areaDistribution,
    Map<String, dynamic>? platformCommissions,
    Map<String, dynamic>? withdrawalSummary,
    List<dynamic>? topCaptains,
    List<dynamic>? mapItems,
    Map<String, dynamic>? activeCaptainsNow,
    List<dynamic>? walletChart,
    List<dynamic>? revenueChart,
    List<dynamic>? usersByRole,
    List<dynamic>? todayTrips,
    Map<String, dynamic>? todayTripStats,
    List<dynamic>? todayOrders,
    List<dynamic>? todayShipments,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stats: stats ?? this.stats,
      lifecycleBreakdown: lifecycleBreakdown ?? this.lifecycleBreakdown,
      recentNotifications: recentNotifications ?? this.recentNotifications,
      areaDistribution: areaDistribution ?? this.areaDistribution,
      platformCommissions: platformCommissions ?? this.platformCommissions,
      withdrawalSummary: withdrawalSummary ?? this.withdrawalSummary,
      topCaptains: topCaptains ?? this.topCaptains,
      mapItems: mapItems ?? this.mapItems,
      activeCaptainsNow: activeCaptainsNow ?? this.activeCaptainsNow,
      walletChart: walletChart ?? this.walletChart,
      revenueChart: revenueChart ?? this.revenueChart,
      usersByRole: usersByRole ?? this.usersByRole,
      todayTrips: todayTrips ?? this.todayTrips,
      todayTripStats: todayTripStats ?? this.todayTripStats,
      todayOrders: todayOrders ?? this.todayOrders,
      todayShipments: todayShipments ?? this.todayShipments,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        error,
        stats,
        lifecycleBreakdown,
        recentNotifications,
        areaDistribution,
        platformCommissions,
        withdrawalSummary,
        topCaptains,
        mapItems,
        activeCaptainsNow,
        walletChart,
        revenueChart,
        usersByRole,
        todayTrips,
        todayTripStats,
        todayOrders,
        todayShipments,
      ];
}
