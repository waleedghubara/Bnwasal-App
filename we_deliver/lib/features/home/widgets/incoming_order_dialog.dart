import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class IncomingOrderDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String orderType;
  final String pickupArea;
  final String deliveryArea;
  final String distance;
  final String priceText;
  final String timeAgo;
  final String notes;
  final int timeoutSeconds;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingOrderDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.orderType,
    required this.pickupArea,
    required this.deliveryArea,
    required this.distance,
    required this.priceText,
    required this.timeAgo,
    required this.notes,
    required this.timeoutSeconds,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingOrderDialog> createState() => _IncomingOrderDialogState();
}

class _IncomingOrderDialogState extends State<IncomingOrderDialog> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeoutSeconds > 0 ? widget.timeoutSeconds : 60;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      } else {
        _timer?.cancel();
        if (mounted) {
          widget.onReject();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final progress = _remainingSeconds / (widget.timeoutSeconds > 0 ? widget.timeoutSeconds : 60);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header with Logo & Title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Text(
                        'تفاصيل الطلب',
                        style: GoogleFonts.tajawal(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // App Logo Symbol
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'bn',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF204CB3),
                            ),
                          ),
                          Container(
                            width: 6.r,
                            height: 6.r,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF78710),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),

                // 2. Top Circular Countdown Banner
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFFFE0B2)),
                  ),
                  child: Row(
                    children: [
                      // Circular Countdown Ring
                      SizedBox(
                        width: 72.w,
                        height: 72.w,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 72.w,
                              height: 72.w,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 5.w,
                                backgroundColor: const Color(0xFFFFE0B2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _remainingSeconds <= 15
                                      ? Colors.red
                                      : const Color(0xFFF78710),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$minutes:$seconds',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'الوقت المتبقي',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 8.sp,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 14.w),

                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  color: const Color(0xFFF78710),
                                  size: 18.sp,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'في انتظار قبولك',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFE65100),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'سيتم إلغاؤه تلقائياً إذا لم يتم قبول الطلب',
                              style: GoogleFonts.tajawal(
                                fontSize: 11.sp,
                                color: Colors.grey.shade700,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),

                // 3. Trip Information Table Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    children: [
                      // Section Header
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: const Color(0xFF204CB3),
                            size: 18.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'معلومات الرحلة',
                            style: GoogleFonts.tajawal(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Divider(height: 1, color: Colors.grey.shade100),

                      _buildTableRow(
                        icon: Icons.shopping_cart_outlined,
                        iconColor: const Color(0xFF204CB3),
                        title: 'نوع الطلب',
                        value: widget.orderType,
                      ),
                      _buildTableRow(
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFF204CB3),
                        title: 'منطقة الاستلام',
                        value: widget.pickupArea,
                      ),
                      _buildTableRow(
                        icon: Icons.location_on,
                        iconColor: const Color(0xFFF78710),
                        title: 'منطقة التسليم',
                        value: widget.deliveryArea,
                      ),
                      _buildTableRow(
                        icon: Icons.alt_route_rounded,
                        iconColor: const Color(0xFF204CB3),
                        title: 'المسافة التقديرية',
                        value: widget.distance,
                      ),
                      _buildTableRow(
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: const Color(0xFF204CB3),
                        title: 'الأجرة',
                        value: widget.priceText,
                        valueColor: const Color(0xFFE65100),
                        isBoldValue: true,
                      ),
                      _buildTableRow(
                        icon: Icons.access_time,
                        iconColor: Colors.grey.shade600,
                        title: 'وقت إنشاء الطلب',
                        value: widget.timeAgo,
                      ),
                      _buildTableRow(
                        icon: Icons.notes_rounded,
                        iconColor: const Color(0xFF204CB3),
                        title: 'ملاحظات مختصرة',
                        value: widget.notes,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),

                // 4. Privacy Shield Box
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFFFE0B2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF78710),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'سيتم إظهار بيانات العميل الكاملة بعد قبول الطلب.',
                          style: GoogleFonts.tajawal(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),

                // 5. Action Buttons (Accept & Reject)
                Row(
                  children: [
                    // Reject Button (Grey with X)
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: widget.onReject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B7280),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded, color: Colors.white, size: 20.sp),
                              SizedBox(width: 6.w),
                              Text(
                                'رفض',
                                style: GoogleFonts.tajawal(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Accept Button (Green with Checkmark)
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: widget.onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF388E3C),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20.sp),
                              SizedBox(width: 6.w),
                              Text(
                                'قبول الطلب',
                                style: GoogleFonts.tajawal(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildTableRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color? valueColor,
    bool isBoldValue = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 16.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: GoogleFonts.tajawal(
                  fontSize: 12.sp,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.tajawal(
                  fontSize: 13.sp,
                  fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }
}
