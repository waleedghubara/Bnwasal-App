// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api/end_point.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_text_field.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _fromPhoneController = TextEditingController();
  final TextEditingController _fromNameController = TextEditingController();

  final List<double> _quickAmounts = [50, 100, 200, 500, 1000];

  // 'direct' (InstaPay / E-Wallet) or 'kashier' (Visa/Mastercard)
  String _depositMethod = 'direct';
  // Sub-channel for direct: 'vodafone' or 'instapay'
  String _selectedWalletType = 'vodafone';

  String _vodafoneNumber = '01033190080';
  String _instapayNumber = '01210633600';

  File? _receiptImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchPaymentMethods();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _fromPhoneController.dispose();
    _fromNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchPaymentMethods() async {
    try {
      final dio = di.sl<Dio>();
      final res = await dio.get('${EndPoint.baseUrl}direct-payments/methods');
      if (res.data != null && res.data['status'] == 1) {
        final methods = res.data['data']?['methods'] as List?;
        if (methods != null) {
          for (final m in methods) {
            final name = (m['name'] ?? '').toString();
            final phone = (m['phone'] ?? '').toString();
            if (name.contains('انستا') || name.toLowerCase().contains('insta')) {
              if (phone.isNotEmpty) _instapayNumber = phone;
            } else if (name.contains('كاش') || name.contains('فودافون')) {
              if (phone.isNotEmpty) _vodafoneNumber = phone;
            }
          }
          if (mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  void _selectQuickAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
    setState(() {});
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ رقم $label بنجاح ($text)',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickReceiptImage() async {
    try {
      final picker = ImagePicker();
      final picked = await showModalBottomSheet<XFile?>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'اختيار صورة الإيصال',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                  title: Text('المعرض (الصور)', style: GoogleFonts.cairo()),
                  onTap: () async {
                    final img = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    Navigator.pop(ctx, img);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                  title: Text('الكاميرا', style: GoogleFonts.cairo()),
                  onTap: () async {
                    final img = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    Navigator.pop(ctx, img);
                  },
                ),
              ],
            ),
          ),
        ),
      );

      if (picked != null) {
        HapticFeedback.selectionClick();
        setState(() {
          _receiptImage = File(picked.path);
        });
      }
    } catch (e) {
      _showError('تعذر اختيار الصورة: $e');
    }
  }

  Future<void> _submitDirectDeposit() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('يرجى إدخال مبلغ الإيداع');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount < 1) {
      _showError('الحد الأدنى للإيداع هو 1 جنيه');
      return;
    }

    final fromPhone = _fromPhoneController.text.trim();
    if (fromPhone.isEmpty) {
      _showError('يرجى إدخال رقم الهاتف المحول منه');
      return;
    }

    if (_receiptImage == null) {
      _showError('يرجى إرفاق صورة إيصال التحويل (سكرين شوت)');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await di.sl<SecureCacheHelper>().getData(key: ApiKey.token);
      final paymentMethod = _selectedWalletType == 'instapay'
          ? 'انستا باي'
          : 'فودافون كاش';

      final formData = FormData.fromMap({
        'amount': amount,
        'paymentMethod': paymentMethod,
        'fromPhone': fromPhone,
        'fromName': _fromNameController.text.trim(),
        'receiptImage': await MultipartFile.fromFile(
          _receiptImage!.path,
          filename: _receiptImage!.path.split('/').last,
        ),
      });

      final dio = di.sl<Dio>();
      final res = await dio.post(
        '${EndPoint.baseUrl}wallet/direct-deposit',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      setState(() => _isSubmitting = false);

      if (res.data != null && res.data['status'] == 1) {
        _showSuccess(amount, res.data['message']?.toString() ?? 'تم إرسال طلب الإيداع بنجاح!');
      } else {
        _showError(res.data?['message']?.toString() ?? 'فشل إرسال طلب الإيداع');
      }
    } on DioException catch (e) {
      setState(() => _isSubmitting = false);
      final msg = e.response?.data?['message']?.toString() ?? 'حدث خطأ أثناء إرسال الإيداع';
      _showError(msg);
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('حدث خطأ غير متوقع: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: Colors.red.shade600,
    ));
  }

  void _showSuccess(double amount, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تم إرسال طلب الإيداع بنجاح! 🎉',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'المبلغ: ${amount.toStringAsFixed(0)} ج.م\nسيتم مراجعة الإيصال وشحن محفظتك فوراً.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // back to wallet
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: Text(
                    'تم',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVodafone = _selectedWalletType == 'vodafone';
    final targetNumber = isVodafone ? _vodafoneNumber : _instapayNumber;
    final providerTitle = isVodafone ? 'فودافون كاش' : 'إنستا باي (InstaPay)';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'إيداع رصيد المحفظة',
            style: GoogleFonts.cairo(
              color: Colors.black,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black, size: 20.sp),
            onPressed: () => Navigator.pop(context),
          ),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 1. مبلغ الإيداع ──────────────────────────────────────
              Text(
                'المبلغ المراد إيداعه',
                style: GoogleFonts.cairo(
                  color: const Color(0xFF0F172A),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              CustomTextField(
                hintText: 'أدخل المبلغ بالجنيه المصري',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                controller: _amountController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                rightWidget: Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: FaIcon(
                    FontAwesomeIcons.moneyBillWave,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // مبالغ سريعة
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _quickAmounts.map((amt) {
                  final isSelected = _amountController.text.trim() == amt.toStringAsFixed(0);
                  return GestureDetector(
                    onTap: () => _selectQuickAmount(amt),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        '${amt.toStringAsFixed(0)} ج.م',
                        style: GoogleFonts.cairo(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5.sp,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 24.h),

              // ─── 2. اختيار وسيلة الدفع (إنستاباي / محفظة إلكترونية) ───
              Text(
                'طريقة الدفع والتحويل',
                style: GoogleFonts.cairo(
                  color: const Color(0xFF0F172A),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),

              Row(
                children: [
                  // فودافون كاش / محفظة إلكترونية
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedWalletType = 'vodafone';
                        _depositMethod = 'direct';
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isVodafone && _depositMethod == 'direct'
                              ? const Color(0xFFE60000)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isVodafone && _depositMethod == 'direct'
                                ? const Color(0xFFE60000)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: isVodafone && _depositMethod == 'direct'
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFE60000).withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'فودافون كاش ومحافظ',
                            style: GoogleFonts.cairo(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.bold,
                              color: isVodafone && _depositMethod == 'direct'
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // إنستا باي (InstaPay)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedWalletType = 'instapay';
                        _depositMethod = 'direct';
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: !isVodafone && _depositMethod == 'direct'
                              ? const LinearGradient(
                                  colors: [Color(0xFF5B2D8E), Color(0xFF9B59B6)],
                                )
                              : null,
                          color: !isVodafone && _depositMethod == 'direct'
                              ? null
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !isVodafone && _depositMethod == 'direct'
                                ? const Color(0xFF5B2D8E)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: !isVodafone && _depositMethod == 'direct'
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF5B2D8E).withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'إنستا باي (InstaPay)',
                            style: GoogleFonts.cairo(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.bold,
                              color: !isVodafone && _depositMethod == 'direct'
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // ─── 3. كارت تفاصيل التحويل ورقم الحساب ─────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF5B00).withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5B00).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'رقم التحويل ($providerTitle):',
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        InkWell(
                          onTap: () => _copyToClipboard(targetNumber, providerTitle),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5B00).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: Color(0xFFFF5B00),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'نسخ الرقم',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFF5B00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      targetNumber,
                      style: GoogleFonts.cairo(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'يرجى تحويل مبلغ الإيداع المحدد أعلاه إلى هذا الرقم/العنوان، ثم إدخال رقم هاتفك المحول منه ورفع صورة الإيصال لتأكيد شحن المحفظة فوراً.',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5.sp,
                        color: const Color(0xFF94A3B8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // ─── 4. رقم الهاتف المحول منه ───────────────────────────────
              Text(
                'رقم الهاتف المحول منه *',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _fromPhoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'مثال: 01012345678',
                  hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),

              SizedBox(height: 14.h),

              // ─── 5. اسم صاحب الحساب (اختياري) ───────────────────────────
              Text(
                'اسم صاحب الحساب المحول منه (اختياري)',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _fromNameController,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اسم المحول كما يظهر في التطبيق',
                  hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),

              SizedBox(height: 18.h),

              // ─── 6. رفع صورة إيصال التحويل ──────────────────────────────
              Text(
                'صورة إيصال التحويل (سكرين شوت) *',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 8.h),

              if (_receiptImage == null) ...[
                InkWell(
                  onTap: _pickReceiptImage,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5B00).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            color: Color(0xFFFF5B00),
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'اضغط لإرفاق صورة إيصال التحويل',
                          style: GoogleFonts.cairo(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'سكرين شوت من تطبيق المحفظة أو إنستاباي',
                          style: GoogleFonts.cairo(
                            fontSize: 11.5.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _receiptImage!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تم إرفاق الإيصال بنجاح',
                              style: GoogleFonts.cairo(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF166534),
                              ),
                            ),
                            Text(
                              _receiptImage!.path.split(Platform.pathSeparator).last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 11.sp,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF166534)),
                        tooltip: 'تغيير الصورة',
                        onPressed: _pickReceiptImage,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        tooltip: 'حذف',
                        onPressed: () => setState(() => _receiptImage = null),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 30.h),

              // ─── 7. زر تأكيد الإيداع ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDirectDeposit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'تأكيد إرسال طلب الإيداع',
                          style: GoogleFonts.cairo(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
