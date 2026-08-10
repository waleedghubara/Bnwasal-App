import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../cubit/merchants_cubit.dart';
import '../cubit/merchants_state.dart';
import 'merchant_detail_screen.dart';

class MerchantsListScreen extends StatefulWidget {
  const MerchantsListScreen({super.key});

  @override
  State<MerchantsListScreen> createState() => _MerchantsListScreenState();
}

class _MerchantsListScreenState extends State<MerchantsListScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _tableScrollCtrl = ScrollController();
  late AnimationController _refreshAnimController;

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    context.read<MerchantsCubit>().loadMerchants(refresh: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tableScrollCtrl.dispose();
    _refreshAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return BlocBuilder<MerchantsCubit, MerchantsState>(
      builder: (context, state) {
        if (state.isLoading) {
          if (!_refreshAnimController.isAnimating) {
            _refreshAnimController.repeat();
          }
        } else {
          if (_refreshAnimController.isAnimating) {
            _refreshAnimController.stop();
          }
        }
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
            _buildPagination(state),
          ],
        );
      },
    );
  }

  Widget _buildHeader(MerchantsState state, bool isWide) {
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
                'التجار',
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
                  color: const Color(0xFF004aad).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${state.total}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF004aad),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Spacer(),
              RotationTransition(
                turns: _refreshAnimController,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    tooltip: 'تحديث البيانات',
                    iconSize: 20.sp,
                    onPressed: state.isLoading
                        ? null
                        : () => context.read<MerchantsCubit>().loadMerchants(
                            refresh: true,
                          ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => context.read<MerchantsCubit>().searchMerchants(v),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'بحث عن تاجر...',
              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey[400], fontSize: 14.sp),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white70 : Colors.grey[600],
                size: 20.sp,
              ),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          _buildFilterChips(context, state),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, MerchantsState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filters = [
      {'status': '', 'label': 'الكل', 'color': const Color(0xFF004aad)},
      {'status': 'active', 'label': 'نشط', 'color': const Color(0xFF10b981)},
      {
        'status': 'pending_verification',
        'label': 'قيد التحقق',
        'color': const Color(0xFFf59e0b),
      },
      {
        'status': 'pending_otp',
        'label': 'لم يؤكد (OTP)',
        'color': const Color(0xFF9ca3af),
      },
      {'status': 'banned', 'label': 'محظور', 'color': const Color(0xFFef4444)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = state.status == f['status'];
          final baseColor = f['color'] as Color;
          return Container(
            margin: EdgeInsets.only(left: 8.w),
            child: InkWell(
              onTap: () {
                context.read<MerchantsCubit>().changeStatusFilter(
                  f['status'] as String,
                );
              },
              borderRadius: BorderRadius.circular(20),
              mouseCursor: SystemMouseCursors.click,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? baseColor.withValues(alpha: 0.15)
                      : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? baseColor.withValues(alpha: 0.5)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: baseColor.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: baseColor,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? (isDark ? Colors.white : baseColor)
                            : (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(MerchantsState state, bool isWide) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (state.isLoading && state.merchants.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }
    if (state.merchants.isEmpty) {
      return Center(
        child: Text(
          'لا يوجد تجار',
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
            fontSize: 15.sp,
          ),
        ),
      );
    }

    if (isWide) {
      return _buildTableView(state);
    }
    return _buildCardView(state);
  }

  Widget _buildCardView(MerchantsState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return RefreshIndicator(
      color: Colors.cyan,
      backgroundColor: isDark ? const Color(0xFF14142a) : Colors.white,
      onRefresh: () async {
        await context.read<MerchantsCubit>().loadMerchants(refresh: true);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: state.merchants.length,
        itemBuilder: (_, i) {
          final m = state.merchants[i] as Map<String, dynamic>;
          return _buildCard(m);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> m) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
    final store = m['storeName'] ?? '';
    final status = m['status'] ?? '';
    final city = m['city'] ?? '';
    final orders = '${m['totalOrders'] ?? 0}';
    final shipments = '${m['totalShipments'] ?? 0}';
    final isOnline = m['isOnline'] == true;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(m['id']),
          hoverColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
          child: Ink(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.015),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    _avatar(
                      m['profileImage']?.toString(),
                      name.isNotEmpty ? name[0] : '?',
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF10b981),
                            border: Border.all(
                              color: isDark ? const Color(0xFF0a0e27) : Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 12.w),
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
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          _statusBadge(status),
                        ],
                      ),
                      if (store.isNotEmpty) SizedBox(height: 2.h),
                      if (store.isNotEmpty)
                        Text(
                          store,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          if (city.isNotEmpty) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 12.sp,
                              color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              city,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.4),
                              ),
                            ),
                            SizedBox(width: 12.w),
                          ],
                          Icon(
                            Icons.receipt_outlined,
                            size: 12.sp,
                            color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            'طلبات: $orders',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.4),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 12.sp,
                            color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            'شحنات: $shipments',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
                  size: 24.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableView(MerchantsState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        // Table Header
        Container(
          margin: EdgeInsets.symmetric(horizontal: 32.w, vertical: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(flex: 35, child: _th('التاجر')),
              Expanded(flex: 20, child: _th('المتجر')),
              Expanded(flex: 15, child: _th('المدينة')),
              Expanded(flex: 12, child: _th('الحالة')),
              Expanded(flex: 10, child: _th('الطلبات')),
              Expanded(flex: 10, child: _th('الشحنات')),
              Expanded(flex: 8, child: const SizedBox()),
            ],
          ),
        ),
        // Table Rows with Scrollbar
        Expanded(
          child: Scrollbar(
            controller: _tableScrollCtrl,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _tableScrollCtrl,
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              itemCount: state.merchants.length,
              itemBuilder: (context, index) {
                final mm = state.merchants[index] as Map<String, dynamic>;
                final name = '${mm['firstName'] ?? ''} ${mm['lastName'] ?? ''}'
                    .trim();
                final store = mm['storeName'] ?? '';
                final city = mm['city'] ?? '';
                final status = mm['status'] ?? '';
                final imgUrl = mm['profileImage']?.toString();
                final online = mm['isOnline'] == true;

                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openDetail(mm['id']),
                      hoverColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                      child: Ink(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.015) : Colors.black.withValues(alpha: 0.015),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 35,
                              child: _tdMerchant(
                                imgUrl,
                                name,
                                isOnline: online,
                              ),
                            ),
                            Expanded(flex: 20, child: _td(store)),
                            Expanded(flex: 15, child: _td(city)),
                            Expanded(
                              flex: 12,
                              child: _td(status, isStatus: true),
                            ),
                            Expanded(
                              flex: 10,
                              child: _td('${mm['totalOrders'] ?? 0}'),
                            ),
                            Expanded(
                              flex: 10,
                              child: _td('${mm['totalShipments'] ?? 0}'),
                            ),
                            Expanded(
                              flex: 8,
                              child: Center(
                                child: Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF004aad,
                                    ).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: FaIcon(
                                    FontAwesomeIcons.eye,
                                    size: 11.sp,
                                    color: const Color(0xFF004aad),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _tdMerchant(String? imgUrl, String name, {bool isOnline = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
      child: Row(
        children: [
          Stack(
            children: [
              _avatar(imgUrl, name.isNotEmpty ? name[0] : '?', size: 36),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10b981),
                      border: Border.all(
                        color: isDark ? const Color(0xFF0a0e27) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _td(String text, {bool isMain = false, bool isStatus = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (isStatus) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
        child: _statusBadge(text),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isMain ? 13.sp : 12.sp,
          fontWeight: isMain ? FontWeight.w600 : FontWeight.w400,
          color: isDark
              ? Colors.white.withValues(alpha: isMain ? 0.85 : 0.5)
              : Colors.black.withValues(alpha: isMain ? 0.85 : 0.5),
        ),
      ),
    );
  }

  Widget _avatar(String? url, String letter, {double size = 42}) {
    if (url != null && url.isNotEmpty) {
      return Container(
        width: size.w,
        height: size.w,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          EndPoint.getCleanImageUrl(url),
          fit: BoxFit.cover,
          width: size.w,
          height: size.w,
          errorBuilder: (_, _, _) => _avatarFallback(letter, size: size),
        ),
      );
    }
    return _avatarFallback(letter, size: size);
  }

  Widget _avatarFallback(String letter, {double size = 42}) {
    return Container(
      width: size.w,
      height: size.w,
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
          fontSize: (size * 0.43).sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Color bg, textColor;
    switch (status) {
      case 'active':
        bg = const Color(0xFF10b981).withValues(alpha: 0.15);
        textColor = const Color(0xFF10b981);
      case 'banned':
        bg = Colors.red.withValues(alpha: 0.15);
        textColor = Colors.red;
      case 'pending_verification':
        bg = const Color(0xFFf59e0b).withValues(alpha: 0.15);
        textColor = const Color(0xFFf59e0b);
      default:
        bg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
        textColor = isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black54;
    }
    final labels = {
      'active': 'نشط',
      'banned': 'محظور',
      'pending_verification': 'قيد التحقق',
      'pending_otp': 'لم يؤكد',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        labels[status] ?? status,
        style: TextStyle(
          fontSize: 10.sp,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _openDetail(int id) {
    if (!mounted) return;
    final cubit = context.read<MerchantsCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: MerchantDetailScreen(merchantId: id),
        ),
      ),
    );
  }

  List<dynamic> _getPageNumbers(int currentPage, int totalPages) {
    final List<dynamic> pages = [];
    if (totalPages <= 5) {
      for (int i = 1; i <= totalPages; i++) {
        pages.add(i);
      }
    } else {
      pages.add(1);
      if (currentPage > 3) {
        pages.add('...');
      }

      int start = currentPage - 1;
      int end = currentPage + 1;

      if (currentPage <= 2) {
        start = 2;
        end = 3;
      } else if (currentPage >= totalPages - 1) {
        start = totalPages - 2;
        end = totalPages - 1;
      }

      for (int i = start; i <= end; i++) {
        if (i > 1 && i < totalPages) {
          pages.add(i);
        }
      }

      if (currentPage < totalPages - 2) {
        pages.add('...');
      }
      pages.add(totalPages);
    }
    return pages;
  }

  Widget _buildPagination(MerchantsState state) {
    if (state.total <= state.limit) return const SizedBox();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalPages = (state.total / state.limit).ceil();
    final currentPage = state.page;
    final pages = _getPageNumbers(currentPage, totalPages);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final infoText = Text(
      'عرض ${(currentPage - 1) * state.limit + 1} - ${currentPage * state.limit > state.total ? state.total : currentPage * state.limit} من أصل ${state.total}',
      style: TextStyle(
        color: isDark ? Colors.white54 : Colors.black54,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      ),
    );

    final controlsRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white70 : Colors.black54),
            disabledColor: isDark ? Colors.white24 : Colors.black12,
            onPressed: currentPage > 1
                ? () =>
                      context.read<MerchantsCubit>().changePage(currentPage - 1)
                : null,
            tooltip: 'الصفحة التالية',
          ),
          ...pages.map((p) {
            if (p == '...') {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text(
                  '...',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12.sp),
                ),
              );
            }

            final isSelected = p == currentPage;
            return GestureDetector(
              onTap: () {
                if (!isSelected) {
                  context.read<MerchantsCubit>().changePage(p as int);
                }
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF004aad)
                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF004aad)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$p',
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            disabledColor: isDark ? Colors.white24 : Colors.black12,
            onPressed: currentPage < totalPages
                ? () =>
                      context.read<MerchantsCubit>().changePage(currentPage + 1)
                : null,
            tooltip: 'الصفحة السابقة',
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14142a) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
      ),
      child: isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                infoText,
                SizedBox(height: 10.h),
                controlsRow,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [infoText, controlsRow],
            ),
    );
  }
}
