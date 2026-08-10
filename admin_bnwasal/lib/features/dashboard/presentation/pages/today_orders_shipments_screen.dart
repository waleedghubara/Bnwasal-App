// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/utils/translation_helper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/typography.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import 'order_detail_screen.dart';
import 'shipment_detail_screen.dart';
import 'package:admin_bnwasal/core/services/notification_service.dart';

class TodayOrdersShipmentsScreen extends StatefulWidget {
  const TodayOrdersShipmentsScreen({super.key});

  @override
  State<TodayOrdersShipmentsScreen> createState() =>
      _TodayOrdersShipmentsScreenState();
}

class _TodayOrdersShipmentsScreenState extends State<TodayOrdersShipmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  bool _showNewOrderAlert = false;
  bool _isFlashOn = false;
  Timer? _flashTimer;
  int _flashCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    final cubit = context.read<DashboardCubit>();
    if (cubit.state.todayOrders == null) {
      cubit.loadDashboard();
    }
    _setupSocketListeners();
    // Periodic refresh every 30 seconds as fallback for missed socket events
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<DashboardCubit>().loadDashboard();
      }
    });
  }

  void _setupSocketListeners() {
    final ns = NotificationService();
    ns.addOrderCreatedListener(_onOrderCreated);
    ns.addOrderUpdatedListener(_onOrderUpdated);
    ns.addShipmentCreatedListener(_onShipmentCreated);
    ns.addShipmentUpdatedListener(_onShipmentUpdated);
  }

  void _triggerNewItemAlert() {
    _flashTimer?.cancel();
    setState(() {
      _showNewOrderAlert = true;
      _isFlashOn = true;
      _flashCount = 0;
    });

    _flashTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
        _flashCount++;
      });
      if (_flashCount >= 8) {
        // 8 toggles = 4 full flashes
        timer.cancel();
        setState(() {
          _showNewOrderAlert = false;
        });
      }
    });
  }

  void _onOrderCreated(Map<String, dynamic> order) {
    if (!mounted) return;
    context.read<DashboardCubit>().insertTodayOrder(order);
    _triggerNewItemAlert();
  }

  void _onOrderUpdated(Map<String, dynamic> order) {
    if (!mounted) return;
    context.read<DashboardCubit>().updateTodayOrder(order);
  }

  void _onShipmentCreated(Map<String, dynamic> shipment) {
    if (!mounted) return;
    context.read<DashboardCubit>().insertTodayShipment(shipment);
    _triggerNewItemAlert();
  }

  void _onShipmentUpdated(Map<String, dynamic> shipment) {
    if (!mounted) return;
    context.read<DashboardCubit>().updateTodayShipment(shipment);
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    final ns = NotificationService();
    ns.removeOrderCreatedListener(_onOrderCreated);
    ns.removeOrderUpdatedListener(_onOrderUpdated);
    ns.removeShipmentCreatedListener(_onShipmentCreated);
    ns.removeShipmentUpdatedListener(_onShipmentUpdated);
    _refreshTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    status = status.trim();
    if (status == 'بانتظار القبول' ||
        status == 'قيد الانتظار' ||
        status == 'جديدة' ||
        status == 'pending') {
      return AppColors.warning;
    } else if (status == 'تم قبول العرض' ||
        status == 'تم القبول' ||
        status == 'جاري التوصيل' ||
        status == 'جاري التنفيذ' ||
        status == 'تم التنفيذ' ||
        status == 'ongoing' ||
        status == 'in_progress') {
      return AppColors.info;
    } else if (status == 'منتهي' ||
        status == 'منتهية' ||
        status == 'تم التسليم' ||
        status == 'completed') {
      return AppColors.success;
    } else if (status == 'ملغي' ||
        status == 'ملغية' ||
        status == 'مرفوض' ||
        status == 'cancelled') {
      return AppColors.error;
    }
    return AppColors.secondary;
  }

  int getCount(List<dynamic> orders, List<dynamic> shipments, int tabIndex) {
    switch (tabIndex) {
      case 0:
        return countStatus(orders, shipments, ['Pending Review']);
      case 1:
        return countStatus(orders, shipments, ['Ready For Assignment']);
      case 2:
        return countStatus(orders, shipments, [
          'Assigned To Captain',
          'Captain Arrived',
        ]);
      case 3:
        return countStatus(orders, shipments, [
          'Picked Up',
          'In Transit',
          'Delivered',
        ]);
      case 4:
        return countStatus(orders, shipments, ['Completed']);
      case 5:
        return countStatus(orders, shipments, ['Cancelled', 'Rejected']);
      default:
        return 0;
    }
  }

  int countStatus(
    List<dynamic> orders,
    List<dynamic> shipments,
    List<String> statuses,
  ) {
    int oCount = orders.where((o) => statuses.contains(o['status'])).length;
    int sCount = shipments.where((s) => statuses.contains(s['status'])).length;
    return oCount + sCount;
  }

  List<dynamic> getFilteredItemsForTab(
    int tabIndex,
    List<dynamic> orders,
    List<dynamic> shipments,
  ) {
    List<dynamic> items = [];
    List<String> statuses;
    switch (tabIndex) {
      case 0:
        statuses = ['Pending Review'];
        break;
      case 1:
        statuses = ['Ready For Assignment'];
        break;
      case 2:
        statuses = ['Assigned To Captain', 'Captain Arrived'];
        break;
      case 3:
        statuses = ['Picked Up', 'In Transit', 'Delivered'];
        break;
      case 4:
        statuses = ['Completed'];
        break;
      case 5:
        statuses = ['Cancelled', 'Rejected'];
        break;
      default:
        statuses = [];
    }

    final tabOrders = orders
        .where((o) => statuses.contains(o['status']))
        .toList();
    final tabShipments = shipments
        .where((s) => statuses.contains(s['status']))
        .toList();

    final query = _searchQuery.toLowerCase().trim();
    if (query.isNotEmpty) {
      final filteredOrders = tabOrders.where((o) {
        final num = (o['orderNumber'] ?? '').toString().toLowerCase();
        final client = (o['clientName'] ?? '').toString().toLowerCase();
        final merchant = (o['merchantName'] ?? '').toString().toLowerCase();
        return num.contains(query) ||
            client.contains(query) ||
            merchant.contains(query);
      }).toList();

      final filteredShipments = tabShipments.where((s) {
        final num = (s['shipmentNumber'] ?? '').toString().toLowerCase();
        final title = (s['title'] ?? '').toString().toLowerCase();
        final merchant = (s['merchantName'] ?? '').toString().toLowerCase();
        return num.contains(query) ||
            title.contains(query) ||
            merchant.contains(query);
      }).toList();

      items.addAll(filteredOrders);
      items.addAll(filteredShipments);
    } else {
      items.addAll(tabOrders);
      items.addAll(tabShipments);
    }

    items.sort((a, b) {
      final dateA =
          DateTime.tryParse(a['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateB =
          DateTime.tryParse(b['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final orders = state.todayOrders ?? [];
        final shipments = state.todayShipments ?? [];

        return Stack(
          children: [
            Column(
              children: [
                _buildHeader(
                  orders.length + shipments.length,
                  orders.length,
                  shipments.length,
                  isWide,
                ),
                _buildStatsGrid(orders, shipments),
                _buildSearchBar(),
                if (state.isLoading && orders.isEmpty && shipments.isEmpty)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.secondary,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        _buildTabBar(orders, shipments),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: List.generate(6, (index) {
                              final items = getFilteredItemsForTab(
                                index,
                                orders,
                                shipments,
                              );
                              return _buildItemsList(items);
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            _buildFlashOverlay(),
            _buildNewItemToast(),
          ],
        );
      },
    );
  }

  Widget _buildFlashOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: _showNewOrderAlert
                  ? AppColors.secondary.withOpacity(_isFlashOn ? 0.7 : 0.1)
                  : Colors.transparent,
              width: 4.w,
            ),
            boxShadow: _showNewOrderAlert
                ? [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(
                        _isFlashOn ? 0.35 : 0.02,
                      ),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildNewItemToast() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      top: _showNewOrderAlert ? 16.h : -80.h,
      left: 16.w,
      right: 16.w,
      child: IgnorePointer(
        ignoring: !_showNewOrderAlert,
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.secondary, Color(0xFFff9800)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, color: Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'طلب / شحنة جديدة واردة الآن!',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    int total,
    int ordersCount,
    int shipmentsCount,
    bool isWide,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isWide ? 32.w : 16.w,
        20.h,
        isWide ? 32.w : 16.w,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلبات وشحنات اليوم',
                  style: TextStyle(
                    fontSize: isWide ? 22.sp : 18.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Manual refresh button
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
            ),
            child: Text(
              '$total',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
                color: AppColors.secondary,
              ),
            ),
          ),
          SizedBox(width: 5.w),
          GestureDetector(
            onTap: _isRefreshing
                ? null
                : () async {
                    setState(() => _isRefreshing = true);
                    await context.read<DashboardCubit>().loadDashboard();
                    if (mounted) setState(() => _isRefreshing = false);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              child: _isRefreshing
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.secondary,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 16.sp,
                      color: isDark
                          ? Colors.white.withOpacity(0.5)
                          : Colors.black.withOpacity(0.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  double _parsePrice(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Widget _buildStatsGrid(List<dynamic> orders, List<dynamic> shipments) {
    double totalRevenue = 0;
    for (var o in orders) {
      totalRevenue +=
          _parsePrice(o['deliveryFee']) + _parsePrice(o['orderPrice']);
    }
    for (var s in shipments) {
      totalRevenue += _parsePrice(s['price']);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 4.h),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'الالتحاق بالطلبات',
              orders.length.toString(),
              Icons.receipt_long_rounded,
              AppColors.secondary,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _buildStatCard(
              'الشحنات النشطة',
              shipments.length.toString(),
              Icons.local_shipping_rounded,
              AppColors.primary,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _buildStatCard(
              'الإيرادات الكلية',
              '${totalRevenue.toStringAsFixed(0)} ج',
              Icons.payments_rounded,
              AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.4)
                        : Colors.black,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 4.w),
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14.sp, color: color),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.primary,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          icon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white.withOpacity(0.3) : Colors.black,
            size: 20,
          ),
          hintText: 'البحث برقم الطلب، اسم العميل، أو التاجر...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.3) : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          border: InputBorder.none,
          fillColor: Colors.transparent,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
      ),
    );
  }

  Widget _buildTabBar(List<dynamic> orders, List<dynamic> shipments) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF005ce6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: isDark
            ? Colors.white.withOpacity(0.35)
            : Colors.black.withOpacity(0.35),
        labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(
          color: isDark ? Colors.white.withOpacity(0.35) : Colors.black,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: Colors.transparent,
        padding: EdgeInsets.all(4.w),
        tabs: [
          _buildTab(0, 'جديدة', orders, shipments),
          _buildTab(1, 'انتظار التوجيه', orders, shipments),
          _buildTab(2, 'معينة', orders, shipments),
          _buildTab(3, 'جارية', orders, shipments),
          _buildTab(4, 'مكتملة', orders, shipments),
          _buildTab(5, 'ملغاة', orders, shipments),
        ],
      ),
    );
  }

  Widget _buildTab(
    int index,
    String label,
    List<dynamic> orders,
    List<dynamic> shipments,
  ) {
    final count = getCount(orders, shipments, index);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.h5),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsList(List<dynamic> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (items.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.clipboardList,
                size: 64.sp,
                color: AppColors.primary,
              ),
              SizedBox(height: 12.h),
              Text(
                'لا يوجد عناصر في هذه الحالة حالياً',
                style: TextStyle(
                  color: isDark ? Colors.white.withOpacity(0.3) : Colors.black,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (_, i) {
        final item = items[i] as Map<String, dynamic>;
        return _buildItemStrip(item);
      },
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'م' : 'ص';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month} ${hour.toString().padLeft(2, '0')}:$minute $amPm';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildItemStrip(Map<String, dynamic> item) {
    final isOrder = item.containsKey('orderNumber');
    final number =
        (isOrder ? item['orderNumber'] : item['shipmentNumber'])?.toString() ??
        '';
    final title = isOrder
        ? 'طلب رقم $number'
        : (item['title'] != null && item['title'].toString().isNotEmpty
              ? item['title'].toString()
              : 'شحنة رقم $number');
    final merchant = item['merchantName']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final statusColor = _getStatusColor(status);
    final createdAt = item['createdAt']?.toString() ?? '';
    final timeStr = _formatTime(createdAt);

    // Assignee details
    final assigneeName = item['assignedAdminName']?.toString() ?? '';
    final hasAssignee = assigneeName.isNotEmpty;

    // Pricing
    String priceText = '';
    if (isOrder) {
      final orderPrice =
          double.tryParse((item['orderPrice'] ?? '0').toString()) ?? 0.0;
      final deliveryFee =
          double.tryParse((item['deliveryFee'] ?? '0').toString()) ?? 0.0;
      priceText =
          '${orderPrice.toStringAsFixed(0)} + ${deliveryFee.toStringAsFixed(0)} ج';
    } else {
      final price = double.tryParse((item['price'] ?? '0').toString()) ?? 0.0;
      priceText = '${price.toStringAsFixed(0)} ج';
    }

    // Route
    final String from = isOrder
        ? (merchant.isNotEmpty ? merchant : 'التاجر')
        : (item['fromAddress']?.toString() ?? '');
    final String to = isOrder
        ? (item['deliveryAddress']?.toString() ?? '')
        : (item['toAddress']?.toString() ?? '');

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _HoverCardWrapper(
      onTap: () => isOrder ? _openOrderDetail(item) : _openShipmentDetail(item),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: isWide
            ? Row(
                children: [
                  // 1. Type Icon
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: (isOrder ? AppColors.secondary : AppColors.primary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOrder
                          ? Icons.receipt_long_rounded
                          : Icons.local_shipping_rounded,
                      size: 20.sp,
                      color: isOrder ? AppColors.secondary : AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 16.w),

                  // 2. ID & Time
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark
                                ? Colors.white.withOpacity(0.3)
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Route (From -> To)
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            from,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Icon(
                            Icons.east_rounded,
                            size: 14.sp,
                            color: isDark
                                ? Colors.white.withOpacity(0.15)
                                : Colors.black,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            to,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Claimed Assignee Info
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (hasAssignee
                                      ? AppColors.primary
                                      : AppColors.warning)
                                  .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                (hasAssignee
                                        ? AppColors.primary
                                        : AppColors.warning)
                                    .withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasAssignee
                                  ? Icons.person_pin_rounded
                                  : Icons.warning_amber_rounded,
                              size: 12.sp,
                              color: hasAssignee
                                  ? AppColors.primary
                                  : AppColors.warning,
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                hasAssignee
                                    ? 'استلمها: $assigneeName'
                                    : 'غير مستلمة',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: hasAssignee
                                      ? AppColors.primary
                                      : AppColors.warning,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 5. Price Tag
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withOpacity(0.05)
                              : AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? AppColors.primary.withOpacity(0.15)
                                : AppColors.primary.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          priceText,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 6. Status Badge
                  _statusBadge(status, statusColor),
                  SizedBox(width: 8.w),

                  // Chevron icon
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14.sp,
                    color: isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color:
                              (isOrder
                                      ? AppColors.secondary
                                      : AppColors.primary)
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isOrder
                              ? Icons.receipt_long_rounded
                              : Icons.local_shipping_rounded,
                          size: 16.sp,
                          color: isOrder
                              ? AppColors.secondary
                              : AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _statusBadge(status, statusColor),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  // Route path
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 7.sp,
                        color: AppColors.secondary,
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          from,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.white.withOpacity(0.4)
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        child: Icon(
                          Icons.east_rounded,
                          size: 12.sp,
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black,
                        ),
                      ),
                      Icon(
                        Icons.place_rounded,
                        size: 12.sp,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          to,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.white.withOpacity(0.4)
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Claim status
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (hasAssignee
                                      ? AppColors.primary
                                      : AppColors.warning)
                                  .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                (hasAssignee
                                        ? AppColors.primary
                                        : AppColors.warning)
                                    .withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasAssignee
                                  ? Icons.person_pin_rounded
                                  : Icons.warning_amber_rounded,
                              size: 10.sp,
                              color: hasAssignee
                                  ? AppColors.primary
                                  : AppColors.warning,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              hasAssignee
                                  ? 'استلمها: $assigneeName'
                                  : 'غير مستلمة',
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: hasAssignee
                                    ? AppColors.primary
                                    : AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Price and Time
                      Row(
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.15),
                              ),
                            ),
                            child: Text(
                              priceText,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        TranslationHelper.getArabicStatus(status),
        style: TextStyle(
          fontSize: 10.sp,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _openOrderDetail(Map<String, dynamic> order) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => OrderDetailScreen(order: order),
        transitionsBuilder: (_, a, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _openShipmentDetail(Map<String, dynamic> ship) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ShipmentDetailScreen(shipment: ship),
        transitionsBuilder: (_, a, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

// ويدجت مخصصة لإضافة تأثير التحويم (Hover) الاحترافي والتكبير البسيط عند تمرير مؤشر الماوس
class _HoverCardWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HoverCardWrapper({required this.child, required this.onTap});

  @override
  State<_HoverCardWrapper> createState() => _HoverCardWrapperState();
}

class _HoverCardWrapperState extends State<_HoverCardWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withOpacity(0.5)
                  : isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.grey.shade300,
              width: _isHovered ? 1.5 : 1.0,
            ),
            gradient: LinearGradient(
              colors: [
                _isHovered
                    ? AppColors.primary.withOpacity(0.08)
                    : isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.white,
                _isHovered
                    ? Colors.white.withOpacity(0.01)
                    : isDark
                    ? Colors.white.withOpacity(0.005)
                    : Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
