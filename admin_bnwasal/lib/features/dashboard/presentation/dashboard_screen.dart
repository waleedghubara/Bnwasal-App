// ignore_for_file: unused_local_variable, deprecated_member_use

import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:admin_bnwasal/core/theme/app_assets.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/services/notification_service.dart';
import 'package:admin_bnwasal/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:admin_bnwasal/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:admin_bnwasal/features/home/presentation/cubit/navigation_cubit.dart';
import 'package:admin_bnwasal/features/home/presentation/cubit/navigation_state.dart';
import 'cubit/dashboard_cubit.dart';
import 'cubit/dashboard_state.dart';

class DashboardScreen extends StatefulWidget {
  final bool showHeader;
  const DashboardScreen({super.key, this.showHeader = true});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _showNotifDropdown = false;
  late AnimationController _notifAnimCtrl;
  late Animation<Offset> _notifSlideAnim;
  String _selectedCommPeriod = '7days';

  @override
  void initState() {
    super.initState();
    _notifAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _notifSlideAnim =
        Tween<Offset>(begin: const Offset(0, -0.02), end: Offset.zero).animate(
          CurvedAnimation(parent: _notifAnimCtrl, curve: Curves.easeOutCubic),
        );
    context.read<DashboardCubit>().loadDashboard();
    NotificationService().addDashboardUpdateListener(_handleDashboardUpdate);
  }

  void _handleDashboardUpdate() {
    if (mounted) {
      context.read<DashboardCubit>().loadDashboard();
    }
  }

  @override
  void dispose() {
    NotificationService().removeDashboardUpdateListener(_handleDashboardUpdate);
    _notifAnimCtrl.dispose();
    super.dispose();
  }

