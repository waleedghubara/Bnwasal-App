import 'package:flutter/material.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:admin_bnwasal/core/services/notification_service.dart';
import '../cubit/captains_cubit.dart';
import '../cubit/captains_state.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'dart:math' as math;
import 'package:admin_bnwasal/core/cache/cache_helper.dart';
import 'package:flutter/gestures.dart';

class CaptainDetailScreen extends StatefulWidget {
  final int captainId;
  const CaptainDetailScreen({super.key, required this.captainId});

  @override
  State<CaptainDetailScreen> createState() => _CaptainDetailScreenState();
}

class _CaptainDetailScreenState extends State<CaptainDetailScreen> {
  late final CaptainsCubit _cubit;
  String _tripFilter = '';
  String? _token;
  bool _isTokenLoaded = false;
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  Map<String, dynamic>? _selectedPastDelivery;
  String _routeMode = 'full'; // 'full', 'pickup', 'delivery'
  LatLng? _currentStartPoint;
  LatLng? _currentDestinationPoint;
  LatLng? _currentPickupPoint;
  final _pastDeliveriesScrollCtrl = ScrollController();
  final _tripsScrollCtrl = ScrollController();

  List<LatLng> _completedPoints = [];
  List<LatLng> _remainingPoints = [];
  double _totalDistance = 0.0;
  double _completedDistance = 0.0;
  double _remainingDistance = 0.0;
  double _progressPercentage = 0.0;
  bool _hasMoved = false;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CaptainsCubit>();
    _cubit.loadCaptainDetail(widget.captainId);

