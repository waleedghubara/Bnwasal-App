// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        Widget content = Column(
          children: [
            _buildHeader(state.unreadCount, state.notifications.length, isWide),
            if (state.isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (state.notifications.isEmpty)
              _buildEmpty(isWide)
            else
              Expanded(child: _buildList(state, isWide)),
          ],
        );

        if (isWide) {
          content = Center(
            child: SizedBox(width: 800.w, child: content),
          );
        }

        return content;
      },
    );
  }

  Widget _buildHeader(int unread, int total, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isWide ? 16.w : 16.w,
        20.h,
        isWide ? 16.w : 16.w,
        16.h,
      ),
      child: Row(
        children: [
          Text(
            'الإشعارات',
            style: TextStyle(
              fontSize: isWide ? 18.sp : 16.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(width: 8.w),
          if (unread > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                '$unread غير مقروء',
                style: TextStyle(
                  fontSize: 9.sp,
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const Spacer(),
          if (unread > 0)
            GestureDetector(
              onTap: () => context.read<NotificationsCubit>().markAllAsRead(),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.done_all_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'قراءة الكل',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (total > 0) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () => _confirmClearAll(context),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_sweep_outlined,
                        size: 12,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'مسح الكل',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.grey.shade300,
                ),
              ),
              child: FaIcon(
                FontAwesomeIcons.bellSlash,
                size: 48.sp,
                color: isDark
                    ? AppColors.textLight.withValues(alpha: 0.5)
                    : Colors.black,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'صندوق الوارد فارغ',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'لا توجد إشعارات جديدة في الوقت الحالي',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black54,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(NotificationsState state, bool isWide) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        isWide ? 16.w : 16.w,
        0,
        isWide ? 16.w : 16.w,
        32.h,
      ),
      itemCount: state.notifications.length,
      itemBuilder: (_, i) =>
          _buildNotificationCard(state.notifications[i], isWide),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = notif['title']?.toString() ?? '';
    final body = notif['body']?.toString() ?? '';
    final isRead = notif['isRead'] == 1 || notif['isRead'] == true;
    final category = notif['category']?.toString() ?? 'system';
    final createdAt = notif['createdAt']?.toString() ?? '';
    final id = notif['id'].toString();

    FaIconData icon;
    Color iconColor;
    switch (category) {
      case 'warning':
        icon = FontAwesomeIcons.triangleExclamation;
        iconColor = const Color.fromARGB(255, 255, 208, 0);
        break;
      case 'order':
        icon = FontAwesomeIcons.receipt;
        iconColor = AppColors.primary;
        break;
      case 'shipment':
        icon = FontAwesomeIcons.truck;
        iconColor = AppColors.success;
        break;
      case 'complaint':
        icon = FontAwesomeIcons.commentDots;
        iconColor = AppColors.error;
        break;
      default:
        icon = FontAwesomeIcons.solidBell;
        iconColor = const Color.fromARGB(255, 255, 208, 0);
    }

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'سحب للحذف',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8.w),
            const FaIcon(
              FontAwesomeIcons.trash,
              color: AppColors.error,
              size: 20,
            ),
            SizedBox(width: 8.w),
          ],
        ),
      ),
      onDismissed: (_) =>
          context.read<NotificationsCubit>().deleteNotification(id),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        child: _HoverCardWrapper(
          isRead: isRead,
          onTap: () {
            if (!isRead) {
              context.read<NotificationsCubit>().markAsRead(id);
            }
            _showNotificationDetails(context, notif);
          },
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Center(
                    child: FaIcon(icon, color: iconColor, size: 18.sp),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: isRead
                                    ? FontWeight.bold
                                    : FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary,
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          height: 1.4,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      if (createdAt.isNotEmpty)
                        Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.clock,
                              size: 14.sp,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.black,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationDetails(
    BuildContext context,
    Map<String, dynamic> notif,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = notif['title']?.toString() ?? '';
    final body = notif['body']?.toString() ?? '';
    final category = notif['category']?.toString() ?? 'system';
    final createdAt = notif['createdAt']?.toString() ?? '';

    IconData icon;
    Color iconColor;
    String categoryName;
    switch (category) {
      case 'warning':
        icon = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFf59e0b);
        categoryName = 'تنبيه هام';
        break;
      case 'order':
        icon = Icons.receipt_long_rounded;
        iconColor = AppColors.primary;
        categoryName = 'تحديث طلب';
        break;
      case 'shipment':
        icon = Icons.local_shipping_rounded;
        iconColor = AppColors.success;
        categoryName = 'حركة شحنة';
        break;
      case 'complaint':
        icon = Icons.feedback_outlined;
        iconColor = AppColors.error;
        categoryName = 'شكوى ودعم فني';
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = const Color(0xFF8b5cf6);
        categoryName = 'إشعار النظام';
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF0d0d1f) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade300,
            ),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85 > 460
                ? 460
                : MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: iconColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: iconColor),
                          const SizedBox(width: 6),
                          Text(
                            categoryName,
                            style: TextStyle(
                              fontSize: 11,
                              color: iconColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark
                            ? Colors.white.withOpacity(0.4)
                            : Colors.black54,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                if (createdAt.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black38,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withOpacity(0.35)
                              : Colors.black45,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: SelectableText(
                    body,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.8)
                          : Colors.black87,
                      fontSize: 13,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'إغلاق',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
      if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }

  void _confirmClearAll(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 20,
            ),
            SizedBox(width: 8.w),
            Text(
              'حذف الكل',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف جميع الإشعارات نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black87,
            fontSize: 12.sp,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black54,
                fontSize: 12.sp,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<NotificationsCubit>().clearAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              elevation: 0,
            ),
            child: Text(
              'حذف',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ويدجت مخصصة لإضافة تأثير التحويم (Hover) الاحترافي والتكبير البسيط عند تمرير مؤشر الماوس
class _HoverCardWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isRead;

  const _HoverCardWrapper({
    required this.child,
    required this.onTap,
    required this.isRead,
  });

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
                  ? AppColors.secondary.withOpacity(0.5)
                  : (widget.isRead
                        ? (isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.grey.shade300)
                        : AppColors.primary.withOpacity(0.25)),
              width: _isHovered ? 1.5 : 1.0,
            ),
            gradient: LinearGradient(
              colors: [
                _isHovered
                    ? AppColors.secondary.withOpacity(0.08)
                    : (widget.isRead
                          ? (isDark ? AppColors.surfaceDark : Colors.white)
                          : AppColors.primary.withOpacity(0.06)),
                _isHovered
                    ? Colors.white.withOpacity(0.01)
                    : (widget.isRead
                          ? (isDark
                                ? AppColors.surfaceDark.withOpacity(0.5)
                                : Colors.white)
                          : AppColors.primary.withOpacity(0.02)),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppColors.secondary.withOpacity(0.08)
                    : (isDark
                          ? Colors.black.withOpacity(0.12)
                          : Colors.black.withOpacity(0.03)),
                blurRadius: _isHovered ? 16 : 12,
                offset: _isHovered ? const Offset(0, 6) : const Offset(0, 4),
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
