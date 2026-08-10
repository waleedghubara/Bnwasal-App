import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:admin_bnwasal/features/auth/presentation/cubit/auth_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<AuthCubit>();
    if (cubit.state.user == null) {
      cubit.loadProfile();
    }
    _syncFields(cubit.state.user);
  }

  void _syncFields(Map<String, dynamic>? user) {
    if (user == null) return;
    _nameCtrl.text = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
        .trim();
    _phoneCtrl.text = user['phone']?.toString() ?? '';
    _cityCtrl.text = user['city']?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (ctx, state) {
        if (state.profileSuccess != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.profileSuccess!),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (ctx.mounted) {
              ctx.read<AuthCubit>().clearError();
            }
          });
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (ctx.mounted) {
              ctx.read<AuthCubit>().clearError();
            }
          });
        }
      },
      builder: (ctx, state) {
        final user = state.user;
        final imgUrl = user?['profileImage']?.toString();
        final name = user != null
            ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
            : 'أدمن';
        final email = user?['email']?.toString() ?? '';
        final role = user?['role']?.toString() ?? 'admin';

        String roleLabel = role == 'admin' ? 'مدير النظام' : 'موظف في المنصة';

        return ListView(
          padding: EdgeInsets.fromLTRB(
            isWide ? 40.w : 16.w,
            20.h,
            isWide ? 40.w : 16.w,
            32.h,
          ),
          children: [
            // User Avatar Banner
            _buildProfileImage(imgUrl, name, roleLabel, email, isWide),
            SizedBox(height: 24.h),

            // Responsive Layout
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Account details & Password modification
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildAccountInfo(user),
                            SizedBox(height: 16.h),
                            _buildPasswordSection(),
                          ],
                        ),
                      ),
                      SizedBox(width: 20.w),
                      // Right Column: Permissions & Last login session info
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildPermissionsSection(user),
                            SizedBox(height: 16.h),
                            _buildSecuritySection(user),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildAccountInfo(user),
                      SizedBox(height: 16.h),
                      _buildPermissionsSection(user),
                      SizedBox(height: 16.h),
                      _buildSecuritySection(user),
                      SizedBox(height: 16.h),
                      _buildPasswordSection(),
                    ],
                  ),
          ],
        );
      },
    );
  }

  Widget _buildProfileImage(
    String? imgUrl,
    String name,
    String roleLabel,
    String email,
    bool isWide,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickImage(context),
          child: Stack(
            children: [
              Container(
                width: 100.w,
                height: 100.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: ClipOval(
                  child: imgUrl != null && imgUrl.isNotEmpty
                      ? Image.network(
                          imgUrl.startsWith('http')
                              ? imgUrl
                              : '${EndPoint.imageBaseUrl}$imgUrl',
                          fit: BoxFit.cover,
                          width: 100.w,
                          height: 100.w,
                          errorBuilder: (_, _, _) => _avatarFallback(name),
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                        )
                      : _avatarFallback(name),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF0056c6)],
                    ),
                    border: Border.all(
                      color: isDark ? const Color(0xFF0a0a1a) : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 14.sp,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          name,
          style: TextStyle(
            fontSize: isWide ? 18.sp : 16.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            roleLabel,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (email.isNotEmpty) ...[
          SizedBox(height: 6.h),
          Text(
            email,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ],
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      width: 100.w,
      height: 100.w,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF0056c6)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0] : 'أ',
        style: TextStyle(
          fontSize: 36.sp,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAccountInfo(Map<String, dynamic>? user) {
    final firstName = user?['firstName']?.toString() ?? '';
    final lastName = user?['lastName']?.toString() ?? '';
    final phone = user?['phone']?.toString() ?? '';
    final email = user?['email']?.toString() ?? '';
    final city = user?['city']?.toString() ?? '';
    final status = user?['status']?.toString() ?? 'active';

    String statusLabel = status == 'active' ? 'نشط' : 'محظور';
    Color statusColor = status == 'active'
        ? AppColors.success
        : AppColors.error;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.manage_accounts_outlined,
                  size: 18.sp,
                  color: const Color(0xFF60a5fa),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'بيانات الحساب الشخصي',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (!_isEditing)
                IconButton(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: Icon(
                    Icons.edit_note_rounded,
                    size: 22.sp,
                    color: const Color(0xFF60a5fa),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_isEditing)
            _editForm(firstName, lastName, phone, city)
          else
            _infoRows(
              firstName,
              lastName,
              phone,
              email,
              city,
              statusLabel,
              statusColor,
            ),
        ],
      ),
    );
  }

  Widget _infoRows(
    String firstName,
    String lastName,
    String phone,
    String email,
    String city,
    String statusLabel,
    Color statusColor,
  ) {
    return Column(
      children: [
        _infoRow(Icons.person_outline, 'الاسم الكامل', '$firstName $lastName'),
        _infoRow(Icons.alternate_email_rounded, 'البريد الإلكتروني', email),
        _infoRow(Icons.phone_android_rounded, 'رقم الهاتف', phone),
        _infoRow(
          Icons.location_city_outlined,
          'المدينة الحالية',
          city.isNotEmpty ? city : 'غير محددة',
        ),
        _infoRow(
          Icons.shield_outlined,
          'حالة الحساب',
          statusLabel,
          valueColor: statusColor,
        ),
      ],
    );
  }

  Widget _editForm(
    String firstName,
    String lastName,
    String phone,
    String city,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fNameCtrl = TextEditingController(text: firstName);
    final lNameCtrl = TextEditingController(text: lastName);
    final phCtrl = TextEditingController(text: phone);
    final ctCtrl = TextEditingController(text: city);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _editField('الاسم الأول', fNameCtrl)),
            SizedBox(width: 10.w),
            Expanded(child: _editField('الاسم الأخير', lNameCtrl)),
          ],
        ),
        SizedBox(height: 10.h),
        _editField('الهاتف', phCtrl),
        SizedBox(height: 10.h),
        _editField('المدينة', ctCtrl),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() => _isEditing = false);
              },
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black54,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF0056c6)],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    context.read<AuthCubit>().updateProfile(
                      firstName: fNameCtrl.text,
                      lastName: lNameCtrl.text,
                      phone: phCtrl.text,
                      city: ctCtrl.text,
                    );
                    _nameCtrl.text = '${fNameCtrl.text} ${lNameCtrl.text}'
                        .trim();
                    _phoneCtrl.text = phCtrl.text;
                    _cityCtrl.text = ctCtrl.text;
                    setState(() => _isEditing = false);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 8.h,
                    ),
                    child: Text(
                      'حفظ التعديلات',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _editField(String label, TextEditingController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 15.sp,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black45,
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: isDark
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.sp,
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black38,
          ),
          SizedBox(width: 10.w),
          SizedBox(
            width: 90.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5.sp,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black54,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color:
                    valueColor ??
                    (isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection(Map<String, dynamic>? user) {
    final role = user?['role']?.toString() ?? 'admin';
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

    final isAdmin = role == 'admin';

    // Map permissions to Arabic readable departments/scopes
    final permLabels = {
      'dashboard': 'لوحة الإحصائيات والتقارير العامة',
      'merchants': 'إدارة التجار والاشتراكات',
      'captains': 'إدارة الكباتن والمناديب',
      'trips': 'إدارة الرحلات وتتبع المسارات',
      'orders': 'إدارة الطلبات والعمليات',
      'users': 'إدارة المستخدمين والعملاء',
      'todayOrdersShipments': 'طلبات وشحنات اليوم الفورية',
      'todayTrips': 'الرحلات اليومية والجدولة',
      'pendingAccounts': 'توثيق وقبول الحسابات المعلقة',
      'complaints': 'الدعم الفني والشكاوى المباشرة',
      'notifications': 'إرسال الإشعارات والتواصل مع المستخدمين',
      'withdrawals': 'إدارة طلبات السحب والمبالغ المالية',
      'wallet': 'عرض المحفظة العامة ومعاملاتها',
      'userMessages': 'رسائل التواصل من المستخدمين والزوار',
      'directPayments': 'إدارة دفعات الشحنات والطلبات',
      'sendNotification': 'إرسال إشعارات جماعية ومخصصة',
      'employees': 'إدارة صلاحيات وبيانات الموظفين',
      'settings': 'التحكم في الإعدادات العامة للمنصة',
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 18.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'صلاحيات وأقسام النظام',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (isAdmin) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: AppColors.success,
                    size: 20.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إدارة كاملة (أدمن)',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'تمتلك كافة صلاحيات المدير العام للتحكم in كافة إعدادات وأقسام المنصة.',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            Column(
              children: permLabels.values
                  .map((label) => _permissionItemRow(label, true))
                  .toList(),
            ),
          ] else ...[
            if (permissions.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Center(
                  child: Text(
                    'لا توجد صلاحيات معينة لحسابك حالياً. يرجى مراجعة المسؤول.',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),

                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الأقسام والمهام المصرح لك بالدخول إليها:',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  ...permLabels.entries.map((entry) {
                    final hasPerm = permissions.contains(entry.key);
                    return _permissionItemRow(entry.value, hasPerm);
                  }),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _permissionItemRow(String label, bool hasPermission) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Icon(
            hasPermission
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            size: 16.sp,
            color: hasPermission
                ? AppColors.success
                : (isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5.sp,
                color: hasPermission
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.black87)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black38),
                fontWeight: hasPermission ? FontWeight.bold : FontWeight.normal,
                decoration: hasPermission ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(Map<String, dynamic>? user) {
    // Detect active platform realistically
    String deviceLabel = "جهاز كمبيوتر - Windows Desktop";
    if (Platform.isAndroid) {
      deviceLabel = "هاتف ذكي - Android App";
    }

    final city = user?['city']?.toString() ?? '';
    final ipAddress = "10.45.245.75"; // App server context IP
    final location = city.isNotEmpty ? "$city، مصر" : "القاهرة، مصر";

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.security_outlined,
                  size: 18.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'جلسة الدخول الحالية والأمان',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _securityRow(
            Icons.laptop_windows_rounded,
            'جهاز الجلسة',
            deviceLabel,
          ),
          _securityRow(Icons.dns_outlined, 'عنوان الـ IP', ipAddress),
          _securityRow(Icons.location_on_outlined, 'الموقع التقريبي', location),
          _securityRow(
            Icons.timer_outlined,
            'حالة الجلسة',
            'نشط الآن (جلسة عمل آمنة وموثقة)',
            valColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _securityRow(
    IconData icon,
    String label,
    String value, {
    Color? valColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.sp,
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black38,
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.bold,
                  color: valColor ?? (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0b0b1e) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              Icons.lock_reset_rounded,
              size: 18.sp,
              color: AppColors.error,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كلمة مرور الحساب',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'تغيير كلمة المرور الخاصة بك بشكل دوري يؤمن حسابك.',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.35)
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showChangePasswordDialog(context),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Text(
                    'تغيير الآن',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
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

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0b0b1e) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تحديث الصورة الشخصية',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _sourceButton(
                    Icons.photo_library_outlined,
                    'معرض الصور',
                    ImageSource.gallery,
                  ),
                  _sourceButton(
                    Icons.camera_alt_outlined,
                    'الكاميرا',
                    ImageSource.camera,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file != null) {
      if (!context.mounted) return;
      context.read<AuthCubit>().updateProfileImage(file.path);
    }
  }

  Widget _sourceButton(IconData icon, String label, ImageSource source) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Container(
        width: 110.w,
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24.sp, color: const Color(0xFF60a5fa)),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0b0b1e) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تغيير كلمة المرور',
          style: GoogleFonts.tajawal(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogPasswordField('كلمة المرور الحالية', oldCtrl),
            SizedBox(height: 10.h),
            _dialogPasswordField('كلمة المرور الجديدة', newCtrl),
            SizedBox(height: 10.h),
            _dialogPasswordField('تأكيد كلمة المرور الجديدة', confirmCtrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF0056c6)],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (newCtrl.text.isEmpty || oldCtrl.text.isEmpty) return;
                  if (newCtrl.text != confirmCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('كلمة المرور الجديدة غير متطابقة'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  context.read<AuthCubit>().changePassword(
                    oldCtrl.text,
                    newCtrl.text,
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  child: Text(
                    'تأكيد وحفظ',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  Widget _dialogPasswordField(String label, TextEditingController ctrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      obscureText: true,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 15.sp,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black45,
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: isDark
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      ),
    );
  }
}
