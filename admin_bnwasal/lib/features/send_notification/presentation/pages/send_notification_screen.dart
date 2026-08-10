// ignore_for_file: deprecated_member_use

import 'package:admin_bnwasal/core/theme/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../cubit/send_notification_cubit.dart';
import '../cubit/send_notification_state.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _searchController = TextEditingController();
  final _userScrollController = ScrollController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animCtrl.dispose();
    _userScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
            ),
        child: BlocConsumer<SendNotificationCubit, SendNotificationState>(
          listener: (ctx, state) {
            if (state.isSuccess) {
              _showResult(
                ctx,
                '✅ تم الإرسال بنجاح',
                'تم إرسال الإشعار بنجاح إلى ${state.sentCount} مستخدم.',
              );
              _titleController.clear();
              _bodyController.clear();
              context.read<SendNotificationCubit>().deselectAllUsers();
              context.read<SendNotificationCubit>().reset();
            }
            if (state.error != null) {
              _showResult(ctx, '⚠️ فشل الإرسال', state.error!);
            }
          },
          builder: (context, state) {
            Widget mainLayout;
            if (isWide) {
              mainLayout = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Target Selector and Users list
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTargetSelector(state, isWide),
                        if (state.targetUsers.isNotEmpty ||
                            state.isLoadingUsers) ...[
                          SizedBox(height: 24.h),
                          _buildUserSelection(state, isWide),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 40.w),
                  // Right Column: Message Inputs and Send button
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          _titleController,
                          'عنوان الإشعار',
                          'أدخل عنوان الإشعار هنا...',
                          Icons.title_rounded,
                          isWide,
                        ),
                        SizedBox(height: 16.h),
                        _buildTextField(
                          _bodyController,
                          'محتوى الإشعار',
                          'أدخل نص الإشعار بالتفصيل هنا...',
                          Icons.message_rounded,
                          isWide,
                          maxLines: 6,
                        ),
                        SizedBox(height: 28.h),
                        _buildSendButton(state, isWide),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              // Mobile stack layout
              mainLayout = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTargetSelector(state, isWide),
                  SizedBox(height: 20.h),
                  if (state.targetUsers.isNotEmpty || state.isLoadingUsers) ...[
                    _buildUserSelection(state, isWide),
                    SizedBox(height: 24.h),
                  ],
                  _buildTextField(
                    _titleController,
                    'عنوان الإشعار',
                    'أدخل عنوان الإشعار هنا...',
                    Icons.title_rounded,
                    isWide,
                  ),
                  SizedBox(height: 16.h),
                  _buildTextField(
                    _bodyController,
                    'محتوى الإشعار',
                    'أدخل نص الإشعار بالتفصيل هنا...',
                    Icons.message_rounded,
                    isWide,
                    maxLines: 4,
                  ),
                  SizedBox(height: 28.h),
                  _buildSendButton(state, isWide),
                ],
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 24.w : 16.w,
                vertical: 20.h,
              ),
              child: Center(
                child: SizedBox(
                  width: isWide ? 1000.w : double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isWide),
                      SizedBox(height: 24.h),
                      mainLayout,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          'إرسال إشعار جماعي',
          style: TextStyle(
            fontSize: isWide ? 18.sp : 16.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTargetSelector(SendNotificationState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targets = [
      {
        'key': 'all',
        'label': 'الجميع',
        'icon': AppAssets.employees,
        'desc': 'التجار والكباتن',
      },
      {
        'key': 'merchants',
        'label': 'التجار',
        'icon': AppAssets.merchants,
        'desc': 'تحديد تجار',
      },
      {
        'key': 'captains',
        'label': 'الكباتن',
        'icon': AppAssets.captains,
        'desc': 'تحديد كباتن',
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الفئة المستهدفة للإشعار',
          style: TextStyle(
            fontSize: 12.sp,
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: targets
              .map(
                (t) => GestureDetector(
                  onTap: () => context
                      .read<SendNotificationCubit>()
                      .setTargetType(t['key'] as String),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: isWide
                          ? 150.w
                          : (MediaQuery.of(context).size.width - 48.w) / 3 -
                                8.w,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 14.h,
                      ),
                      decoration: BoxDecoration(
                        color: state.targetType == t['key']
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : (isDark ? AppColors.surfaceDark : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: state.targetType == t['key']
                              ? AppColors.primary
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade300),
                        ),
                        boxShadow: state.targetType == t['key']
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.04,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : (isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]),
                      ),
                      child: Column(
                        children: [
                          SvgPicture.asset(
                            t['icon'] as String,
                            width: 33.w,
                            height: 33.w,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            t['label'] as String,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: state.targetType == t['key']
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: state.targetType == t['key']
                                  ? (isDark ? Colors.white : AppColors.primary)
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : Colors.black),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            t['desc'] as String,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.black,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildUserSelection(SendNotificationState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredUsers = state.targetUsers.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery) ||
          email.contains(searchQuery) ||
          phone.contains(searchQuery) ||
          role.contains(searchQuery);
    }).toList();

    final filteredIds = filteredUsers.map((u) => u['id'].toString()).toList();
    final allFilteredSelected =
        filteredIds.isNotEmpty &&
        filteredIds.every((id) => state.selectedUserIds.contains(id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'اختر من القائمة',
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8.w),
            if (state.isLoadingUsers)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                if (allFilteredSelected) {
                  for (final id in filteredIds) {
                    if (state.selectedUserIds.contains(id)) {
                      context.read<SendNotificationCubit>().toggleUserSelection(
                        id,
                      );
                    }
                  }
                } else {
                  for (final id in filteredIds) {
                    if (!state.selectedUserIds.contains(id)) {
                      context.read<SendNotificationCubit>().toggleUserSelection(
                        id,
                      );
                    }
                  }
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: allFilteredSelected ? Colors.red : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    allFilteredSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: allFilteredSelected
                          ? Colors.white
                          : AppColors.background,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        // Search Box
        TextField(
          controller: _searchController,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'البحث بالاسم، الهاتف أو البريد الإلكتروني...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.black,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 16.sp,
            ),
            fillColor: Colors.transparent,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black45,
                      size: 16.sp,
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12.h),
          ),
        ),
        SizedBox(height: 10.h),
        Container(
          constraints: BoxConstraints(maxHeight: 260.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.grey.shade300,
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
          clipBehavior: Clip.antiAlias,
          child: state.isLoadingUsers
              ? const SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : Scrollbar(
                  controller: _userScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _userScrollController,
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    itemCount: filteredUsers.length,
                    itemBuilder: (_, i) {
                      final user = filteredUsers[i];
                      final uid = user['id'].toString();
                      final name = user['name']?.toString() ?? '';
                      final email = user['email']?.toString() ?? '';
                      final phone = user['phone']?.toString() ?? '';
                      final role = user['role']?.toString() ?? '';
                      final fcmToken = user['fcmToken']?.toString() ?? '';
                      final hasWebPush = user['webPushSubscription'] != null;
                      final isSelected = state.selectedUserIds.contains(uid);

                      return GestureDetector(
                        onTap: () => context
                            .read<SendNotificationCubit>()
                            .toggleUserSelection(uid),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.04)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : Colors.grey.shade100,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Circle checkmark
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 18.w,
                                  height: 18.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.25,
                                                  )
                                                : Colors.black26),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 10.sp,
                                        )
                                      : null,
                                ),
                                SizedBox(width: 12.w),
                                // User role icon
                                Container(
                                  width: 35.w,
                                  height: 35.w,
                                  decoration: BoxDecoration(
                                    color: role == 'merchant'
                                        ? AppColors.secondary.withValues(
                                            alpha: 0.1,
                                          )
                                        : AppColors.success.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      role == 'merchant'
                                          ? AppAssets.merchants
                                          : AppAssets.captains,
                                      width: 25.w,
                                      height: 25.w,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                // User info text
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      if (phone.isNotEmpty || email.isNotEmpty)
                                        Text(
                                          [
                                            if (phone.isNotEmpty) phone,
                                            if (email.isNotEmpty) email,
                                          ].join(' | '),
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.4,
                                                  )
                                                : Colors.black54,
                                          ),
                                        ),
                                      SizedBox(height: 4.h),
                                      // Status system indicators
                                      Row(
                                        children: [
                                          if (fcmToken.trim().isNotEmpty)
                                            Container(
                                              margin: EdgeInsets.only(
                                                left: 6.w,
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6.w,
                                                vertical: 2.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.success
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: AppColors.success
                                                      .withValues(alpha: 0.3),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.phone_android_rounded,
                                                    color: AppColors.success,
                                                    size: 8.sp,
                                                  ),
                                                  SizedBox(width: 3.w),
                                                  Text(
                                                    'نشط جوال',
                                                    style: TextStyle(
                                                      fontSize: 8.sp,
                                                      color: AppColors.success,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (hasWebPush)
                                            Container(
                                              margin: EdgeInsets.only(
                                                left: 6.w,
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6.w,
                                                vertical: 2.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.3),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.computer_rounded,
                                                    color: AppColors.primary,
                                                    size: 8.sp,
                                                  ),
                                                  SizedBox(width: 3.w),
                                                  Text(
                                                    'نشط ويب',
                                                    style: TextStyle(
                                                      fontSize: 8.sp,
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (fcmToken.trim().isEmpty &&
                                              !hasWebPush)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6.w,
                                                vertical: 2.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: Colors.red.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .notifications_off_rounded,
                                                    color: Colors.red,
                                                    size: 8.sp,
                                                  ),
                                                  SizedBox(width: 3.w),
                                                  Text(
                                                    'غير مسجل توكن',
                                                    style: TextStyle(
                                                      fontSize: 8.sp,
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Role badge
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: role == 'merchant'
                                        ? AppColors.secondary.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.success.withValues(
                                            alpha: 0.15,
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    role == 'merchant' ? 'تاجر' : 'كابتن',
                                    style: TextStyle(
                                      fontSize: 8.sp,
                                      color: role == 'merchant'
                                          ? AppColors.secondary
                                          : AppColors.success,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        SizedBox(height: 8.h),
        Text(
          state.selectedUserIds.isEmpty
              ? 'تنبيه: عدم اختيار مستخدمين يعني إرسال الإشعار لجميع ${state.targetType == 'merchants' ? 'التجار' : 'الكباتن'}.'
              : 'تم اختيار ${state.selectedUserIds.length} مستخدم وسيتم الإرسال لهم فقط.',
          style: TextStyle(
            fontSize: 14.sp,
            color: state.selectedUserIds.isEmpty
                ? (isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black)
                : AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
    bool isWide, {
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: hint,
            fillColor: Colors.transparent,
            hintStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.black,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.grey.shade300,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: maxLines > 1 ? 14.h : 12.h,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 18.sp),
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(SendNotificationState state, bool isWide) {
    final canSend = !state.isLoading;
    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: ElevatedButton(
        onPressed: canSend
            ? () {
                if (_titleController.text.trim().isEmpty ||
                    _bodyController.text.trim().isEmpty) {
                  _showResult(
                    context,
                    '⚠️ تنبيه هام',
                    'يرجى ملء كلاً من عنوان ونص الإشعار قبل الإرسال.',
                  );
                  return;
                }
                context.read<SendNotificationCubit>().send(
                  title: _titleController.text.trim(),
                  body: _bodyController.text.trim(),
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: state.isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8.w),
                  Text(
                    'إرسال الإشعار الآن',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showResult(BuildContext context, String title, String message) {
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
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black87,
            fontSize: 12.sp,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'حسناً',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
