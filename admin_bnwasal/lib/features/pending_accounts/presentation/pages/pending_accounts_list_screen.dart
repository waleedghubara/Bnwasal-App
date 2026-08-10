import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../cubit/pending_accounts_cubit.dart';
import '../cubit/pending_accounts_state.dart';
import 'pending_accounts_detail_screen.dart';

class PendingAccountsListScreen extends StatefulWidget {
  const PendingAccountsListScreen({super.key});

  @override
  State<PendingAccountsListScreen> createState() =>
      _PendingAccountsListScreenState();
}

class _PendingAccountsListScreenState extends State<PendingAccountsListScreen>
    with SingleTickerProviderStateMixin {
  final _roles = [
    {'label': 'الكل', 'value': ''},
    {'label': 'تجار', 'value': 'merchant'},
    {'label': 'كباتن', 'value': 'captain'},
  ];
  late AnimationController _refreshAnimController;

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    context.read<PendingAccountsCubit>().loadAccounts(refresh: true);
  }

  @override
  void dispose() {
    _refreshAnimController.dispose();
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
    final isWide = MediaQuery.of(context).size.width >= 900;
    return BlocBuilder<PendingAccountsCubit, PendingAccountsState>(
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
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'خطأ في تحميل البيانات: ${state.error}',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: _buildList(state, isWide)),
            _buildPagination(state),
          ],
        );
      },
    );
  }

  Widget _buildHeader(PendingAccountsState state, bool isWide) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isWide ? 32.w : 16.w,
        24.h,
        isWide ? 32.w : 16.w,
        16.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'قبول الحسابات الجديدة',
                style: TextStyle(
                  fontSize: isWide ? 24.sp : 20.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 14.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFf59e0b).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFf59e0b).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${state.total} معلق',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFFf59e0b),
                    fontWeight: FontWeight.w800,
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
                        : () => context
                              .read<PendingAccountsCubit>()
                              .loadAccounts(refresh: true),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: _roles.map((r) {
              final selected = state.roleFilter == r['value'];
              return Padding(
                padding: EdgeInsets.only(left: 8.w),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context
                        .read<PendingAccountsCubit>()
                        .filterByRole(r['value'] as String),
                    hoverColor: const Color(0xFFf59e0b).withValues(alpha: 0.08),
                    child: Ink(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFf59e0b).withValues(alpha: 0.18)
                            : isDark
                            ? Colors.white12
                            : Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFf59e0b).withValues(alpha: 0.4)
                              : isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        r['label'] as String,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: selected
                              ? const Color(0xFFf59e0b)
                              : isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black87,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList(PendingAccountsState state, bool isWide) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (state.isLoading && state.accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }
    if (state.accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 56.sp,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black87.withValues(alpha: 0.12),
            ),
            SizedBox(height: 16.h),
            Text(
              'لا يوجد حسابات بانتظار الموافقة حالياً',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (isWide) {
      return _buildTableView(state);
    }
    return _buildCardView(state);
  }

  Widget _buildCardView(PendingAccountsState state) {
    return RefreshIndicator(
      color: const Color(0xFFf59e0b),
      backgroundColor: const Color(0xFF14142a),
      onRefresh: () async {
        await context.read<PendingAccountsCubit>().loadAccounts(refresh: true);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        itemCount: state.accounts.length,
        itemBuilder: (_, i) {
          final m = state.accounts[i] as Map<String, dynamic>;
          return _buildCard(m);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> m) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
    final role = m['role'] ?? '';
    final roleLabel = role == 'merchant' ? 'تاجر' : 'كابتن';
    final store = m['storeName'] ?? '';
    final city = m['city'] ?? '';
    final createdAt = m['createdAt'] ?? '';
    final dateStr = createdAt.toString().length >= 10
        ? createdAt.toString().substring(0, 10)
        : '';

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Material(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(m['id']),
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white,
          child: Ink(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade200,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                _avatar(
                  m['profileImage']?.toString(),
                  name.isNotEmpty ? name[0] : '?',
                ),
                SizedBox(width: 14.w),
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
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          _roleBadge(roleLabel),
                          if (role == 'captain') ...[
                            SizedBox(width: 6.w),
                            _vehicleBadge(m['vehicleType']?.toString()),
                          ],
                        ],
                      ),
                      if (store.isNotEmpty) SizedBox(height: 4.h),
                      if (store.isNotEmpty)
                        Text(
                          store,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          if (city.isNotEmpty) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 12.sp,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.black.withValues(alpha: 0.4),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              city,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.black.withValues(alpha: 0.5),
                              ),
                            ),
                            SizedBox(width: 14.w),
                          ],
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12.sp,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.4),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                  size: 24.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableView(PendingAccountsState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        // Column headers
        Container(
          margin: EdgeInsets.symmetric(horizontal: 32.w),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black12.withValues(alpha: 0.02)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.black12.withValues(alpha: 0.04)
                  : Colors.white,
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 300, child: _th('الاسم الكامل')),
              Expanded(flex: 140, child: _th('نوع الحساب')),
              Expanded(flex: 150, child: _th('المدينة / المتجر')),
              Expanded(flex: 130, child: _th('تاريخ التسجيل')),
              Expanded(flex: 120, child: _th('الحالة')),
              Expanded(flex: 70, child: Center(child: _th('تفاصيل'))),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        // Rows
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 4.h),
            itemCount: state.accounts.length,
            itemBuilder: (context, index) {
              final m = state.accounts[index] as Map<String, dynamic>;
              final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'
                  .trim();
              final role = m['role'] ?? '';
              final roleLabel = role == 'merchant' ? 'تاجر' : 'كابتن';
              final store = m['storeName'] ?? '';
              final city = m['city'] ?? '';
              final createdAt = m['createdAt'] ?? '';
              final dateStr = createdAt.toString().length >= 10
                  ? createdAt.toString().substring(0, 10)
                  : '';
              final imgUrl = m['profileImage']?.toString();

              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openDetail(m['id']),
                    hoverColor: isDark ? Colors.black26 : Colors.black12,
                    child: Ink(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black12 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade200 : Colors.black12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 300, child: _tdName(imgUrl, name)),
                          Expanded(
                            flex: 140,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _roleBadge(roleLabel),
                                if (role == 'captain') ...[
                                  SizedBox(width: 6.w),
                                  _vehicleBadge(m['vehicleType']?.toString()),
                                ],
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 150,
                            child: _td(
                              store.isNotEmpty
                                  ? store
                                  : (city.isNotEmpty ? city : 'غير محدد'),
                            ),
                          ),
                          Expanded(flex: 130, child: _td(dateStr)),
                          Expanded(flex: 120, child: _pendingBadge()),
                          Expanded(
                            flex: 70,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFf59e0b,
                                  ).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: FaIcon(
                                  FontAwesomeIcons.eye,
                                  size: 11.sp,
                                  color: const Color(0xFFf59e0b),
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
      ],
    );
  }

  Widget _th(String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black,
      ),
    );
  }

  Widget _td(String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _tdName(String? imgUrl, String name) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        _avatar(imgUrl, name.isNotEmpty ? name[0] : '?', size: 36),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
          color: isMerchant ? const Color(0xFF38bdf8) : const Color(0xFF0ea5e9),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _pendingBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: const Color(0xFFf59e0b).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFf59e0b).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFf59e0b),
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                'قيد التحقق',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: const Color(0xFFf59e0b),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(String? url, String letter, {double size = 42}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (url != null && url.isNotEmpty) {
      return Container(
        width: size.w,
        height: size.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url.startsWith('http') ? url : '${EndPoint.imageBaseUrl}$url',
          fit: BoxFit.cover,
          width: size.w,
          height: size.w,
          errorBuilder: (_, __, ___) => _avatarFallback(letter, size: size),
        ),
      );
    }
    return _avatarFallback(letter, size: size);
  }

  Widget _avatarFallback(String letter, {double size = 42}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black,
          width: 1.5,
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
          color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black,
          fontSize: (size * 0.4).sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _openDetail(int id) {
    if (!mounted) return;
    final cubit = context.read<PendingAccountsCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: PendingAccountsDetailScreen(accountId: id),
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

  Widget _buildPagination(PendingAccountsState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (state.total <= state.limit) return const SizedBox();

    final totalPages = (state.total / state.limit).ceil();
    final currentPage = state.page;
    final pages = _getPageNumbers(currentPage, totalPages);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final infoText = Text(
      'عرض ${(currentPage - 1) * state.limit + 1} - ${currentPage * state.limit > state.total ? state.total : currentPage * state.limit} من أصل ${state.total}',
      style: TextStyle(
        color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black,
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
            icon: Icon(
              Icons.chevron_left_rounded,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.black,
            ),
            disabledColor: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.black,
            onPressed: currentPage > 1
                ? () => context.read<PendingAccountsCubit>().changePage(
                    currentPage - 1,
                  )
                : null,
            tooltip: 'الصفحة التالية',
          ),
          ...pages.map((p) {
            if (p == '...') {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text(
                  '...',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.black,
                    fontSize: 12.sp,
                  ),
                ),
              );
            }

            final isSelected = p == currentPage;
            return GestureDetector(
              onTap: () {
                if (!isSelected) {
                  context.read<PendingAccountsCubit>().changePage(p as int);
                }
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFf59e0b)
                      : isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFf59e0b)
                        : isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$p',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isDark
                        ? Colors.white70
                        : Colors.black,
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
              color: isDark ? Colors.white70 : Colors.black,
            ),
            disabledColor: isDark ? Colors.white24 : Colors.black,
            onPressed: currentPage < totalPages
                ? () => context.read<PendingAccountsCubit>().changePage(
                    currentPage + 1,
                  )
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
            color: isDark
                ? Colors.black
                : const Color.fromARGB(255, 190, 232, 245),
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