  void _toggleNotifDropdown() {
    setState(() {
      _showNotifDropdown = !_showNotifDropdown;
      if (_showNotifDropdown) {
        context.read<NotificationsCubit>().loadNotifications();
        _notifAnimCtrl.forward();
      } else {
        _notifAnimCtrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D1F)
          : const Color(0xFFF4F6F9),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          return SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    if (widget.showHeader) _buildTopHeader(isTablet),
                    Expanded(
                      child: state.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : state.error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    AppAssets.error,
                                    width: 160,
                                    height: 160,
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    'خطأ في تحميل البيانات',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      context
                                          .read<DashboardCubit>()
                                          .loadDashboard();
                                    },
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('إعادة المحاولة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildDashboardContent(state, isTablet),
                    ),
                  ],
                ),
                if (_showNotifDropdown)
                  GestureDetector(
                    onTap: _toggleNotifDropdown,
                    child: Container(
                      color: (isDark ? Colors.black : Colors.white).withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                if (_showNotifDropdown) _buildNotifDropdown(isTablet),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 1. Top Header Bar ──────────────────────────────────────────────────────
  Widget _buildTopHeader(bool isTablet) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nowFormatted = DateFormat(
      'EEEE d MMMM yyyy - hh:mm a',
      'ar',
    ).format(DateTime.now());

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.w : 16.w,
        vertical: 12.h,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14142B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحباً بك في لوحة التحكم الرئيسية',
                style: TextStyle(
                  fontSize: isTablet ? 18.sp : 15.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12.sp,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    nowFormatted,
                    style: TextStyle(
                      fontSize: isTablet ? 12.sp : 10.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Refresh Button
          IconButton(
            onPressed: () => context.read<DashboardCubit>().loadDashboard(),
            icon: SvgPicture.asset(
              AppAssets.dashboard,
              width: 20.w,
              height: 20.h,
            ),
            tooltip: 'تحديث البيانات',
          ),
          SizedBox(width: 8.w),
          // Notification Bell
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (ctx, notifState) {
              final unread = notifState.unreadCount;
              return GestureDetector(
                onTap: _toggleNotifDropdown,
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E38)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SvgPicture.asset(
                        AppAssets.notification,
                        width: 20.w,
                        height: 20.h,
                      ),
                      if (unread > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unread',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(width: 14.w),
          // User Avatar & Title
          Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  'أ',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أحمد المدير',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'مدير المنصة',
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. Main Dashboard Scroll Body ──────────────────────────────────────────
  Widget _buildDashboardContent(DashboardState state, bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => context.read<DashboardCubit>().loadDashboard(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isTablet ? 20.w : 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Top 7 Stat Cards Grid
            _buildTop7StatCards(state, isTablet),
            SizedBox(height: 16.h),

            // Row 2: Withdrawal Requests (35%) + Order Lifecycle (40%) + Recent Notifications (25%)
            LayoutBuilder(
              builder: (ctx, constraints) {
                if (constraints.maxWidth >= 950) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 35,
                        child: _buildWithdrawalRequestsCard(state, isDark),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        flex: 40,
                        child: _buildOrderLifecycleCard(state, isDark),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        flex: 25,
                        child: _buildRecentNotificationsCard(state, isDark),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildWithdrawalRequestsCard(state, isDark),
                      SizedBox(height: 14.h),
                      _buildOrderLifecycleCard(state, isDark),
                      SizedBox(height: 14.h),
                      _buildRecentNotificationsCard(state, isDark),
                    ],
                  );
                }
              },
            ),
            SizedBox(height: 16.h),

            // Row 3: Area Distribution (30%) + Platform Commissions (45%) + Top Captains (25%)
            LayoutBuilder(
              builder: (ctx, constraints) {
                if (constraints.maxWidth >= 950) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 30,
                        child: _buildAreaDistributionCard(state, isDark),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        flex: 45,
                        child: _buildPlatformCommissionsCard(state, isDark),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        flex: 25,
                        child: _buildTopCaptainsCard(state, isDark),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildAreaDistributionCard(state, isDark),
                      SizedBox(height: 14.h),
                      _buildPlatformCommissionsCard(state, isDark),
                      SizedBox(height: 14.h),
                      _buildTopCaptainsCard(state, isDark),
                    ],
                  );
                }
              },
            ),
            SizedBox(height: 16.h),

            // Row 4: Latest Orders & Shipments (45%) + Today's Captain Trips (35%) + Active Captains Now (20%)
            LayoutBuilder(
              builder: (ctx, constraints) {
                if (constraints.maxWidth >= 950) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 45,
                        child: _buildLatestOrdersShipmentsCard(state, isDark),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        flex: 35,
                        child: _buildTodayTripsCard(state, isDark),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        flex: 20,
                        child: _buildActiveCaptainsNowCard(state, isDark),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildLatestOrdersShipmentsCard(state, isDark),
                      SizedBox(height: 14.h),
                      _buildTodayTripsCard(state, isDark),
                      SizedBox(height: 14.h),
                      _buildActiveCaptainsNowCard(state, isDark),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Stat Card Helper ───────────────────────────────────────────────────────
  Widget _buildTop7StatCards(DashboardState state, bool isTablet) {
    final s = state.stats ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _TopCardData(
        title: 'إجمالي الطلبات والشحنات',
        value:
            '${(int.tryParse(s['orders']?.toString() ?? '0') ?? 0) + (int.tryParse(s['shipments']?.toString() ?? '0') ?? 0)}',
        growth: '+18.6%',
        iconSvg: AppAssets.box,
        color: const Color(0xFF2563EB),
      ),
      _TopCardData(
        title: 'إجمالي الكباتن',
        value: '${s['captains'] ?? 0}',
        growth: '+18.7%',
        iconSvg: AppAssets.captains,
        color: const Color(0xFF7C3AED),
      ),
      _TopCardData(
        title: 'الطلبات المكتملة',
        value: '${s['completed'] ?? 0}',
        growth: '+15.2%',
        iconSvg: AppAssets.ordersa,
        color: const Color(0xFF10B981),
      ),
      _TopCardData(
        title: 'قيد التنفيذ',
        value: '${s['delivering'] ?? 0}',
        growth: '+8.7%',
        iconSvg: AppAssets.delivery,
        color: const Color(0xFFF59E0B),
      ),
      _TopCardData(
        title: 'الطلبات المتأخرة',
        value: '${s['complaints'] ?? 0}',
        growth: '+12.4%',
        iconSvg: AppAssets.notes,
        color: const Color(0xFFEF4444),
      ),
      _TopCardData(
        title: 'إجمالي التجار والعملاء',
        value: '${s['merchants_and_clients'] ?? 0}',
        growth: '+22.5%',
        iconSvg: AppAssets.merchants,
        color: const Color(0xFF6366F1),
      ),
      _TopCardData(
        title: 'إجمالي الكباتن / المتاحين',
        value: '${s['active_captains'] ?? 0}',
        growth: '+17.3%',
        iconSvg: AppAssets.profile,
        color: const Color(0xFF0EA5E9),
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossCount = constraints.maxWidth > 1200
            ? 7
            : (constraints.maxWidth > 700 ? 4 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 10.w,
            mainAxisSpacing: 10.h,
            childAspectRatio: 1.4,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, idx) {
            final card = items[idx];
            return Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14142B) : Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          card.title,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: card.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: SvgPicture.asset(
                          card.iconSvg,
                          width: 16.w,
                          height: 16.h,
                          // colorFilter: ColorFilter.mode(
                          //   card.color,
                          //   BlendMode.srcIn,
                          // ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    card.value,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        color: const Color(0xFF10B981),
                        size: 12.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${card.growth} عن أمس',
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── 3. Panel: Live Map ─────────────────────────────────────────────────────
  // ignore: unused_element
  Widget _buildLiveMapCard(DashboardState state, bool isDark) {
    final mapItems = state.mapItems ?? [];
    // Default center to Alexandria / Egypt center
    final markers = mapItems.map((item) {
      final lat =
          double.tryParse(item['latitude']?.toString() ?? '31.2001') ?? 31.2001;
      final lng =
          double.tryParse(item['longitude']?.toString() ?? '29.9187') ??
          29.9187;
      final type = item['type']?.toString() ?? 'captain';

      Color markerColor = Colors.green;
      if (type == 'order') markerColor = Colors.blue;

      return Marker(
        point: LatLng(lat, lng),
        width: 32,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Icon(
            type == 'captain'
                ? Icons.directions_bike_rounded
                : Icons.shopping_bag_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      );
    }).toList();

    return _CardContainer(
      isDark: isDark,
      title: 'الخريطة المباشرة',
      actionText: 'عرض الكل',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              height: 240.h,
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(31.2001, 29.9187),
                  initialZoom: 11.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.bnwasal.admin',
                  ),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Legend row
          Wrap(
            spacing: 12.w,
            runSpacing: 6.h,
            children: const [
              _LegendDot(label: 'كابتن متاح', color: Colors.blue),
              _LegendDot(label: 'طلب قيد التنفيذ', color: Colors.green),
              _LegendDot(label: 'طلب متأخر', color: Colors.red),
              _LegendDot(label: 'تاجر/عميل', color: Colors.orange),
              _LegendDot(label: 'طلب بدون كابتن', color: Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Panel: Order Lifecycle ──────────────────────────────────────────────
  Widget _buildOrderLifecycleCard(DashboardState state, bool isDark) {
    final lf = state.lifecycleBreakdown ?? {};
    final total = lf['total'] ?? 0;

    final items = [
      _LifecycleItemData(
        'قيد المراجعة',
        lf['under_review'] ?? 0,
        const Color(0xFF3B82F6),
        Icons.hourglass_empty_rounded,
      ),
      _LifecycleItemData(
        'بانتظار تعيين مندوب',
        lf['pending_captain'] ?? 0,
        const Color(0xFFF59E0B),
        Icons.access_time_filled_rounded,
      ),
      _LifecycleItemData(
        'تم تعيين مندوب',
        lf['captain_assigned'] ?? 0,
        const Color(0xFF06B6D4),
        Icons.two_wheeler_rounded,
      ),
      _LifecycleItemData(
        'تم استلام الشحنة',
        lf['picked_up'] ?? 0,
        const Color(0xFF8B5CF6),
        Icons.local_shipping_rounded,
      ),
      _LifecycleItemData(
        'جاري توصيل الشحنة',
        lf['in_delivery'] ?? 0,
        const Color(0xFF6366F1),
        Icons.directions_bike_rounded,
      ),
      _LifecycleItemData(
        'تم التوصيل',
        lf['delivered'] ?? 0,
        const Color(0xFF10B981),
        Icons.check_circle_rounded,
      ),
      _LifecycleItemData(
        'مكتملة',
        lf['completed'] ?? 0,
        const Color(0xFF059669),
        Icons.task_alt_rounded,
      ),
      _LifecycleItemData(
        'ملغاة',
        lf['cancelled'] ?? 0,
        const Color(0xFFEF4444),
        Icons.cancel_rounded,
      ),
      _LifecycleItemData(
        'متأخرة',
        lf['delayed'] ?? 0,
        const Color(0xFFE11D48),
        Icons.warning_amber_rounded,
      ),
    ];

    final leftItems = items.sublist(0, 4);
    final rightItems = items.sublist(4, 8);
    final delayedItem = items[8];

    return _CardContainer(
      isDark: isDark,
      title: 'دورة حياة الطلبات',
      actionText: 'عرض الكل',
      onAction: () => context.read<NavigationCubit>().navigateTo(
        AppPage.allOrdersShipments,
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Right Column (4 Items)
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: rightItems.map((item) {
                      return _LifecycleBadge(
                        label: item.label,
                        count: item.count,
                        total: total,
                        color: item.color,
                        icon: item.icon,
                        isDark: isDark,
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(width: 8.w),

                // Center Donut Chart
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 120.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                            sections: items.map((d) {
                              return PieChartSectionData(
                                color: d.color,
                                value: d.count > 0
                                    ? d.count.toDouble()
                                    : 0.0001,
                                title: '',
                                radius: 12,
                              );
                            }).toList(),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              NumberFormat('#,###').format(total),
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'إجمالي الطلبات',
                              style: TextStyle(
                                fontSize: 8.5.sp,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),

                // Left Column (4 Items)
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: leftItems.map((item) {
                      return _LifecycleBadge(
                        label: item.label,
                        count: item.count,
                        total: total,
                        color: item.color,
                        icon: item.icon,
                        isDark: isDark,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),

          // Bottom Center Item: Delayed
          SizedBox(
            width: 170.w,
            child: _LifecycleBadge(
              label: delayedItem.label,
              count: delayedItem.count,
              total: total,
              color: delayedItem.color,
              icon: delayedItem.icon,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Panel: Recent Notifications ─────────────────────────────────────────
  Widget _buildRecentNotificationsCard(DashboardState state, bool isDark) {
    final notifs = state.recentNotifications ?? [];

    return _CardContainer(
      isDark: isDark,
      title: 'التنبيهات الأخيرة',
      actionText: 'عرض الكل',
      onAction: () =>
          context.read<NavigationCubit>().navigateTo(AppPage.notifications),
      child: notifs.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(20.h),
                child: Text(
                  'لا توجد تنبيهات جديدة',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
              ),
            )
          : Column(
              children: notifs.take(5).map((n) {
                return Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          AppAssets.notification,
                          width: 14.w,
                          height: 14.h,
                          colorFilter: const ColorFilter.mode(
                            AppColors.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['title']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              n['body']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── 6. Panel: Area Distribution ────────────────────────────────────────────
  Widget _buildAreaDistributionCard(DashboardState state, bool isDark) {
    final areas = state.areaDistribution ?? [];

    final palette = const [
      Color(0xFF2563EB), // Blue
      Color(0xFF0284C7), // Sky Blue
      Color(0xFF16A34A), // Green
      Color(0xFFEA580C), // Orange
      Color(0xFFDC2626), // Red
      Color(0xFF9333EA), // Purple
      Color(0xFF1E3A8A), // Dark Blue
      Color(0xFFD97706), // Amber
      Color(0xFF991B1B), // Dark Red
      Color(0xFF475569), // Slate Grey
    ];

    return _CardContainer(
      isDark: isDark,
      title: 'توزيع الطلبات حسب المنطقة',
      actionText: null, // User specified: NO 'عرض الكل' button
      child: areas.isEmpty
          ? Center(
              child: Text(
                'لا توجد بيانات مناطق حالية',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey),
              ),
            )
          : Row(
              children: [
                // Left Side: Donut Chart
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 140.w,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: areas.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final a = entry.value;
                          final count = (a['count'] as int? ?? 0).toDouble();
                          final color = palette[idx % palette.length];
                          return PieChartSectionData(
                            color: color,
                            value: count > 0 ? count : 0.0001,
                            title: '',
                            radius: 16,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),

                // Right Side: List of Areas (Square, Name, Percentage, Count)
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    child: Column(
                      children: areas.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final a = entry.value;
                        final name = a['area']?.toString() ?? '';
                        final pct = a['percentage'] ?? 0;
                        final count = a['count'] ?? 0;
                        final color = palette[idx % palette.length];

                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 3.h),
                          child: Row(
                            children: [
                              // Colored Indicator Square
                              Container(
                                width: 8.w,
                                height: 8.w,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              // Area Name
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Percentage
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // Count
                              SizedBox(
                                width: 34.w,
                                child: Text(
                                  NumberFormat('#,###').format(count),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── 7. Panel: Platform Commissions ────────────────────────────────────────
  Widget _buildPlatformCommissionsCard(DashboardState state, bool isDark) {
    final pc = state.platformCommissions ?? {};

    String formatNum(dynamic val) {
      final n = int.tryParse(val?.toString() ?? '0') ?? 0;
      return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }

    final todayVal = formatNum(pc['today'] ?? 18750);
    final weekVal = formatNum(pc['week'] ?? 128650);
    final monthVal = formatNum(pc['month'] ?? 512430);
    final totalVal = formatNum(pc['total'] ?? 4215850);

    final todayGrowth =
        double.tryParse(pc['todayGrowth']?.toString() ?? '12.6') ?? 12.6;
    final weekGrowth =
        double.tryParse(pc['weekGrowth']?.toString() ?? '10.3') ?? 10.3;
    final monthGrowth =
        double.tryParse(pc['monthGrowth']?.toString() ?? '14.8') ?? 14.8;

    List<dynamic> rawChartList = [];
    String periodTitleText = 'العمولات خلال آخر 7 أيام';

    if (_selectedCommPeriod == 'monthly') {
      rawChartList = (pc['chartMonthly'] as List<dynamic>?) ?? [];
      periodTitleText = 'العمولات خلال هذا الشهر';
    } else if (_selectedCommPeriod == 'quarterly') {
      rawChartList = (pc['chartQuarterly'] as List<dynamic>?) ?? [];
      periodTitleText = 'العمولات ربع سنوي';
    } else if (_selectedCommPeriod == 'semi_annual') {
      rawChartList = (pc['chartSemiAnnual'] as List<dynamic>?) ?? [];
      periodTitleText = 'العمولات نصف سنوي';
    } else if (_selectedCommPeriod == 'yearly') {
      rawChartList = (pc['chartYearly'] as List<dynamic>?) ?? [];
      periodTitleText = 'العمولات السنوية';
    } else {
      rawChartList = (pc['chart7Days'] as List<dynamic>?) ?? [];
      periodTitleText = 'العمولات خلال آخر 7 أيام';
    }

    final defaultSpots = const [
      FlSpot(0, 15),
      FlSpot(1, 12),
      FlSpot(2, 19),
      FlSpot(3, 16),
      FlSpot(4, 34),
      FlSpot(5, 19),
      FlSpot(6, 23),
    ];
    final defaultDates = [
      '19 مايو',
      '20 مايو',
      '21 مايو',
      '22 مايو',
      '23 مايو',
      '24 مايو',
      '25 مايو',
    ];

    List<FlSpot> spots = [];
    List<String> dates = [];
    double maxAmt = 40.0;

    if (rawChartList.isNotEmpty) {
      for (int i = 0; i < rawChartList.length; i++) {
        final amt =
            (double.tryParse(rawChartList[i]['amount']?.toString() ?? '0') ??
                0) /
            1000;
        spots.add(FlSpot(i.toDouble(), amt));
        dates.add(rawChartList[i]['day']?.toString() ?? '');
        if (amt > maxAmt) maxAmt = amt;
      }
      maxAmt = (maxAmt * 1.25).clamp(40.0, 10000.0);
    } else {
      spots = defaultSpots;
      dates = defaultDates;
    }

    return _CardContainer(
      isDark: isDark,
      title: 'عمولات المنصة',
      actionText: 'عرض الكل',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row of 4 Stat Cards
          Row(
            children: [
              _CommStatCard(
                title: 'اليوم',
                titleColor: const Color(0xFF2563EB),
                value: '$todayVal ج',
                growthVal: todayGrowth,
                isDark: isDark,
              ),
              SizedBox(width: 8.w),
              _CommStatCard(
                title: 'الأسبوع',
                titleColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                value: '$weekVal ج',
                growthVal: weekGrowth,
                isDark: isDark,
              ),
              SizedBox(width: 8.w),
              _CommStatCard(
                title: 'الشهر',
                titleColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                value: '$monthVal ج',
                growthVal: monthGrowth,
                isDark: isDark,
              ),
              SizedBox(width: 8.w),
              _CommStatCard(
                title: 'إجمالي العمولات',
                titleColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                value: '$totalVal ج',
                growthVal: null,
                isDark: isDark,
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Sub-header + Period Filter Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                periodTitleText,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  setState(() {
                    _selectedCommPeriod = val;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                color: isDark ? const Color(0xFF1E1E38) : Colors.white,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getCommPeriodLabel(_selectedCommPeriod),
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 14.sp,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF475569),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: '7days',
                    child: Text('7 أيام', style: TextStyle(fontSize: 11)),
                  ),
                  const PopupMenuItem(
                    value: 'monthly',
                    child: Text('شهري', style: TextStyle(fontSize: 11)),
                  ),
                  const PopupMenuItem(
                    value: 'quarterly',
                    child: Text('ربع سنوي', style: TextStyle(fontSize: 11)),
                  ),
                  const PopupMenuItem(
                    value: 'semi_annual',
                    child: Text('نصف سنوي', style: TextStyle(fontSize: 11)),
                  ),
                  const PopupMenuItem(
                    value: 'yearly',
                    child: Text('سنوي', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Line Chart with Hover/Touch Tooltip & Overflow-Safe Axis Labels
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (spots.length - 1).toDouble().clamp(0.0, 100.0),
                  minY: 0,
                  maxY: maxAmt,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => isDark
                          ? const Color(0xFF1E1E38)
                          : const Color(0xFF0F172A),
                      tooltipRoundedRadius: 8.r,
                      tooltipPadding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.toInt();
                          final label = (idx >= 0 && idx < dates.length)
                              ? dates[idx]
                              : '';
                          final rawAmt = (idx >= 0 && idx < rawChartList.length)
                              ? (double.tryParse(
                                      rawChartList[idx]['amount']?.toString() ??
                                          '0',
                                    ) ??
                                    (spot.y * 1000))
                              : (spot.y * 1000);
                          final formattedAmt = rawAmt
                              .toStringAsFixed(0)
                              .replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]},',
                              );
                          return LineTooltipItem(
                            '$label\n$formattedAmt ج.م',
                            TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.sp,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxAmt / 4).clamp(1.0, 1000.0),
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34.w,
                        interval: (maxAmt / 4).clamp(1.0, 1000.0),
                        getTitlesWidget: (val, meta) {
                          final v = val.toInt();
                          if (v < 0) return const SizedBox.shrink();
                          return Text(
                            '${v}K',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32.h,
                        interval: (spots.length <= 7)
                            ? 1.0
                            : (spots.length > 12
                                  ? (spots.length / 6).roundToDouble()
                                  : 1.0),
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < dates.length) {
                            final labelText = dates[idx];
                            return SideTitleWidget(
                              meta: meta,
                              space: 4.h,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: dates.length > 8 ? 32.w : 48.w,
                                ),
                                child: Text(
                                  labelText,
                                  style: TextStyle(
                                    fontSize: dates.length > 8 ? 7.5.sp : 9.sp,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: const Color(0xFF2563EB),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: spots.length <= 12,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3.5,
                            color: const Color(0xFF2563EB),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF2563EB).withValues(alpha: 0.25),
                            const Color(0xFF2563EB).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCommPeriodLabel(String period) {
    switch (period) {
      case 'monthly':
        return 'شهري';
      case 'quarterly':
        return 'ربع سنوي';
      case 'semi_annual':
        return 'نصف سنوي';
      case 'yearly':
        return 'سنوي';
      case '7days':
      default:
        return '7 أيام';
    }
  }

  // ── 8. Panel: Withdrawal Requests ──────────────────────────────────────────
  Widget _buildWithdrawalRequestsCard(DashboardState state, bool isDark) {
    final ws = state.withdrawalSummary ?? {};
    final newCount = ws['new'] ?? 0;
    final underReviewCount = ws['underReview'] ?? 0;
    final transferredCount = ws['transferred'] ?? 0;
    final rejectedCount = ws['rejected'] ?? 0;
    final totalAmount = ws['totalAmount'] ?? 0;

    final amountFormatted = NumberFormat('#,###').format(totalAmount);

    return _CardContainer(
      isDark: isDark,
      title: 'طلبات السحب',
      actionText: 'عرض الكل',
      onAction: () =>
          context.read<NavigationCubit>().navigateTo(AppPage.withdrawals),
      child: Column(
        children: [
          // 2x2 Grid Cards
          Row(
            children: [
              _WithdrawalStatItem(
                label: 'جديدة',
                count: newCount,
                labelColor: const Color(0xFF2563EB),
                countColor: const Color(0xFF2563EB),
                isDark: isDark,
              ),
              SizedBox(width: 8.w),
              _WithdrawalStatItem(
                label: 'تحت المراجعة',
                count: underReviewCount,
                labelColor: const Color(0xFFD97706),
                countColor: isDark ? Colors.white : const Color(0xFF0F172A),
                isDark: isDark,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _WithdrawalStatItem(
                label: 'تم التحويل',
                count: transferredCount,
                labelColor: const Color(0xFF16A34A),
                countColor: isDark ? Colors.white : const Color(0xFF0F172A),
                isDark: isDark,
              ),
              SizedBox(width: 8.w),
              _WithdrawalStatItem(
                label: 'مرفوضة',
                count: rejectedCount,
                labelColor: const Color(0xFFDC2626),
                countColor: isDark ? Colors.white : const Color(0xFF0F172A),
                isDark: isDark,
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Total Amounts Box
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E38) : Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'إجمالي المبالغ',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$amountFormatted ج',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Full Width Outlined Button: "عرض جميع الطلبات" with External Icon
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.read<NavigationCubit>().navigateTo(
                AppPage.withdrawals,
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF93C5FD),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'عرض جميع الطلبات',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 13.sp,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 9. Panel: Top Captains ─────────────────────────────────────────────────
  Widget _buildTopCaptainsCard(DashboardState state, bool isDark) {
    final topCaptains = state.topCaptains ?? [];

    return _CardContainer(
      isDark: isDark,
      title: 'أفضل الكباتن',
      actionText: 'عرض الكل',
      onAction: () =>
          context.read<NavigationCubit>().navigateTo(AppPage.captains),
      child: Column(
        children: [
          // Table Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            child: Row(
              children: [
                SizedBox(
                  width: 22.w,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  flex: 3,
                  child: Text(
                    'الكابتن',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الطلبات',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'نسبة النجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'التقييم',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          SizedBox(height: 4.h),

          // Rows
          topCaptains.isEmpty
              ? Expanded(
                  child: Center(
                    child: Text(
                      'لا يوجد كباتن حالياً',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    ),
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: topCaptains.take(5).length,
                    itemBuilder: (context, index) {
                      final c = topCaptains[index];
                      final rank = c['rank'] ?? (index + 1);
                      final name = c['name']?.toString() ?? 'كابتن';
                      final profileImg = c['profileImage']?.toString() ?? '';
                      final ordersCount = c['ordersCount'] ?? 0;
                      final successRate = c['successRate'] ?? 95;
                      final rating = c['rating'] ?? 4.8;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 6.h,
                        ),
                        child: Row(
                          children: [
                            // Rank Badge (Blue Circle)
                            Container(
                              width: 20.w,
                              height: 20.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 6.w),

                            // Captain Info (Avatar + Name)
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12.r,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    backgroundImage: profileImg.isNotEmpty
                                        ? NetworkImage(
                                            EndPoint.getCleanImageUrl(
                                              profileImg,
                                            ),
                                          )
                                        : null,
                                    child: profileImg.isEmpty
                                        ? Icon(
                                            Icons.person,
                                            size: 14.sp,
                                            color: const Color(0xFF64748B),
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: 6.w),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Orders Count
                            Expanded(
                              flex: 2,
                              child: Text(
                                NumberFormat('#,###').format(ordersCount),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ),

                            // Success Rate
                            Expanded(
                              flex: 2,
                              child: Text(
                                '$successRate%',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ),

                            // Rating
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: const Color(0xFFF59E0B),
                                    size: 14.sp,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    '$rating',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  // ── 10. Panel: Latest Orders and Shipments ──────────────────────────────────
  Widget _buildLatestOrdersShipmentsCard(DashboardState state, bool isDark) {
    final orders = (state.todayOrders ?? []).take(5).toList();

    return _CardContainer(
      isDark: isDark,
      title: 'آخر الطلبات والشحنات',
      actionText: 'عرض الكل',
      onAction: () => context.read<NavigationCubit>().navigateTo(
        AppPage.allOrdersShipments,
      ),
      child: Column(
        children: [
          // Table Header Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            child: Row(
              children: [
                SizedBox(
                  width: 18.w,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'رقم الطلب',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'العميل / التاجر',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'المنطقة',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'الحالة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الوقت',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          SizedBox(height: 4.h),

          // Rows
          orders.isEmpty
              ? Expanded(
                  child: Center(
                    child: Text(
                      'لا توجد طلبات حديثة',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    ),
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final o = orders[index];
                      final num =
                          o['orderNumber']?.toString() ??
                          o['shipmentNumber']?.toString() ??
                          '${index + 12675}';
                      final merchant =
                          o['merchantName']?.toString() ??
                          o['storeDescription']?.toString();
                      final client = o['clientName']?.toString();
                      final personName =
                          (merchant != null && merchant.isNotEmpty)
                          ? merchant
                          : ((client != null && client.isNotEmpty)
                                ? client
                                : 'عميل/تاجر');
                      final area =
                          o['fromArea']?.toString() ??
                          o['toArea']?.toString() ??
                          _extractArea(o['deliveryAddress']?.toString());
                      final status = o['status']?.toString() ?? 'جديد';
                      final createdAtStr = o['createdAt']?.toString();
                      final timeStr = _formatTimeOnly(createdAtStr);

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 6.h,
                        ),
                        child: Row(
                          children: [
                            // Index
                            SizedBox(
                              width: 18.w,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),

                            // Order Number (#12679)
                            Expanded(
                              flex: 2,
                              child: Text(
                                '#$num',
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),

                            // Merchant / Client Name
                            Expanded(
                              flex: 3,
                              child: Text(
                                personName,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Area Name
                            Expanded(
                              flex: 2,
                              child: Text(
                                area,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Status Badge
                            Expanded(
                              flex: 3,
                              child: Center(
                                child: _OrderStatusBadge(
                                  status: status,
                                  isDark: isDark,
                                ),
                              ),
                            ),

                            // Time
                            Expanded(
                              flex: 2,
                              child: Text(
                                timeStr,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  // ── 11. Panel: Today Trips ─────────────────────────────────────────────────
  Widget _buildTodayTripsCard(DashboardState state, bool isDark) {
    final trips = state.todayTrips ?? [];

    return _CardContainer(
      isDark: isDark,
      title: 'الرحلات مع الكباتن اليوم',
      actionText: 'عرض الكل',
      onAction: () =>
          context.read<NavigationCubit>().navigateTo(AppPage.todayTrips),
      child: Column(
        children: [
          // Table Headers Row
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'الكابتن',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'الرحلة',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'عدد الشحنات',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الحالة',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(height: 6.h),

          if (trips.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              child: Center(
                child: Text(
                  'لا توجد رحلات كباتن اليوم',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                ),
              ),
            )
          else
            ...trips.take(5).map((t) {
              final captain = t['captainName']?.toString() ?? 'كابتن';
              final rawImg = t['profileImage']?.toString();
              final profileImg = EndPoint.getCleanImageUrl(rawImg);
              final fromLoc = t['fromArea'] ?? t['fromAddress'] ?? 'العجمي';
              final toLoc = t['toArea'] ?? t['toAddress'] ?? 'المنتزه';
              final routeText = '$fromLoc ↔ $toLoc';
              final shipmentsCount =
                  t['shipmentsCount'] ?? (t['assignedItems']?.length ?? 2);
              final statusText =
                  t['effectiveStatus'] ?? t['status'] ?? 'في الطريق';

              return InkWell(
                onTap: () => _showTripDetailsDialog(context, t),
                borderRadius: BorderRadius.circular(8.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Row(
                    children: [
                      // Captain Avatar + Name
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12.r,
                              backgroundColor: const Color(0xFFDBEAFE),
                              backgroundImage: (profileImg.isNotEmpty)
                                  ? NetworkImage(profileImg)
                                  : null,
                              child: (profileImg.isEmpty)
                                  ? Text(
                                      captain.isNotEmpty ? captain[0] : 'ك',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    )
                                  : null,
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                captain,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Route Waypoints
                      Expanded(
                        flex: 4,
                        child: Text(
                          routeText,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Shipments Count
                      Expanded(
                        flex: 2,
                        child: Text(
                          '$shipmentsCount',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Status Pill
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              statusText == 'completed'
                                  ? 'مكتملة'
                                  : (statusText == 'cancelled'
                                        ? 'ملغاة'
                                        : 'في الطريق'),
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: const Color(0xFF166534),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── 12. Panel: Active Captains Now ─────────────────────────────────────────
  Widget _buildActiveCaptainsNowCard(DashboardState state, bool isDark) {
    final ac = state.activeCaptainsNow ?? {};
    final count = ac['count'] ?? 128;
    final captains = (ac['captains'] as List<dynamic>?) ?? [];

    return _CardContainer(
      isDark: isDark,
      title: 'الكباتن النشطين الآن',
      actionText: 'عرض الكل',
      onAction: () =>
          context.read<NavigationCubit>().navigateTo(AppPage.captains),
      child: Column(
        children: [
          SizedBox(height: 6.h),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Text(
            'كابتن نشط الآن',
            style: TextStyle(
              fontSize: 11.sp,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),

          // Avatars Row with Green Online Dot
          SizedBox(
            height: 36.h,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (captains.isEmpty)
                    Text(
                      'لا يوجد كباتن نشطين حالياً',
                      style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                    )
                  else ...[
                    ...List.generate(captains.take(4).length, (idx) {
                      final c = captains[idx];
                      final rawImg = c['profileImage']?.toString();
                      final img = EndPoint.getCleanImageUrl(rawImg);
                      final name = c['name']?.toString() ?? 'كابتن';

                      return Padding(
                        padding: EdgeInsets.only(left: idx == 0 ? 0 : 4.w),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF14142B)
                                  : Colors.white,
                              width: 2.w,
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 14.r,
                                backgroundColor: const Color(0xFFDBEAFE),
                                backgroundImage: (img.isNotEmpty)
                                    ? NetworkImage(img)
                                    : null,
                                child: (img.isEmpty)
                                    ? Text(
                                        name.isNotEmpty ? name[0] : 'ك',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      )
                                    : null,
                              ),
                              // Green Online Dot
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 8.r,
                                  height: 8.r,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5.w,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (count > 4) ...[
                      SizedBox(width: 4.w),
                      CircleAvatar(
                        radius: 14.r,
                        backgroundColor: isDark
                            ? const Color(0xFF1E1E38)
                            : const Color(0xFFF1F5F9),
                        child: Text(
                          '+${count - 4}',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),

          // Full Width Outlined Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  context.read<NavigationCubit>().navigateTo(AppPage.captains),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF93C5FD),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'عرض جميع الكباتن',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTripDetailsDialog(BuildContext context, Map<String, dynamic> trip) {
    final captain = trip['captainName']?.toString() ?? 'الكابتن';
    final captainPhone = trip['captainPhone']?.toString() ?? '';
    final fromLoc = trip['fromArea'] ?? trip['fromAddress'] ?? 'العجمي';
    final toLoc = trip['toArea'] ?? trip['toAddress'] ?? 'المنتزه';
    final status = trip['effectiveStatus'] ?? trip['status'] ?? 'في الطريق';
    final items = (trip['assignedItems'] as List<dynamic>?) ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E38) : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.directions_car_rounded,
              color: const Color(0xFF2563EB),
              size: 20.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'تفاصيل رحلة $captain',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 450.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المسار: $fromLoc ↔ $toLoc',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            status == 'completed'
                                ? 'مكتملة'
                                : (status == 'cancelled'
                                      ? 'ملغاة'
                                      : 'في الطريق'),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: const Color(0xFF166534),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (captainPhone.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'الهاتف: $captainPhone',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'الشحنات والطلبات المسندة (${items.length}):',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              if (items.isEmpty)
                Padding(
                  padding: EdgeInsets.all(12.h),
                  child: Center(
                    child: Text(
                      'لا توجد شحنات معينة حالياً لهذه الرحلة',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (c, idx) {
                      final item = items[idx];
                      final num = item['number']?.toString() ?? '';
                      final title = item['title']?.toString() ?? 'طلب/شحنة';
                      final itemStatus =
                          item['status']?.toString() ?? 'جاري التوصيل';
                      final price = item['price']?.toString() ?? '0';

                      return Container(
                        margin: EdgeInsets.only(bottom: 6.h),
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '#$num',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(fontSize: 10.sp),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$price ج.م',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            _OrderStatusBadge(
                              status: itemStatus,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // ── Notification Dropdown Widget ───────────────────────────────────────────
  Widget _buildNotifDropdown(bool isTablet) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: _notifSlideAnim,
      child: FadeTransition(
        opacity: _notifAnimCtrl,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: isTablet ? 420.w : double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14142A) : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (ctx, notifState) {
                final notifs = notifState.notifications;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Row(
                        children: [
                          Text(
                            'الإشعارات',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                ctx.read<NotificationsCubit>().markAllAsRead(),
                            child: Text(
                              'تحديد الكل كقروء',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: notifs.isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد إشعارات',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: notifs.length,
                              itemBuilder: (ctx, idx) {
                                final item = notifs[idx];
                                return ListTile(
                                  title: Text(
                                    item['title']?.toString() ?? '',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item['body']?.toString() ?? '',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared Card Container Widget ─────────────────────────────────────────────
class _CardContainer extends StatelessWidget {
  final bool isDark;
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget child;

  const _CardContainer({
    required this.isDark,
    required this.title,
    this.actionText = 'عرض الكل',
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 345.h,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14142B) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actionText != null) ...[
                SizedBox(width: 4.w),
                OutlinedButton(
                  onPressed: onAction ?? () {},
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF93C5FD),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                  child: Text(
                    actionText!,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Small Components ─────────────────────────────────────────────────────────
class _TopCardData {
  final String title;
  final String value;
  final String growth;
  final String iconSvg;
  final Color color;

  _TopCardData({
    required this.title,
    required this.value,
    required this.growth,
    required this.iconSvg,
    required this.color,
  });
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(fontSize: 9.sp, color: Colors.grey),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _PieData {
  final String label;
  final int value;
  final Color color;

  _PieData(this.label, this.value, this.color);
}

class _CommStatCard extends StatelessWidget {
  final String title;
  final Color titleColor;
  final String value;
  final double? growthVal;
  final bool isDark;

  const _CommStatCard({
    required this.title,
    required this.titleColor,
    required this.value,
    this.growthVal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = (growthVal ?? 0) >= 0;
    final growthColor = isPositive
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final growthIcon = isPositive
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final growthText = growthVal != null
        ? (isPositive
              ? '+ ${growthVal!.toStringAsFixed(1)}%'
              : '${growthVal!.toStringAsFixed(1)}%')
        : null;

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E38) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10.sp,
                color: titleColor,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 3.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (growthText != null) ...[
              SizedBox(height: 2.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(growthIcon, color: growthColor, size: 10.sp),
                  SizedBox(width: 2.w),
                  Text(
                    growthText,
                    style: TextStyle(
                      fontSize: 8.sp,
                      color: growthColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _StatusBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9.sp, color: color),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalStatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color labelColor;
  final Color countColor;
  final bool isDark;

  const _WithdrawalStatItem({
    required this.label,
    required this.count,
    required this.labelColor,
    required this.countColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final countFormatted = NumberFormat('#,###').format(count);
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E38) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: labelColor,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                countFormatted,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: countColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LifecycleItemData {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  _LifecycleItemData(this.label, this.count, this.color, this.icon);
}

class _LifecycleBadge extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _LifecycleBadge({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? ((count / total) * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: EdgeInsets.all(5.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 14.sp),
          ),
          SizedBox(width: 6.w),
          // Title + Count + Percentage
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(
                      NumberFormat('#,###').format(count),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _getArabicStatus(String rawStatus) {
  final s = rawStatus.trim();
  final lower = s.toLowerCase();

  if (lower.contains('pending review') ||
      lower.contains('pending_review') ||
      lower.contains('قيد المراجعة') ||
      lower.contains('processing') ||
      lower.contains('preparing') ||
      lower.contains('بانتظار الدفع') ||
      lower.contains('قيد التفاوض')) {
    return 'قيد المراجعة';
  }
  if (lower.contains('ready for assignment') ||
      lower.contains('ready_for_assignment') ||
      lower.contains('بانتظار تعيين') ||
      lower.contains('في انتظار القبول') ||
      lower.contains('بانتظار القبول') ||
      lower.contains('pending_approval')) {
    return 'بانتظار تعيين مندوب';
  }
  if (lower.contains('assigned to captain') ||
      lower.contains('assigned_to_captain') ||
      lower.contains('تم تعيين') ||
      lower.contains('معينة لكابتن') ||
      lower.contains('assigned_captain')) {
    return 'تم تعيين مندوب';
  }
  if (lower.contains('picked up') ||
      lower.contains('picked_up') ||
      lower.contains('تم استلام') ||
      lower.contains('استلام')) {
    return 'تم استلام الشحنة';
  }
  if (lower.contains('in transit') ||
      lower.contains('in_transit') ||
      lower.contains('out_for_delivery') ||
      lower.contains('delivering') ||
      lower.contains('جاري') ||
      lower.contains('في الطريق')) {
    return 'جاري توصيل الشحنة';
  }
  if (lower == 'delivered' || lower.contains('تم التوصيل')) {
    return 'تم التوصيل';
  }
  if (lower == 'completed' ||
      lower.contains('مكتملة') ||
      lower.contains('مكتمل')) {
    return 'مكتملة';
  }
  if (lower == 'cancelled' ||
      lower.contains('ملغاة') ||
      lower.contains('ملغي') ||
      lower.contains('ملغى')) {
    return 'ملغاة';
  }
  if (lower.contains('delayed') ||
      lower.contains('expired') ||
      lower.contains('متأخر')) {
    return 'متأخرة';
  }
  if (lower == 'new' ||
      lower == 'جديد' ||
      lower == 'جديدة' ||
      lower == 'pending') {
    return 'جديد';
  }

  return s;
}

class _OrderStatusBadge extends StatelessWidget {
  final String status;
  final bool isDark;

  const _OrderStatusBadge({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final arabicText = _getArabicStatus(status);

    Color bg;
    Color fg;

    if (arabicText == 'جاري توصيل الشحنة' || arabicText == 'في الطريق') {
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF6D28D9);
    } else if (arabicText == 'تم استلام الشحنة' ||
        arabicText == 'تم التوصيل' ||
        arabicText == 'مكتملة') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (arabicText == 'قيد المراجعة' ||
        arabicText == 'جديد' ||
        arabicText == 'جديدة') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (arabicText == 'بانتظار تعيين مندوب' ||
        arabicText == 'تم تعيين مندوب') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    } else if (arabicText == 'ملغاة' || arabicText == 'متأخرة') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isDark ? fg.withValues(alpha: 0.18) : bg,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        arabicText,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.bold,
          color: isDark ? Color.lerp(fg, Colors.white, 0.4) : fg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

String _extractArea(String? address) {
  if (address == null || address.isEmpty) return 'الإسكندرية';
  final knownAreas = [
    'العجمي',
    'الدخيلة',
    'العامرية',
    'كرموز',
    'محطة مصر',
    'سموحة',
    'سيدي جابر',
    'ميامي',
    'المنتزه',
    'المعمورة',
    'فيكتوريا',
    'الورديان',
  ];
  for (final area in knownAreas) {
    if (address.contains(area)) return area;
  }
  final parts = address.split('،').where((p) => p.trim().isNotEmpty).toList();
  if (parts.isNotEmpty) return parts.last.trim();
  return 'الإسكندرية';
}

String _formatTimeOnly(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '10:15 ص';
  try {
    final dt = DateTime.parse(dateStr).toLocal();
    return DateFormat('h:mm a', 'ar').format(dt);
  } catch (_) {
    return '10:15 ص';
  }
}
