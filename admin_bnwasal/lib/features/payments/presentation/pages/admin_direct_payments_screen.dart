// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';

class AdminDirectPaymentsScreen extends StatefulWidget {
  const AdminDirectPaymentsScreen({super.key});

  @override
  State<AdminDirectPaymentsScreen> createState() =>
      _AdminDirectPaymentsScreenState();
}

class _AdminDirectPaymentsScreenState extends State<AdminDirectPaymentsScreen> {
  List<dynamic> _payments = [];
  bool _isLoading = false;
  String? _error;
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = sl<DioConsumer>();
      final response = await dio.get(
        EndPoint.directPaymentsList,
        queryParameters: {'status': _statusFilter},
      );
      if (response != null && response['status'] == 1) {
        setState(() {
          _payments = response['data']['payments'] as List;
        });
      } else {
        setState(() {
          _error = response?['message']?.toString() ?? 'فشل تحميل البيانات';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _review(String id, String action, {String? note}) async {
    try {
      final dio = sl<DioConsumer>();
      final response = await dio.put(
        EndPoint.directPaymentReview(id),
        data: {'action': action, 'adminNote': note ?? ''},
      );
      if (response != null && response['status'] == 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                action == 'approve'
                    ? '✅ تم قبول الدفع بنجاح'
                    : '❌ تم رفض الدفع',
                style: GoogleFonts.tajawal(),
              ),
              backgroundColor: action == 'approve'
                  ? AppColors.success
                  : AppColors.error,
            ),
          );
          _loadPayments();
        }
      } else {
        if (mounted) {
          _showError(response?['message']?.toString() ?? 'فشل العملية');
        }
      }
    } catch (e) {
      if (mounted) _showError('حدث خطأ: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.tajawal()),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _showReviewDialog(Map<String, dynamic> payment) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String noteText = '';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: isDark
                ? const Color(0xFF14142a)
                : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'مراجعة إيصال الدفع',
              style: GoogleFonts.tajawal(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt image
                  _buildReceiptPreview(payment['receiptImage']?.toString()),
                  SizedBox(height: 16.h),
                  // Payment info
                  _buildInfoRow(
                    'رقم الطلب',
                    payment['orderNumber'] ?? payment['shipmentNumber'] ?? '—',
                  ),
                  _buildInfoRow('طريقة الدفع', payment['paymentMethod'] ?? '—'),
                  _buildInfoRow(
                    'رقم الهاتف المُحوَّل منه',
                    payment['fromPhone'] ?? '—',
                  ),
                  _buildInfoRow('اسم صاحب الرقم', payment['fromName'] ?? '—'),
                  _buildInfoRow('المبلغ', '${payment['amount']} ج.م'),
                  SizedBox(height: 16.h),
                  Text(
                    'ملاحظة للمستخدم (اختياري):',
                    style: GoogleFonts.tajawal(
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  TextField(
                    onChanged: (v) => noteText = v,
                    style: GoogleFonts.tajawal(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'سبب الرفض أو ملاحظة...',
                      hintStyle: GoogleFonts.tajawal(
                        color: isDark ? Colors.white38 : AppColors.textLight,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.025),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      contentPadding: EdgeInsets.all(12.w),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.tajawal(
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'reject'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error,
                ),
                child: Text(
                  'رفض',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'قبول',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      await _review(payment['id'].toString(), result, note: noteText);
    }
  }

  Widget _buildReceiptPreview(String? filename) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (filename == null || filename.isEmpty) {
      return Container(
        height: 140.h,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.015),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.03),
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
            size: 40,
          ),
        ),
      );
    }
    final url = '${EndPoint.imageBaseUrl}/uploads/receipts/$filename';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        height: 180.h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 140.h,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.015),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              Icons.broken_image,
              color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white54 : AppColors.textSecondary,
              fontSize: 12.sp,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.tajawal(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0a0a1a)
            : AppColors.background,
        body: Column(
          children: [
            _buildHeader(isWide),
            _buildFilters(),
            Expanded(
              child: _isLoading && _payments.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _error != null
                  ? _buildErrorWidget()
                  : _payments.isEmpty
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
        color: isDark
            ? const Color(0xFF14142a).withOpacity(0.4)
            : AppColors.surface.withOpacity(0.4),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.025),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'دفعات الشحنات والطلبات',
                  style: GoogleFonts.tajawal(
                    fontSize: isWide ? 18.sp : 16.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.015),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
              tooltip: 'تحديث',
              onPressed: _loadPayments,
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.6)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_payments.length}',
              style: GoogleFonts.tajawal(
                fontSize: 12.sp,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14142a) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.025),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterItem(
              'pending',
              'قيد الانتظار',
              Icons.hourglass_empty_rounded,
            ),
          ),
          Expanded(
            child: _buildFilterItem(
              'approved',
              'المقبولة',
              Icons.check_circle_outline_rounded,
            ),
          ),
          Expanded(
            child: _buildFilterItem('rejected', 'المرفوضة', Icons.cancel_outlined),
          ),
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
          setState(() => _statusFilter = value);
          _loadPayments();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
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
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15.sp,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white54 : AppColors.textSecondary),
            ),
            SizedBox(width: 5.w),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.tajawal(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.textSecondary),
                  fontWeight: selected ? FontWeight.bold : FontWeight.w700,
                  fontSize: 14.sp,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.black.withOpacity(0.01),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.025),
              ),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: isDark ? Colors.white24 : const Color(0xFFBDBDBD),
              size: 48.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد دفعات',
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'لا توجد إيصالات دفع ${_statusFilter == 'pending'
                ? 'قيد الانتظار'
                : _statusFilter == 'approved'
                ? 'مقبولة'
                : 'مرفوضة'} حالياً',
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white38 : AppColors.textLight,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 48.sp,
            ),
            SizedBox(height: 12.h),
            Text(
              _error!,
              style: GoogleFonts.tajawal(
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadPayments,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text('إعادة المحاولة', style: GoogleFonts.tajawal()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardView() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: _payments.length,
      itemBuilder: (context, index) => _buildPaymentCard(_payments[index]),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPending = payment['status'] == 'pending';
    final isApproved = payment['status'] == 'approved';
    final firstName = payment['firstName']?.toString() ?? '';
    final lastName = payment['lastName']?.toString() ?? '';
    final userName = '$firstName $lastName'.trim().isEmpty
        ? 'مجهول'
        : '$firstName $lastName'.trim();
    final userPhone = payment['phone']?.toString() ?? '';
    final profileImg = payment['profileImage']?.toString();
    final String? imgUrl = (profileImg != null && profileImg.isNotEmpty)
        ? '${EndPoint.imageBaseUrl}$profileImg'
        : null;
    final amount = double.tryParse(payment['amount']?.toString() ?? '') ?? 0.0;
    final itemNumber =
        payment['orderNumber'] ?? payment['shipmentNumber'] ?? '—';
    final type = payment['orderId'] != null ? 'طلب' : 'شحنة';
    final payMethod = payment['paymentMethod']?.toString() ?? '—';
    final fromPhone = payment['fromPhone']?.toString() ?? '—';
    final fromName = payment['fromName']?.toString() ?? '—';

    return GestureDetector(
      onTap: isPending ? () => _showReviewDialog(payment) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF14142a) : AppColors.surface,
              isDark ? const Color(0xFF0e0e20) : const Color(0xFFF0F2F5),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPending
                ? AppColors.primary.withOpacity(0.2)
                : isApproved
                ? AppColors.success.withOpacity(0.2)
                : AppColors.error.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.025),
                    backgroundImage: imgUrl != null
                        ? NetworkImage(imgUrl)
                        : null,
                    child: imgUrl == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 22.r,
                            color: isDark
                                ? Colors.white54
                                : AppColors.textSecondary,
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
                          style: GoogleFonts.tajawal(
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userPhone,
                          style: GoogleFonts.tajawal(
                            color: isDark
                                ? Colors.white38
                                : AppColors.textLight,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${amount.toInt()} ج.م',
                        style: GoogleFonts.tajawal(
                          color: const Color(0xFFF78710),
                          fontWeight: FontWeight.w900,
                          fontSize: 16.sp,
                        ),
                      ),
                      _buildStatusBadge(payment['status']?.toString() ?? ''),
                    ],
                  ),
                ],
              ),
              Divider(
                color: isDark ? Colors.white10 : Colors.black12,
                height: 20,
              ),
              // Payment details
              _buildDetailChip(
                Icons.confirmation_number_outlined,
                '$type #$itemNumber',
              ),
              SizedBox(height: 6.h),
              _buildDetailChip(Icons.smartphone_rounded, 'عبر: $payMethod'),
              SizedBox(height: 4.h),
              _buildDetailChip(
                Icons.phone_outlined,
                'من: $fromPhone ($fromName)',
              ),
              SizedBox(height: 4.h),
              _buildDetailChip(
                Icons.access_time_rounded,
                _formatDate(payment['createdAt']?.toString()),
              ),
              // Action buttons for pending
              if (isPending) ...[
                Divider(
                  color: isDark ? Colors.white10 : Colors.black12,
                  height: 20,
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showReviewDialog(payment),
                        icon: const Icon(Icons.image_search_rounded, size: 16),
                        label: Text(
                          'عرض الإيصال ومراجعة',
                          style: GoogleFonts.tajawal(fontSize: 12.sp),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 13.sp,
          color: isDark ? Colors.white38 : AppColors.textLight,
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white60 : Colors.black,
              fontSize: 14.sp,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = AppColors.success;
        label = 'مقبول';
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'مرفوض';
        break;
      default:
        color = Colors.amber;
        label = 'قيد الانتظار';
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.tajawal(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  // ─── Table View for wide screens ─────────────────────────────────────────────
  Widget _buildTableView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          // Table header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14142a) : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildTableHeader('التاجر', flex: 2),
                _buildTableHeader('النوع والرقم', flex: 2),
                _buildTableHeader('طريقة الدفع', flex: 2),
                _buildTableHeader('المبلغ', flex: 1),
                _buildTableHeader('الحالة', flex: 1),
                _buildTableHeader('التاريخ', flex: 2),
                _buildTableHeader('إجراء', flex: 1),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          ..._payments.map((p) => _buildTableRow(p as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String label, {int flex = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.tajawal(
          color: isDark ? Colors.white54 : Colors.black,
          fontSize: 13.sp,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> payment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPending = payment['status'] == 'pending';
    final firstName = payment['firstName']?.toString() ?? '';
    final lastName = payment['lastName']?.toString() ?? '';
    final userName = '$firstName $lastName'.trim().isEmpty
        ? 'مجهول'
        : '$firstName $lastName'.trim();
    final amount = double.tryParse(payment['amount']?.toString() ?? '') ?? 0.0;
    final itemNumber =
        payment['orderNumber'] ?? payment['shipmentNumber'] ?? '—';
    final type = payment['orderId'] != null ? 'طلب' : 'شحنة';
    final profileImg = payment['profileImage']?.toString();
    final imgUrl = (profileImg != null && profileImg.isNotEmpty)
        ? '${EndPoint.imageBaseUrl}$profileImg'
        : null;

    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0e0e20) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16.r,
                  backgroundImage: imgUrl != null ? NetworkImage(imgUrl) : null,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.025),
                  child: imgUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 16.r,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                        )
                      : null,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    userName,
                    style: GoogleFonts.tajawal(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$type #$itemNumber',
              style: GoogleFonts.tajawal(
                color: isDark ? Colors.white70 : AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              payment['paymentMethod']?.toString() ?? '—',
              style: GoogleFonts.tajawal(
                color: isDark ? Colors.white70 : Colors.black,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${amount.toInt()} ج',
              style: GoogleFonts.tajawal(
                color: const Color(0xFFF78710),
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _buildStatusBadge(payment['status']?.toString() ?? ''),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(payment['createdAt']?.toString()),
              style: GoogleFonts.tajawal(
                color: isDark ? Colors.white38 : Colors.black,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: isPending
                  ? IconButton(
                      icon: const Icon(
                        Icons.image_search_rounded,
                        color: AppColors.primary,
                      ),
                      tooltip: 'مراجعة',
                      onPressed: () => _showReviewDialog(payment),
                    )
                  : Icon(
                      payment['status'] == 'approved'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: payment['status'] == 'approved'
                          ? AppColors.success
                          : AppColors.error,
                      size: 20.sp,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
