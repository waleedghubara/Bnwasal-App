import 'package:admin_bnwasal/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/cache/cache_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import '../cubit/pending_accounts_cubit.dart';
import '../cubit/pending_accounts_state.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';

class PendingAccountsDetailScreen extends StatefulWidget {
  final int accountId;
  const PendingAccountsDetailScreen({super.key, required this.accountId});

  @override
  State<PendingAccountsDetailScreen> createState() =>
      _PendingAccountsDetailScreenState();
}

class _PendingAccountsDetailScreenState
    extends State<PendingAccountsDetailScreen> {
  late final PendingAccountsCubit _cubit;
  String? _token;
  bool _isTokenLoaded = false;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<PendingAccountsCubit>();
    _cubit.loadAccountDetail(widget.accountId);
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
    _cubit.clearDetail();
    super.dispose();
  }

  Map<String, dynamic> _getVehicleInfo(String? type) {
    switch (type) {
      case 'scooter':
        return {
          'title': 'سكوتر',
          'icon': Icons.electric_scooter_rounded,
          'color': const Color(0xFF10b981), // Emerald green
        };
      case 'motorcycle':
        return {
          'title': 'موتوسيكل',
          'icon': Icons.two_wheeler_rounded,
          'color': const Color(0xFF3b82f6), // Blue
        };
      case 'car':
        return {
          'title': 'سيارة',
          'icon': Icons.directions_car_rounded,
          'color': const Color(0xFFa855f7), // Purple
        };
      case 'public':
        return {
          'title': 'مواصلات',
          'icon': Icons.directions_bus_rounded,
          'color': const Color(0xFFf97316), // Orange
        };
      default:
        return {
          'title': 'غير محدد',
          'icon': Icons.help_outline_rounded,
          'color': Colors.grey,
        };
    }
  }

  Widget _vehicleBadge(String? type) {
    if (type == null || type.isEmpty) return const SizedBox();
    final info = _getVehicleInfo(type);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: (info['color'] as Color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (info['color'] as Color).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            info['icon'] as IconData,
            size: 12.sp,
            color: info['color'] as Color,
          ),
          SizedBox(width: 4.w),
          Text(
            info['title'] as String,
            style: TextStyle(
              fontSize: 10.sp,
              color: info['color'] as Color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0a0e27) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0a0e27) : Colors.white,
        elevation: 0,
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 18.sp,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'تفاصيل الحساب المعلق',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: BlocBuilder<PendingAccountsCubit, PendingAccountsState>(
        builder: (context, state) {
          if (state.isLoadingDetail) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state.detailError != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'حدث خطأ أثناء تحميل البيانات',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: () => context
                        .read<PendingAccountsCubit>()
                        .loadAccountDetail(widget.accountId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004aad),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          if (state.account == null) return const SizedBox();

          final m = state.account!;
          final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
          final email = m['email'] ?? '';
          final phone = m['phone'] ?? '';
          final role = m['role'] ?? '';
          final city = m['city'] ?? '';
          final store = m['storeName'] ?? '';
          final wallet = '${m['walletBalance'] ?? 0}';
          final vehicleType = m['vehicleType']?.toString();

          final isWide = MediaQuery.of(context).size.width >= 950;
          final pad = isWide ? 32.w : 16.w;

          Widget content;
          if (isWide) {
            content = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(
                        name,
                        email,
                        phone,
                        role,
                        city,
                        store,
                        wallet,
                        m,
                      ),
                      if (_isTokenLoaded) ...[
                        SizedBox(height: 20.h),
                        _buildDocumentsSection(state),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 24.w),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (role == 'captain') ...[
                        _buildVehicleSection(vehicleType),
                        SizedBox(height: 20.h),
                      ],
                      _buildStatsSection(state),
                      SizedBox(height: 20.h),
                      _buildActions(state),
                      if (state.processingError != null)
                        Padding(
                          padding: EdgeInsets.only(top: 12.h),
                          child: Text(
                            state.processingError!,
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      SizedBox(height: 24.h),
                      _buildDeleteSection(m),
                    ],
                  ),
                ),
              ],
            );
          } else {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(
                  name,
                  email,
                  phone,
                  role,
                  city,
                  store,
                  wallet,
                  m,
                ),
                if (role == 'captain') ...[
                  SizedBox(height: 20.h),
                  _buildVehicleSection(vehicleType),
                ],
                SizedBox(height: 20.h),
                _buildStatsSection(state),
                if (_isTokenLoaded) ...[
                  SizedBox(height: 20.h),
                  _buildDocumentsSection(state),
                ],
                SizedBox(height: 24.h),
                _buildActions(state),
                if (state.processingError != null)
                  Padding(
                    padding: EdgeInsets.only(top: 12.h),
                    child: Text(
                      state.processingError!,
                      style: TextStyle(
                        color: Colors.red.shade300,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                SizedBox(height: 24.h),
                _buildDeleteSection(m),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1200.w),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 16.h, pad, 48.h),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(
    String name,
    String email,
    String phone,
    String role,
    String city,
    String store,
    String wallet,
    Map<String, dynamic> m,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final roleLabel = role == 'merchant' ? 'تاجر' : 'كابتن';
    final status = m['status'] ?? '';
    final imgUrl = m['profileImage']?.toString();
    final vehicleType = m['vehicleType']?.toString();
    final labels = {
      'pending_verification': 'قيد التحقق',
      'pending_otp': 'لم يؤكد رقم الهاتف',
    };
    Color statusColor = const Color(0xFFf59e0b);
    if (status == 'pending_otp') {
      statusColor = Colors.orange;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0a0e27) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(imgUrl, name.isNotEmpty ? name[0] : '?'),
              SizedBox(width: 18.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        _roleBadge(roleLabel),
                        if (role == 'captain' && vehicleType != null) ...[
                          SizedBox(width: 8.w),
                          _vehicleBadge(vehicleType),
                        ],
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          labels[status] ?? status,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade300,
            height: 1,
          ),
          SizedBox(height: 20.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 14.h,
            alignment: WrapAlignment.start,
            children: [
              _infoItem(Icons.person_outline, 'الاسم بالكامل', name),
              if (role == 'merchant')
                _infoItem(
                  Icons.store_outlined,
                  'اسم المتجر',
                  store.isNotEmpty ? store : 'غير محدد',
                ),
              _infoItem(Icons.person_pin_outlined, 'نوع الحساب', roleLabel),
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

  Widget _buildVehicleSection(String? vehicleType) {
    final isWide = MediaQuery.of(context).size.width >= 950;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (vehicleType == null || vehicleType.isEmpty) {
      return Align(
        alignment: isWide ? Alignment.centerRight : Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420.w),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 28.sp,
                    color: Colors.red.shade300,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تنبيه: وسيلة نقل غير مسجلة',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.red.shade300,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'لم يقم هذا الكابتن بإدخال وسيلة التنقل الخاصة به بعد.',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final info = _getVehicleInfo(vehicleType);
    return Align(
      alignment: isWide ? Alignment.centerRight : Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420.w),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: (info['color'] as Color).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (info['color'] as Color).withValues(alpha: 0.2),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: (info['color'] as Color).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  info['icon'] as IconData,
                  size: 32.sp,
                  color: info['color'] as Color,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وسيلة النقل المختارة للكابتن',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      info['title'] as String,
                      style: TextStyle(
                        fontSize: 20.sp,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: (info['color'] as Color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'جاهز للعمل',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: info['color'] as Color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(PendingAccountsState state) {
    final stats = state.stats;
    if (stats == null || stats.isEmpty) return const SizedBox();

    final role = state.account?['role'] ?? '';
    final List<Widget> statItems = [];

    if (role == 'merchant') {
      final orders = stats['orders'] ?? {};
      final shipments = stats['shipments'] ?? {};
      statItems.addAll([
        _buildStatItem(
          'إجمالي الطلبات',
          '${orders['totalOrders'] ?? 0}',
          Icons.shopping_basket_outlined,
          const Color(0xFF3b82f6),
        ),
        _buildStatItem(
          'الطلبات المكتملة',
          '${orders['completedOrders'] ?? 0}',
          Icons.check_circle_outline,
          const Color(0xFF10b981),
        ),
        _buildStatItem(
          'إجمالي الشحنات',
          '${shipments['totalShipments'] ?? 0}',
          Icons.local_shipping_outlined,
          const Color(0xFFa855f7),
        ),
        _buildStatItem(
          'الشحنات المكتملة',
          '${shipments['completedShipments'] ?? 0}',
          Icons.verified_outlined,
          const Color(0xFF06b6d4),
        ),
      ]);
    } else if (role == 'captain') {
      final trips = stats['trips'] ?? {};
      statItems.addAll([
        _buildStatItem(
          'إجمالي الرحلات',
          '${trips['totalTrips'] ?? 0}',
          Icons.map_outlined,
          const Color(0xFF3b82f6),
        ),
        _buildStatItem(
          'الرحلات المكتملة',
          '${trips['completedTrips'] ?? 0}',
          Icons.task_alt_rounded,
          const Color(0xFF10b981),
        ),
      ]);
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (statItems.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0a0e27) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإحصائيات والنشاط المكتشف',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 18.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 16.h,
            alignment: WrapAlignment.start,
            children: statItems,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 150.w,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(PendingAccountsState state) {
    final Map<String, dynamic>? sources = state.documents;
    final Map<String, dynamic>? driverDocs = state.driverDocuments;
    final Map<String, dynamic> acct = state.account ?? {};

    String? front = sources?['nationalIdFront']?.toString();
    String? back = sources?['nationalIdBack']?.toString();
    String? nationalId = sources?['nationalId']?.toString();

    if ((front == null || front.isEmpty) && driverDocs != null) {
      front = driverDocs['nationalIdFront']?.toString();
    }
    if ((back == null || back.isEmpty) && driverDocs != null) {
      back = driverDocs['nationalIdBack']?.toString();
    }
    if ((nationalId == null || nationalId.isEmpty) && driverDocs != null) {
      nationalId = driverDocs['nationalId']?.toString();
    }

    if ((front == null || front.isEmpty)) {
      front = acct['nationalIdFront']?.toString();
    }
    if ((back == null || back.isEmpty)) {
      back = acct['nationalIdBack']?.toString();
    }
    if ((nationalId == null || nationalId.isEmpty)) {
      nationalId = acct['nationalId']?.toString();
    }

    final hasFront = front != null && front.isNotEmpty;
    final hasBack = back != null && back.isNotEmpty;
    final hasId = nationalId != null && nationalId.isNotEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0a0e27) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أوراق الهوية الوطنية والمستندات',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 18.h),
          if (hasId) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0a0e27) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 20.sp,
                    color: const Color(0xFFf59e0b),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رقم الهوية الوطنية',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black54,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        nationalId,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFf59e0b),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
          ] else ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 20.sp,
                    color: Colors.red.shade300,
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رقم الهوية الوطنية',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'غير مدخل',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
          ],
          if (!hasFront && !hasBack)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade300,
                    size: 24.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'تنبيه: لم يتم رفع صور البطاقة الشخصية (الوجه الأمامي والخلفي).',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 16.w,
                runSpacing: 16.h,
                alignment: WrapAlignment.start,
                children: [
                  if (hasFront)
                    _docImage(front, 'الوجه الأمامي للبطاقة')
                  else
                    _missingDocPlaceholder('الوجه الأمامي للبطاقة'),
                  if (hasBack)
                    _docImage(back, 'الوجه الخلفي للبطاقة')
                  else
                    _missingDocPlaceholder('الوجه الخلفي للبطاقة'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _missingDocPlaceholder(String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 320.w,
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.15),
          style: BorderStyle.solid,
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 30.h),
          Icon(Icons.portrait_rounded, color: Colors.red.shade300, size: 48.sp),
          SizedBox(height: 12.h),
          Text(
            'صورة غير مرفوعة',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade300,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          SizedBox(height: 30.h),
        ],
      ),
    );
  }

  Widget _buildActions(PendingAccountsState state) {
    if (state.isProcessing) {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          child: const CircularProgressIndicator(color: AppColors.success),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 950;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: isWide ? Alignment.centerRight : Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 450.w),
        child: Row(
          children: [
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  onPressed: () => _handleApprove(),
                  icon: Icon(
                    Icons.check_rounded,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                  label: Text(
                    'موافقة وتفعيل',
                    style: GoogleFonts.tajawal(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    elevation: 4,
                    shadowColor: AppColors.success.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  onPressed: () => _handleReject(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  label: Text(
                    'رفض الطلب',
                    style: GoogleFonts.tajawal(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    elevation: 4,
                    shadowColor: Colors.red.shade600.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteSection(Map<String, dynamic> m) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.12),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'حذف الحساب نهائياً',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade300,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'سيؤدي حذف هذا الحساب إلى إزالته وجميع مستنداته من قاعدة البيانات بشكل نهائي ودون إمكانية للاسترجاع.',
            style: GoogleFonts.tajawal(
              fontSize: 14.sp,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black,
              height: 1.4,
            ),
          ),
          SizedBox(height: 20.h),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 220.w),
              child: SizedBox(
                width: double.infinity,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleDelete(m['id']),
                    icon: const Icon(
                      Icons.delete_forever_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      'حذف الحساب نهائياً',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  String _cleanImageUrl(String? path) {
    return EndPoint.getCleanImageUrl(path);
  }

  Widget _docImage(String url, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fullUrl = _cleanImageUrl(url);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showFullImage(url, label),
        child: Container(
          width: 320.w,
          margin: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.015),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 180.h,
                  child: Image.network(
                    fullUrl,
                    headers: _token != null
                        ? {'Authorization': 'Bearer $_token'}
                        : null,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180.h,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint(
                        '❌ [PendingAccountsDetail] Failed to load image: $fullUrl',
                      );
                      return Container(
                        color: Colors.red.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red.shade300,
                              size: 28.sp,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'خطأ في تحميل الصورة',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade300,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.zoom_in_rounded,
                      size: 16.sp,
                      color: const Color(0xFFf59e0b),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(String url, String label) {
    final fullUrl = _cleanImageUrl(url);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(label, style: const TextStyle(color: Colors.white)),
            leading: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                fullUrl,
                headers: _token != null
                    ? {'Authorization': 'Bearer $_token'}
                    : null,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleApprove() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1a1a3e) : Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 20.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'قبول الحساب وتفعيله',
              style: AppTypography.h5.copyWith(
                fontSize: 16.sp,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من الموافقة على تفعيل هذا الحساب؟ سيتمكن المستخدم من تسجيل الدخول فوراً واستخدام كافة الميزات.',
          style: AppTypography.h5.copyWith(
            fontSize: 13.sp,
            color: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.black.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: AppTypography.h5.copyWith(
                  fontSize: 14.sp,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'تفعيل الحساب',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final err = await _cubit.approveAccount(widget.accountId);
    if (!mounted) return;
    if (err.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          showCloseIcon: true,
          closeIconColor: Colors.white,
          content: Text(
            'تم تفعيل الحساب بنجاح ✅',
            style: AppTypography.h5.copyWith(
              fontSize: 14.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      context.read<PendingAccountsCubit>().loadAccounts(refresh: true);
    }
  }

  Future<void> _handleReject() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1a1a3e) : Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              'رفض طلب التفعيل',
              style: AppTypography.h5.copyWith(
                fontSize: 16.sp,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رفض تفعيل هذا الحساب؟ سيتم حظر الحساب وإشعار المستخدم.',
          style: AppTypography.h5.copyWith(
            fontSize: 13.sp,
            color: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.black.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'رفض الطلب',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final err = await _cubit.rejectAccount(widget.accountId);
    if (!mounted) return;
    if (err.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          showCloseIcon: true,
          closeIconColor: Colors.white,
          content: Text(
            'تم رفض طلب تفعيل الحساب ❌',
            style: AppTypography.h5.copyWith(
              fontSize: 14.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      context.read<PendingAccountsCubit>().loadAccounts(refresh: true);
    }
  }

  Future<void> _handleDelete(dynamic id) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1a1a3e) : Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              'حذف الحساب نهائياً',
              style: AppTypography.h5.copyWith(
                fontSize: 16.sp,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          'تنبيه! هل أنت متأكد من حذف الحساب بشكل كامل من السيرفر؟ لا يمكن التراجع عن هذا الإجراء.',
          style: AppTypography.h5.copyWith(
            fontSize: 13.sp,
            color: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.black.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: AppTypography.h5.copyWith(
                  fontSize: 14.sp,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'تأكيد الحذف النهائي',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    int idInt;
    try {
      idInt = id is int ? id : int.parse(id.toString());
    } catch (_) {
      return;
    }

    final err = await _cubit.rejectAccount(idInt);
    if (!mounted) return;
    if (err.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          showCloseIcon: true,
          closeIconColor: Colors.white,
          content: Text(
            'تم حذف الحساب نهائياً من السيرفر',
            style: AppTypography.h5.copyWith(
              fontSize: 14.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      context.read<PendingAccountsCubit>().loadAccounts(refresh: true);
    }
  }

  Widget _infoItem(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Tooltip(
      message: 'انقر لنسخ $label',
      textStyle: GoogleFonts.tajawal(
        fontSize: 12.sp,
        color: isDark ? Colors.white : Colors.black,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a1a3e) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade300,
        ),
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
                style: GoogleFonts.tajawal(
                  fontSize: 13.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              backgroundColor: const Color(0xFF004aad),
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _avatar(String? url, String letter, {double size = 60}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatarWidget = url != null && url.isNotEmpty
        ? Container(
            width: size.w,
            height: size.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black,
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              EndPoint.getCleanImageUrl(url),
              fit: BoxFit.cover,
              width: size.w,
              height: size.w,
              errorBuilder: (_, _, _) => _avatarFallback(letter, size: size),
            ),
          )
        : _avatarFallback(letter, size: size);

    if (url != null && url.isNotEmpty) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showFullImage(url, 'الصورة الشخصية'),
          child: Tooltip(
            message: 'انقر لعرض الصورة الشخصية',
            textStyle: GoogleFonts.tajawal(
              fontSize: 12.sp,
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1a1a3e) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300,
              ),
            ),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                avatarWidget,
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: const BoxDecoration(
                    color: Color(0xFFf59e0b),
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

  Widget _avatarFallback(String letter, {double size = 60}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade300,
          width: 2,
        ),
        gradient: const LinearGradient(
          colors: [Color(0xFFf59e0b), Color(0xFF004aad)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: (size * 0.4).sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _roleBadge(String label) {
    final isMerchant = label == 'تاجر';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: isMerchant
            ? const Color(0xFF004aad).withValues(alpha: 0.12)
            : const Color(0xFF0ea5e9).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMerchant
              ? const Color(0xFF004aad).withValues(alpha: 0.3)
              : const Color(0xFF0ea5e9).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          color: isMerchant ? AppColors.primary : const Color(0xFF0ea5e9),
          fontWeight: FontWeight.bold,
        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200.w,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.05)
                : isDark
                ? Colors.white.withValues(alpha: 0.015)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
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
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 16.sp, color: AppColors.primary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.black,
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
                          fontSize: 13.sp,
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isHovered) ...[
                SizedBox(width: 4.w),
                Icon(Icons.copy_rounded, size: 12.sp, color: Colors.white54),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
