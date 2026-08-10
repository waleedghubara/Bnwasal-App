import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  List<dynamic> _withdrawals = [];
  bool _isLoading = false;
  String? _error;
  String _statusFilter = 'pending'; // 'pending', 'success', 'failed'

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dioConsumer = sl<DioConsumer>();
      final response = await dioConsumer.get(
        EndPoint.adminWithdrawals,
        queryParameters: {'status': _statusFilter},
      );
      if (response != null && response['status'] == 1) {
        final list = response['data'] as List;
        setState(() {
          _withdrawals = list
              .where((item) =>
                  item['paymentMethod'] == 'wallet' ||
                  item['paymentMethod'] == 'bank')
              .toList();
        });
      } else {
        setState(() {
          _error = response?['message']?.toString() ?? 'فشل تحميل طلبات السحب';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ أثناء تحميل البيانات: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveWithdrawal(
    String id,
    double amount,
    String userName,
  ) async {
    final confirm = await _showConfirmDialog(
      title: 'موافقة على طلب السحب',
      content:
          'هل أنت متأكد من الموافقة على طلب سحب بقيمة $amount ج.م للمستخدم $userName؟\nيرجى التأكد من تحويل المبلغ فعلياً لحساب المستخدم أولاً.',
      confirmLabel: 'موافقة وتأكيد التحويل',
      confirmColor: AppColors.success,
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dioConsumer = sl<DioConsumer>();
      final response = await dioConsumer.post(
        '${EndPoint.adminWithdrawals}/$id/approve',
      );
      if (!mounted) return;
      if (response != null && response['status'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت الموافقة على طلب السحب بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadWithdrawals();
      } else {
        _showErrorSnackBar(
          response?['message']?.toString() ?? 'فشل اعتماد طلب السحب',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('حدث خطأ: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rejectWithdrawal(
    String id,
    double amount,
    String userName,
  ) async {
    final confirm = await _showConfirmDialog(
      title: 'رفض طلب السحب',
      content:
          'هل أنت متأكد من رفض طلب سحب بقيمة $amount ج.م للمستخدم $userName؟\nسيتم إرجاع المبلغ المخصوم فوراً لرصيد محفظة المستخدم.',
      confirmLabel: 'رفض وإرجاع الرصيد',
      confirmColor: AppColors.error,
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dioConsumer = sl<DioConsumer>();
      final response = await dioConsumer.post(
        '${EndPoint.adminWithdrawals}/$id/reject',
      );
      if (!mounted) return;
      if (response != null && response['status'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض طلب السحب وإرجاع المبلغ لمحفظة المستخدم'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadWithdrawals();
      } else {
        _showErrorSnackBar(
          response?['message']?.toString() ?? 'فشل رفض طلب السحب',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('حدث خطأ: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF14142a) : AppColors.surface,
          title: Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            content,
            style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'إلغاء',
                style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: isDark ? Colors.white : AppColors.textOnPrimary,
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0a0a1a) : AppColors.background,
        body: Column(
          children: [
            _buildHeader(isWide),
            _buildFilters(),
            Expanded(
              child: _isLoading && _withdrawals.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _error != null
                  ? _buildErrorWidget()
                  : _withdrawals.isEmpty
                  ? _buildEmptyWidget()
                  : isWide
                  ? _buildTableView()
                  : _buildCardView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF14142a) : AppColors.surface).withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.025),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        isWide ? 32.w : 20.w,
        isWide ? 28.h : 20.h,
        isWide ? 32.w : 20.w,
        isWide ? 24.h : 16.h,
      ),
      child: Row(
        children: [
          Text(
            'طلبات سحب الرصيد',
            style: TextStyle(
              fontSize: isWide ? 22.sp : 18.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${_withdrawals.length}',
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : AppColors.textSecondary),
              tooltip: 'تحديث البيانات',
              onPressed: _loadWithdrawals,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14142a) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.025)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterItem(
            'pending',
            'قيد الانتظار',
            Icons.hourglass_empty_rounded,
          ),
          _buildFilterItem(
            'success',
            'المقبولة',
            Icons.check_circle_outline_rounded,
          ),
          _buildFilterItem('failed', 'المرفوضة', Icons.cancel_outlined),
        ],
      ),
    );
  }

  Widget _buildFilterItem(String value, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        if (!selected) {
          setState(() {
            _statusFilter = value;
          });
          _loadWithdrawals();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF003b8a)],
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: selected ? (isDark ? Colors.white : AppColors.textPrimary) : (isDark ? Colors.white54 : AppColors.textSecondary),
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: selected ? (isDark ? Colors.white : AppColors.textPrimary) : (isDark ? Colors.white70 : AppColors.textSecondary),
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: EdgeInsets.all(24.w),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'حدث خطأ في تحميل البيانات',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 12.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: _loadWithdrawals,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: isDark ? Colors.white : AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.025)),
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              color: isDark ? Colors.white24 : const Color(0xFFBDBDBD),
              size: 48.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد طلبات سحب',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'لا توجد طلبات سحب ${_statusFilter == 'pending'
                ? 'قيد الانتظار'
                : _statusFilter == 'success'
                ? 'مقبولة'
                : 'مرفوضة'} حالياً',
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: _withdrawals.length,
      itemBuilder: (context, index) {
        final item = _withdrawals[index];
        final id = item['id'].toString();
        final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        final details = item['accountDetails'] as Map<String, dynamic>;
        final user = item['user'] as Map<String, dynamic>;
        final userName = user['name'] ?? '';
        final method = item['paymentMethod'] ?? 'wallet';
        final isPending = item['status'] == 'pending';
        final role = user['role']?.toString() ?? '';
        final balance = (user['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final profileImg = user['profileImage']?.toString();
        final String? imgUrl = (profileImg != null && profileImg.isNotEmpty)
            ? "${EndPoint.imageBaseUrl.trim()}$profileImg"
            : null;

        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark ? [const Color(0xFF14142a), const Color(0xFF0e0e20)] : [AppColors.surface, const Color(0xFFF0F2F5)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showUserDetailsDialog(item),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header of Card (Avatar, Name, Amount)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22.r,
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.025),
                          backgroundImage: imgUrl != null
                              ? NetworkImage(imgUrl)
                              : null,
                          child: imgUrl == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 22.r,
                                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                                )
                              : null,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (role == 'captain'
                                                  ? AppColors.primary2
                                                  : AppColors.primary)
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      role == 'captain'
                                          ? 'كابتن / مندوب'
                                          : 'تاجر',
                                      style: TextStyle(
                                        color: role == 'captain'
                                            ? AppColors.primary2
                                            : AppColors.primary,
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 12.sp,
                                    color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    '${balance.toStringAsFixed(2)} ج.م',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : AppColors.textLight,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amount.toStringAsFixed(2),
                              style: TextStyle(
                                color: AppColors.primary2,
                                fontWeight: FontWeight.w900,
                                fontSize: 16.sp,
                              ),
                            ),
                            Text(
                              'ج.م',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : AppColors.textSecondary,
                                fontSize: 9.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Divider(color: isDark ? Colors.white10 : Colors.black12, height: 24),

                    // Transfer Details Container
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                method == 'wallet'
                                    ? Icons.phone_android_rounded
                                    : Icons.account_balance_rounded,
                                size: 14.sp,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                method == 'wallet'
                                    ? 'طريقة السحب: محفظة إلكترونية'
                                    : 'طريقة السحب: حساب بنكي',
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          if (method == 'wallet') ...[
                            _buildDetailRow(
                              'مزود المحفظة:',
                              details['walletProvider'] ?? '',
                              Icons.business_rounded,
                            ),
                            _buildDetailRow(
                              'رقم المحفظة:',
                              details['phone'] ?? '',
                              Icons.phone_rounded,
                            ),
                            _buildDetailRow(
                              'الاسم المسجل:',
                              details['name'] ?? '',
                              Icons.assignment_ind_rounded,
                            ),
                          ] else ...[
                            _buildDetailRow(
                              'اسم البنك:',
                              details['bankName'] ?? '',
                              Icons.business_rounded,
                            ),
                            _buildDetailRow(
                              'رقم الحساب/IBAN:',
                              details['bankAccountNumber'] ?? '',
                              Icons.numbers_rounded,
                            ),
                            _buildDetailRow(
                              'الاسم بالكامل:',
                              details['name'] ?? '',
                              Icons.assignment_ind_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Date and Status / Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12.sp,
                              color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'تاريخ الطلب: ${item['date']}',
                              style: TextStyle(
                                color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                        if (!isPending)
                          _buildStatusBadge(item['status']?.toString() ?? ''),
                      ],
                    ),

                    if (isPending) ...[
                      Divider(color: isDark ? Colors.white10 : Colors.black12, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _rejectWithdrawal(id, amount, userName),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.error.withValues(alpha: 0.5),
                                ),
                                foregroundColor: AppColors.error,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                              ),
                              label: const Text('رفض الطلب'),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _approveWithdrawal(id, amount, userName),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: isDark ? Colors.white : AppColors.textOnPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                elevation: 2,
                                shadowColor: AppColors.success.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              label: const Text('موافقة وقبول'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 12.sp, color: isDark ? Colors.white30 : const Color(0xFF9E9E9E)),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 11.sp),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    if (status == 'success') {
      color = AppColors.success;
      label = 'مقبول';
      icon = Icons.check_circle_rounded;
    } else if (status == 'failed') {
      color = AppColors.error;
      label = 'مرفوض';
      icon = Icons.cancel_rounded;
    } else {
      color = AppColors.warning;
      label = 'قيد الانتظار';
      icon = Icons.hourglass_empty_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14142a) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
              width: 1,
            ),
          ),
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(3.5),
            4: FlexColumnWidth(1.5),
            5: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
              ),
              children: [
                _th('المستخدم'),
                _th('رصيد المحفظة'),
                _th('المبلغ المطلوب'),
                _th('تفاصيل السحب والتحويل'),
                _th('تاريخ الطلب'),
                _th('الإجراءات'),
              ],
            ),
            ..._withdrawals.map((item) {
              final id = item['id'].toString();
              final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
              final details = item['accountDetails'] as Map<String, dynamic>;
              final user = item['user'] as Map<String, dynamic>;
              final userName = user['name'] ?? '';
              final method = item['paymentMethod'] ?? 'wallet';
              final isPending = item['status'] == 'pending';

              Widget detailsWidget;
              if (method == 'wallet') {
                detailsWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.phone_android_rounded,
                          size: 12.sp,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'محفظة: ${details['walletProvider'] ?? ""}',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'رقم: ${details['phone'] ?? ""}',
                      style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 11.sp),
                    ),
                    Text(
                      'الاسم: ${details['name'] ?? ""}',
                      style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 10.sp),
                    ),
                  ],
                );
              } else {
                detailsWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 12.sp,
                          color: AppColors.primary2,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'بنك: ${details['bankName'] ?? ""}',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'حساب: ${details['bankAccountNumber'] ?? ""}',
                      style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 11.sp),
                    ),
                    Text(
                      'الاسم: ${details['name'] ?? ""}',
                      style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 10.sp),
                    ),
                  ],
                );
              }

              return TableRow(
                children: [
                  _tdUser(
                    userName,
                    user['role']?.toString() ?? '',
                    user['profileImage']?.toString(),
                    onTap: () => _showUserDetailsDialog(item),
                  ),
                  _td(
                    '${user['walletBalance']} ج.م',
                    onTap: () => _showUserDetailsDialog(item),
                  ),
                  _td(
                    '$amount ج.م',
                    isMain: true,
                    onTap: () => _showUserDetailsDialog(item),
                  ),
                  InkWell(
                    onTap: () => _showUserDetailsDialog(item),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 8.w,
                      ),
                      child: detailsWidget,
                    ),
                  ),
                  _td(
                    item['date'] ?? '',
                    onTap: () => _showUserDetailsDialog(item),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 8.w,
                    ),
                    child: isPending
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    _approveWithdrawal(id, amount, userName),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: isDark ? Colors.white : AppColors.textOnPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 8.h,
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  'قبول',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              OutlinedButton(
                                onPressed: () =>
                                    _rejectWithdrawal(id, amount, userName),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(
                                    color: AppColors.error,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 8.h,
                                  ),
                                ),
                                child: Text(
                                  'رفض',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: _buildStatusBadge(
                              item['status']?.toString() ?? '',
                            ),
                          ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _th(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _td(String text, {bool isMain = false, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: isMain ? FontWeight.w800 : FontWeight.normal,
            color: isMain ? AppColors.primary2 : (isDark ? Colors.white70 : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _tdUser(
    String name,
    String role,
    String? profileImg, {
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String? imgUrl = (profileImg != null && profileImg.isNotEmpty)
        ? "${EndPoint.imageBaseUrl.trim()}$profileImg"
        : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16.r,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.025),
              backgroundImage: imgUrl != null ? NetworkImage(imgUrl) : null,
              child: imgUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      size: 16.r,
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                    )
                  : null,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (role == 'captain'
                                  ? AppColors.primary2
                                  : AppColors.primary)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      role == 'captain' ? 'كابتن / مندوب' : 'تاجر',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: role == 'captain'
                            ? AppColors.primary2
                            : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailsDialog(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = item['user'] as Map<String, dynamic>;
    final details = item['accountDetails'] as Map<String, dynamic>;
    final method = item['paymentMethod'] ?? 'wallet';
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final isPending = item['status'] == 'pending';
    final id = item['id'].toString();
    final userName = user['name'] ?? '';
    final role = user['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر';
    final balance = (user['walletBalance'] as num?)?.toDouble() ?? 0.0;

    final profileImg = user['profileImage']?.toString();
    final String? imgUrl = (profileImg != null && profileImg.isNotEmpty)
        ? "${EndPoint.imageBaseUrl.trim()}$profileImg"
        : null;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: isDark ? const Color(0xFF14142a) : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: 450.w,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14142a) : AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Bar
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        color: AppColors.primary2,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'تفاصيل العميل والطلب',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white60 : AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? Colors.white10 : Colors.black12),
                  SizedBox(height: 12.h),

                  // Profile Image / Avatar
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: user['role'] == 'captain'
                            ? AppColors.primary2
                            : AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 36.r,
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.025),
                      backgroundImage: imgUrl != null
                          ? NetworkImage(imgUrl)
                          : null,
                      child: imgUrl == null
                          ? Icon(
                              Icons.person_rounded,
                              size: 36.r,
                              color: isDark ? Colors.white54 : AppColors.textSecondary,
                            )
                          : null,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    userName,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (user['role'] == 'captain'
                                  ? AppColors.primary2
                                  : AppColors.primary)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        color: user['role'] == 'captain'
                            ? AppColors.primary2
                            : AppColors.primary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // User Personal Info Card
                  _buildDialogInfoSection(
                    title: 'بيانات العميل الشخصية',
                    icon: Icons.contact_phone_rounded,
                    children: [
                      _buildDialogInfoRow(
                        'الهاتف:',
                        user['phone'] ?? '',
                        context,
                        showCopy: true,
                      ),
                      _buildDialogInfoRow(
                        'البريد الإلكتروني:',
                        user['email'] ?? '',
                        context,
                        showCopy: true,
                      ),
                      if (user['storeName'] != null &&
                          user['storeName'].toString().isNotEmpty)
                        _buildDialogInfoRow(
                          'اسم المتجر:',
                          user['storeName'].toString(),
                          context,
                          showCopy: true,
                        ),
                      _buildDialogInfoRow(
                        'رصيد المحفظة الحالي:',
                        '${balance.toStringAsFixed(2)} ج.م',
                        context,
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Withdrawal details Card
                  _buildDialogInfoSection(
                    title: 'بيانات التحويل المطلوب',
                    icon: Icons.currency_exchange_rounded,
                    children: [
                      _buildDialogInfoRow(
                        'المبلغ المطلوب سحبه:',
                        '${amount.toStringAsFixed(2)} ج.م',
                        context,
                        isHighlight: true,
                      ),
                      _buildDialogInfoRow(
                        'طريقة التحويل:',
                        method == 'wallet' ? 'محفظة إلكترونية' : 'حساب بنكي',
                        context,
                      ),
                      if (method == 'wallet') ...[
                        _buildDialogInfoRow(
                          'مزود المحفظة:',
                          details['walletProvider'] ?? '',
                          context,
                        ),
                        _buildDialogInfoRow(
                          'رقم المحفظة:',
                          details['phone'] ?? '',
                          context,
                          showCopy: true,
                        ),
                        _buildDialogInfoRow(
                          'الاسم بالكامل:',
                          details['name'] ?? '',
                          context,
                          showCopy: true,
                        ),
                      ] else ...[
                        _buildDialogInfoRow(
                          'اسم البنك:',
                          details['bankName'] ?? '',
                          context,
                        ),
                        _buildDialogInfoRow(
                          'رقم الحساب/IBAN:',
                          details['bankAccountNumber'] ?? '',
                          context,
                          showCopy: true,
                        ),
                        _buildDialogInfoRow(
                          'الاسم بالكامل:',
                          details['name'] ?? '',
                          context,
                          showCopy: true,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 10.sp,
                        color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'تاريخ تقديم الطلب: ${item['date']}',
                        style: TextStyle(
                          color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Bottom Action Buttons
                  if (isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _rejectWithdrawal(id, amount, userName);
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.error.withValues(alpha: 0.5),
                              ),
                              foregroundColor: AppColors.error,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('رفض وإرجاع الرصيد'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _approveWithdrawal(id, amount, userName);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: isDark ? Colors.white : AppColors.textOnPrimary,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: AppColors.success.withValues(
                                alpha: 0.2,
                              ),
                            ),
                            child: const Text('قبول وتأكيد التحويل'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        color: item['status'] == 'success'
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item['status'] == 'success'
                              ? AppColors.success.withValues(alpha: 0.2)
                              : AppColors.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        item['status'] == 'success'
                            ? 'مقبول وتم التحويل'
                            : 'مرفوض وتم إرجاع الرصيد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: item['status'] == 'success'
                              ? AppColors.success
                              : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14.sp, color: AppColors.primary2),
              SizedBox(width: 6.w),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.primary2,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          Divider(color: isDark ? Colors.white10 : Colors.black12, height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(
    String label,
    String value,
    BuildContext context, {
    bool isHighlight = false,
    bool showCopy = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 12.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight ? AppColors.primary2 : (isDark ? Colors.white : AppColors.textPrimary),
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (showCopy && value.isNotEmpty) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text('تم نسخ: $value'),
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Icon(
                Icons.copy_rounded,
                size: 14.sp,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
