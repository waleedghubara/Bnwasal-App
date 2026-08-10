// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../cubit/wallet_cubit.dart';
import '../cubit/wallet_state.dart';
import 'payment_webview_screen.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  final List<double> _quickAmounts = [50, 100, 200, 500, 1000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
  }

  void _submit(WalletCubit cubit) {
    final text = _amountController.text.trim();
    if (text.isEmpty) {
      _showError('يرجى إدخال المبلغ');
      return;
    }
    final amount = double.tryParse(text);
    if (amount == null || amount < 1) {
      _showError('المبلغ غير صالح. الحد الأدنى 1 جنيه');
      return;
    }
    cubit.createDepositSession(amount);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.tajawal()),
      backgroundColor: Colors.red.shade600,
    ));
  }

  void _showSuccess(double amount, double balance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32), size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'تم الإيداع بنجاح! 🎉',
                style: GoogleFonts.tajawal(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'تم إضافة ${amount.toStringAsFixed(2)} جنيه لمحفظتك',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                    color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'الرصيد الحالي: ${balance.toStringAsFixed(2)} جنيه',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFF204CB3),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
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
                    backgroundColor: const Color(0xFF204CB3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text('ممتاز!',
                      style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
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
    return BlocProvider(
      create: (_) => di.sl<WalletCubit>(),
      child: BlocConsumer<WalletCubit, WalletState>(
        listener: (context, state) async {
          if (state is DepositSessionReady) {
            // Open Kashier WebView
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<WalletCubit>(),
                  child: PaymentWebviewScreen(
                    sessionUrl: state.sessionUrl,
                    sessionId: state.sessionId,
                    amount: state.amount,
                  ),
                ),
              ),
            );
            // WebView closed — check session was handled inside PaymentWebviewScreen
          } else if (state is DepositSuccess) {
            _showSuccess(state.depositedAmount, state.newBalance);
          } else if (state is DepositFailed) {
            _showError(state.message);
          } else if (state is DepositPending) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                'الدفع لا يزال قيد المعالجة. سيتم تحديث رصيدك قريباً.',
                style: GoogleFonts.tajawal(),
              ),
              backgroundColor: Colors.orange.shade600,
              duration: const Duration(seconds: 4),
            ));
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          final cubit = context.read<WalletCubit>();
          final isLoading = state is DepositSessionLoading;

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'إيداع الرصيد',
                style: GoogleFonts.tajawal(
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
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20.h),

                  // Kashier badge
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF204CB3), Color(0xFF3B6FDF)],
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.security,
                              color: Colors.white, size: 20),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الدفع الآمن عبر كاشير',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                              ),
                              Text(
                                'بطاقات بنكية • محفظة فورى • تسليم فوري',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.shield_outlined, color: Colors.white70),
                      ],
                    ),
                  ),

                  SizedBox(height: 28.h),
                  Text(
                    'المبلغ',
                    style: GoogleFonts.tajawal(
                      color: Colors.black,
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
                        color: const Color(0xFF204CB3),
                        size: 20.sp,
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),
                  Text(
                    'مبالغ سريعة',
                    style: GoogleFonts.tajawal(
                      color: Colors.grey.shade600,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 10.w,
                    runSpacing: 8.h,
                    children: _quickAmounts.map((amt) {
                      return GestureDetector(
                        onTap: () => _selectQuickAmount(amt),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F5FF),
                            borderRadius: BorderRadius.circular(30.r),
                            border: Border.all(
                                color: const Color(0xFF204CB3).withOpacity(0.3)),
                          ),
                          child: Text(
                            '${amt.toStringAsFixed(0)} ج.م',
                            style: GoogleFonts.tajawal(
                              color: const Color(0xFF204CB3),
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 10.h),
                  Text(
                    '• الحد الأدنى للإيداع: 1 جنيه\n• سيتم فتح صفحة الدفع الآمنة من كاشير',
                    style: GoogleFonts.tajawal(
                        color: Colors.grey.shade500, fontSize: 12.sp),
                  ),

                  SizedBox(height: 40.h),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () => _submit(cubit),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF204CB3),
                        disabledBackgroundColor:
                            const Color(0xFF204CB3).withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.payment, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'ادفع الآن',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
