// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart' as di;
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import '../cubit/trips_cubit.dart';
import '../cubit/trips_state.dart';
import 'captain_items_sheet.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({super.key});

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  final _searchCtrl = TextEditingController();
  final Map<int, int> _tripOrders = {};
  final Map<int, int> _tripShipments = {};
  final Set<int> _loadingOrders = {};
  final Set<int> _loadingShipments = {};

  static const _statusLabels = <String, String>{
    'pending': 'قيد الانتظار',
    'in_progress': 'جاري التنفيذ',
    'completed': 'منتهية',
    'cancelled': 'ملغية',
    'expired': 'منتهية',
  };
  static const _statusColors = <String, Color>{
    'pending': Color(0xFF9ca3af),
    'in_progress': Color(0xFFf59e0b),
    'completed': Color(0xFF10b981),
    'cancelled': Color(0xFFef4444),
    'expired': Color(0xFF6b7280),
  };

  @override
  void initState() {
    super.initState();
    final cubit = context.read<TripsCubit>();
    cubit.filterByDate('');
  }

  Future<void> _fetchTripOrders(int tripId) async {
    if (_tripOrders.containsKey(tripId) || _loadingOrders.contains(tripId))
      return;
    _loadingOrders.add(tripId);
    try {
      final dio = di.sl<DioConsumer>();
      final res = await dio.get(
        EndPoint.getOrders,
        queryParameters: {'tripId': tripId.toString()},
      );
      final items =
          ((res as Map<String, dynamic>?)?['data'] as List<dynamic>?)?.length ??
          0;
      if (mounted)
        setState(() {
          _tripOrders[tripId] = items;
          _loadingOrders.remove(tripId);
        });
    } catch (_) {
      if (mounted) setState(() => _loadingOrders.remove(tripId));
    }
  }

  Future<void> _fetchTripShipments(int tripId) async {
    if (_tripShipments.containsKey(tripId) ||
        _loadingShipments.contains(tripId))
      return;
    _loadingShipments.add(tripId);
    try {
      final dio = di.sl<DioConsumer>();
      final res = await dio.get(
        EndPoint.getShipments,
        queryParameters: {'tripId': tripId.toString()},
      );
      final items =
          ((res as Map<String, dynamic>?)?['data'] as List<dynamic>?)?.length ??
          0;
      if (mounted)
        setState(() {
          _tripShipments[tripId] = items;
          _loadingShipments.remove(tripId);
        });
    } catch (_) {
      if (mounted) setState(() => _loadingShipments.remove(tripId));
    }
  }

  String _statusOf(Map<String, dynamic> trip) {
    return trip['effectiveStatus'] as String? ??
        trip['status'] as String? ??
        'pending';
  }

  Widget _countBadge({
    required int tripId,
    required Map<int, int> cache,
    required Set<int> loading,
    required Future<void> Function(int) fetch,
    required IconData icon,
    required Color color,
    required void Function() onTap,
  }) {
    final count = cache[tripId];
    final isLoading = loading.contains(tripId);
    if (count == null && !isLoading) fetch(tripId);
    return GestureDetector(
      onTap: count != null ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: isLoading
            ? SizedBox(
                width: 14.w,
                height: 14.w,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12.sp, color: color),
                  SizedBox(width: 4.w),
                  Text(
                    '${count ?? 0}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _ordersBadge(int tripId, {String? captainName, int? driverId}) {
    return _countBadge(
      tripId: tripId,
      cache: _tripOrders,
      loading: _loadingOrders,
      fetch: _fetchTripOrders,
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFFf59e0b),
      onTap: () => showCaptainItemsSheet(
        context,
        captainName ?? '',
        driverId ?? 0,
        filter: CaptainItemsFilter.orders,
        tripId: tripId,
      ),
    );
  }

  Widget _shipmentsBadge(int tripId, {String? captainName, int? driverId}) {
    return _countBadge(
      tripId: tripId,
      cache: _tripShipments,
      loading: _loadingShipments,
      fetch: _fetchTripShipments,
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFF06b6d4),
      onTap: () => showCaptainItemsSheet(
        context,
        captainName ?? '',
        driverId ?? 0,
        filter: CaptainItemsFilter.shipments,
        tripId: tripId,
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return BlocBuilder<TripsCubit, TripsState>(
      builder: (context, state) {
        return Column(
          children: [
            _buildHeader(state, isWide),
            if (state.error != null)
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  'خطأ في تحميل البيانات',
                  style: TextStyle(color: Colors.red.shade300, fontSize: 13.sp),
                ),
              ),
            Expanded(child: _buildList(state, isWide)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(TripsState state, bool isWide) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isWide ? 32.w : 16.w,
        16.h,
        isWide ? 32.w : 16.w,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'الرحلات',
                style: TextStyle(
                  fontSize: isWide ? 22.sp : 18.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF8b5cf6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${state.total}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF8b5cf6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => context.read<TripsCubit>().search(v),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: 'بحث عن كابتن...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black38,
                        fontSize: 14.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                        size: 20.sp,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: isDark
                            ? BorderSide.none
                            : BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: isDark
                            ? BorderSide.none
                            : BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              _filterChip(
                icon: Icons.calendar_today_rounded,
                label:
                    state.dateFromFilter.isNotEmpty &&
                        state.dateToFilter.isNotEmpty
                    ? '${state.dateFromFilter.split('-').reversed.join('/')} - ${state.dateToFilter.split('-').reversed.join('/')}'
                    : (state.dateFilter.isNotEmpty
                          ? state.dateFilter.split('-').reversed.join('/')
                          : 'التاريخ'),
                active:
                    state.dateFilter.isNotEmpty ||
                    state.dateFromFilter.isNotEmpty,
                onTap: () => _pickDateRange(state),
                onClear:
                    state.dateFilter.isNotEmpty ||
                        state.dateFromFilter.isNotEmpty
                    ? () {
                        context.read<TripsCubit>().filterByDate('');
                      }
                    : null,
              ),
              SizedBox(width: 8.w),
              _statusDropdown(state),
            ],
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: active
            ? AppColors.secondary.withOpacity(0.12)
            : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? AppColors.secondary.withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300),
        ),
        boxShadow: active
            ? null
            : (isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 14.sp,
                    color: active
                        ? AppColors.secondary
                        : (isDark ? Colors.white.withOpacity(0.5) : Colors.black45),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: active
                          ? AppColors.secondary
                          : (isDark ? Colors.white.withOpacity(0.5) : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onClear != null) ...[
            SizedBox(width: 2.w),
            InkWell(
              onTap: onClear,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 2.w),
                child: Icon(
                  Icons.close_rounded,
                  size: 14.sp,
                  color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusDropdown(TripsState state) {
    final statuses = {
      '': 'الكل',
      'pending': 'قيد الانتظار',
      'in_progress': 'جاري التنفيذ',
      'completed': 'منتهية',
      'cancelled': 'ملغية',
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: state.statusFilter.isNotEmpty
            ? AppColors.secondary.withOpacity(0.12)
            : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state.statusFilter.isNotEmpty
              ? AppColors.secondary.withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300),
        ),
        boxShadow: state.statusFilter.isNotEmpty
            ? null
            : (isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.statusFilter,
          dropdownColor: isDark ? const Color(0xFF1a1a3e) : Colors.white,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
            size: 18.sp,
          ),
          style: TextStyle(
            fontSize: 12.sp,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onChanged: (v) => context.read<TripsCubit>().filterByStatus(v ?? ''),
          items: statuses.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white.withOpacity(0.7) : Colors.black87,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _pickDateRange(TripsState state) async {
    final DateTime? initialFrom = state.dateFromFilter.isNotEmpty
        ? DateTime.parse(state.dateFromFilter)
        : null;
    final DateTime? initialTo = state.dateToFilter.isNotEmpty
        ? DateTime.parse(state.dateToFilter)
        : null;

    final Map<String, DateTime?>? result =
        await showDialog<Map<String, DateTime?>>(
          context: context,
          builder: (BuildContext context) {
            return _CustomDateRangeDialog(
              initialDateFrom: initialFrom,
              initialDateTo: initialTo,
            );
          },
        );

    if (result != null) {
      final from = result['dateFrom'];
      final to = result['dateTo'];
      if (from != null && to != null) {
        final fromStr =
            '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
        final toStr =
            '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';
        context.read<TripsCubit>().filterByDateRange(fromStr, toStr);
      } else {
        context.read<TripsCubit>().filterByDate('');
      }
    }
  }

  Widget _buildList(TripsState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (state.isLoading && state.trips.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }
    if (state.trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 48.sp,
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
            ),
            SizedBox(height: 12.h),
            Text(
              'لا توجد رحلات',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                fontSize: 15.sp,
              ),
            ),
          ],
        ),
      );
    }
    if (isWide) return _buildTableView(state);
    return _buildCardView(state);
  }

  Widget _buildCardView(TripsState state) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
          if (!state.isLoading && state.trips.length < state.total) {
            context.read<TripsCubit>().loadMore();
          }
        }
        return false;
      },
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: state.trips.length + (state.isLoading ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= state.trips.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.cyan,
                ),
              ),
            );
          }
          return _buildCard(state.trips[i] as Map<String, dynamic>, state);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> trip, TripsState state) {
    final captainName = trip['captainName']?.toString() ?? '';
    final tripId = int.tryParse('${trip['id'] ?? ''}');
    final driverId = int.tryParse('${trip['driverId'] ?? ''}');
    final fromAddr = trip['fromAddress']?.toString() ?? '';
    final toAddr = trip['toAddress']?.toString() ?? '';
    final depTime =
        trip['departureTime']?.toString() ?? trip['time']?.toString() ?? '';
    final arrTime = trip['arrivalTime']?.toString() ?? '';
    final date = _formatDateDDMMYYYY(trip['date']);
    final status = _statusOf(trip);
    final statusColor = _statusColors[status] ?? Colors.white.withOpacity(0.4);
    final statusLabel = _statusLabels[status] ?? status;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: _HoverCardWrapper(
        onTap: () {
          if (tripId != null && driverId != null) {
            showCaptainItemsSheet(
              context,
              captainName,
              driverId,
              filter: CaptainItemsFilter.all,
              tripId: tripId,
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 16.sp,
                      color: AppColors.secondary,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          captainName,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '#${trip['id'] ?? ''}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark ? Colors.white.withOpacity(0.35) : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tripId != null && driverId != null) ...[
                    _ordersBadge(
                      tripId,
                      captainName: captainName,
                      driverId: driverId,
                    ),
                    SizedBox(width: 6.w),
                    _shipmentsBadge(
                      tripId,
                      captainName: captainName,
                      driverId: driverId,
                    ),
                    SizedBox(width: 10.w),
                  ],
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              _routeCell(fromAddr, toAddr),
              if (trip['passingCities'] != null &&
                  trip['passingCities'].toString().trim().isNotEmpty) ...[
                SizedBox(height: 6.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    'خط السير: ${trip['passingCities']}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.secondary.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              SizedBox(height: 12.h),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _metaChip(
                      Icons.access_time_rounded,
                      depTime.isNotEmpty
                          ? 'البداية: ${_formatTime(depTime)}'
                          : '—',
                    ),
                    SizedBox(width: 6.w),
                    _metaChip(
                      Icons.timer_outlined,
                      arrTime.isNotEmpty
                          ? 'النهاية: ${_formatTime(arrTime)}'
                          : '—',
                    ),
                    SizedBox(width: 6.w),
                    _metaChip(Icons.calendar_today_rounded, date),
                    if (trip['price'] != null) ...[
                      SizedBox(width: 6.w),
                      _metaChip(
                        Icons.monetization_on_outlined,
                        '${trip['price']} ج.م',
                      ),
                    ],
                    if (trip['distance'] != null) ...[
                      SizedBox(width: 6.w),
                      _metaChip(
                        Icons.straighten_rounded,
                        '${trip['distance']} كم',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: isDark ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11.sp,
            color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
          ),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView(TripsState state) {
    final trips = _applyFilters(state);
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 48.sp,
              color: Colors.white.withOpacity(0.1),
            ),
            SizedBox(height: 12.h),
            Text(
              'لا توجد رحلات',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 15.sp,
              ),
            ),
          ],
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
          if (!state.isLoading && state.trips.length < state.total) {
            context.read<TripsCubit>().loadMore();
          }
        }
        return false;
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(32.w, 0, 32.w, 32.h),
        child: Column(
          children: [
            _buildTableHeader(),
            SizedBox(height: 10.h),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trips.length,
              itemBuilder: (context, i) {
                final trip = trips[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: _buildTableRowCard(trip, i),
                );
              },
            ),
            if (state.isLoading && state.trips.length < state.total)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.cyan),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e1e3a) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: _th('#')),
          Expanded(flex: 3, child: _th('المندوب')),
          Expanded(flex: 4, child: _th('خط السير')),
          Expanded(flex: 2, child: _th('التاريخ')),
          Expanded(flex: 2, child: _th('البداية')),
          Expanded(flex: 2, child: _th('النهاية')),
          Expanded(flex: 2, child: _th('الطلبات')),
          Expanded(flex: 2, child: _th('الشحنات')),
          Expanded(flex: 2, child: _th('الحالة')),
        ],
      ),
    );
  }

  Widget _buildTableRowCard(Map<String, dynamic> trip, int index) {
    final status = _statusOf(trip);
    final tripId = int.tryParse('${trip['id'] ?? ''}');
    final driverId = int.tryParse('${trip['driverId'] ?? ''}');
    final captainName = trip['captainName']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _HoverCardWrapper(
      onTap: () {
        if (tripId != null && driverId != null) {
          showCaptainItemsSheet(
            context,
            captainName,
            driverId,
            filter: CaptainItemsFilter.all,
            tripId: tripId,
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
        child: Row(
          children: [
            Expanded(flex: 1, child: _td('${trip['id'] ?? ''}')),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 14.sp,
                      color: AppColors.secondary,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      captainName,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _routeCell(
                    trip['fromAddress']?.toString() ?? '',
                    trip['toAddress']?.toString() ?? '',
                  ),
                  if (trip['passingCities'] != null &&
                      trip['passingCities'].toString().trim().isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: Text(
                        'خط السير: ${trip['passingCities']}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppColors.secondary.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(flex: 2, child: _td(_formatDateDDMMYYYY(trip['date']))),
            Expanded(
              flex: 2,
              child: _td(
                _formatTime(
                  trip['departureTime']?.toString() ??
                      trip['time']?.toString() ??
                      '',
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: _td(_formatTime(trip['arrivalTime']?.toString() ?? '')),
            ),
            Expanded(
              flex: 2,
              child: _badgeCell(
                tripId,
                driverId: driverId,
                captainName: captainName,
                isOrders: true,
              ),
            ),
            Expanded(
              flex: 2,
              child: _badgeCell(
                tripId,
                driverId: driverId,
                captainName: captainName,
                isOrders: false,
              ),
            ),
            Expanded(flex: 2, child: _statusCell(status)),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(TripsState state) {
    return state.trips.cast<Map<String, dynamic>>().toList();
  }

  String _formatDateDDMMYYYY(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString().split('T')[0];
    if (s.length < 10) return s;
    try {
      final parts = s.split('-');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    } catch (_) {
      return s;
    }
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    if (raw.contains('T')) {
      final parts = raw.split('T');
      if (parts.length >= 2) {
        final timeParts = parts[1].split(':');
        if (timeParts.length >= 2) return '${timeParts[0]}:${timeParts[1]}';
      }
    }
    final parts = raw.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return raw;
  }

  Widget _th(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white.withOpacity(0.75) : Colors.black87,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _td(String text, {bool bold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: bold ? FontWeight.w600 : null,
          color: isDark
              ? Colors.white.withOpacity(bold ? 0.85 : 0.6)
              : Colors.black.withOpacity(bold ? 0.85 : 0.7),
        ),
      ),
    );
  }

  Widget _routeCell(String from, String to) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 6.sp, color: AppColors.secondary),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                from.isNotEmpty ? from : 'غير محدد',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark ? Colors.white.withOpacity(0.65) : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            Icon(Icons.place_rounded, size: 10.sp, color: AppColors.primary),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                to.isNotEmpty ? to : 'غير محدد',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark ? Colors.white.withOpacity(0.65) : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badgeCell(
    int? tripId, {
    int? driverId,
    String captainName = '',
    required bool isOrders,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: tripId != null && driverId != null
          ? (isOrders
                ? _ordersBadge(
                    tripId,
                    captainName: captainName,
                    driverId: driverId,
                  )
                : _shipmentsBadge(
                    tripId,
                    captainName: captainName,
                    driverId: driverId,
                  ))
          : const SizedBox.shrink(),
    );
  }

  Widget _statusCell(String status) {
    final c = _statusColors[status] ?? Colors.white.withOpacity(0.4);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Text(
          _statusLabels[status] ?? status,
          style: TextStyle(
            fontSize: 12.sp,
            color: c,
            fontWeight: FontWeight.w700,
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? AppColors.secondary.withOpacity(0.4)
                  : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
              width: _isHovered ? 1.2 : 1.0,
            ),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      _isHovered
                          ? AppColors.secondary.withOpacity(0.06)
                          : Colors.white.withOpacity(0.025),
                      _isHovered
                          ? Colors.white.withOpacity(0.01)
                          : Colors.white.withOpacity(0.005),
                    ]
                  : [
                      _isHovered
                          ? AppColors.secondary.withOpacity(0.04)
                          : Colors.white,
                      _isHovered
                          ? Colors.white.withOpacity(0.95)
                          : Colors.white,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppColors.secondary.withOpacity(0.08)
                    : (isDark ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.02)),
                blurRadius: _isHovered ? 14 : 10,
                offset: _isHovered ? const Offset(0, 5) : const Offset(0, 3),
              ),
            ],
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

// نافذة تصفية التاريخ المخصصة والجميلة المتوافقة مع ألوان وهوية التطبيق
class _CustomDateRangeDialog extends StatefulWidget {
  final DateTime? initialDateFrom;
  final DateTime? initialDateTo;

  const _CustomDateRangeDialog({this.initialDateFrom, this.initialDateTo});

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog> {
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initialDateFrom;
    _dateTo = widget.initialDateTo;
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      switch (preset) {
        case 'today':
          _dateFrom = today;
          _dateTo = today;
          break;
        case 'yesterday':
          _dateFrom = today.subtract(const Duration(days: 1));
          _dateTo = today.subtract(const Duration(days: 1));
          break;
        case 'last7':
          _dateFrom = today.subtract(const Duration(days: 6));
          _dateTo = today;
          break;
        case 'last30':
          _dateFrom = today.subtract(const Duration(days: 29));
          _dateTo = today;
          break;
        case 'thisMonth':
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = today;
          break;
        case 'clear':
          _dateFrom = null;
          _dateTo = null;
          break;
      }
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final initialDate = isFrom
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.secondary,
                    onPrimary: Color(0xFF070715),
                    surface: Color(0xFF0d0d1f),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
            dialogBackgroundColor: isDark ? const Color(0xFF0d0d1f) : Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
          if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
            _dateTo = _dateFrom;
          }
        } else {
          _dateTo = picked;
          if (_dateFrom != null && _dateFrom!.isAfter(_dateTo!)) {
            _dateFrom = _dateTo;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedRange = _dateFrom == null
        ? 'لم يتم تحديد فترة زمنية بعد'
        : 'من  ${_dateFrom!.year}/${_dateFrom!.month}/${_dateFrom!.day}  إلى  ${_dateTo!.year}/${_dateTo!.month}/${_dateTo!.day}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0d0d1f) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300,
        ),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85 > 420
            ? 420
            : MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.secondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'تصفية حسب التاريخ',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Presets Label
            Text(
              'اختيار سريع:',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Preset Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _presetChip('اليوم', 'today'),
                _presetChip('أمس', 'yesterday'),
                _presetChip('آخر 7 أيام', 'last7'),
                _presetChip('آخر 30 يوم', 'last30'),
                _presetChip('هذا الشهر', 'thisMonth'),
              ],
            ),
            const SizedBox(height: 20),
            Divider(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300,
            ),
            const SizedBox(height: 15),

            // Custom Range Label
            Text(
              'أو حدد فترة مخصصة:',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Custom Range Selection Row
            Row(
              children: [
                Expanded(
                  child: _datePickerButton(
                    'من تاريخ',
                    _dateFrom,
                    () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _datePickerButton(
                    'إلى تاريخ',
                    _dateTo,
                    () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current selection indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: _dateFrom != null
                    ? AppColors.secondary.withOpacity(0.05)
                    : (isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dateFrom != null
                      ? AppColors.secondary.withOpacity(0.15)
                      : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
                ),
              ),
              child: Text(
                formattedRange,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _dateFrom != null
                      ? AppColors.secondary
                      : (isDark ? Colors.white60 : Colors.black54),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop({'dateFrom': _dateFrom, 'dateTo': _dateTo});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: const Color(0xFF070715),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'تطبيق التصفية',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Clear / Cancel Button
                if (_dateFrom != null || _dateTo != null) ...[
                  IconButton(
                    onPressed: () {
                      _setPreset('clear');
                    },
                    icon: const Icon(Icons.delete_sweep_rounded),
                    color: AppColors.error,
                    tooltip: 'مسح التصفية',
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white60 : Colors.black54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, String presetKey) {
    bool isSelected = false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_dateFrom != null && _dateTo != null) {
      if (presetKey == 'today') {
        isSelected = _dateFrom == today && _dateTo == today;
      } else if (presetKey == 'yesterday') {
        final yesterday = today.subtract(const Duration(days: 1));
        isSelected = _dateFrom == yesterday && _dateTo == yesterday;
      } else if (presetKey == 'last7') {
        isSelected =
            _dateFrom == today.subtract(const Duration(days: 6)) &&
            _dateTo == today;
      } else if (presetKey == 'last30') {
        isSelected =
            _dateFrom == today.subtract(const Duration(days: 29)) &&
            _dateTo == today;
      } else if (presetKey == 'thisMonth') {
        isSelected =
            _dateFrom == DateTime(now.year, now.month, 1) && _dateTo == today;
      }
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _setPreset(presetKey),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF070715)
                : (isDark ? Colors.white.withOpacity(0.7) : Colors.black87),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _datePickerButton(String label, DateTime? date, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? AppColors.secondary.withOpacity(0.4)
                : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: date != null ? AppColors.secondary : (isDark ? Colors.white38 : Colors.black38),
              size: 16,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  date != null
                      ? '${date.year}/${date.month}/${date.day}'
                      : 'حدد تاريخ',
                  style: TextStyle(
                    color: date != null ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white54 : Colors.black54),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
