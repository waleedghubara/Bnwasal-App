// ignore_for_file: unnecessary_brace_in_string_interps, deprecated_member_use

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

class TodayTripsScreen extends StatefulWidget {
  const TodayTripsScreen({super.key});

  @override
  State<TodayTripsScreen> createState() => _TodayTripsScreenState();
}

class _TodayTripsScreenState extends State<TodayTripsScreen> {
  final Map<int, int> _tripOrders = {};
  final Map<int, int> _tripShipments = {};
  final Set<int> _loadingOrders = {};
  final Set<int> _loadingShipments = {};

  @override
  void initState() {
    super.initState();
    context.read<TripsCubit>().loadTodayTrips();
  }

  Future<void> _fetchTripOrders(int tripId) async {
    if (_tripOrders.containsKey(tripId) || _loadingOrders.contains(tripId)) {
      return;
    }
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
      if (mounted) {
        setState(() {
          _tripOrders[tripId] = items;
          _loadingOrders.remove(tripId);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders.remove(tripId));
    }
  }

  Future<void> _fetchTripShipments(int tripId) async {
    if (_tripShipments.containsKey(tripId) ||
        _loadingShipments.contains(tripId)) {
      return;
    }
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
      if (mounted) {
        setState(() {
          _tripShipments[tripId] = items;
          _loadingShipments.remove(tripId);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingShipments.remove(tripId));
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 900;
    return BlocBuilder<TripsCubit, TripsState>(
      builder: (context, state) {
        final active = state.trips
            .where((t) {
              final trip = t as Map<String, dynamic>;
              final dbStatus = trip['status'] as String? ?? '';
              final eff = trip['effectiveStatus'] as String? ?? dbStatus;

              // 1. Finished/Completed/Cancelled trips are never shown
              if (dbStatus == 'completed' ||
                  dbStatus == 'cancelled' ||
                  eff == 'completed' ||
                  eff == 'cancelled') {
                return false;
              }

              // 2. Active (in_progress) trips are always shown
              if (dbStatus == 'in_progress' || eff == 'in_progress') {
                return true;
              }

              // 3. Pending trips are shown only if their time has not ended (not expired)
              return eff != 'expired';
            })
            .cast<Map<String, dynamic>>()
            .toList();
        return Column(
          children: [
            _buildHeader(active.length, isWide),
            if (state.isLoading && state.trips.isEmpty)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.cyan),
                ),
              )
            else if (active.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.route_outlined,
                        size: 48.sp,
                        color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.15),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'لا يوجد رحلات نشطة اليوم',
                        style: TextStyle(
                          color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                          fontSize: 15.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: isWide
                    ? _buildTableView(active)
                    : _buildCardView(active),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int count, bool isWide) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return Container(
      padding: EdgeInsets.fromLTRB(
        isWide ? 32.w : 16.w,
        16.h,
        isWide ? 32.w : 16.w,
        12.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الرحلات اليومية',
                    style: TextStyle(
                      fontSize: isWide ? 22.sp : 18.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white.withOpacity(0.35) : Colors.black45,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF8b5cf6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trip_origin_rounded,
                      size: 10.sp,
                      color: const Color(0xFF8b5cf6),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF8b5cf6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            height: 1,
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  // ── Table View (wide screens) ──────────────────────────────────────────────

  static const _statusColors = <String, Color>{
    'pending': Color(0xFFf59e0b),
    'in_progress': Color(0xFF06b6d4),
    'completed': Color(0xFF10b981),
    'cancelled': Color(0xFFef4444),
    'expired': Color(0xFF6b7280),
  };
  static const _statusLabels = <String, String>{
    'pending': 'قيد الانتظار',
    'in_progress': 'جاري التنفيذ',
    'completed': 'منتهية',
    'cancelled': 'ملغية',
    'expired': 'منتهية',
  };

  Widget _buildTableView(List<Map<String, dynamic>> trips) {
    return SingleChildScrollView(
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
        ],
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
    final status =
        trip['effectiveStatus'] as String? ??
        trip['status'] as String? ??
        'pending';
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
              child: _td(_timeWithFallback(trip, 'departureTime', 'time')),
            ),
            Expanded(
              flex: 2,
              child: _td(_timeWithFallback(trip, 'arrivalTime', '')),
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

  // ── Card View (narrow screens) ─────────────────────────────────────────────

  Widget _buildCardView(List<Map<String, dynamic>> trips) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 32.h),
      itemCount: trips.length,
      itemBuilder: (_, i) => _buildCard(trips[i]),
    );
  }

  Widget _buildCard(Map<String, dynamic> trip) {
    final driverName = trip['captainName']?.toString() ?? '';
    final tripId = int.tryParse('${trip['id'] ?? ''}');
    final driverId = int.tryParse('${trip['driverId'] ?? ''}');
    final from = trip['fromAddress']?.toString() ?? '';
    final to = trip['toAddress']?.toString() ?? '';
    final date = _formatDateDDMMYYYY(trip['date']);
    final status =
        trip['effectiveStatus'] as String? ??
        trip['status'] as String? ??
        'pending';
    final price = trip['price'];
    final distance = trip['distance'];
    final depTime = _timeWithFallback(trip, 'departureTime', 'time');
    final arrTime = _timeWithFallback(trip, 'arrivalTime', '');

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
              driverName,
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
                          driverName,
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
                      captainName: driverName,
                      driverId: driverId,
                    ),
                    SizedBox(width: 6.w),
                    _shipmentsBadge(
                      tripId,
                      captainName: driverName,
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
              _routeCell(from, to),
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
                      depTime.isNotEmpty ? 'البداية: $depTime' : '—',
                    ),
                    SizedBox(width: 6.w),
                    _metaChip(
                      Icons.timer_outlined,
                      arrTime.isNotEmpty ? 'النهاية: $arrTime' : '—',
                    ),
                    SizedBox(width: 6.w),
                    _metaChip(Icons.calendar_today_rounded, date),
                    if (price != null) ...[
                      SizedBox(width: 6.w),
                      _metaChip(Icons.monetization_on_outlined, '$price ج.م'),
                    ],
                    if (distance != null) ...[
                      SizedBox(width: 6.w),
                      _metaChip(Icons.straighten_rounded, '${distance} كم'),
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

  // ── Shared helpers ─────────────────────────────────────────────────────────

  String _timeWithFallback(
    Map<String, dynamic> trip,
    String key,
    String fallbackKey,
  ) {
    var raw = trip[key];
    if (raw != null && raw.toString().isNotEmpty) {
      return _formatTime(raw.toString());
    }
    raw = trip[fallbackKey];
    if (raw != null && raw.toString().isNotEmpty) {
      return _formatTime(raw.toString());
    }
    return '';
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

  Widget _td(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.sp,
          color: isDark ? Colors.white.withOpacity(0.6) : Colors.black87,
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
