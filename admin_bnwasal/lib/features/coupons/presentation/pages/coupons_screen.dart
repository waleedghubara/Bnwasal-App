// ignore_for_file: unnecessary_string_interpolations, use_build_context_synchronously, deprecated_member_use

import 'package:admin_bnwasal/core/theme/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart';

// Helper functions for custom Arabic date and time formatting
String formatArabicDate(DateTime date) {
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
  final days = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];
  final dayName = days[date.weekday % 7];
  final monthName = months[date.month - 1];
  return '$dayName، ${date.day} $monthName ${date.year}';
}

String formatArabicTime(DateTime date) {
  int hour = date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'مساءً' : 'صباحاً';
  if (hour > 12) hour -= 12;
  if (hour == 0) hour = 12;
  return '$hour:$minute $period';
}

// Premium Ticket shape cutout clipper
class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);

    // Left cut
    final leftCut = Path();
    leftCut.addOval(
      Rect.fromCircle(center: Offset(0, size.height / 2), radius: 10),
    );
    // Right cut
    final rightCut = Path();
    rightCut.addOval(
      Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: 10),
    );

    return Path.combine(
      PathOperation.difference,
      path,
      Path.combine(PathOperation.union, leftCut, rightCut),
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Custom Painter for Dashed separator line
class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({this.color = Colors.grey});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    double max = size.height;
    double dashHeight = 5;
    double dashSpace = 4;
    double startY = 0;
    while (startY < max) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final _dio = sl<DioConsumer>();
  List<dynamic> _coupons = [];
  bool _isLoading = false;
  String _filter = 'الكل'; // 'الكل', 'نشط', 'غير نشط'

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.get(EndPoint.couponsAdmin);
      if (response != null && response['status'] == 1) {
        setState(() {
          _coupons = response['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading coupons: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(String couponId, int currentStatus) async {
    try {
      final newStatus = currentStatus == 1 ? 0 : 1;
      final response = await _dio.put(
        '${EndPoint.couponsAdmin}/$couponId/status',
        data: {'status': newStatus},
      );
      if (response != null && response['status'] == 1) {
        _loadCoupons();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث حالة الكوبون بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling coupon status: $e');
    }
  }

  Future<void> _deleteCoupon(String couponId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'تأكيد الحذف',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف هذا الكوبون نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'حذف',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final response = await _dio.delete(
          '${EndPoint.couponsAdmin}/$couponId',
        );
        if (response != null && response['status'] == 1) {
          _loadCoupons();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف الكوبون بنجاح', style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error deleting coupon: $e');
      }
    }
  }

  void _showCreateCouponDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: CreateCouponDialog(
            onCreate: () {
              _loadCoupons();
            },
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  List<dynamic> get _filteredCoupons {
    if (_filter == 'الكل') return _coupons;
    if (_filter == 'نشط')
      return _coupons.where((c) => c['status'] == 1).toList();
    return _coupons.where((c) => c['status'] == 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateCouponDialog,
          backgroundColor: AppColors.primary,
          elevation: 4,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: Text(
            'إنشاء كوبون جديد',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters & Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: ['الكل', 'نشط', 'غير نشط'].map((t) {
                      final isSel = _filter == t;
                      return Padding(
                        padding: EdgeInsetsDirectional.only(end: 8.w),
                        child: ChoiceChip(
                          label: Text(t, style: GoogleFonts.cairo()),
                          selected: isSel,
                          onSelected: (_) => setState(() => _filter = t),
                          selectedColor: AppColors.primary,
                          labelStyle: GoogleFonts.cairo(
                            color: isSel
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      foregroundColor: isDark ? Colors.white70 : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(
                      'تحديث القائمة',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _loadCoupons,
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              // Content Grid
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredCoupons.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              AppAssets.coupons,
                              height: 200.h,
                              width: 200.w,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'لا يوجد كوبونات متوفرة حالياً',
                              style: GoogleFonts.cairo(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420.w,
                          crossAxisSpacing: 20.w,
                          mainAxisSpacing: 20.w,
                          childAspectRatio: 1.7,
                        ),
                        itemCount: _filteredCoupons.length,
                        itemBuilder: (context, index) {
                          final c = _filteredCoupons[index];
                          return _buildCouponCard(c, isDark);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponCard(dynamic c, bool isDark) {
    final code = c['code']?.toString() ?? '';
    final discountType = c['discountType']?.toString() ?? 'fixed';

    final rawDiscount = c['discountValue'];
    final discountVal = rawDiscount == null
        ? 0.0
        : (rawDiscount is num
              ? rawDiscount.toDouble()
              : double.tryParse(rawDiscount.toString()) ?? 0.0);

    final maxUsages = c['maxUsages'] == null
        ? 0
        : (c['maxUsages'] is int
              ? c['maxUsages'] as int
              : int.tryParse(c['maxUsages'].toString()) ?? 0);

    final usedCount = c['realUsedCount'] == null
        ? 0
        : (c['realUsedCount'] is int
              ? c['realUsedCount'] as int
              : int.tryParse(c['realUsedCount'].toString()) ?? 0);

    final status = c['status'] == null
        ? 0
        : (c['status'] is int
              ? c['status'] as int
              : int.tryParse(c['status'].toString()) ?? 0);

    final expirationType = c['expirationType']?.toString() ?? 'never';
    final targetUserRole = c['targetUserRole']?.toString() ?? 'all';

    String discountText = '';
    if (discountType == 'full') {
      discountText = '100% خصم كامل';
    } else {
      discountText = 'خصم ${discountVal.toInt()} ج.م';
    }

    String expiryText = '';
    if (expirationType == 'never') {
      expiryText = 'صلاحية مفتوحة';
    } else if (expirationType == 'date') {
      if (c['expiryDate'] != null) {
        final parsedDate = DateTime.tryParse(c['expiryDate'].toString());
        expiryText = parsedDate != null ? formatArabicDate(parsedDate) : '';
      } else {
        expiryText = '';
      }
    } else {
      final days = {
        1: 'الأحد',
        2: 'الاثنين',
        3: 'الثلاثاء',
        4: 'الأربعاء',
        5: 'الخميس',
        6: 'الجمعة',
        7: 'السبت',
      };
      final rawDay = c['expiryDayOfWeek'];
      final expiryDayOfWeekVal = rawDay == null
          ? null
          : (rawDay is int ? rawDay : int.tryParse(rawDay.toString()));
      expiryText = 'أسبوعي: كل ${days[expiryDayOfWeekVal] ?? ''}';
    }

    final isExpired = maxUsages > 0 && usedCount >= maxUsages;

    return ClipPath(
      clipper: TicketClipper(),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Left Ticket Section (Details)
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.w, 16.h, 20.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E4BA1), Color(0xFF132e4d)],
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            code,
                            style: GoogleFonts.cairo(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Status indicator badge
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: status == 1 ? Colors.green : Colors.grey,
                            boxShadow: status == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      discountText,
                      style: GoogleFonts.cairo(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E4BA1),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            expiryText,
                            style: GoogleFonts.cairo(
                              fontSize: 11.sp,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          targetUserRole == 'specific'
                              ? Icons.lock_outline
                              : Icons.public,
                          size: 13,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          targetUserRole == 'specific'
                              ? 'تجار محددين فقط'
                              : 'عام لجميع التجار',
                          style: GoogleFonts.cairo(
                            fontSize: 11.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Dashed Divider
            CustomPaint(
              size: Size(1.w, double.infinity),
              painter: DashedLinePainter(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.grey.shade300,
              ),
            ),
            // Right Ticket Section (Usages / Controls)
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Switch status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          status == 1 ? 'مفعّل' : 'معطّل',
                          style: GoogleFonts.cairo(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: status == 1 ? Colors.green : Colors.grey,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: status == 1,
                            activeColor: Colors.green,
                            onChanged: (_) =>
                                _toggleStatus(c['id'].toString(), status),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Usage text and indicator
                    Text(
                      'الاستخدام: $usedCount/$maxUsages',
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: LinearProgressIndicator(
                        value: maxUsages > 0 ? (usedCount / maxUsages) : 0,
                        backgroundColor: isDark
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade200,
                        color: isExpired ? Colors.red : const Color(0xFF1E4BA1),
                        minHeight: 5,
                      ),
                    ),
                    const Spacer(),
                    // Delete button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _deleteCoupon(c['id'].toString()),
                        tooltip: 'حذف الكوبون',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateCouponDialog extends StatefulWidget {
  final VoidCallback onCreate;

  const CreateCouponDialog({super.key, required this.onCreate});

  @override
  State<CreateCouponDialog> createState() => _CreateCouponDialogState();
}

class _CreateCouponDialogState extends State<CreateCouponDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _maxUsagesController = TextEditingController(text: '10');

  String _discountType = 'fixed';
  String _expirationType = 'never';
  String _targetUserRole = 'all';

  DateTime? _expiryDate;
  int? _expiryDayOfWeek = 1;
  final List<int> _selectedUserIds = [];
  bool _isLoading = false;
  bool _isLoadingMerchants = false;
  List<dynamic> _merchants = [];
  String _searchMerchantQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMerchants();
  }

  Future<void> _loadMerchants() async {
    setState(() => _isLoadingMerchants = true);
    try {
      final response = await sl<DioConsumer>().get(
        EndPoint.adminMerchants,
        queryParameters: {'limit': 1000},
      );
      if (response != null && response['status'] == 1) {
        final data = response['data'] as Map<String, dynamic>?;
        setState(() {
          _merchants = data?['merchants'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading merchants in dialog: $e');
    } finally {
      setState(() => _isLoadingMerchants = false);
    }
  }

  void _generateCode() {
    final characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomCode = List.generate(6, (index) {
      final randomIndex =
          (DateTime.now().microsecondsSinceEpoch + index + (index * 7)) %
          characters.length;
      return characters[randomIndex];
    }).join();
    setState(() {
      _codeController.text = 'بنوصل-$randomCode';
    });
  }

  Future<void> _selectDate() async {
    final initialDate =
        _expiryDate ?? DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        final currentExpiry = _expiryDate ?? DateTime.now();
        _expiryDate = DateTime(
          date.year,
          date.month,
          date.day,
          currentExpiry.hour,
          currentExpiry.minute,
        );
      });
    }
  }

  Future<void> _selectTimeOnly() async {
    final currentExpiry = _expiryDate ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentExpiry),
    );
    if (time != null) {
      setState(() {
        final date = _expiryDate ?? DateTime.now().add(const Duration(days: 1));
        _expiryDate = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expirationType == 'date' && _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى تحديد تاريخ ووقت الانتهاء',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_targetUserRole == 'specific' && _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى اختيار تاجر واحد على الأقل',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await sl<DioConsumer>().post(
        '${EndPoint.couponsAdmin}',
        data: {
          'code': _codeController.text.trim().toUpperCase(),
          'discountType': _discountType,
          'discountValue': _discountType == 'full'
              ? 0.0
              : double.tryParse(_valueController.text) ?? 0.0,
          'expirationType': _expirationType,
          'expiryDate': _expirationType == 'date'
              ? _expiryDate?.toIso8601String()
              : null,
          'expiryDayOfWeek': _expirationType == 'day_of_week'
              ? _expiryDayOfWeek
              : null,
          'maxUsages': int.tryParse(_maxUsagesController.text) ?? 10,
          'targetUserRole': _targetUserRole,
          'userIds': _targetUserRole == 'specific' ? _selectedUserIds : null,
        },
      );

      if (response != null && response['status'] == 1) {
        widget.onCreate();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء الكوبون بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating coupon: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredMerchants = _merchants.where((m) {
      final storeName = m['storeName']?.toString() ?? '';
      final firstName = m['firstName']?.toString() ?? '';
      final lastName = m['lastName']?.toString() ?? '';
      final name = '$storeName $firstName $lastName'.trim();
      return name.toLowerCase().contains(_searchMerchantQuery.toLowerCase());
    }).toList();

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width > 900 ? 800.w : 600.w,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                'تصميم وإنشاء كوبون خصم جديد',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              backgroundColor: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9),
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            body: Row(
              children: [
                // Right Pane (Form inputs)
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24.w),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Coupon Code
                          Text(
                            'رمز الكوبون والعقد',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _codeController,
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.cairo(),
                                  decoration: InputDecoration(
                                    labelText: 'رمز الكوبون *',
                                    labelStyle: GoogleFonts.cairo(),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'هذا الحقل مطلوب'
                                      : null,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              ElevatedButton.icon(
                                onPressed: _generateCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E4BA1),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 16.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.bolt_outlined,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'توليد تلقائي',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),

                          // Discount details
                          Text(
                            'معايير وقيمة الخصم',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          DropdownButtonFormField<String>(
                            value: _discountType,
                            style: GoogleFonts.cairo(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'fixed',
                                child: Text(
                                  'قيمة خصم ثابتة (ج.م)',
                                  style: GoogleFonts.cairo(),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'full',
                                child: Text(
                                  'خصم التوصيل بالكامل (100%)',
                                  style: GoogleFonts.cairo(),
                                ),
                              ),
                            ],
                            onChanged: (val) => setState(() {
                              _discountType = val!;
                              if (_discountType == 'full') {
                                _valueController.clear();
                              }
                            }),
                          ),
                          if (_discountType == 'fixed') ...[
                            SizedBox(height: 12.h),
                            TextFormField(
                              controller: _valueController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              style: GoogleFonts.cairo(),
                              decoration: InputDecoration(
                                labelText: 'قيمة الخصم بالجنيه *',
                                labelStyle: GoogleFonts.cairo(),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'هذا الحقل مطلوب'
                                  : null,
                            ),
                          ],
                          SizedBox(height: 20.h),

                          // Max Usages limit
                          Text(
                            'شروط وقيود الاستخدام',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextFormField(
                            controller: _maxUsagesController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.cairo(),
                            decoration: InputDecoration(
                              labelText: 'الحد الأقصى لعدد الاستخدامات *',
                              labelStyle: GoogleFonts.cairo(),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'هذا الحقل مطلوب'
                                : null,
                          ),
                          SizedBox(height: 20.h),

                          // Expiration configuration
                          Text(
                            'صلاحية وانتهاء الكوبون',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          DropdownButtonFormField<String>(
                            value: _expirationType,
                            style: GoogleFonts.cairo(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'never',
                                child: Text(
                                  'صالح دائماً وبدون انتهاء',
                                  style: GoogleFonts.cairo(),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'date',
                                child: Text(
                                  'ينتهي في تاريخ وساعة محددة',
                                  style: GoogleFonts.cairo(),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'day_of_week',
                                child: Text(
                                  'يتكرر وينتهي في يوم أسبوعي محدد',
                                  style: GoogleFonts.cairo(),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _expirationType = val!),
                          ),
                          if (_expirationType == 'date') ...[
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectDate,
                                    borderRadius: BorderRadius.circular(16.r),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 14.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F172A)
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        border: Border.all(
                                          color: _expiryDate != null
                                              ? const Color(0xFF1E4BA1)
                                              : (isDark
                                                    ? Colors.white.withOpacity(
                                                        0.08,
                                                      )
                                                    : Colors.grey.shade300),
                                          width: _expiryDate != null ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8.w),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF1E4BA1,
                                              ).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.calendar_month_rounded,
                                              color: Color(0xFF1E4BA1),
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'تاريخ الانتهاء',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 10.sp,
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  _expiryDate == null
                                                      ? 'تحديد التاريخ'
                                                      : formatArabicDate(
                                                          _expiryDate!,
                                                        ),
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectTimeOnly,
                                    borderRadius: BorderRadius.circular(16.r),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 14.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F172A)
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        border: Border.all(
                                          color: _expiryDate != null
                                              ? const Color(0xFF1E4BA1)
                                              : (isDark
                                                    ? Colors.white.withOpacity(
                                                        0.08,
                                                      )
                                                    : Colors.grey.shade300),
                                          width: _expiryDate != null ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8.w),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF1E4BA1,
                                              ).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.access_time_filled_rounded,
                                              color: Color(0xFF1E4BA1),
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'وقت الانتهاء',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 10.sp,
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  _expiryDate == null
                                                      ? 'تحديد الوقت'
                                                      : formatArabicTime(
                                                          _expiryDate!,
                                                        ),
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (_expirationType == 'day_of_week') ...[
                            SizedBox(height: 12.h),
                            DropdownButtonFormField<int>(
                              value: _expiryDayOfWeek,
                              style: GoogleFonts.cairo(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: 'اليوم الأسبوعي لانتهاء الصلاحية',
                                labelStyle: GoogleFonts.cairo(),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text(
                                    'كل يوم أحد',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text(
                                    'كل يوم اثنين',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text(
                                    'كل يوم ثلاثاء',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 4,
                                  child: Text(
                                    'كل يوم أربعاء',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text(
                                    'كل يوم خميس',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 6,
                                  child: Text(
                                    'كل يوم جمعة',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 7,
                                  child: Text(
                                    'كل يوم سبت',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _expiryDayOfWeek = val),
                            ),
                          ],
                          SizedBox(height: 20.h),

                          // Target users restrictions
                          Text(
                            'الوصول والتخصيص',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          DropdownButtonFormField<String>(
                            value: _targetUserRole,
                            style: GoogleFonts.cairo(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text(
                                  'عام لجميع المستخدمين في التطبيق',
                                  style: GoogleFonts.cairo(),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'specific',
                                child: Text(
                                  'مخصص ومقيد لتجار محددين فقط',
                                  style: GoogleFonts.cairo(),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _targetUserRole = val!),
                          ),
                          if (_targetUserRole == 'specific') ...[
                            SizedBox(height: 12.h),
                            TextFormField(
                              style: GoogleFonts.cairo(),
                              decoration: InputDecoration(
                                labelText: 'البحث عن تاجر...',
                                labelStyle: GoogleFonts.cairo(),
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              onChanged: (val) =>
                                  setState(() => _searchMerchantQuery = val),
                            ),
                            SizedBox(height: 12.h),
                            Container(
                              constraints: BoxConstraints(maxHeight: 180.h),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: _isLoadingMerchants
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : filteredMerchants.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 20.h,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.search_off_rounded,
                                              color: Colors.grey,
                                              size: 36,
                                            ),
                                            SizedBox(height: 8.h),
                                            Text(
                                              'لم يتم العثور على تجار',
                                              style: GoogleFonts.cairo(
                                                fontSize: 12.sp,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8.h,
                                        horizontal: 8.w,
                                      ),
                                      itemCount: filteredMerchants.length,
                                      separatorBuilder: (_, __) =>
                                          SizedBox(height: 8.h),
                                      itemBuilder: (context, i) {
                                        final m = filteredMerchants[i];
                                        final mId = m['id'] as int;
                                        final storeName =
                                            m['storeName']?.toString() ?? '';
                                        final firstName =
                                            m['firstName']?.toString() ?? '';
                                        final lastName =
                                            m['lastName']?.toString() ?? '';
                                        final name = storeName.isNotEmpty
                                            ? storeName
                                            : '$firstName $lastName'.trim();
                                        final phone =
                                            m['phone']?.toString() ?? '';
                                        final isSelected = _selectedUserIds
                                            .contains(mId);

                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedUserIds.remove(mId);
                                              } else {
                                                _selectedUserIds.add(mId);
                                              }
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 14.w,
                                              vertical: 12.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(
                                                      0xFF1E4BA1,
                                                    ).withOpacity(0.08)
                                                  : (isDark
                                                        ? const Color(
                                                            0xFF0F172A,
                                                          )
                                                        : Colors.grey.shade50),
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF1E4BA1)
                                                    : (isDark
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.06,
                                                                )
                                                          : Colors
                                                                .grey
                                                                .shade200),
                                                width: isSelected ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                // Store Avatar
                                                Container(
                                                  width: 38.w,
                                                  height: 38.w,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      colors: isSelected
                                                          ? [
                                                              const Color(
                                                                0xFF1E4BA1,
                                                              ),
                                                              const Color(
                                                                0xFF132e4d,
                                                              ),
                                                            ]
                                                          : [
                                                              Colors
                                                                  .grey
                                                                  .shade400,
                                                              Colors
                                                                  .grey
                                                                  .shade600,
                                                            ],
                                                    ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    name.isNotEmpty
                                                        ? name.substring(0, 1)
                                                        : 'ت',
                                                    style: GoogleFonts.cairo(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14.sp,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 12.w),
                                                // Store Name & Phone
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: GoogleFonts.cairo(
                                                          fontSize: 12.sp,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isDark
                                                              ? Colors.white
                                                              : Colors.black87,
                                                        ),
                                                      ),
                                                      SizedBox(height: 2.h),
                                                      Text(
                                                        phone,
                                                        style:
                                                            GoogleFonts.cairo(
                                                              fontSize: 10.sp,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Check indicator
                                                Container(
                                                  width: 20.w,
                                                  height: 20.w,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF1E4BA1,
                                                          )
                                                        : Colors.transparent,
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF1E4BA1,
                                                            )
                                                          : Colors
                                                                .grey
                                                                .shade400,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: isSelected
                                                      ? const Icon(
                                                          Icons.check,
                                                          size: 12,
                                                          color: Colors.white,
                                                        )
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                          SizedBox(height: 30.h),

                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'إلغاء',
                                  style: GoogleFonts.cairo(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E4BA1),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 32.w,
                                    vertical: 16.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'حفظ وإنشاء الكوبون',
                                        style: GoogleFonts.cairo(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
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

                // Left Pane (Visual Coupon Preview Card!) - Visible on wide layouts
                if (MediaQuery.of(context).size.width > 900)
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9),
                        border: Border(
                          right: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'معاينة الكوبون التفاعلية',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            // The Live Ticket Card!
                            ClipPath(
                              clipper: TicketClipper(),
                              child: Container(
                                height: 180.h,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: EdgeInsets.all(16.w),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 4.h,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF1E4BA1),
                                                    Color(0xFF132e4d),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.r),
                                              ),
                                              child: Text(
                                                _codeController.text.isEmpty
                                                    ? 'رمز الكوبون'
                                                    : _codeController.text
                                                          .toUpperCase(),
                                                style: GoogleFonts.cairo(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _discountType == 'full'
                                                  ? 'خصم كامل 100%'
                                                  : 'خصم ${_valueController.text.isEmpty ? '0' : _valueController.text} ج.م',
                                              style: GoogleFonts.cairo(
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1E4BA1),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.timer_outlined,
                                                  size: 12,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 4.w),
                                                Expanded(
                                                  child: Text(
                                                    _expirationType == 'never'
                                                        ? 'صلاحية دائمة'
                                                        : _expirationType ==
                                                              'date'
                                                        ? (_expiryDate != null
                                                              ? formatArabicDate(
                                                                  _expiryDate!,
                                                                )
                                                              : 'صلاحية محددة بالتاريخ')
                                                        : 'صلاحية تتكرر أسبوعياً',
                                                    style: GoogleFonts.cairo(
                                                      fontSize: 10.sp,
                                                      color: Colors.grey,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    CustomPaint(
                                      size: Size(1.w, double.infinity),
                                      painter: DashedLinePainter(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.15)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: EdgeInsets.all(16.w),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'كوبون ترويجي',
                                              style: GoogleFonts.cairo(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black54,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 12.h),
                                            Icon(
                                              _targetUserRole == 'specific'
                                                  ? Icons.lock_person_outlined
                                                  : Icons.share,
                                              color: const Color(0xFF1E4BA1),
                                              size: 28.w,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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
}
