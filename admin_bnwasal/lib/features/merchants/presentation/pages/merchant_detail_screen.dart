import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/cache/cache_helper.dart';
import '../cubit/merchants_cubit.dart';
import '../cubit/merchants_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

class MerchantDetailScreen extends StatefulWidget {
  final int merchantId;
  const MerchantDetailScreen({super.key, required this.merchantId});

  @override
  State<MerchantDetailScreen> createState() => _MerchantDetailScreenState();
}

class _MerchantDetailScreenState extends State<MerchantDetailScreen> {
  late final MerchantsCubit _cubit;
  String? _token;
  bool _isTokenLoaded = false;
  final _activityScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _cubit = context.read<MerchantsCubit>();
    _cubit.loadMerchantDetail(widget.merchantId);
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
    _activityScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0a0e27) : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0a0e27) : theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 18.sp,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'تفاصيل التاجر',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: BlocBuilder<MerchantsCubit, MerchantsState>(
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
                        .read<MerchantsCubit>()
                        .loadMerchantDetail(widget.merchantId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004aad),
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          if (state.merchant == null) return const SizedBox();

          final m = state.merchant!;
          final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
          final store = m['storeName'] ?? '';
          final email = m['email'] ?? '';
          final phone = m['phone'] ?? '';
          final city = m['city'] ?? '';
          final wallet = '${m['walletBalance'] ?? 0}';

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 48.w : 16.w,
              8.h,
              isWide ? 48.w : 16.w,
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
                          store,
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
                        store,
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
    MerchantsState state,
    String name,
    String store,
    String email,
    String phone,
    String city,
    String wallet,
    Map<String, dynamic> m,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(name, store, email, phone, city, wallet, m),
        SizedBox(height: 20.h),
        _buildStatsGrid(state),
        if (_isTokenLoaded) ...[
          SizedBox(height: 20.h),
          _buildDocumentsSection(state.documents),
        ],
      ],
    );
  }

  Widget _buildRightColumn(MerchantsState state) {
    final merchant = state.merchant;
    return Column(
      children: [
        _buildAnalysisCard(state.analysis),
        SizedBox(height: 20.h),
        _buildRecentActivity(state.recentActivity),
        SizedBox(height: 20.h),
        if (merchant != null) _buildActions(merchant),
      ],
    );
  }

  Widget _buildInfoCard(
    String name,
    String store,
    String email,
    String phone,
    String city,
    String wallet,
    Map<String, dynamic> m,
  ) {
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
        statusColor = const Color(0xFF10b981);
        break;
      case 'banned':
        statusColor = Colors.red;
        break;
      case 'pending_verification':
        statusColor = const Color(0xFFf59e0b);
        break;
      default:
        statusColor = Colors.white.withValues(alpha: 0.4);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (store.isNotEmpty)
                      Text(
                        store,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
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
            textStyle: TextStyle(fontSize: 10.sp, color: Colors.white),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a3e),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Tooltip(
      message: 'انقر لنسخ $label',
      textStyle: TextStyle(fontSize: 10.sp, color: Colors.white),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a3e),
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

  Widget _buildStatsGrid(MerchantsState state) {
    final s = state.stats;
    if (s == null) return const SizedBox();

    final orders = s['orders'] as Map<String, dynamic>?;
    final shipments = s['shipments'] as Map<String, dynamic>?;
    final wallet = s['wallet'] as Map<String, dynamic>?;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
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
              color: isDark ? Colors.white : Colors.black87,
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
                'مكتملة',
                '${orders?['completedOrders'] ?? 0}',
                Icons.check_circle_outline_rounded,
                const Color(0xFF10b981),
              ),
              _statTile(
                'ملغية',
                '${orders?['cancelledOrders'] ?? 0}',
                Icons.cancel_outlined,
                Colors.red.shade400,
              ),
              _statTile(
                'إيرادات الطلبات',
                '${_fmtNum(orders?['totalRevenue'])} جنيه',
                Icons.trending_up_rounded,
                const Color(0xFF004aad),
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
                const Color(0xFF10b981),
              ),
              _statTile(
                'شحنات ملغية',
                '${shipments?['cancelledShipments'] ?? 0}',
                Icons.cancel_outlined,
                Colors.red.shade400,
              ),
              _statTile(
                'إيرادات الشحنات',
                '${_fmtNum(shipments?['totalShipmentRevenue'])} جنيه',
                Icons.trending_up_rounded,
                const Color(0xFFF78710),
              ),
              _statTile(
                'إجمالي الإيداعات',
                '${_fmtNum(wallet?['totalDeposits'])} جنيه',
                Icons.add_circle_outline_rounded,
                const Color(0xFF10b981),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final front = docs?['nationalIdFront'] as String?;
    final back = docs?['nationalIdBack'] as String?;
    final nationalId = docs?['nationalId'] as String?;

    final hasFront = front != null && front.isNotEmpty;
    final hasBack = back != null && back.isNotEmpty;
    final hasId = nationalId != null && nationalId.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.credit_card_rounded,
                size: 16.sp,
                color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
              ),
              SizedBox(width: 8.w),
              Text(
                'البطاقة الشخصية والمستندات',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (hasId) ...[
            Text(
              'الرقم القومي: $nationalId',
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 14.h),
          ] else ...[
            Text(
              'الرقم القومي: غير مدخل',
              style: TextStyle(fontSize: 12.sp, color: Colors.red.shade300),
            ),
            SizedBox(height: 14.h),
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
                    size: 20.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'لم يتم رفع صور البطاقة الشخصية بعد للتاجر (الوجه الأمامي والخلفي).',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: [
                if (hasFront)
                  _docImage(front, 'الوجه الأمامي')
                else
                  _missingDocPlaceholder('الوجه الأمامي'),
                if (hasBack)
                  _docImage(back, 'الوجه الخلفي')
                else
                  _missingDocPlaceholder('الوجه الخلفي'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _missingDocPlaceholder(String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 200.w,
      height: 130.w,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.15),
          style: BorderStyle.solid,
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.portrait_rounded, color: Colors.red.shade300, size: 32.sp),
          SizedBox(height: 8.h),
          Text(
            'غير مرفوع',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade300,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9.sp, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  String _cleanImageUrl(String? path) {
    return EndPoint.getCleanImageUrl(path);
  }

  Widget _docImage(String path, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
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
                        '❌ [MerchantDetail] Failed to load image: $url',
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
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  void _showFullscreenImage(String url, String label) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => Scaffold(
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
                    '❌ [MerchantDetail Fullscreen] Failed to load image: $url',
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
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Widget _buildActions(Map<String, dynamic> merchant) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentStatus = merchant['status'] ?? '';
    final isBanned = currentStatus == 'banned';
    final id = merchant['id'] as int? ?? 0;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
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
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.gavel_rounded,
                  size: 14.sp,
                  color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'الإجراءات',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
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
                label: isBanned ? 'إلغاء حظر التاجر' : 'حظر التاجر',
                desc: isBanned
                    ? 'السماح للتاجر باستخدام المنصة مرة أخرى'
                    : 'منع التاجر من الوصول للمنصة',
                color: isBanned
                    ? const Color(0xFF10b981)
                    : const Color(0xFFf59e0b),
                gradientColors: isBanned
                    ? [
                        const Color(0xFF10b981).withValues(alpha: 0.12),
                        const Color(0xFF10b981).withValues(alpha: 0.02),
                      ]
                    : [
                        const Color(0xFFf59e0b).withValues(alpha: 0.12),
                        const Color(0xFFf59e0b).withValues(alpha: 0.02),
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
                desc: 'إشعار فوري للتاجر برسالة تحذيرية',
                color: const Color(0xFFf59e0b),
                gradientColors: [
                  const Color(0xFFf59e0b).withValues(alpha: 0.12),
                  const Color(0xFFf59e0b).withValues(alpha: 0.02),
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
                desc: 'إزالة كاملة للتاجر وكل بياناته - لا يمكن التراجع',
                color: Colors.red,
                gradientColors: [
                  Colors.red.withValues(alpha: 0.12),
                  Colors.red.withValues(alpha: 0.02),
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.4),
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
    final cubit = context.read<MerchantsCubit>();
    final newStatus = currentlyBanned ? 'active' : 'banned';
    final err = await cubit.updateMerchantStatus(id, newStatus);
    if (!mounted) return;
    if (err.isEmpty) {
      cubit.loadMerchantDetail(id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlyBanned ? 'تم إلغاء الحظر' : 'تم حظر التاجر'),
          backgroundColor: currentlyBanned
              ? const Color(0xFF10b981)
              : const Color(0xFFf59e0b),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $err'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a3e),
        title: Text(
          'تأكيد الحذف',
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
        content: Text(
          'هل أنت متأكد من حذف هذا التاجر نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
    final cubit = context.read<MerchantsCubit>();
    final err = await cubit.deleteMerchant(id);
    if (!mounted) return;
    if (err.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف التاجر'),
          backgroundColor: Color(0xFF10b981),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $err'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showWarningDialog(int id) async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1a1a3e),
          title: Text(
            'إرسال تحذير',
            style: TextStyle(color: Colors.white, fontSize: 16.sp),
          ),
          content: SizedBox(
            width: 300.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'عنوان التحذير',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 14.sp,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
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
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'نص التحذير',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 14.sp,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
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
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'إرسال',
                style: TextStyle(color: const Color(0xFFf59e0b)),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('العنوان والنص مطلوبان'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final cubit = context.read<MerchantsCubit>();
    final err = await cubit.sendWarning(id, titleCtrl.text, bodyCtrl.text);
    if (!mounted) return;
    if (err.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال التحذير'),
          backgroundColor: const Color(0xFF10b981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $err'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildAnalysisCard(Map<String, dynamic>? analysis) {
    if (analysis == null) return const SizedBox();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final behavior = analysis['behavior'] ?? '';
    final score = (analysis['behaviorScore'] ?? 0) as int;
    final isActive = analysis['isActiveNow'] ?? false;
    final avg = analysis['avgActivitiesPerDay'] ?? 0.0;
    final daysSince = analysis['daysSinceLastActive'] ?? 0;
    final totalActivities = analysis['totalActivities'] ?? 0;

    Color scoreColor;
    if (score >= 80) {
      scoreColor = const Color(0xFF10b981);
    } else if (score >= 50) {
      scoreColor = const Color(0xFFf59e0b);
    } else {
      scoreColor = Colors.red;
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
            isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
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
                  color: isDark ? Colors.white : Colors.black87,
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      labels[behavior] ?? '',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(
                          Icons.circle_rounded,
                          size: 8.sp,
                          color: isActive
                              ? const Color(0xFF10b981)
                              : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2)),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          isActive ? 'نشط حالياً' : 'غير نشط حالياً',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isActive
                                ? const Color(0xFF10b981)
                                : (isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35)),
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
                daysSince == 0 ? 'اليوم' : 'منذ ${daysSince} أيام',
                scoreColor,
              ),
              _analysisItem(
                'إجمالي الأنشطة',
                totalActivities.toString(),
                scoreColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCircle(int score, Color color) {
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
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisItem(String label, String value, Color color) {
    return SizedBox(
      width: 160.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white.withValues(alpha: 0.3),
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
    if (activity == null || activity.isEmpty) return const SizedBox();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardWidth = 160.w;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
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
                color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
              ),
              SizedBox(width: 8.w),
              Text(
                'آخر الأنشطة',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildHorizontalList(
            controller: _activityScrollCtrl,
            itemCount: activity.length,
            height: 105.h,
            itemBuilder: (context, index) {
              final item = activity[index] as Map<String, dynamic>;
              return _ActivityCard(item: item, width: cardWidth);
            },
          ),
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

class _ActivityCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final double width;
  const _ActivityCard({required this.item, required this.width});

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final type = item['type'] == 'order' ? 'طلب' : 'شحنة';
    final ref = item['refNumber'] ?? '';
    final status = item['status'] ?? '';

    Color statusColor;
    switch (status) {
      case 'منتهية':
      case 'Completed':
      case 'تم التسليم':
      case 'منتهي':
      case 'تم التنفيذ':
        statusColor = const Color(0xFF10b981);
        break;
      case 'ملغية':
      case 'Cancelled':
      case 'ملغي':
      case 'ملغاة':
        statusColor = Colors.red;
        break;
      default:
        statusColor = const Color(0xFFf59e0b);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
              ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04))
              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.015)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF004aad).withValues(alpha: 0.3)
                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF004aad).withValues(alpha: 0.08),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  item['type'] == 'order'
                      ? Icons.receipt_outlined
                      : Icons.local_shipping_outlined,
                  size: 16.sp,
                  color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
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
              '$type #$ref',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              _formatDate(item['createdAt']),
              style: TextStyle(
                fontSize: 9.sp,
                color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
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
          width: 190.w,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04))
                : (isDark ? Colors.white.withValues(alpha: 0.015) : Colors.black.withValues(alpha: 0.015)),
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
                        color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
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
                          color: isDark ? Colors.white : Colors.black87,
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
