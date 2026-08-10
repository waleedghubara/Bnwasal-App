// ignore_for_file: unused_element, deprecated_member_use, use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart' as di;
import 'package:admin_bnwasal/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

enum _CaptainAvailability { all, available, busy, inTrip }

enum _SortBy { recommended, rating }

class CaptainDispatcherScreen extends StatefulWidget {
  final String? shipmentId;
  final String? orderId;
  final String fromCity;
  final String toCity;

  const CaptainDispatcherScreen({
    super.key,
    this.shipmentId,
    this.orderId,
    required this.fromCity,
    required this.toCity,
  });

  @override
  State<CaptainDispatcherScreen> createState() =>
      _CaptainDispatcherScreenState();
}

class _CaptainDispatcherScreenState extends State<CaptainDispatcherScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _captains = [];
  List<Map<String, dynamic>> _filteredCaptains = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String? _selectedCaptainId;
  _CaptainAvailability _availabilityFilter = _CaptainAvailability.all;
  _SortBy _sortBy = _SortBy.recommended;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAvailableCaptains();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  int _toInt(dynamic v) => (v is num) ? v.toInt() : 0;

  /// A captain is considered:
  ///   inTrip  — if they have a currently-running trip (effectiveStatus == 'in_progress')
  ///   busy    — if they have active orders/shipments (picked up, in transit)
  ///   available — otherwise
  String _captainStatus(Map<String, dynamic> c) {
    final overallOrders = _toInt(c['activeOrdersCount']);
    final overallShipments = _toInt(c['activeShipmentsCount']);

    if (overallOrders + overallShipments == 0) {
      return 'available';
    }

    final trips = c['trips'] as List<dynamic>? ?? [];
    for (final t in trips) {
      final es = (t['effectiveStatus'] ?? t['status'] ?? '').toString();
      if (es == 'in_progress') {
        final activeOrders = _toInt(t['activeOrdersCount']);
        final activeShipments = _toInt(t['activeShipmentsCount']);
        if (activeOrders + activeShipments > 0) {
          return 'inTrip';
        }
      }
    }

    return 'busy';
  }

  String _captainStatusLabel(Map<String, dynamic> c) {
    switch (_captainStatus(c)) {
      case 'inTrip':
        return 'في رحلة';
      case 'busy':
        return 'مشغول';
      default:
        return 'متاح';
    }
  }

  Color _captainStatusColor(Map<String, dynamic> c) {
    switch (_captainStatus(c)) {
      case 'inTrip':
        return const Color(0xFF06b6d4);
      case 'busy':
        return const Color(0xFFf59e0b);
      default:
        return const Color(0xFF10b981);
    }
  }

  String _captainStatusIcon(Map<String, dynamic> c) {
    switch (_captainStatus(c)) {
      case 'inTrip':
        return '🚚';
      case 'busy':
        return '⏳';
      default:
        return '✅';
    }
  }

  bool _availabilityPasses(Map<String, dynamic> c) {
    if (_availabilityFilter == _CaptainAvailability.all) return true;
    return _captainStatus(c) == _availabilityFilter.name;
  }

  Future<void> _loadAvailableCaptains() async {
    try {
      final dio = di.sl<DioConsumer>();
      final path = widget.shipmentId != null
          ? 'dispatcher/available-captains?shipmentId=${widget.shipmentId}'
          : 'dispatcher/available-captains?orderId=${widget.orderId}';
      final response = await dio.get(path);
      final list = response['data'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _captains = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _applyFilterAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل قائمة الكباتن: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _applyFilterAndSort() {
    var list = List<Map<String, dynamic>>.from(_captains);
    final query = _searchQuery.toLowerCase().trim();
    if (query.isNotEmpty) {
      list = list.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    }
    list = list.where(_availabilityPasses).toList();
    if (_sortBy == _SortBy.rating) {
      list.sort(
        (a, b) => (b['avgRating'] ?? 0.0).compareTo(a['avgRating'] ?? 0.0),
      );
    }
    _filteredCaptains = list;
  }

  Future<void> _assignCaptain(String captainId, String captainName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildAssigningDialog(captainName),
    );
    try {
      final dio = di.sl<DioConsumer>();
      await dio.post(
        'dispatcher/assign',
        data: {
          if (widget.shipmentId != null) 'shipmentId': widget.shipmentId,
          if (widget.orderId != null) 'orderId': widget.orderId,
          'captainId': captainId,
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'تم تعيين الكابتن $captainName بنجاح',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF065f46),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      );
      di.sl<DashboardCubit>().loadDashboard();
      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'فشل تعيين الكابتن: $e',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF991b1b),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      );
    }
  }

  // ── Skeleton Loading ─────────────────────────────────────────────────────

  Widget _buildSkeletonGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = _crossAxisCount(width);
        final double spacing = 14.w;
        final double itemWidth =
            (width - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          child: Wrap(
            spacing: spacing,
            runSpacing: 14.h,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: List.generate(6, (index) {
              return SizedBox(width: itemWidth, child: _buildSkeletonCard());
            }),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300,
        ),
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmerBox(44.w, 44.w, borderRadius: 22),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(120.w, 16.h),
                    SizedBox(height: 8.h),
                    _shimmerBox(80.w, 12.h),
                  ],
                ),
              ),
              _shimmerBox(56.w, 26.h, borderRadius: 8),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _shimmerBox(60.w, 22.h, borderRadius: 6),
              const Spacer(),
              _shimmerBox(70.w, 22.h, borderRadius: 6),
            ],
          ),
          SizedBox(height: 14.h),
          _shimmerBox(double.infinity, 36.h, borderRadius: 10),
        ],
      ),
    );
  }

  Widget _shimmerBox(double w, double h, {double borderRadius = 6}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: w.isFinite ? w : null,
      height: h,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  // ── Assigning Dialog ─────────────────────────────────────────────────────

  Widget _buildAssigningDialog(String captainName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1a1a3e) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 10.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56.w,
              height: 56.w,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'جاري التعيين...',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'الكابتن $captainName',
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Responsive Helpers ───────────────────────────────────────────────────

  int _crossAxisCount(double width) =>
      width >= 1100 ? 4 : (width >= 800 ? 3 : (width >= 500 ? 2 : 1));

  bool _isWide(BuildContext c) => MediaQuery.of(c).size.width >= 800;

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recommended = _filteredCaptains
        .where((c) => c['isRecommended'] == true)
        .toList();
    final all = _filteredCaptains;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050512) : const Color(0xFFf8f9fa),
      appBar: _buildAppBar(),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _buildRouteBanner(),
            SizedBox(height: 16.h),
            _buildSearchAndFilterBar(),
            _buildTabBar(recommended.length, all.length),
            SizedBox(height: 8.h),
            Expanded(
              child: _isLoading
                  ? _buildSkeletonGrid()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        recommended.isEmpty
                            ? _buildEmptyState(
                                'لا يوجد كباتن مطابقة مساراتهم لهذا الطلب اليوم.\nيمكنك العثور على الكباتن في تبويب "كل الكباتن".',
                              )
                            : _buildCaptainsGrid(recommended),
                        all.isEmpty
                            ? _buildEmptyState('لا يوجد كباتن متاحين حالياً.')
                            : _buildCaptainsGrid(all),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppBar(
      backgroundColor: isDark
          ? const Color(0xFF0F0F29).withOpacity(0.4)
          : Colors.white.withOpacity(0.8),
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: Text(
        'اختيار الكابتن',
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : Colors.black87,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // ── Route Banner ─────────────────────────────────────────────────────────

  Widget _buildRouteBanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.primary.withOpacity(0.12),
                  const Color(0xFF1a1a3e).withOpacity(0.4),
                ]
              : [
                  AppColors.primary.withOpacity(0.08),
                  Colors.white,
                ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.primary.withOpacity(0.08)
                : Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.route_rounded,
              color: AppColors.secondary,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مسار التوصيل المطلوب',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.fromCity,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                        size: 18.sp,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06b6d4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.toCity,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF06b6d4),
                          fontWeight: FontWeight.w800,
                        ),
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

  // ── Search + Filters ─────────────────────────────────────────────────────

  Widget _buildSearchAndFilterBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Container(
            height: 48.h,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF12122a) : Colors.white,
              borderRadius: BorderRadius.circular(14),
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
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 15.sp,
              ),
              decoration: InputDecoration(
                hintText: 'البحث عن كابتن بالاسم أو الهاتف...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38,
                  fontSize: 15.sp,
                ),
                fillColor: Colors.transparent,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
                  size: 22.sp,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
                          size: 20.sp,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilterAndSort();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12.h,
                  horizontal: 14.w,
                ),
              ),
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _applyFilterAndSort();
                });
              },
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        'الكل',
                        _CaptainAvailability.all,
                        Icons.filter_list_rounded,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        'متاح',
                        _CaptainAvailability.available,
                        Icons.check_circle_outline,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        'مشغول',
                        _CaptainAvailability.busy,
                        Icons.access_time_rounded,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        'في رحلة',
                        _CaptainAvailability.inTrip,
                        Icons.local_shipping_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              _buildSortButton(),
              SizedBox(width: 8.w),
              _buildStatsBadge(_filteredCaptains.length),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBadge(int count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_rounded, size: 14.sp, color: AppColors.primary),
          SizedBox(width: 4.w),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    _CaptainAvailability value,
    IconData icon,
  ) {
    final active = _availabilityFilter == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() {
          _availabilityFilter = value;
          _applyFilterAndSort();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.2)
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.primary.withOpacity(0.4)
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
            Icon(
              icon,
              size: 14.sp,
              color: active
                  ? AppColors.primary
                  : (isDark ? Colors.white.withOpacity(0.4) : Colors.black45),
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: active
                    ? AppColors.primary
                    : (isDark ? Colors.white.withOpacity(0.5) : Colors.black87),
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    final labels = {
      _SortBy.recommended: 'الموصى به',
      _SortBy.rating: 'التقييم',
    };
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 38.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_SortBy>(
          value: _sortBy,
          dropdownColor: isDark ? const Color(0xFF1a1a3e) : Colors.white,
          icon: Icon(
            Icons.swap_vert_rounded,
            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
            size: 20.sp,
          ),
          style: TextStyle(
            fontSize: 13.sp,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _sortBy = v;
              _applyFilterAndSort();
            });
          },
          items: _SortBy.values.map((e) {
            return DropdownMenuItem(
              value: e,
              child: Text(
                labels[e]!,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar(int recommendedCount, int totalCount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF005ce6)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white.withOpacity(0.4) : Colors.black54,
        labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.medal, size: 14.sp),
                  SizedBox(width: 2.w),
                  Flexible(
                    child: Text(
                      'المطابقة',
                      style: GoogleFonts.tajawal(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$recommendedCount',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.peopleGroup, size: 14.sp),
                  SizedBox(width: 2.w),
                  Flexible(
                    child: Text(
                      'الكل',
                      style: GoogleFonts.tajawal(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalCount',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(28.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300,
                ),
              ),
              child: Icon(
                Icons.sports_motorsports_outlined,
                size: 56.sp,
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.15),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                fontSize: 15.sp,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Captains Grid ────────────────────────────────────────────────────────

  Widget _buildCaptainsGrid(List<Map<String, dynamic>> captains) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = _crossAxisCount(width);
        final double spacing = 14.w;
        final double itemWidth =
            (width - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
          child: Wrap(
            spacing: spacing,
            runSpacing: 14.h,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: captains.map((captain) {
              return SizedBox(
                width: itemWidth,
                child: _buildCaptainCard(captain),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Captain Card ─────────────────────────────────────────────────────────

  Widget _buildCaptainCard(Map<String, dynamic> captain) {
    final name = captain['name']?.toString() ?? '';
    final phone = captain['phone']?.toString() ?? '';
    final balance = captain['walletBalance'] ?? 0;
    final isRecommended = captain['isRecommended'] == true;
    final reason = captain['recommendationReason']?.toString() ?? '';
    final trips = captain['trips'] as List<dynamic>? ?? [];
    final cid = captain['id']?.toString() ?? '';
    final isSelected = _selectedCaptainId == cid;
    final avgRating = captain['avgRating'] ?? 0.0;
    final reviewCount = captain['reviewCount'] ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedCaptainId = cid),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: 8.h),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.primary.withOpacity(0.06),
                  ]
                : isRecommended
                ? (isDark
                    ? [
                        AppColors.secondary.withOpacity(0.08),
                        Colors.white.withOpacity(0.01),
                      ]
                    : [
                        AppColors.secondary.withOpacity(0.08),
                        Colors.white,
                      ])
                : (isDark
                    ? [
                        Colors.white.withOpacity(0.03),
                        Colors.white.withOpacity(0.005),
                      ]
                    : [
                        Colors.white,
                        Colors.white,
                      ]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.6)
                : isRecommended
                ? AppColors.secondary.withOpacity(0.25)
                : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top row: avatar + name/phone + status ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _avatar(
                  captain['avatar']?.toString(),
                  name.isNotEmpty ? name[0] : '?',
                  size: 48,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 17.sp,
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecommended) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'مطابق',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 13.sp,
                            color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
                          ),
                          SizedBox(width: 6.w),
                          Flexible(
                            child: Text(
                              phone,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: _captainStatusColor(captain).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _captainStatusColor(captain).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _captainStatusIcon(captain),
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _captainStatusLabel(captain),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _captainStatusColor(captain),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // ── Stats row: rating + trips + wallet ──
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB000).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14.sp,
                        color: const Color(0xFFFFB000),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        avgRating.toString(),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFFFFB000),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        reviewCount > 0 ? '($reviewCount)' : 'جديد',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark ? Colors.white.withOpacity(0.35) : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.route_rounded,
                        size: 13.sp,
                        color: AppColors.secondary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${trips.length} رحلات',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (captain['vehicleType'] != null &&
                    captain['vehicleType'].toString().isNotEmpty) ...[
                  SizedBox(width: 8.w),
                  _buildVehicleBadge(captain['vehicleType'].toString()),
                ],
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 13.sp,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          '${balance.toStringAsFixed(0)} ج.م',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Recommendation reason ──
            if (isRecommended && reason.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.explore_outlined,
                      size: 16.sp,
                      color: AppColors.secondary,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Assign button ──
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100),
                    foregroundColor: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    disabledBackgroundColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade200,
                    disabledForegroundColor: isDark ? Colors.white.withOpacity(0.2) : Colors.black26,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.6)
                            : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade300),
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: isSelected
                      ? () => _assignCaptain(cid, name)
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          isSelected
                              ? 'تأكيد تعيين الكابتن'
                              : 'اضغط لاختيار الكابتن',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.touch_app_rounded,
                        size: 20.sp,
                        color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar ───────────────────────────────────────────────────────────────

  Widget _avatar(String? url, String letter, {double size = 50}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (url != null && url.isNotEmpty) {
      return Container(
        width: size.w,
        height: size.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url.startsWith('http') ? url : '${EndPoint.imageBaseUrl}$url'.trim(),
          fit: BoxFit.cover,
          width: size.w,
          height: size.w,
          errorBuilder: (_, _, _) => _avatarFallback(letter, size: size),
        ),
      );
    }
    return _avatarFallback(letter, size: size);
  }

  Widget _avatarFallback(String letter, {double size = 50}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF004aad), Color(0xFFF78710)],
        ),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: (size * 0.42).sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVehicleBadge(String vehicleType) {
    final labels = {
      'scooter': 'سكوتر',
      'motorcycle': 'موتوسيكل',
      'car': 'سيارة',
      'public': 'مواصلات',
    };
    final icons = {
      'scooter': Icons.motorcycle_rounded,
      'motorcycle': Icons.motorcycle_rounded,
      'car': Icons.directions_car_rounded,
      'public': Icons.directions_bus_rounded,
    };

    final label = labels[vehicleType] ?? 'غير محدد';
    final icon = icons[vehicleType] ?? Icons.help_outline_rounded;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF8b5cf6).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8b5cf6).withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: const Color(0xFFa78bfa)),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: const Color(0xFFa78bfa),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