    // Join room for this captain to receive location updates in real-time
    NotificationService().joinRoom('captain_${widget.captainId}');
    NotificationService().onLocationUpdate = (data) {
      if (mounted) {
        final lat = double.tryParse(data['latitude']?.toString() ?? '');
        final lng = double.tryParse(data['longitude']?.toString() ?? '');
        if (lat != null && lng != null) {
          _cubit.updateCaptainLocation(lat, lng);
          _calculateRouteProgress(LatLng(lat, lng));
        }
      }
    };
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    if (mounted) {
      setState(() {
        _token = token;
        _isTokenLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    NotificationService().leaveRoom('captain_${widget.captainId}');
    if (NotificationService().onLocationUpdate != null) {
      NotificationService().onLocationUpdate = null;
    }
    _cubit.clearDetail();
    _mapController.dispose();
    _pastDeliveriesScrollCtrl.dispose();
    _tripsScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0a0e27) : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0a0e27) : AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 18.sp,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'تفاصيل الكابتن',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
      body: BlocBuilder<CaptainsCubit, CaptainsState>(
        builder: (context, state) {
          if (state.isLoadingDetail) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyan),
            );
          }
          if (state.detailError != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'خطأ في تحميل البيانات',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 15.sp,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<CaptainsCubit>()
                        .loadCaptainDetail(widget.captainId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          if (state.captain == null) return const SizedBox();

          final m = state.captain!;
          final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
          final email = m['email'] ?? '';
          final phone = m['phone'] ?? '';
          final city = m['city'] ?? '';
          final wallet = '${m['walletBalance'] ?? 0}';

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 32.w : 16.w,
              8.h,
              isWide ? 32.w : 16.w,
              32.h,
            ),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildLeftColumn(
                          state,
                          name,
                          email,
                          phone,
                          city,
                          wallet,
                          m,
                        ),
                      ),
                      SizedBox(width: 24.w),
                      Expanded(flex: 4, child: _buildRightColumn(state)),
                    ],
                  )
                : Column(
                    children: [
                      _buildLeftColumn(
                        state,
                        name,
                        email,
                        phone,
                        city,
                        wallet,
                        m,
                      ),
                      SizedBox(height: 20.h),
                      _buildRightColumn(state),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildLeftColumn(
    CaptainsState state,
    String name,
    String email,
    String phone,
    String city,
    String wallet,
    Map<String, dynamic> m,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(name, email, phone, city, wallet, m),
        SizedBox(height: 20.h),
        _buildStatsGrid(state),
        SizedBox(height: 20.h),
        _buildCaptainTripsSection(state),
        if (_isTokenLoaded) ...[
          SizedBox(height: 20.h),
          _buildDocumentsSection(state.documents),
        ],
      ],
    );
  }

  Widget _buildRightColumn(CaptainsState state) {
    return Column(
      children: [
        _buildMapCard(state),
        SizedBox(height: 20.h),
        _buildAnalysisCard(state.analysis),
        SizedBox(height: 20.h),
        _buildRecentActivity(state.recentActivity),
        SizedBox(height: 20.h),
        if (state.captain != null) _buildActions(state.captain!),
      ],
    );
  }

  Widget _buildInfoCard(
    String name,
    String email,
    String phone,
    String city,
    String wallet,
    Map<String, dynamic> m,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = m['status'] ?? '';
    final labels = {
      'active': 'نشط',
      'banned': 'محظور',
      'pending_verification': 'قيد التحقق',
      'pending_otp': 'لم يؤكد',
    };
    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = AppColors.success;
        break;
      case 'banned':
        statusColor = AppColors.error;
        break;
      case 'pending_verification':
        statusColor = AppColors.warning;
        break;
      default:
        statusColor = isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary.withValues(alpha: 0.6);
    }

    final vehicleType = m['vehicleType'] ?? '';
    final vehicleTypeLabels = {
      'scooter': 'سكوتر',
      'motorcycle': 'موتوسيكل',
      'car': 'سيارة',
      'public': 'مواصلات',
    };
    final vehicleLabel = vehicleTypeLabels[vehicleType] ?? 'غير محدد';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _detailAvatar(
                m['profileImage']?.toString(),
                name.isNotEmpty ? name[0] : '?',
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    _infoRow(
                      Icons.circle_rounded,
                      labels[status] ?? status,
                      color: statusColor,
                      size: 10.sp,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Divider(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06), height: 1),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 12.h,
            children: [
              _infoItem(Icons.email_outlined, 'البريد الإلكتروني', email),
              _infoItem(Icons.phone_outlined, 'رقم الهاتف', phone),
              _infoItem(
                Icons.location_on_outlined,
                'المدينة',
                city.isNotEmpty ? city : 'غير محدد',
              ),
              _infoItem(
                Icons.account_balance_wallet_outlined,
                'رصيد المحفظة',
                '$wallet جنيه',
              ),
              _infoItem(
                Icons.directions_bike_outlined,
                'وسيلة النقل',
                vehicleLabel,
              ),
              _infoItem(
                Icons.calendar_today_outlined,
                'تاريخ التسجيل',
                _formatDate(m['createdAt']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailAvatar(String? url, String letter) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarWidget = url != null && url.isNotEmpty
        ? Container(
            width: 56.w,
            height: 56.w,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              EndPoint.getCleanImageUrl(url),
              fit: BoxFit.cover,
              width: 56.w,
              height: 56.w,
              errorBuilder: (context, error, stackTrace) =>
                  _detailAvatarFallback(letter),
            ),
          )
        : _detailAvatarFallback(letter);

    if (url != null && url.isNotEmpty) {
      final cleanUrl = EndPoint.getCleanImageUrl(url);
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showFullscreenImage(cleanUrl, 'الصورة الشخصية'),
          child: Tooltip(
            message: 'انقر لعرض الصورة الشخصية',
            textStyle: TextStyle(fontSize: 10.sp, color: isDark ? Colors.white : AppColors.textPrimary),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1a1a3e) : AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
            ),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                avatarWidget,
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF78710),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.remove_red_eye_rounded,
                    size: 10.sp,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return avatarWidget;
  }

  Widget _detailAvatarFallback(String letter) {
    return Container(
      width: 56.w,
      height: 56.w,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF004aad), Color(0xFFF78710)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'انقر لنسخ $label',
      textStyle: TextStyle(fontSize: 10.sp, color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a1a3e) : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
      ),
      child: _InfoItemTile(
        icon: icon,
        label: label,
        value: value,
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم نسخ $label بنجاح 📋',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              width: 250.w,
              duration: const Duration(seconds: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String text, {
    Color? color,
    double size = 14,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: color),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(CaptainsState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = state.stats;
    if (s == null) return const SizedBox();

    final shipments = s['shipments'] as Map<String, dynamic>?;
    final orders = s['orders'] as Map<String, dynamic>?;
    final trips = s['trips'] as Map<String, dynamic>?;
    final reviews = s['reviews'] as Map<String, dynamic>?;
    final wallet = s['wallet'] as Map<String, dynamic>?;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إحصائيات',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              _statTile(
                'إجمالي الطلبات',
                '${orders?['totalOrders'] ?? 0}',
                Icons.receipt_long_rounded,
                Colors.cyan,
              ),
              _statTile(
                'طلبات مكتملة',
                '${orders?['completedOrders'] ?? 0}',
                Icons.check_circle_outline_rounded,
                AppColors.success,
              ),
              _statTile(
                'طلبات ملغية',
                '${orders?['cancelledOrders'] ?? 0}',
                Icons.cancel_outlined,
                Colors.red.shade400,
              ),
              _statTile(
                'إجمالي الشحنات',
                '${shipments?['totalShipments'] ?? 0}',
                Icons.local_shipping_rounded,
                Colors.orange,
              ),
              _statTile(
                'شحنات مكتملة',
                '${shipments?['completedShipments'] ?? 0}',
                Icons.check_circle_outline_rounded,
                AppColors.success,
              ),
              _statTile(
                'شحنات ملغية',
                '${shipments?['cancelledShipments'] ?? 0}',
                Icons.cancel_outlined,
                Colors.red.shade400,
              ),
              _statTile(
                'إجمالي الرحلات',
                '${trips?['totalTrips'] ?? 0}',
                Icons.route_rounded,
                const Color(0xFF8b5cf6),
              ),
              _statTile(
                'رحلات مكتملة',
                '${trips?['completedTrips'] ?? 0}',
                Icons.check_circle_outline_rounded,
                AppColors.success,
              ),
              _statTile(
                'التقييم العام',
                '${reviews?['avgRating'] ?? '-'}',
                Icons.star_rounded,
                AppColors.warning,
              ),
              _statTile(
                'عدد التقييمات',
                '${reviews?['totalReviews'] ?? 0}',
                Icons.rate_review_outlined,
                const Color(0xFF6366f1),
              ),
              _statTile(
                'إجمالي الإيداعات',
                '${_fmtNum(wallet?['totalDeposits'])} جنيه',
                Icons.add_circle_outline_rounded,
                AppColors.success,
              ),
              _statTile(
                'إجمالي السحوبات',
                '${_fmtNum(wallet?['totalWithdrawals'])} جنيه',
                Icons.remove_circle_outline_rounded,
                Colors.red.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 170.w,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: color),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(Map<String, dynamic>? docs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (docs == null) return const SizedBox();
    final front = docs['nationalIdFront'] as String?;
    final back = docs['nationalIdBack'] as String?;
    final nationalId = docs['nationalId'] as String?;

    if (front == null && back == null) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card_rounded, size: 16.sp, color: Colors.cyan),
              SizedBox(width: 8.w),
              Text(
                'البطاقة الشخصية والمستندات',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (nationalId != null) ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, color: Colors.cyan, size: 18.sp),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرقم القومي للكابتن',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        nationalId,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 16.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 12.h,
            children: [
              if (front != null) _docImage(front, 'الوجه الأمامي للبطاقة'),
              if (back != null) _docImage(back, 'الوجه الخلفي للبطاقة'),
            ],
          ),
        ],
      ),
    );
  }

  String _cleanImageUrl(String? path) {
    return EndPoint.getCleanImageUrl(path);
  }

  Widget _docImage(String path, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final url = _cleanImageUrl(path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HoverDocImage(
          child: GestureDetector(
            onTap: () => _showFullscreenImage(url, label),
            child: Container(
              width: 200.w,
              height: 130.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    url,
                    headers: _token != null
                        ? {'Authorization': 'Bearer $_token'}
                        : null,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.cyan,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint(
                        '❌ [CaptainDetail] Failed to load image: $url',
                      );
                      debugPrint(
                        'Token present: ${_token != null ? "Yes" : "No"}',
                      );
                      debugPrint('Error: $error');
                      final tokenStr = _token != null
                          ? (_token!.length > 10
                                ? '${_token!.substring(0, 10)}...'
                                : _token)
                          : 'لا يوجد';
                      return Container(
                        color: Colors.red.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red.shade300,
                                size: 24.sp,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'خطأ في تحميل الصورة',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade300,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                error.toString(),
                                style: TextStyle(
                                  fontSize: 8.sp,
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'الرابط: $url',
                                style: TextStyle(
                                  fontSize: 7.sp,
                                  color: Colors.white38,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'توكن: $tokenStr',
                                style: TextStyle(
                                  fontSize: 7.sp,
                                  color: _token != null
                                      ? Colors.green.shade300
                                      : Colors.red.shade300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.fullscreen_rounded,
                        size: 14.sp,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showFullscreenImage(String url, String label) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: Colors.white, size: 22.sp),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 15.sp),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                headers: _token != null
                    ? {'Authorization': 'Bearer $_token'}
                    : null,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.cyan),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint(
                    '❌ [CaptainDetail Fullscreen] Failed to load image: $url',
                  );
                  debugPrint('Token present: ${_token != null ? "Yes" : "No"}');
                  debugPrint('Error: $error');
                  final tokenStr = _token != null
                      ? (_token!.length > 10
                            ? '${_token!.substring(0, 10)}...'
                            : _token)
                      : 'لا يوجد';
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'فشل تحميل الصورة بدقة كاملة',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14.sp,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 12.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'الرابط: $url',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'توكن: $tokenStr',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: _token != null
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Widget _buildCaptainTripsSection(CaptainsState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (state.isLoadingCaptTrips) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
        ),
      );
    }
    final trips = state.captainTrips;
    if (trips == null || trips.isEmpty) return const SizedBox();

    final filtered = _tripFilter.isEmpty
        ? trips
        : trips.where((t) => (t as Map)['status'] == _tripFilter).toList();

    final statuses = {
      '': 'الكل',
      'pending': 'قيد الانتظار',
      'in_progress': 'جاري التنفيذ',
      'completed': 'منتهية',
      'cancelled': 'ملغية',
    };

    final cardWidth = 180.w;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                size: 16.sp,
                color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                'الرحلات',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF8b5cf6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${filtered.length}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF8b5cf6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                decoration: BoxDecoration(
                  color: _tripFilter.isNotEmpty
                      ? const Color(0xFF8b5cf6).withValues(alpha: 0.12)
                      : isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _tripFilter.isNotEmpty
                        ? const Color(0xFF8b5cf6).withValues(alpha: 0.3)
                        : isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _tripFilter,
                    dropdownColor: isDark ? const Color(0xFF1a1a3e) : AppColors.surface,
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondary,
                      size: 16.sp,
                    ),
                    style: TextStyle(fontSize: 11.sp, color: isDark ? Colors.white : AppColors.textPrimary),
                    onChanged: (v) => setState(() => _tripFilter = v ?? ''),
                    items: statuses.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildHorizontalList(
            controller: _tripsScrollCtrl,
            itemCount: filtered.length,
            height: 125.h,
            itemBuilder: (context, index) {
              final trip = filtered[index] as Map<String, dynamic>;
              return _TripCard(trip: trip, width: cardWidth);
            },
          ),
        ],
      ),
    );
  }

  // Widget _tripStatusBadge(
  //   String status,
  //   Map<String, String> labels,
  //   Map<String, Color> colors,
  // ) {
  //   final c = colors[status] ?? Colors.white.withValues(alpha: 0.4);
  //   return Container(
  //     padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
  //     decoration: BoxDecoration(
  //       color: c.withValues(alpha: 0.12),
  //       borderRadius: BorderRadius.circular(20),
  //     ),
  //     child: Text(
  //       labels[status] ?? status,
  //       style: TextStyle(fontSize: 9.sp, color: c, fontWeight: FontWeight.w600),
  //     ),
  //   );
  // }

  // Widget _tripMetaBadge(IconData icon, String text) {
  //   return Container(
  //     padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
  //     decoration: BoxDecoration(
  //       color: Colors.white.withValues(alpha: 0.04),
  //       borderRadius: BorderRadius.circular(4),
  //     ),
  //     child: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Icon(icon, size: 8.sp, color: Colors.white.withValues(alpha: 0.3)),
  //         SizedBox(width: 2.w),
  //         Text(
  //           text,
  //           style: TextStyle(
  //             fontSize: 8.sp,
  //             color: Colors.white.withValues(alpha: 0.4),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildActions(Map<String, dynamic> captain) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStatus = captain['status'] ?? '';
    final isBanned = currentStatus == 'banned';
    final id = captain['id'] as int? ?? 0;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.gavel_rounded,
                  size: 14.sp,
                  color: isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textSecondary,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'الإجراءات',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Align(
            alignment: isWide ? Alignment.centerRight : Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420.w),
              child: _actionCard(
                icon: isBanned ? Icons.lock_open_rounded : Icons.lock_outlined,
                label: isBanned ? 'إلغاء حظر الكابتن' : 'حظر الكابتن',
                desc: isBanned
                    ? 'السماح للكابتن باستخدام المنصة مرة أخرى'
                    : 'منع الكابتن من الوصول للمنصة',
                color: isBanned ? AppColors.success : AppColors.warning,
                gradientColors: isBanned
                    ? [
                        AppColors.success.withValues(alpha: 0.12),
                        AppColors.success.withValues(alpha: 0.02),
                      ]
                    : [
                        AppColors.warning.withValues(alpha: 0.12),
                        AppColors.warning.withValues(alpha: 0.02),
                      ],
                onTap: () => _toggleBan(id, isBanned),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Align(
            alignment: isWide ? Alignment.centerRight : Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420.w),
              child: _actionCard(
                icon: Icons.warning_amber_rounded,
                label: 'إرسال تحذير',
                desc: 'إشعار فوري للكابتن برسالة تحذيرية',
                color: AppColors.warning,
                gradientColors: [
                  AppColors.warning.withValues(alpha: 0.12),
                  AppColors.warning.withValues(alpha: 0.02),
                ],
                onTap: () => _showWarningDialog(id),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Align(
            alignment: isWide ? Alignment.centerRight : Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420.w),
              child: _actionCard(
                icon: Icons.delete_forever_rounded,
                label: 'حذف الحساب نهائياً',
                desc: 'إزالة كاملة للكابتن وكل بياناته - لا يمكن التراجع',
                color: AppColors.error,
                gradientColors: [
                  AppColors.error.withValues(alpha: 0.12),
                  AppColors.error.withValues(alpha: 0.02),
                ],
                onTap: () => _confirmDelete(id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String desc,
    required Color color,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20.sp, color: color),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 26.w,
                height: 26.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 12.sp,
                  color: color.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBan(int id, bool currentlyBanned) async {
    final cubit = context.read<CaptainsCubit>();
    final newStatus = currentlyBanned ? 'active' : 'banned';
    final err = await cubit.updateCaptainStatus(id, newStatus);
    if (!mounted) return;
    if (err.isEmpty) {
      cubit.loadCaptainDetail(id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlyBanned ? 'تم إلغاء الحظر' : 'تم حظر الكابتن'),
          backgroundColor: currentlyBanned
              ? AppColors.success
              : AppColors.warning,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $err'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _confirmDelete(int id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1a1a3e) : AppColors.surface,
        title: Text(
          'تأكيد الحذف',
          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 16.sp),
        ),
        content: Text(
          'هل أنت متأكد من حذف هذا الكابتن نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cubit = context.read<CaptainsCubit>();
    final err = await cubit.deleteCaptain(id);
    if (!mounted) return;
    if (err.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الكابتن'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $err'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showWarningDialog(int id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1a1a3e) : AppColors.surface,
          title: Text(
            'إرسال تحذير',
            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 16.sp),
          ),
          content: SizedBox(
            width: 300.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'عنوان التحذير',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.25) : AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'نص التحذير',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.25) : AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'إرسال',
                style: TextStyle(color: AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('العنوان والنص مطلوبان'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final cubit = context.read<CaptainsCubit>();
    final err = await cubit.sendWarning(id, titleCtrl.text, bodyCtrl.text);
    if (!mounted) return;
    if (err.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال التحذير'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $err'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildAnalysisCard(Map<String, dynamic>? analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (analysis == null) return const SizedBox();

    final behavior = analysis['behavior'] ?? '';
    final score = (analysis['behaviorScore'] ?? 0) as int;
    final isOnline = analysis['isOnline'] ?? false;
    final avg = analysis['avgActivitiesPerDay'] ?? 0.0;
    final daysSince = analysis['daysSinceLastActive'] ?? 0;
    final totalActivities = analysis['totalActivities'] ?? 0;
    final completionRate = analysis['completionRate'] ?? 0;

    Color scoreColor;
    if (score >= 80) {
      scoreColor = AppColors.success;
    } else if (score >= 50) {
      scoreColor = AppColors.warning;
    } else {
      scoreColor = AppColors.error;
    }

    final labels = {
      'دائم الاستخدام': 'نشاط يومي مستمر',
      'نشط أسبوعياً': 'نشاط خلال الأيام الأخيرة',
      'متوسط الاستخدام': 'نشاط محدود',
      'خفيف الاستخدام': 'نادر النشاط',
      'نادر الاستخدام': 'غير نشط تقريباً',
      'متوقف': 'حساب غير فعال',
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withValues(alpha: 0.08),
            isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: scoreColor, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'تحليل الذكاء الاصطناعي',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _buildScoreCircle(score, scoreColor),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      behavior.toString(),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      labels[behavior] ?? '',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(
                          Icons.circle_rounded,
                          size: 8.sp,
                          color: isOnline
                              ? AppColors.success
                              : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2)),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          isOnline ? 'نشط حالياً' : 'غير نشط حالياً',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isOnline
                                ? AppColors.success
                                : (isDark ? Colors.white.withValues(alpha: 0.35) : AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Divider(color: scoreColor.withValues(alpha: 0.1), height: 1),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 8.h,
            children: [
              _analysisItem('معدل النشاط اليومي', avg.toString(), scoreColor),
              _analysisItem(
                'آخر نشاط',
                daysSince == 0 ? 'اليوم' : 'منذ $daysSince أيام',
                scoreColor,
              ),
              _analysisItem(
                'إجمالي الأنشطة',
                totalActivities.toString(),
                scoreColor,
              ),
              _analysisItem('معدل الإنجاز', '$completionRate%', scoreColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCircle(int score, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 64.w,
      height: 64.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64.w,
            height: 64.w,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5.w,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisItem(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 160.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<dynamic>? activity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (activity == null || activity.isEmpty) return const SizedBox();
    final filtered = activity.where((a) {
      final type = (a as Map)['type']?.toString();
      return type == 'order' || type == 'shipment';
    }).toList();
    if (filtered.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 16.sp,
                color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                'آخر الأنشطة',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...filtered.map((a) {
            final item = a as Map<String, dynamic>;
            final typeName = item['type'] == 'order' ? 'طلب' : 'شحنة';
            final ref = item['ref'] ?? '';
            final status = item['status'] ?? '';
            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    item['type'] == 'order'
                        ? Icons.receipt_outlined
                        : Icons.local_shipping_outlined,
                    size: 16.sp,
                    color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.textSecondary,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$typeName $ref',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: isDark ? Colors.white.withValues(alpha: 0.35) : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(item['createdAt']),
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isDark ? Colors.white.withValues(alpha: 0.25) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(0);
    final n = double.tryParse(v.toString());
    return n != null ? n.toStringAsFixed(0) : v.toString();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildMapCard(CaptainsState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final captain = state.captain;
    if (captain == null) return const SizedBox();

    final isOnline = state.analysis?['isOnline'] ?? false;
    final active = state.activeDelivery;
    final isDelivering = active != null;

    final lat = double.tryParse(captain['latitude']?.toString() ?? '');
    final lng = double.tryParse(captain['longitude']?.toString() ?? '');
    final captainLatLng = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : null;

    // Determine default center
    LatLng center =
        captainLatLng ?? const LatLng(30.0444, 31.2357); // Cairo fallback

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14142a) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.map_outlined, color: Colors.cyan, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'تتبع الكابتن المباشر والرحلات',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // Status Indicator
              _buildMapStatusBadge(isOnline, isDelivering),
            ],
          ),
          SizedBox(height: 12.h),

          // Route Mode Segment Selector
          Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                _buildSegmentButton(
                  mode: 'full',
                  label: 'المسار الكامل',
                  icon: Icons.map_outlined,
                ),
                _buildSegmentButton(
                  mode: 'pickup',
                  label: 'مسار الاستلام',
                  icon: Icons.hail_rounded,
                ),
                _buildSegmentButton(
                  mode: 'delivery',
                  label: 'مسار التوصيل',
                  icon: Icons.local_shipping_outlined,
                ),
              ],
            ),
          ),

          // Map Container
          Container(
            height: 300.h,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: center, initialZoom: 13.0),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      userAgentPackageName: 'com.bnwasal.admin',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          if (_selectedPastDelivery != null) ...[
                            Polyline(
                              points: _routePoints,
                              color: const Color(0xFF00bcd4),
                              strokeWidth: 4.0,
                              pattern: const StrokePattern.dotted(),
                            ),
                          ] else ...[
                            if (_completedPoints.isNotEmpty)
                              Polyline(
                                points: _completedPoints,
                                color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.25),
                                strokeWidth: 4.0,
                                pattern: const StrokePattern.dotted(),
                              ),
                            if (_remainingPoints.isNotEmpty)
                              Polyline(
                                points: _remainingPoints,
                                color: _hasMoved
                                    ? AppColors.success
                                    : const Color(0xFF00bcd4),
                                strokeWidth: 4.0,
                                pattern: const StrokePattern.solid(),
                              )
                            else if (_completedPoints.isEmpty)
                              Polyline(
                                points: _routePoints,
                                color: const Color(0xFF00bcd4),
                                strokeWidth: 4.0,
                                pattern: const StrokePattern.solid(),
                              ),
                          ],
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Captain Marker
                        if (captainLatLng != null)
                          Marker(
                            point: captainLatLng,
                            width: 40.w,
                            height: 40.w,
                            child: _buildCaptainMarker(isOnline, isDelivering),
                          ),
                        // Pickup/Merchant Marker
                        if (_selectedPastDelivery != null &&
                            _selectedPastDelivery!['merchantLatitude'] !=
                                null &&
                            _selectedPastDelivery!['merchantLongitude'] != null)
                          Marker(
                            point: LatLng(
                              double.parse(
                                _selectedPastDelivery!['merchantLatitude']
                                    .toString(),
                              ),
                              double.parse(
                                _selectedPastDelivery!['merchantLongitude']
                                    .toString(),
                              ),
                            ),
                            width: 32.w,
                            height: 32.w,
                            child: _buildLocationMarker(
                              Icons.store_rounded,
                              Colors.orange,
                            ),
                          )
                        else if (active != null &&
                            active['merchantLatitude'] != null &&
                            active['merchantLongitude'] != null &&
                            _selectedPastDelivery == null)
                          Marker(
                            point: LatLng(
                              double.parse(
                                active['merchantLatitude'].toString(),
                              ),
                              double.parse(
                                active['merchantLongitude'].toString(),
                              ),
                            ),
                            width: 32.w,
                            height: 32.w,
                            child: _buildLocationMarker(
                              Icons.store_rounded,
                              Colors.orange,
                            ),
                          ),
                        // Destination Marker
                        if (_selectedPastDelivery != null &&
                            _selectedPastDelivery!['toLatitude'] != null &&
                            _selectedPastDelivery!['toLongitude'] != null)
                          Marker(
                            point: LatLng(
                              double.parse(
                                _selectedPastDelivery!['toLatitude'].toString(),
                              ),
                              double.parse(
                                _selectedPastDelivery!['toLongitude']
                                    .toString(),
                              ),
                            ),
                            width: 32.w,
                            height: 32.w,
                            child: _buildLocationMarker(
                              Icons.location_on_rounded,
                              Colors.red,
                            ),
                          )
                        else if (active != null &&
                            active['toLatitude'] != null &&
                            active['toLongitude'] != null &&
                            _selectedPastDelivery == null)
                          Marker(
                            point: LatLng(
                              double.parse(active['toLatitude'].toString()),
                              double.parse(active['toLongitude'].toString()),
                            ),
                            width: 32.w,
                            height: 32.w,
                            child: _buildLocationMarker(
                              Icons.location_on_rounded,
                              Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Floating Action Buttons on map
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Column(
                    children: [
                      // Recenter button
                      _floatingMapButton(
                        icon: Icons.my_location_rounded,
                        onPressed: () {
                          if (captainLatLng != null) {
                            _mapController.move(captainLatLng, 14.0);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('موقع الكابتن غير متوفر حالياً'),
                              ),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 8.h),
                      // Route zoom button
                      if (_routePoints.isNotEmpty)
                        _floatingMapButton(
                          icon: Icons.zoom_out_map_rounded,
                          onPressed: _fitMapBounds,
                        ),
                    ],
                  ),
                ),
                if (_isLoadingRoute)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.cyan),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // Active/Historical status bar
          if (_selectedPastDelivery != null)
            _buildSelectedPastDeliveryBanner()
          else if (active != null)
            _buildActiveDeliveryBanner(active)
          else
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14.sp,
                    color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'الكابتن غير مرتبط بأي طلبات توصيل حالياً.',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 16.h),
          // History Section Header
          Text(
            'مسارات الرحلات السابقة المتاحة',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          _buildPastDeliveriesList(state.pastDeliveries),
        ],
      ),
    );
  }

  Widget _buildMapStatusBadge(bool isOnline, bool isDelivering) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String text = 'غير نشط';
    Color color = isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary.withValues(alpha: 0.6);
    Color dotColor = isDark ? Colors.grey : const Color(0xFF757575);

    if (isDelivering) {
      text = 'يُوصّل طلباً';
      color = const Color(0xFF00bcd4);
      dotColor = const Color(0xFF00bcd4);
    } else if (isOnline) {
      text = 'نشط حالياً';
      color = AppColors.success;
      dotColor = AppColors.success;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dotColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: isOnline || isDelivering
                  ? [BoxShadow(color: dotColor, blurRadius: 4, spreadRadius: 1)]
                  : null,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptainMarker(bool isOnline, bool isDelivering) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color baseColor = isDelivering
        ? const Color(0xFF00bcd4)
        : (isOnline ? AppColors.success : (isDark ? Colors.grey : const Color(0xFF757575)));
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: baseColor.withValues(alpha: 0.2),
        border: Border.all(color: baseColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: EdgeInsets.all(4.w),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(Icons.navigation_rounded, color: baseColor, size: 16.sp),
      ),
    );
  }

  Widget _buildLocationMarker(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 16.sp),
    );
  }

  Widget _floatingMapButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 34.w,
        height: 34.w,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1c1a30) : AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: isDark ? Colors.white : AppColors.textPrimary, size: 16.sp),
      ),
    );
  }

  Widget _buildActiveDeliveryBanner(Map<String, dynamic> active) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isShipment = active['type'] == 'shipment';
    final typeLabel = isShipment ? 'شحنة' : 'طلب';
    final number = active['number'] ?? '';
    final merchantName = active['merchantName'] ?? 'تاجر غير معروف';
    final merchantPhone = active['merchantPhone'] ?? '';
    final price = active['price'] != null
        ? '${active['price']} ج.م'
        : 'غير محدد';
    final fromAddress = active['fromAddress'] ?? 'موقع التاجر';
    final toAddress = active['toAddress'] ?? 'عنوان العميل';
    final status = active['status'] ?? '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF00bcd4).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00bcd4).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_bike_rounded,
                color: const Color(0xFF00bcd4),
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'طلب توصيل نشط حالياً ($typeLabel)',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF00bcd4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: const Color(0xFF00bcd4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Metadata Info
          _buildInfoRow(
            icon: Icons.tag,
            label: 'رقم ال$typeLabel',
            value: number,
            onCopy: () => _copyToClipboard(number, 'رقم ال$typeLabel'),
          ),
          SizedBox(height: 6.h),
          _buildInfoRow(
            icon: Icons.store_rounded,
            label: 'التاجر',
            value: merchantName,
            onCopy: () => _copyToClipboard(merchantName, 'اسم التاجر'),
          ),
          if (merchantPhone.toString().isNotEmpty) ...[
            SizedBox(height: 6.h),
            _buildInfoRow(
              icon: Icons.phone_rounded,
              label: 'رقم هاتف التاجر',
              value: merchantPhone.toString(),
              onCopy: () =>
                  _copyToClipboard(merchantPhone.toString(), 'رقم هاتف التاجر'),
              onCall: () => _makePhoneCall(merchantPhone.toString()),
            ),
          ],
          SizedBox(height: 6.h),
          _buildInfoRow(
            icon: Icons.monetization_on_outlined,
            label: 'السعر',
            value: price,
          ),
          SizedBox(height: 12.h),

          // Address Timeline
          _buildAddressTimeline(fromAddress, toAddress),
          _buildProgressCard(),
          SizedBox(height: 14.h),

          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 240.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final startLat =
                        double.tryParse(
                          active['startLatitude']?.toString() ?? '',
                        ) ??
                        double.tryParse(
                          _cubit.state.captain?['latitude']?.toString() ?? '',
                        ) ??
                        double.tryParse(
                          active['merchantLatitude']?.toString() ?? '',
                        );

                    final startLng =
                        double.tryParse(
                          active['startLongitude']?.toString() ?? '',
                        ) ??
                        double.tryParse(
                          _cubit.state.captain?['longitude']?.toString() ?? '',
                        ) ??
                        double.tryParse(
                          active['merchantLongitude']?.toString() ?? '',
                        );

                    final toLat = double.tryParse(
                      active['toLatitude']?.toString() ?? '',
                    );
                    final toLng = double.tryParse(
                      active['toLongitude']?.toString() ?? '',
                    );

                    if (startLat != null &&
                        startLng != null &&
                        toLat != null &&
                        toLng != null) {
                      final startPoint = LatLng(startLat, startLng);
                      final toPoint = LatLng(toLat, toLng);
                      final pickupLat = double.tryParse(
                        active['merchantLatitude']?.toString() ?? '',
                      );
                      final pickupLng = double.tryParse(
                        active['merchantLongitude']?.toString() ?? '',
                      );
                      final pickupPoint =
                          (pickupLat != null && pickupLng != null)
                          ? LatLng(pickupLat, pickupLng)
                          : null;

                      _fetchRoutePoints(
                        start: startPoint,
                        destination: toPoint,
                        pickup: pickupPoint,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'إحداثيات المسار غير مكتملة لهذا الطلب',
                          ),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    Icons.route_rounded,
                    size: 14.sp,
                    color: Colors.black,
                  ),
                  label: Text(
                    'رسم مسار التوصيل المباشر',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00bcd4),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPastDeliveryBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_selectedPastDelivery == null) return const SizedBox();
    final isShipment = _selectedPastDelivery!['type'] == 'shipment';
    final typeLabel = isShipment ? 'شحنة سابقة' : 'طلب سابق';
    final number = _selectedPastDelivery!['number'] ?? '';
    final merchantName =
        _selectedPastDelivery!['merchantName'] ?? 'تاجر غير معروف';
    final merchantPhone = _selectedPastDelivery!['merchantPhone'] ?? '';
    final price = _selectedPastDelivery!['price'] != null
        ? '${_selectedPastDelivery!['price']} ج.م'
        : 'غير محدد';
    final fromAddress = _selectedPastDelivery!['fromAddress'] ?? 'موقع التاجر';
    final toAddress = _selectedPastDelivery!['toAddress'] ?? 'عنوان العميل';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                color: Colors.cyan,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'عرض مسار تاريخي ($typeLabel)',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPastDelivery = null;
                    _routePoints = [];
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 12.sp,
                    color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Metadata Info
          _buildInfoRow(
            icon: Icons.tag,
            label: 'رقم ال${isShipment ? "شحنة" : "طلب"}',
            value: number,
            onCopy: () => _copyToClipboard(
              number,
              'رقم ال${isShipment ? "شحنة" : "طلب"}',
            ),
          ),
          SizedBox(height: 6.h),
          _buildInfoRow(
            icon: Icons.store_rounded,
            label: 'التاجر',
            value: merchantName,
            onCopy: () => _copyToClipboard(merchantName, 'اسم التاجر'),
          ),
          if (merchantPhone.toString().isNotEmpty) ...[
            SizedBox(height: 6.h),
            _buildInfoRow(
              icon: Icons.phone_rounded,
              label: 'رقم هاتف التاجر',
              value: merchantPhone.toString(),
              onCopy: () =>
                  _copyToClipboard(merchantPhone.toString(), 'رقم هاتف التاجر'),
              onCall: () => _makePhoneCall(merchantPhone.toString()),
            ),
          ],
          SizedBox(height: 6.h),
          _buildInfoRow(
            icon: Icons.monetization_on_outlined,
            label: 'السعر',
            value: price,
          ),
          SizedBox(height: 12.h),

          // Address Timeline
          _buildAddressTimeline(fromAddress, toAddress),
          _buildProgressCard(),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
    VoidCallback? onCall,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary),
        SizedBox(width: 8.w),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onCall != null) ...[
          GestureDetector(
            onTap: onCall,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_rounded,
                    size: 10.sp,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'اتصال',
                    style: TextStyle(
                      fontSize: 8.sp,
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 6.w),
        ],
        if (onCopy != null)
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              size: 12.sp,
              color: Colors.cyan.withValues(alpha: 0.6),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onCopy,
            splashRadius: 16,
          ),
      ],
    );
  }

  Widget _buildAddressTimeline(String from, String to) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange,
                    ),
                  ),
                  Container(
                    width: 2.w,
                    height: 18.h,
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                  ),
                ],
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'موقع الاستلام (من)',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      from,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 12.sp,
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _copyToClipboard(from, 'عنوان الاستلام'),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyan,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'موقع التسليم (إلى)',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      to,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 12.sp,
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _copyToClipboard(to, 'عنوان التسليم'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label بنجاح'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await url_launcher.canLaunchUrl(url)) {
      await url_launcher.launchUrl(url);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، تعذر إجراء الاتصال الهاتفي')),
      );
    }
  }

  Widget _buildPastDeliveriesList(List<dynamic>? past) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (past == null || past.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        alignment: Alignment.center,
        child: Text(
          'لا تتوفر رحلات سابقة بإحداثيات مسار مسجلة.',
          style: TextStyle(
            fontSize: 10.sp,
            color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
          ),
        ),
      );
    }

    final cardWidth = 180.w;

    return _buildHorizontalList(
      controller: _pastDeliveriesScrollCtrl,
      itemCount: past.length,
      height: 135.h,
      itemBuilder: (context, index) {
        final item = past[index] as Map<String, dynamic>;
        final isSelected =
            _selectedPastDelivery != null &&
            _selectedPastDelivery!['id'] == item['id'] &&
            _selectedPastDelivery!['type'] == item['type'];

        return _DeliveryCard(
          item: item,
          width: cardWidth,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedPastDelivery = item;
            });
            final startLat =
                double.tryParse(item['startLatitude']?.toString() ?? '') ??
                double.tryParse(item['merchantLatitude']?.toString() ?? '');
            final startLng =
                double.tryParse(item['startLongitude']?.toString() ?? '') ??
                double.tryParse(item['merchantLongitude']?.toString() ?? '');
            final toLat = double.tryParse(item['toLatitude']?.toString() ?? '');
            final toLng = double.tryParse(
              item['toLongitude']?.toString() ?? '',
            );

            if (startLat != null &&
                startLng != null &&
                toLat != null &&
                toLng != null) {
              final startPoint = LatLng(startLat, startLng);
              final toPoint = LatLng(toLat, toLng);
              final pickupLat = double.tryParse(
                item['merchantLatitude']?.toString() ?? '',
              );
              final pickupLng = double.tryParse(
                item['merchantLongitude']?.toString() ?? '',
              );
              final pickupPoint = (pickupLat != null && pickupLng != null)
                  ? LatLng(pickupLat, pickupLng)
                  : null;

              _fetchRoutePoints(
                start: startPoint,
                destination: toPoint,
                pickup: pickupPoint,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('إحداثيات المسار غير كاملة لهذه الرحلة'),
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _fetchRoutePoints({
    required LatLng start,
    required LatLng destination,
    LatLng? pickup,
  }) async {
    _currentStartPoint = start;
    _currentDestinationPoint = destination;
    _currentPickupPoint = pickup;

    setState(() {
      _isLoadingRoute = true;
      _routePoints = [];
    });

    // 1. Try OSRM Routing API (Free & OpenStreetMap-based, gives exact street navigation)
    List<LatLng> coords = [];
    if (_routeMode == 'pickup') {
      coords.add(start);
      if (pickup != null) {
        coords.add(pickup);
      } else {
        coords.add(destination);
      }
    } else if (_routeMode == 'delivery') {
      if (pickup != null) {
        coords.add(pickup);
      } else {
        coords.add(start);
      }
      coords.add(destination);
    } else {
      // full mode
      coords.add(start);
      if (pickup != null) {
        coords.add(pickup);
      }
      coords.add(destination);
    }

    final coordsString = coords
        .map((c) => '${c.longitude},${c.latitude}')
        .join(';');
    final osrmUrl =
        'https://router.project-osrm.org/route/v1/driving/$coordsString?geometries=polyline&overview=full';

    try {
      final dio = Dio();
      final response = await dio.get(osrmUrl);
      if (response.statusCode == 200 && response.data['code'] == 'Ok') {
        final routes = response.data['routes'] as List;
        if (routes.isNotEmpty) {
          final points = routes[0]['geometry'] as String;
          final decoded = _decodePolyline(points);
          setState(() {
            _routePoints = decoded;
            _isLoadingRoute = false;
          });

          final lat = double.tryParse(
            _cubit.state.captain?['latitude']?.toString() ?? '',
          );
          final lng = double.tryParse(
            _cubit.state.captain?['longitude']?.toString() ?? '',
          );
          final captainLatLng = (lat != null && lng != null)
              ? LatLng(lat, lng)
              : null;
          _calculateRouteProgress(captainLatLng);

          // Fit map bounds to show the entire route
          if (_routePoints.isNotEmpty) {
            _fitMapBounds();
          }
          return;
        }
      }
    } catch (_) {
      // If OSRM fails, try Google Directions API as fallback
    }

    // 2. Google Directions API as a secondary fallback
    const apiKey = 'AIzaSyD28fMfWYgzxlx_kYPGdvH6FCJ145LhWxE';
    String originStr;
    String destStr;
    LatLng? waypoint;

    if (_routeMode == 'pickup') {
      originStr = '${start.latitude},${start.longitude}';
      if (pickup != null) {
        destStr = '${pickup.latitude},${pickup.longitude}';
      } else {
        destStr = '${destination.latitude},${destination.longitude}';
      }
    } else if (_routeMode == 'delivery') {
      if (pickup != null) {
        originStr = '${pickup.latitude},${pickup.longitude}';
      } else {
        originStr = '${start.latitude},${start.longitude}';
      }
      destStr = '${destination.latitude},${destination.longitude}';
    } else {
      originStr = '${start.latitude},${start.longitude}';
      destStr = '${destination.latitude},${destination.longitude}';
      waypoint = pickup;
    }

    String googleUrl =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$originStr&destination=$destStr';
    if (waypoint != null) {
      final waypointStr = '${waypoint.latitude},${waypoint.longitude}';
      googleUrl += '&waypoints=$waypointStr';
    }
    googleUrl += '&key=$apiKey';

    try {
      final dio = Dio();
      final response = await dio.get(googleUrl);
      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final routes = response.data['routes'] as List;
        if (routes.isNotEmpty) {
          final points = routes[0]['overview_polyline']['points'] as String;
          final decoded = _decodePolyline(points);
          setState(() {
            _routePoints = decoded;
            _isLoadingRoute = false;
          });

          final lat = double.tryParse(
            _cubit.state.captain?['latitude']?.toString() ?? '',
          );
          final lng = double.tryParse(
            _cubit.state.captain?['longitude']?.toString() ?? '',
          );
          final captainLatLng = (lat != null && lng != null)
              ? LatLng(lat, lng)
              : null;
          _calculateRouteProgress(captainLatLng);

          if (_routePoints.isNotEmpty) {
            _fitMapBounds();
          }
          return;
        }
      }
    } catch (_) {}

    // 3. Ultimate Fallback: draw straight lines if all APIs fail
    setState(() {
      if (_routeMode == 'pickup') {
        _routePoints = [start, ?pickup];
      } else if (_routeMode == 'delivery') {
        _routePoints = [?pickup, destination];
      } else {
        _routePoints = [start, ?pickup, destination];
      }
      _isLoadingRoute = false;
    });

    final lat = double.tryParse(
      _cubit.state.captain?['latitude']?.toString() ?? '',
    );
    final lng = double.tryParse(
      _cubit.state.captain?['longitude']?.toString() ?? '',
    );
    final captainLatLng = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : null;
    _calculateRouteProgress(captainLatLng);

    _fitMapBounds();
  }

  void _fitMapBounds() {
    if (_routePoints.isEmpty) return;
    if (_routePoints.length == 1) {
      _mapController.move(_routePoints.first, 14);
      return;
    }
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: _routePoints,
          padding: const EdgeInsets.all(40),
        ),
      );
    } catch (_) {
      // Fallback
      _mapController.move(_routePoints.first, 13);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  Widget _buildSegmentButton({
    required String mode,
    required String label,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _routeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_routeMode == mode) return;
          setState(() {
            _routeMode = mode;
          });
          if (_currentStartPoint != null && _currentDestinationPoint != null) {
            _fetchRoutePoints(
              start: _currentStartPoint!,
              destination: _currentDestinationPoint!,
              pickup: _currentPickupPoint,
            );
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF00bcd4), Color(0xFF00acc1)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF00bcd4).withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14.sp,
                color: isSelected
                    ? Colors.black
                    : (isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.6)),
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _calculateRouteProgress(LatLng? captainLatLng) {
    if (_routePoints.isEmpty) {
      setState(() {
        _completedPoints = [];
        _remainingPoints = [];
        _totalDistance = 0.0;
        _completedDistance = 0.0;
        _remainingDistance = 0.0;
        _progressPercentage = 0.0;
        _hasMoved = false;
      });
      return;
    }

    // 1. Calculate total distance of the route
    double totalDist = 0.0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      totalDist += _distanceBetween(_routePoints[i], _routePoints[i + 1]);
    }

    if (captainLatLng == null) {
      setState(() {
        _completedPoints = [];
        _remainingPoints = List.from(_routePoints);
        _totalDistance = totalDist;
        _completedDistance = 0.0;
        _remainingDistance = totalDist;
        _progressPercentage = 0.0;
        _hasMoved = false;
      });
      return;
    }

    // 2. Find the point in _routePoints closest to the captain's location
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < _routePoints.length; i++) {
      final dist = _distanceBetween(_routePoints[i], captainLatLng);
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // 3. Split the route points
    final completed = _routePoints.sublist(0, closestIndex + 1);
    final remaining = _routePoints.sublist(closestIndex);

    // Add captain's location to connect paths smoothly
    if (completed.isNotEmpty) {
      completed.add(captainLatLng);
    }
    if (remaining.isNotEmpty) {
      remaining.insert(0, captainLatLng);
    }

    // 4. Calculate completed distance
    double completedDist = 0.0;
    for (int i = 0; i < completed.length - 1; i++) {
      completedDist += _distanceBetween(completed[i], completed[i + 1]);
    }

    if (completedDist > totalDist) {
      completedDist = totalDist;
    }

    final remainingDist = totalDist - completedDist;
    final progress = totalDist > 0 ? (completedDist / totalDist) * 100 : 0.0;
    final hasMovedFromStart = completedDist > 0.1; // moved > 100m

    setState(() {
      _completedPoints = completed;
      _remainingPoints = remaining;
      _totalDistance = totalDist;
      _completedDistance = completedDist;
      _remainingDistance = remainingDist < 0.0 ? 0.0 : remainingDist;
      _progressPercentage = progress;
      _hasMoved = hasMovedFromStart;
    });
  }

  double _distanceBetween(LatLng p1, LatLng p2) {
    const p = 0.017453292519943295; // Math.pi / 180
    final a =
        0.5 -
        math.cos((p2.latitude - p1.latitude) * p) / 2 +
        math.cos(p1.latitude * p) *
            math.cos(p2.latitude * p) *
            (1 - math.cos((p2.longitude - p1.longitude) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  Widget _buildProgressCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_routePoints.isEmpty) return const SizedBox();

    final statusColor = _hasMoved
        ? AppColors.success
        : AppColors.warning;

    return Container(
      margin: EdgeInsets.only(top: 12.h, bottom: 6.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _hasMoved ? Icons.directions_run_rounded : Icons.hail_rounded,
                color: statusColor,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                _hasMoved
                    ? 'الكابتن على الطريق'
                    : 'الكابتن لم يتحرك من مكانه بعد',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              Text(
                '${_progressPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progressPercentage / 100,
              minHeight: 6.h,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricColumn(
                'المسافة الكلية',
                '${_totalDistance.toStringAsFixed(1)} كم',
              ),
              _metricColumn(
                'المسافة المقطوعة',
                '${_completedDistance.toStringAsFixed(1)} كم',
              ),
              _metricColumn(
                'المسافة المتبقية',
                '${_remainingDistance.toStringAsFixed(1)} كم',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricColumn(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalList({
    required ScrollController controller,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    double height = 140.0,
  }) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          final double delta = pointerSignal.scrollDelta.dy;
          if (delta != 0) {
            double newOffset = controller.offset + delta;
            if (newOffset < 0) newOffset = 0;
            if (newOffset > controller.position.maxScrollExtent) {
              newOffset = controller.position.maxScrollExtent;
            }
            controller.jumpTo(newOffset);
          }
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SizedBox(
          height: height,
          child: Scrollbar(
            controller: controller,
            thumbVisibility: true,
            trackVisibility: false,
            thickness: 4.0,
            radius: const Radius.circular(10),
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: itemCount,
              itemBuilder: itemBuilder,
            ),
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final double width;
  const _TripCard({required this.trip, required this.width});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trip = widget.trip;
    final from = trip['fromAddress'] ?? '';
    final to = trip['toAddress'] ?? '';
    final date = trip['date']?.toString() ?? '';
    final status = trip['status'] ?? '';
    final price = trip['price'] ?? 0;

    final statusColors = {
      'pending': isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary.withValues(alpha: 0.6),
      'in_progress': AppColors.warning,
      'completed': AppColors.success,
      'cancelled': AppColors.error,
    };
    final statusLabels = {
      'pending': 'قيد الانتظار',
      'in_progress': 'جاري التنفيذ',
      'completed': 'منتهية',
      'cancelled': 'ملغية',
    };

    final baseColor =
        statusColors[status] ?? (isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.textSecondary.withValues(alpha: 0.6));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width,
        margin: EdgeInsets.only(left: 10.w, bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: _isHovered
              ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06))
              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.3)
                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0.0, -2.0))
            : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'رحلة #${trip['id']}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabels[status] ?? status,
                    style: TextStyle(
                      fontSize: 8.sp,
                      color: baseColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6.sp,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          from,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 8.sp, color: Colors.red),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          to,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$price جنيه',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 8.sp,
                    color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.textSecondary,
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

class _DeliveryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final double width;
  final bool isSelected;
  final VoidCallback onTap;
  const _DeliveryCard({
    required this.item,
    required this.width,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<_DeliveryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final type = item['type'] == 'shipment' ? 'شحنة' : 'طلب شحن';
    final number = item['number'] ?? '';
    final isSelected = widget.isSelected;

    final status = item['status'] ?? '';
    Color statusColor;
    switch (status) {
      case 'منتهية':
      case 'Completed':
      case 'تم التسليم':
        statusColor = AppColors.success;
        break;
      case 'ملغية':
      case 'Cancelled':
      case 'ملغي':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.warning;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width,
        margin: EdgeInsets.only(left: 10.w, bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00bcd4).withValues(alpha: 0.15)
              : (_isHovered
                    ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06))
                    : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03))),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00bcd4)
                : (_isHovered
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06))),
            width: isSelected || _isHovered ? 1.5 : 1,
          ),
          boxShadow: isSelected || _isHovered
              ? [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFF00bcd4).withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0.0, -2.0))
            : Matrix4.identity(),
        child: InkWell(
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          splashColor: const Color(0xFF00bcd4).withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isSelected
                          ? const Color(0xFF00bcd4)
                          : (isDark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondary),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 8.sp,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                'رقم #$number',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'من: ${item['fromAddress'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.sp,
                  color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                ),
              ),
              Text(
                'إلى: ${item['toAddress'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.sp,
                  color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item['price'] ?? 0} جنيه',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  Icon(
                    Icons.map_rounded,
                    size: 12.sp,
                    color: isSelected
                        ? const Color(0xFF00bcd4)
                        : (isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverDocImage extends StatefulWidget {
  final Widget child;
  const _HoverDocImage({required this.child});

  @override
  State<_HoverDocImage> createState() => _HoverDocImageState();
}

class _HoverDocImageState extends State<_HoverDocImage> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.cyan.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        transform: _isHovered
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        child: widget.child,
      ),
    );
  }
}

class _InfoItemTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _InfoItemTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  State<_InfoItemTile> createState() => _InfoItemTileState();
}

class _InfoItemTileState extends State<_InfoItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 190.w,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
                : (isDark ? Colors.white.withValues(alpha: 0.015) : Colors.black.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFFF78710).withValues(alpha: 0.4)
                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFFF78710).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? const Color(0xFFF78710).withValues(alpha: 0.15)
                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 16.sp,
                  color: const Color(0xFFF78710),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: isDark ? Colors.white.withValues(alpha: 0.4) : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        widget.value,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isHovered) ...[
                SizedBox(width: 4.w),
                Icon(Icons.copy_rounded, size: 12.sp, color: isDark ? Colors.white54 : Colors.black54),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
