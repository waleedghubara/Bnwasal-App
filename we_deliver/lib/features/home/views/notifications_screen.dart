// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:we_deliver/core/theme/colors.dart';
import '../data/models/notification_model.dart';
import '../presentation/manager/notification_cubit.dart';
import '../presentation/manager/notification_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedCategory =
      'all'; // 'all', 'order', 'wallet', 'offer', 'system'

  @override
  void initState() {
    super.initState();
    context.read<NotificationCubit>().loadNotifications();
  }

  List<NotificationModel> _getFilteredNotifications(
    List<NotificationModel> notifications,
  ) {
    if (_selectedCategory == 'all') {
      return notifications;
    }
    return notifications.where((n) => n.category == _selectedCategory).toList();
  }

  void _markAllAsRead() {
    context.read<NotificationCubit>().markAllAsRead();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.done_all_rounded, color: Colors.white, size: 20.sp),
            SizedBox(width: 8.w),
            const Text('تم تحديد جميع الإشعارات كمقروءة'),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }

  void _clearAllNotifications() {
    final fullList = context.read<NotificationCubit>().allNotifications;
    if (fullList.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'مسح كل الإشعارات؟',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف جميع الإشعارات نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'إلغاء',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13.sp),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                context.read<NotificationCubit>().clearAll();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('تم مسح جميع الإشعارات بنجاح'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text('حذف الكل', style: TextStyle(fontSize: 13.sp)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNotification(NotificationModel notification, int index) {
    context.read<NotificationCubit>().deleteNotification(notification.id);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم حذف الإشعار'),
        action: SnackBarAction(
          label: 'تراجع',
          textColor: AppColors.secondary,
          onPressed: () {
            context.read<NotificationCubit>().restoreNotification(
              notification,
              index,
            );
          },
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }

  void _showNotificationDetail(NotificationModel notification) {
    context.read<NotificationCubit>().markAsRead(notification.id);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    _getCategoryBadge(notification.category),
                    const Spacer(),
                    Text(
                      _formatTimeDetail(notification.timestamp),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  notification.body,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? const Color(0xFF2C2C2C)
                              : Colors.grey.shade100,
                          foregroundColor: isDarkMode
                              ? Colors.white
                              : Colors.black87,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text('إغلاق', style: TextStyle(fontSize: 13.sp)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getCategoryBadge(String category) {
    Color color;
    String name;

    switch (category) {
      case 'order':
        color = AppColors.primary;
        name = 'الطلبات والشحنات';
        break;
      case 'wallet':
        color = Colors.green;
        name = 'المحفظة والمدفوعات';
        break;
      case 'offer':
        color = Colors.orange;
        name = 'العروض والخصومات';
        break;
      case 'system':
      default:
        color = Colors.purple;
        name = 'تنبيه النظام';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            name,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeDetail(DateTime dt) {
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'م' : 'ص';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} - $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'الإشعارات',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 20.sp,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            BlocBuilder<NotificationCubit, NotificationState>(
              builder: (context, state) {
                final hasNotifications = context
                    .read<NotificationCubit>()
                    .allNotifications
                    .isNotEmpty;
                if (!hasNotifications) return const SizedBox.shrink();

                return PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    size: 22.sp,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  onSelected: (value) {
                    if (value == 'read_all') {
                      _markAllAsRead();
                    } else if (value == 'clear_all') {
                      _clearAllNotifications();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'read_all',
                      child: Row(
                        children: [
                          Icon(
                            Icons.done_all,
                            size: 18.sp,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'تحديد الكل كمقروء',
                            style: TextStyle(fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_sweep_outlined,
                            size: 18.sp,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'مسح الكل',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            // Filter Tabs Section
            _buildFiltersBar(isDarkMode),

            // Content List
            Expanded(
              child: BlocBuilder<NotificationCubit, NotificationState>(
                builder: (context, state) {
                  if (state is NotificationLoading &&
                      context
                          .read<NotificationCubit>()
                          .allNotifications
                          .isEmpty) {
                    return _buildSkeletonList(isDarkMode);
                  } else if (state is NotificationError &&
                      context
                          .read<NotificationCubit>()
                          .allNotifications
                          .isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 64.sp,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              state.message,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24.h),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              onPressed: () => context
                                  .read<NotificationCubit>()
                                  .loadNotifications(),
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final allNotifs = context
                      .read<NotificationCubit>()
                      .allNotifications;
                  final filteredNotifs = _getFilteredNotifications(allNotifs);

                  if (filteredNotifs.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () =>
                          context.read<NotificationCubit>().loadNotifications(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: _buildEmptyState(isDarkMode),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () =>
                        context.read<NotificationCubit>().loadNotifications(),
                    child: _buildGroupedNotificationList(
                      filteredNotifs,
                      isDarkMode,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersBar(bool isDarkMode) {
    final filters = [
      {'id': 'all', 'label': 'الكل'},
      {'id': 'order', 'label': 'الطلبات'},
      {'id': 'wallet', 'label': 'المحفظة'},
      {'id': 'offer', 'label': 'العروض'},
      {'id': 'system', 'label': 'النظام'},
    ];

    return Container(
      height: 60.h,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedCategory == filter['id'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = filter['id']!;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDarkMode
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Center(
                child: Text(
                  filter['label']!,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupedNotificationList(
    List<NotificationModel> filteredNotifs,
    bool isDarkMode,
  ) {
    final now = DateTime.now();
    final todayNotifications = <NotificationModel>[];
    final yesterdayNotifications = <NotificationModel>[];
    final earlierNotifications = <NotificationModel>[];

    for (var n in filteredNotifs) {
      final difference = now.difference(n.timestamp).inDays;
      if (difference == 0 && n.timestamp.day == now.day) {
        todayNotifications.add(n);
      } else if (difference <= 1 &&
          n.timestamp.day == now.subtract(const Duration(days: 1)).day) {
        yesterdayNotifications.add(n);
      } else {
        earlierNotifications.add(n);
      }
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      children: [
        if (todayNotifications.isNotEmpty) ...[
          _buildGroupHeader('اليوم', isDarkMode),
          ...todayNotifications.map(
            (n) => _buildDismissibleItem(n, isDarkMode),
          ),
        ],
        if (yesterdayNotifications.isNotEmpty) ...[
          SizedBox(height: 16.h),
          _buildGroupHeader('أمس', isDarkMode),
          ...yesterdayNotifications.map(
            (n) => _buildDismissibleItem(n, isDarkMode),
          ),
        ],
        if (earlierNotifications.isNotEmpty) ...[
          SizedBox(height: 16.h),
          _buildGroupHeader('سابقاً', isDarkMode),
          ...earlierNotifications.map(
            (n) => _buildDismissibleItem(n, isDarkMode),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(String title, bool isDarkMode) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, right: 4.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildDismissibleItem(NotificationModel item, bool isDarkMode) {
    final fullList = context.read<NotificationCubit>().allNotifications;
    final index = fullList.indexWhere((n) => n.id == item.id);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) => _deleteNotification(item, index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        margin: EdgeInsets.symmetric(vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 24.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'حذف',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
      child: FadeInUp(
        duration: const Duration(milliseconds: 350),
        child: _buildNotificationCard(item, isDarkMode),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel item, bool isDarkMode) {
    FaIconData categoryIcon;
    Color categoryColor;

    switch (item.category) {
      case 'order':
        categoryIcon = FontAwesomeIcons.boxOpen;
        categoryColor = AppColors.primary;
        break;
      case 'wallet':
        categoryIcon = FontAwesomeIcons.wallet;
        categoryColor = Colors.green;
        break;
      case 'offer':
        categoryIcon = FontAwesomeIcons.tag;
        categoryColor = Colors.orange;
        break;
      case 'system':
      default:
        categoryIcon = FontAwesomeIcons.circleInfo;
        categoryColor = Colors.purple;
        break;
    }

    return GestureDetector(
      onTap: () => _showNotificationDetail(item),
      child: Stack(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 6.h),
            decoration: BoxDecoration(
              color: item.isRead
                  ? (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white)
                  : (isDarkMode
                        ? const Color(0xFF2C2C2C).withOpacity(0.4)
                        : AppColors.primary.withOpacity(0.04)),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: !item.isRead
                    ? AppColors.primary.withOpacity(0.2)
                    : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                right: 18.w,
                left: 14.w,
                top: 14.h,
                bottom: 14.h,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42.w,
                    height: 42.w,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: FaIcon(
                        categoryIcon,
                        color: categoryColor,
                        size: 18.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  fontWeight: item.isRead
                                      ? FontWeight.bold
                                      : FontWeight.w900,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (!item.isRead) ...[
                              SizedBox(width: 8.w),
                              Container(
                                width: 8.w,
                                height: 8.w,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              _formatDisplayTime(item.timestamp),
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
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
          if (!item.isRead)
            Positioned(
              top: 6.h + 1.h,
              bottom: 6.h + 1.h,
              right: 1.w,
              child: Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16.r),
                    bottomRight: Radius.circular(16.r),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDisplayTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'م' : 'ص';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month} - $hour:$minute $ampm';
    }
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return FadeIn(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1E1E1E)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: ZoomIn(
                    duration: const Duration(milliseconds: 600),
                    child: FaIcon(
                      FontAwesomeIcons.bellSlash,
                      size: 48.sp,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'لا توجد إشعارات حالياً',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _selectedCategory == 'all'
                    ? 'سنقوم بإخطارك فوراً عندما تتلقى أي تحديثات أو شحنات جديدة!'
                    : 'لا توجد إشعارات في هذا التصنيف حالياً.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDarkMode) {
    return Shimmer.fromColors(
      baseColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade300,
      highlightColor: isDarkMode
          ? const Color(0xFF3D3D3D)
          : Colors.grey.shade100,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          height: 96.h,
          margin: EdgeInsets.symmetric(vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
      ),
    );
  }
}
