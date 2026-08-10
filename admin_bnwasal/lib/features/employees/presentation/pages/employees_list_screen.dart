// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../cubit/employees_cubit.dart';
import '../cubit/employees_state.dart';
import 'add_edit_employee_screen.dart';

class EmployeesListScreen extends StatefulWidget {
  const EmployeesListScreen({super.key});

  @override
  State<EmployeesListScreen> createState() => _EmployeesListScreenState();
}

class _EmployeesListScreenState extends State<EmployeesListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<EmployeesCubit>().loadEmployees(refresh: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Column(
      children: [
        _buildHeader(context.watch<EmployeesCubit>().state, isWide),
        if (context.watch<EmployeesCubit>().state.error != null)
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'خطأ في تحميل البيانات',
              style: TextStyle(color: AppColors.error, fontSize: 13.sp),
            ),
          ),
        Expanded(
          child: _buildList(context.watch<EmployeesCubit>().state, isWide),
        ),
      ],
    );
  }

  Widget _buildHeader(EmployeesState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                'الموظفين',
                style: TextStyle(
                  fontSize: isWide ? 22.sp : 18.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${state.total}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDark ? const Color(0xFF60a5fa) : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              _addButton(),
            ],
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => context.read<EmployeesCubit>().search(v),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'بحث عن موظف بالاسم، البريد أو الهاتف...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white54 : Colors.black,
                size: 20.sp,
              ),
              fillColor: Colors.transparent,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _addButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToAdd(),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF0056c6)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18.sp, color: Colors.white),
              SizedBox(width: 6.w),
              Text(
                'إضافة موظف',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(EmployeesState state, bool isWide) {
    if (state.isLoading && state.employees.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (state.employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 56.sp,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black12,
            ),
            SizedBox(height: 16.h),
            Text(
              'لا يوجد موظفين مسجلين حالياً',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
          if (!state.isLoading && state.employees.length < state.total) {
            context.read<EmployeesCubit>().loadMore();
          }
        }
        return false;
      },
      child: isWide
          ? GridView.builder(
              padding: EdgeInsets.fromLTRB(32.w, 0, 32.w, 32.h),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380.w,
                mainAxisSpacing: 14.h,
                crossAxisSpacing: 14.w,
                mainAxisExtent: 155.h,
              ),
              itemCount: state.employees.length + (state.isLoading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= state.employees.length) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  );
                }
                return _buildEmployeeCard(
                  state.employees[i] as Map<String, dynamic>,
                  isWide: true,
                );
              },
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 32.h),
              itemCount: state.employees.length + (state.isLoading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= state.employees.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                return _buildEmployeeCard(
                  state.employees[i] as Map<String, dynamic>,
                  isWide: false,
                );
              },
            ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp, {required bool isWide}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
    final email = emp['email'] ?? '';
    final phone = emp['phone'] ?? '';
    final permStr = emp['permissions']?.toString() ?? '';
    final perms = permStr.isNotEmpty
        ? permStr
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
        : <String>[];
    final status = emp['status'] ?? 'active';

    return Container(
      margin: isWide ? EdgeInsets.zero : EdgeInsets.only(bottom: 12.h),
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
                ? Colors.black.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToEdit(emp),
          hoverColor: AppColors.primary.withValues(alpha: 0.05),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: [
                _avatar(name),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isNotEmpty ? name : 'بدون اسم',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _statusBadge(status),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      if (email.isNotEmpty)
                        Text(
                          email.toString(),
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            color: isDark ? Colors.white : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,
                        ),
                      if (phone.isNotEmpty)
                        Text(
                          phone.toString(),
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.primary2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (perms.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 4.w,
                          runSpacing: 4.h,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ...perms
                                .take(isWide ? 2 : 3)
                                .map((p) => _permChip(p)),
                            if (perms.length > (isWide ? 2 : 3))
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  '+${perms.length - (isWide ? 2 : 3)}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.primary2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                FaIcon(
                  FontAwesomeIcons.longArrowLeft,
                  size: 20.sp,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: TextStyle(
          fontSize: 16.sp,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final active = status == 'active';
    final badgeColor = active ? AppColors.success : AppColors.error;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        active ? 'نشط' : 'محظور',
        style: TextStyle(
          fontSize: 9.sp,
          color: badgeColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _permChip(String key) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = {
      'dashboard': 'الإحصائيات',
      'merchants': 'التجار',
      'captains': 'الكباتن',
      'trips': 'الرحلات',
      'orders': 'الطلبات',
      'users': 'المستخدمين',
      'todayOrdersShipments': 'طلبات اليوم',
      'todayTrips': 'رحلات اليوم',
      'pendingAccounts': 'قبول الحسابات',
      'complaints': 'الشكاوى',
      'notifications': 'الإشعارات',
      'withdrawals': 'طلبات السحب',
      'wallet': 'المحفظة العامة',
      'userMessages': 'رسائل المستخدمين',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.shade300,
        ),
      ),
      child: Text(
        labels[key] ?? key,
        style: TextStyle(
          fontSize: 12.sp,
          color: isDark ? const Color(0xFF60a5fa) : AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navigateToAdd() {
    final cubit = context.read<EmployeesCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const AddEditEmployeeScreen(),
        ),
      ),
    );
  }

  void _navigateToEdit(Map<String, dynamic> emp) {
    final cubit = context.read<EmployeesCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: AddEditEmployeeScreen(employee: emp),
        ),
      ),
    );
  }
}
