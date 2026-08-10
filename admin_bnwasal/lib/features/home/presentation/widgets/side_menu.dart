// ignore_for_file: unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:admin_bnwasal/core/theme/app_assets.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/routes/routes.dart';
import 'package:admin_bnwasal/features/auth/presentation/cubit/auth_cubit.dart';
import '../cubit/navigation_cubit.dart';
import '../cubit/navigation_state.dart';

class SideMenu extends StatelessWidget {
  final bool isRail;
  final VoidCallback? onClose;

  const SideMenu({super.key, this.isRail = false, this.onClose});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return BlocBuilder<NavigationCubit, NavigationState>(
      builder: (context, state) {
        return Container(
          width: isRail ? 72.w : (isTablet ? 270.w : 270.w),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF041930), // Deep Dark Navy
                Color(0xFF020d1a), // Even Darker Navy
              ],
            ),
            border: Border(
              left: BorderSide(color: Color(0xFF132e4d), width: 1),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(context, isTablet, isRail),
              if (!isRail) _buildDivider(context),
              Expanded(
                child: _buildMenuItems(
                  context,
                  state.currentPage,
                  isTablet,
                  isRail,
                ),
              ),
              if (!isRail) _buildDivider(context),
              if (!isRail) _buildFooter(context, isTablet),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet, bool isRail) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (isRail) {
      return Container(
        height: 72.h,
        alignment: Alignment.center,
        child: Container(
          width: 38.w,
          height: 38.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(AppAssets.appLogo2, fit: BoxFit.cover),
          ),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 24.h, 18.w, 18.h),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            padding: EdgeInsets.all(5.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(child: Image.asset(AppAssets.logo)),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة التحكم',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'بنواصل أدمن',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
                size: 20.sp,
              ),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      color: isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.05),
      height: 1,
      thickness: 1,
    );
  }

  Widget _buildMenuItems(
    BuildContext context,
    AppPage current,
    bool isTablet,
    bool isRail,
  ) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState.user;
    final userRole = user?['role']?.toString() ?? 'admin';
    final rawPerms = user?['permissions'];
    final Set<String> permissions;
    if (rawPerms is List) {
      permissions = rawPerms.map((e) => e.toString()).toSet();
    } else if (rawPerms is String && rawPerms.isNotEmpty) {
      permissions = rawPerms
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    } else {
      permissions = {};
    }
    final isAdmin = userRole == 'admin';

    bool hasAccess(AppPage page) {
      if (isAdmin) return true;
      return _pagePermission(page).any((p) => permissions.contains(p));
    }

    final items = [
      // 1. لوحة التحكم - الإحصائيات
      if (hasAccess(AppPage.dashboard))
        _MenuItem(AppPage.dashboard, 'الإحصائيات', AppAssets.dashboard),
      // 2. قبول الحسابات
      if (hasAccess(AppPage.pendingAccounts))
        _MenuItem(
          AppPage.pendingAccounts,
          'قبول الحسابات',
          AppAssets.pendingVerifications,
        ),
      // 3. طلبات وشحنات اليوم
      if (hasAccess(AppPage.todayOrdersShipments))
        _MenuItem(
          AppPage.todayOrdersShipments,
          'طلبات وشحنات اليوم',
          AppAssets.todayOrders,
        ),
      // 4. دفعات الشحنات والطلبات
      if (hasAccess(AppPage.directPayments))
        _MenuItem(
          AppPage.directPayments,
          'دفعات الشحنات والطلبات',
          AppAssets.deposits,
        ),
      // 5. الرحلات اليومية
      if (hasAccess(AppPage.todayTrips))
        _MenuItem(AppPage.todayTrips, 'الرحلات اليومية', AppAssets.todayTrips),
      // 6. الدعم
      if (hasAccess(AppPage.complaints))
        _MenuItem(AppPage.complaints, 'الدعم', AppAssets.complaints),
      // 7. جميع الشحنات والطلبات
      if (hasAccess(AppPage.allOrdersShipments))
        _MenuItem(
          AppPage.allOrdersShipments,
          'جميع الشحنات والطلبات',
          AppAssets.orders,
        ),
      // 7.1 قسم الكوبون والخصومات
      if (hasAccess(AppPage.coupons))
        _MenuItem(AppPage.coupons, 'الكوبونات والخصومات', AppAssets.coupons),
      // 8. جميع الرحلات
      if (hasAccess(AppPage.trips))
        _MenuItem(AppPage.trips, 'جميع الرحلات', AppAssets.trips),
      // 9. المحفظة العامة
      if (hasAccess(AppPage.wallet))
        _MenuItem(AppPage.wallet, 'المحفظة العامة', AppAssets.wallet),
      // 10. طلبات السحب
      if (hasAccess(AppPage.withdrawals))
        _MenuItem(AppPage.withdrawals, 'طلبات السحب', AppAssets.withdrawals),
      // 11. الإشعارات
      if (hasAccess(AppPage.notifications))
        _MenuItem(AppPage.notifications, 'الإشعارات', AppAssets.notification),
      // 12. رسائل المستخدمين
      if (hasAccess(AppPage.userMessages))
        _MenuItem(AppPage.userMessages, 'رسائل المستخدمين', AppAssets.messages),
      // 13. إرسال إشعار
      if (hasAccess(AppPage.sendNotification))
        _MenuItem(
          AppPage.sendNotification,
          'إرسال إشعار',
          AppAssets.notification,
        ),
      // 14. التجار
      if (hasAccess(AppPage.merchants))
        _MenuItem(AppPage.merchants, 'التجار', AppAssets.merchants),
      // 15. الكابتن
      if (hasAccess(AppPage.captains))
        _MenuItem(AppPage.captains, 'الكباتن', AppAssets.captains),
      // 16. الموظفين
      if (hasAccess(AppPage.employees))
        _MenuItem(AppPage.employees, 'الموظفين', AppAssets.employees),
      // الإعدادات (غير مذكورة، تبقى في مكانها آخر القائمة)
      if (hasAccess(AppPage.settings))
        _MenuItem(AppPage.settings, 'الإعدادات', AppAssets.settings),
    ];

    return RepaintBoundary(
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: isRail ? 8.w : 12.w,
          vertical: 14.h,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final selected = current == item.page;
          return RepaintBoundary(
            child: _buildMenuItem(context, item, selected, isTablet, isRail),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    _MenuItem item,
    bool selected,
    bool isTablet,
    bool isRail,
  ) {
    final labelSize = isRail ? 8.sp : (isTablet ? 14.5.sp : 14.5.sp);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color contentColor = selected
        ? (isDark ? Colors.white : Colors.white)
        : (isDark ? Colors.white : Colors.white);

    final SvgPicture iconWidget = SvgPicture.asset(
      item.iconPath,
      cacheColorFilter: true,
      width: isRail ? 22.w : 20.w,
      height: isRail ? 22.w : 20.w,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isRail ? 6.h : 8.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (onClose != null) onClose!();
            context.read<NavigationCubit>().navigateTo(item.page);
          },
          hoverColor: const Color.fromARGB(
            255,
            255,
            255,
            255,
          ).withValues(alpha: 0.1),
          splashColor: AppColors.secondary.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isRail ? 0 : 12.w,
              vertical: isRail ? 12.h : 11.h,
            ),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        const Color.fromARGB(
                          0,
                          247,
                          135,
                          16,
                        ).withValues(alpha: 0.12),
                        const Color.fromARGB(
                          0,
                          247,
                          135,
                          16,
                        ).withValues(alpha: 0.01),
                      ],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: AppColors.secondary, width: 0.8)
                  : Border.all(color: Colors.transparent, width: 0.8),
            ),
            child: isRail
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      SizedBox(height: 6.h),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: labelSize,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: contentColor,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.secondary.withValues(alpha: 0.12)
                              : (isDark
                                    ? Colors.black.withValues(alpha: 0.7)
                                    : Colors.black.withValues(alpha: 0.05)),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: iconWidget),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: labelSize,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: contentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isTablet) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile shortcut
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  context.read<NavigationCubit>().navigateTo(AppPage.profile),
              hoverColor: const Color.fromARGB(
                255,
                255,
                255,
                255,
              ).withValues(alpha: 0.04),
              splashColor: const Color.fromARGB(
                255,
                255,
                255,
                255,
              ).withValues(alpha: 0.08),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        AppAssets.profile,
                        cacheColorFilter: true,
                        width: 20.w,
                        height: 20.w,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'الملف الشخصي',
                      style: TextStyle(
                        fontSize: isTablet ? 14.sp : 14.sp,
                        color: isDark ? Colors.white : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          // Logout
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                context.read<AuthCubit>().logout();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
              },
              hoverColor: AppColors.error.withValues(alpha: 0.04),
              splashColor: AppColors.error.withValues(alpha: 0.08),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Center(
                        child: SvgPicture.asset(
                          AppAssets.logout,
                          cacheColorFilter: true,
                          width: 18.w,
                          height: 18.w,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontSize: isTablet ? 14.sp : 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<String> _pagePermission(AppPage page) {
    switch (page) {
      case AppPage.dashboard:
        return {'dashboard'};
      case AppPage.merchants:
        return {'merchants'};
      case AppPage.captains:
        return {'captains'};
      case AppPage.trips:
        return {'trips'};
      case AppPage.orders:
        return {'orders'};
      case AppPage.users:
        return {'users'};
      case AppPage.todayOrdersShipments:
        return {'todayOrdersShipments'};
      case AppPage.allOrdersShipments:
        return {'todayOrdersShipments', 'orders'};
      case AppPage.todayTrips:
        return {'todayTrips'};
      case AppPage.pendingAccounts:
        return {'pendingAccounts'};
      case AppPage.complaints:
        return {'complaints'};
      case AppPage.notifications:
        return {'notifications'};
      case AppPage.sendNotification:
        return {'sendNotification', 'notifications'};
      case AppPage.employees:
        return {'employees'};
      case AppPage.settings:
        return {'settings'};
      case AppPage.directPayments:
        return {'directPayments'};
      case AppPage.withdrawals:
        return {'withdrawals'};
      case AppPage.wallet:
        return {'wallet'};
      case AppPage.userMessages:
        return {'userMessages'};
      case AppPage.coupons:
        return {'coupons'};
      default:
        return {};
    }
  }
}

class _MenuItem {
  final AppPage page;
  final String label;
  final String iconPath;

  const _MenuItem(this.page, this.label, this.iconPath);
}
