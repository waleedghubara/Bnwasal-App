// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_button.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/routes/routes.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final input = _emailController.text.trim();
    if (input.isEmpty) {
      _showSnack('يرجى إدخال البريد الإلكتروني أو رقم الهاتف', isError: true);
      return;
    }

    final isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input);
    final isPhone = RegExp(r'^\d{11}$').hasMatch(input);

    if (!isEmail && !isPhone) {
      _showSnack(
        'يرجى إدخال بريد إلكتروني صحيح أو رقم هاتف مكون من 11 رقماً',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dio = sl<Dio>();
      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.forgotPassword}',
        data: {'email': input},
      );

      final data = response.data as Map<String, dynamic>;
      final resetOtp = data['data']?['resetOtp']?.toString() ?? '';

      if (!mounted) return;
      _showSnack(
        data['message'] as String? ?? 'تم إرسال الكود',
        isError: false,
      );

      Navigator.pushNamed(
        context,
        Routes.resetOtp,
        arguments: {'phone': input, 'resetOtp': resetOtp},
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?.containsKey('message') == true
          ? e.response!.data['message'] as String
          : 'حدث خطأ. يرجى المحاولة مرة أخرى';
      _showSnack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.right),
        backgroundColor: isError ? Colors.red : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(AppAssets.appLogo2, width: 110, height: 110),
              ),
              const SizedBox(height: 32),

              const Text(
                'نسيت كلمة المرور؟',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'أدخل البريد الإلكتروني أو رقم هاتفك المسجل وسنرسل لك كود على الواتساب للتحقق من هويتك وإعادة تعيين كلمة المرور',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                'البريد الإلكتروني أو رقم الهاتف',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              CustomTextField(
                controller: _emailController,
                hintText: 'أدخل البريد الإلكتروني أو رقم الهاتف',
                keyboardType: TextInputType.emailAddress,
                rightWidget: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FaIcon(
                    FontAwesomeIcons.solidUser,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              CustomButton(
                text: 'إرسال الكود',
                isLoading: _isLoading,
                onPressed: _sendOtp,
                textColor: Colors.white,
                borderRadius: 16,
                height: 56,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
