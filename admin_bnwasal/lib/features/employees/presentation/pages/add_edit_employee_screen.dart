import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import '../../data/all_permissions.dart';
import '../cubit/employees_cubit.dart';
import '../cubit/employees_state.dart';

class AddEditEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic>? employee;
  const AddEditEmployeeScreen({super.key, this.employee});

  bool get isEditing => employee != null;

  @override
  State<AddEditEmployeeScreen> createState() => _AddEditEmployeeScreenState();
}

class _AddEditEmployeeScreenState extends State<AddEditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _searchPermCtrl = TextEditingController();
  final _searchRoleCtrl = TextEditingController();

  Set<String> _selectedPermissions = {};
  String? _selectedRoleGroup;
  bool _obscurePassword = true;

  static const _roleGroups = {
    'services': {
      'label': 'خدمة العملاء',
      'icon': Icons.headset_mic_outlined,
      'desc': 'إدارة الشكاوى والطلبات',
      'permissions': {'orders', 'users', 'complaints', 'todayOrdersShipments'},
    },
    'operations': {
      'label': 'العمليات',
      'icon': Icons.engineering_outlined,
      'desc': 'إدارة الكباتن والرحلات',
      'permissions': {'captains', 'trips', 'todayTrips', 'pendingAccounts'},
    },
    'sales': {
      'label': 'المبيعات والتسويق',
      'icon': Icons.trending_up_outlined,
      'desc': 'عرض الإحصائيات والتجار',
      'permissions': {'dashboard', 'merchants'},
    },
    'management': {
      'label': 'إدارة كاملة',
      'icon': Icons.admin_panel_settings_outlined,
      'desc': 'جميع الصلاحيات (عدا الموظفين)',
      'permissions': {
        'dashboard',
        'merchants',
        'captains',
        'trips',
        'orders',
        'users',
        'todayOrdersShipments',
        'todayTrips',
        'pendingAccounts',
        'complaints',
        'notifications',
        'withdrawals',
        'wallet',
        'userMessages',
        'directPayments',
        'sendNotification',
        'settings',
      },
    },
  };

  bool get _isEditing => widget.isEditing;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.employee!;
      _firstNameCtrl.text = e['firstName'] ?? '';
      _lastNameCtrl.text = e['lastName'] ?? '';
      _emailCtrl.text = e['email'] ?? '';
      _phoneCtrl.text = e['phone'] ?? '';
      _cityCtrl.text = e['city'] ?? '';
      _nationalIdCtrl.text = e['nationalId']?.toString() ?? '';
      final permStr = e['permissions']?.toString() ?? '';
      if (permStr.isNotEmpty) {
        _selectedPermissions = permStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
      }
      _syncRoleGroup();
    }
  }

  void _syncRoleGroup() {
    for (final entry in _roleGroups.entries) {
      final groupPerms = (entry.value['permissions'] as Set<String>);
      if (groupPerms.containsAll(_selectedPermissions) &&
          groupPerms.length == _selectedPermissions.length) {
        _selectedRoleGroup = entry.key;
        return;
      }
    }
    _selectedRoleGroup = null;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _cityCtrl.dispose();
    _nationalIdCtrl.dispose();
    _searchPermCtrl.dispose();
    _searchRoleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0a0a1a)
          : const Color(0xFFf8f9fa),
      appBar: _buildAppBar(context),
      body: BlocConsumer<EmployeesCubit, EmployeesState>(
        listener: (ctx, state) {
          if (state.submitSuccess != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(state.submitSuccess!),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            ctx.read<EmployeesCubit>().clearSubmit();
            Navigator.pop(ctx);
          }
          if (state.submitError != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(state.submitError!),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
            ctx.read<EmployeesCubit>().clearSubmit();
          }
        },
        builder: (ctx, state) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 80.w : 16.w,
                8.h,
                isWide ? 80.w : 16.w,
                32.h,
              ),
              children: [
                _buildBasicInfo(isWide),
                SizedBox(height: 20.h),
                _buildRoleGroups(isWide),
                SizedBox(height: 20.h),
                _buildPermissionsGrid(),
                SizedBox(height: 28.h),
                _buildSubmitButton(state),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1a1a2e) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        title: Text(
          'حذف الموظف',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذا الموظف نهائياً؟',
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black87,
            fontSize: 13.sp,
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
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              context.read<EmployeesCubit>().deleteEmployee(
                widget.employee!['id'] as int,
              );
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: isDark
          ? const Color(0xFF0a0a1a)
          : const Color(0xFFf8f9fa),
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : Colors.black87,
            size: 18.sp,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _isEditing ? 'تعديل بيانات موظف' : 'إضافة موظف جديد',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      actions: [
        if (_isEditing)
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 18.sp,
              ),
            ),
            onPressed: () => _confirmDelete(context),
          ),
        SizedBox(width: 16.w),
      ],
    );
  }

  Widget _buildBasicInfo(bool isWide) {
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
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  Icons.person_outline_rounded,
                  size: 18.sp,
                  color: isDark ? const Color(0xFF60a5fa) : AppColors.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'البيانات الأساسية للموظف',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (isWide) ...[
            Row(
              children: [
                Expanded(
                  child: _textField(
                    'الاسم الأول',
                    _firstNameCtrl,
                    required: true,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: _textField(
                    'الاسم الأخير',
                    _lastNameCtrl,
                    required: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    'البريد الإلكتروني',
                    _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    required: true,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: _textField(
                    'رقم الهاتف',
                    _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    required: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    _isEditing
                        ? 'كلمة المرور (اتركه فارغاً للاحتفاظ بالقديمة)'
                        : 'كلمة المرور',
                    _passwordCtrl,
                    obscureText: _obscurePassword,
                    required: !_isEditing,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18.sp,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black38,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(child: _textField('المدينة', _cityCtrl)),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    'الرقم القومي (البطاقة الشخصية)',
                    _nationalIdCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ] else ...[
            _textField('الاسم الأول', _firstNameCtrl, required: true),
            SizedBox(height: 12.h),
            _textField('الاسم الأخير', _lastNameCtrl, required: true),
            SizedBox(height: 12.h),
            _textField(
              'البريد الإلكتروني',
              _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              required: true,
            ),
            SizedBox(height: 12.h),
            _textField(
              'رقم الهاتف',
              _phoneCtrl,
              keyboardType: TextInputType.phone,
              required: true,
            ),
            SizedBox(height: 12.h),
            _textField(
              _isEditing
                  ? 'كلمة المرور (اتركه فارغاً للاحتفاظ بالقديمة)'
                  : 'كلمة المرور',
              _passwordCtrl,
              obscureText: _obscurePassword,
              required: !_isEditing,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18.sp,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black38,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            SizedBox(height: 12.h),
            _textField('المدينة', _cityCtrl),
            SizedBox(height: 12.h),
            _textField(
              'الرقم القومي (البطاقة الشخصية)',
              _nationalIdCtrl,
              keyboardType: TextInputType.number,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleGroups(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _roleGroups.entries.where((e) {
      if (_searchRoleCtrl.text.isEmpty) return true;
      return e.value['label'].toString().contains(_searchRoleCtrl.text);
    }).toList();

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
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  color: isDark ? const Color(0xFF60a5fa) : AppColors.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مجموعات الصلاحيات والوظائف',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'اختر مجموعة لتحديد الصلاحيات تلقائياً',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _searchRoleCtrl,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 13.sp,
            ),
            decoration: InputDecoration(
              hintText: 'بحث عن مجموعة صلاحيات...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18.sp,
                color: isDark ? Colors.white54 : Colors.black,
              ),
              fillColor: Colors.transparent,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 12.h,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          isWide
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10.w,
                    mainAxisSpacing: 10.h,
                    mainAxisExtent: 130.h,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    return _roleGroupChip(filtered[i].key, filtered[i].value);
                  },
                )
              : Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: filtered
                      .map((entry) => _roleGroupChip(entry.key, entry.value))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _roleGroupChip(String key, Map<String, dynamic> group) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selectedRoleGroup == key;
    final perms = (group['permissions'] as Set<String>);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedRoleGroup = null;
            _selectedPermissions = {};
          } else {
            _selectedRoleGroup = key;
            _selectedPermissions = Set.from(perms);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140.w,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF0056c6)],
                )
              : LinearGradient(
                  colors: [
                    isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.grey.shade50,
                    isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.grey.shade50,
                  ],
                ),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.5)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade300),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : (isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              group['icon'] as IconData,
              size: 24.sp,
              color: selected
                  ? Colors.white
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black),
            ),
            SizedBox(height: 6.h),
            Text(
              group['label'].toString(),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: selected
                    ? Colors.white
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.primary),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              group['desc'].toString(),
              style: TextStyle(
                fontSize: 14.sp,
                color: selected
                    ? Colors.white.withValues(alpha: 0.6)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              '${perms.length} صلاحيات',
              style: TextStyle(
                fontSize: 13.sp,
                color: selected
                    ? const Color(0xFF93c5fd)
                    : (isDark ? const Color(0xFF60a5fa) : AppColors.warning),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = AllPermissions.all.where((p) {
      if (_searchPermCtrl.text.isEmpty) return true;
      return p.label.contains(_searchPermCtrl.text) ||
          p.key.contains(_searchPermCtrl.text);
    }).toList();

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
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  Icons.checklist_rounded,
                  size: 18.sp,
                  color: isDark ? const Color(0xFF60a5fa) : AppColors.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Flexible(
                child: Text(
                  'تخصيص الصلاحيات المنفردة',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selectedPermissions.length}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isDark ? const Color(0xFF60a5fa) : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (_selectedPermissions.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedPermissions = {};
                    _selectedRoleGroup = null;
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'إلغاء الكل',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _searchPermCtrl,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'بحث عن صلاحية معينة بالاسم...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18.sp,
                color: isDark ? Colors.white54 : Colors.black,
              ),
              fillColor: Colors.transparent,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 12.h,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: filtered.map((perm) => _permissionChip(perm)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _permissionChip(PermissionDef perm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selectedPermissions.contains(perm.key);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedPermissions.remove(perm.key);
          } else {
            _selectedPermissions.add(perm.key);
          }
          _syncRoleGroup();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.3)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              perm.icon,
              size: 14.sp,
              color: selected
                  ? (isDark ? const Color(0xFF60a5fa) : AppColors.primary)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black),
            ),
            SizedBox(width: 6.w),
            Text(
              perm.label,
              style: TextStyle(
                fontSize: 14.sp,
                color: selected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(EmployeesState state) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: Material(
        borderRadius: BorderRadius.circular(14),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: state.isSubmitting ? null : _submit,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF0056c6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: state.isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isEditing
                        ? 'حفظ التعديلات الحالية'
                        : 'تسجيل وإضافة الموظف',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final data = <String, dynamic>{
      'firstName': _firstNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'nationalId': _nationalIdCtrl.text.trim().isEmpty
          ? null
          : _nationalIdCtrl.text.trim(),
      'permissions': _selectedPermissions.toList(),
    };
    if (_passwordCtrl.text.isNotEmpty) {
      data['password'] = _passwordCtrl.text;
    }
    if (_isEditing) {
      context.read<EmployeesCubit>().updateEmployee(
        widget.employee!['id'] as int,
        data,
      );
    } else {
      context.read<EmployeesCubit>().createEmployee(data);
    }
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 14.sp,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black,
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: isDark
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: isDark
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        suffixIcon: suffix,
      ),
      validator: (val) {
        if (required && (val == null || val.trim().isEmpty)) {
          return 'هذا الحقل مطلوب';
        }
        if (controller == _nationalIdCtrl && val != null && val.isNotEmpty) {
          if (val.trim().length != 14 || int.tryParse(val.trim()) == null) {
            return 'الرقم القومي يجب أن يكون مكوناً من 14 رقماً';
          }
        }
        if (keyboardType == TextInputType.emailAddress &&
            val != null &&
            val.isNotEmpty) {
          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          if (!emailRegex.hasMatch(val.trim())) {
            return 'البريد الإلكتروني غير صالح';
          }
        }
        if (keyboardType == TextInputType.phone &&
            val != null &&
            val.isNotEmpty) {
          if (val.trim().length < 8) {
            return 'رقم الهاتف غير صالح';
          }
        }
        return null;
      },
    );
  }
}
