import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart' as di;
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/utils/translation_helper.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/features/dashboard/presentation/pages/order_detail_screen.dart';
import 'package:admin_bnwasal/features/dashboard/presentation/pages/shipment_detail_screen.dart';

enum CaptainItemsFilter { all, orders, shipments }

Future<void> showCaptainItemsSheet(BuildContext context, String captainName, int captainId, {CaptainItemsFilter filter = CaptainItemsFilter.all, int? tripId}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF0a0a1a) : Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
    builder: (_) => _CaptainItemsSheet(captainName: captainName, captainId: captainId, initialFilter: filter, tripId: tripId),
  );
}

class _CaptainItemsSheet extends StatefulWidget {
  final String captainName;
  final int captainId;
  final CaptainItemsFilter initialFilter;
  final int? tripId;
  const _CaptainItemsSheet({required this.captainName, required this.captainId, this.initialFilter = CaptainItemsFilter.all, this.tripId});

  @override
  State<_CaptainItemsSheet> createState() => _CaptainItemsSheetState();
}

class _CaptainItemsSheetState extends State<_CaptainItemsSheet> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _shipments = [];
  bool _loading = true;
  String? _error;
  late CaptainItemsFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final dio = di.sl<DioConsumer>();
      final f = <String, Future<dynamic>>{};
      if (_filter == CaptainItemsFilter.all || _filter == CaptainItemsFilter.orders) {
        final q = <String, String>{};
        if (widget.tripId != null) {
          q['tripId'] = widget.tripId.toString();
        } else {
          q['captainId'] = widget.captainId.toString();
        }
        f['orders'] = dio.get(EndPoint.getOrders, queryParameters: q);
      }
      if (_filter == CaptainItemsFilter.all || _filter == CaptainItemsFilter.shipments) {
        final q = <String, String>{};
        if (widget.tripId != null) {
          q['tripId'] = widget.tripId.toString();
        } else {
          q['captainId'] = widget.captainId.toString();
        }
        f['shipments'] = dio.get(EndPoint.getShipments, queryParameters: q);
      }
      final results = await Future.wait(f.values);
      if (!mounted) return;
      final keys = f.keys.toList();
      setState(() {
        for (var i = 0; i < keys.length; i++) {
          final data = (results[i] as Map<String, dynamic>?)?['data'];
          if (keys[i] == 'orders') {
            _orders = (data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          } else if (keys[i] == 'shipments') {
            _shipments = (data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0d0d1f) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              Divider(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300,
                height: 1,
              ),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.cyan)))
              else if (_error != null)
                Expanded(child: Center(child: Text('خطأ: $_error', style: TextStyle(color: Colors.red.shade300, fontSize: 13.sp))))
              else
                Expanded(
                  child: _orders.isEmpty && _shipments.isEmpty
                      ? Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 48.sp,
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              _emptyMessage(),
                              style: TextStyle(
                                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                                fontSize: 15.sp,
                              ),
                            ),
                          ],
                        ))
                      : ListView(
                          controller: scrollController,
                          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
                          children: [
                            if (_orders.isNotEmpty) ...[
                              _sectionHeader(Icons.receipt_long_rounded, 'الطلبات (${_orders.length})', const Color(0xFFf59e0b)),
                              ..._orders.map((o) => _buildOrderItem(o)),
                              SizedBox(height: 12.h),
                            ],
                            if (_shipments.isNotEmpty) ...[
                              _sectionHeader(Icons.inventory_2_rounded, 'الشحنات (${_shipments.length})', const Color(0xFF06b6d4)),
                              ..._shipments.map((s) => _buildShipmentItem(s)),
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

  String _emptyMessage() {
    switch (_filter) {
      case CaptainItemsFilter.orders: return 'لا توجد طلبات لهذا المندوب في هذه الرحلة';
      case CaptainItemsFilter.shipments: return 'لا توجد شحنات لهذا المندوب في هذه الرحلة';
      case CaptainItemsFilter.all: return 'لا توجد طلبات أو شحنات لهذا المندوب في هذه الرحلة';
    }
  }

  Widget _buildHandle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(top: 10.h, bottom: 8.h),
      child: Container(
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.person_rounded, size: 18.sp, color: AppColors.secondary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.captainName,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'قائمة الشحنات والطلبات المسندة',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (!_loading)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: isDark ? null : Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                '${_orders.length + _shipments.length} عنصر',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white.withOpacity(0.7) : Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, top: 10.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? '';
    final number = order['orderNumber']?.toString() ?? '#---';
    final client = order['clientName']?.toString() ?? '';
    return _itemCard(
      icon: Icons.receipt_long_rounded,
      iconColor: const Color(0xFFf59e0b),
      title: number,
      subtitle: client,
      status: status,
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderDetailScreen(order: order),
        ));
      },
    );
  }

  Widget _buildShipmentItem(Map<String, dynamic> shipment) {
    final status = shipment['status']?.toString() ?? '';
    final number = shipment['shipmentNumber']?.toString() ?? '#---';
    final title = shipment['title']?.toString() ?? '';
    final from = shipment['fromAddress']?.toString() ?? '';
    final to = shipment['toAddress']?.toString() ?? '';
    final subtitle = title.isNotEmpty ? title : (from.isNotEmpty && to.isNotEmpty ? '$from ← $to' : '');
    return _itemCard(
      icon: Icons.inventory_2_rounded,
      iconColor: const Color(0xFF06b6d4),
      title: number,
      subtitle: subtitle,
      status: status,
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ShipmentDetailScreen(shipment: shipment),
        ));
      },
    );
  }

  Widget _itemCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: _HoverCardWrapper(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18.sp, color: iconColor),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ]),
              ),
              SizedBox(width: 8.w),
              _statusBadge(status),
              SizedBox(width: 6.w),
              Icon(
                Icons.chevron_left_rounded,
                size: 18.sp,
                color: isDark ? Colors.white.withOpacity(0.25) : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final statusColor = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.18)),
      ),
      child: Text(
        TranslationHelper.getArabicStatus(status),
        style: TextStyle(fontSize: 10.sp, color: statusColor, fontWeight: FontWeight.w800),
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.trim();
    if (s == 'Pending Review' || s == 'pending') return const Color(0xFFf59e0b);
    if (s == 'Ready For Assignment' || s == 'Assigned To Captain' || s == 'Captain Arrived' || s == 'Picked Up' || s == 'In Transit' || s == 'ongoing' || s == 'in_progress') return const Color(0xFF06b6d4);
    if (s == 'Delivered' || s == 'Completed' || s == 'completed') return const Color(0xFF10b981);
    if (s == 'Cancelled' || s == 'cancelled' || s == 'Rejected' || s == 'rejected') return const Color(0xFFef4444);
    return Colors.white.withOpacity(0.4);
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
