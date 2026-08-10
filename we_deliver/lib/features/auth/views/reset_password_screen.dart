// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_button.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import '../../../core/routes/routes.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String resetToken;

  const ResetPasswordScreen({super.key, required this.resetToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      _showSnack('يرجى ملء جميع الحقول', isError: true);
      return;
    }
    if (password.length < 6) {
      _showSnack('كلمة المرور يجب أن تكون 6 أحرف على الأقل', isError: true);
      return;
    }
    if (password != confirm) {
      _showSnack('كلمتا المرور غير متطابقتين', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dio = sl<Dio>();
      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.resetPassword}',
        data: {'newPassword': password},
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.resetToken}'},
        ),
      );

      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;

      _showSnack(data['message'] as String? ?? 'تم تحديث كلمة المرور', isError: false);

      // Wait briefly then go to login
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.login,
          (route) => false,
        );
      }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.right),
      backgroundColor: isError ? Colors.red : AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // No back — one-way flow
        title: const Text(
          'تعيين كلمة مرور جديدة',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
              const SizedBox(height: 28),

              const Text(
                'كلمة مرور جديدة',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'أدخل كلمة المرور الجديدة وتأكد من تطابقها',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // Password field
              const Text(
                'كلمة المرور الجديدة',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              CustomTextField(
                controller: _passwordController,
                hintText: 'أدخل كلمة المرور',
                obscureText: _obscurePassword,
                rightWidget: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FaIcon(FontAwesomeIcons.lock,
                      color: AppColors.primary, size: 18),
                ),
                leftWidget: GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: FaIcon(
                      _obscurePassword
                          ? FontAwesomeIcons.eyeSlash
                          : FontAwesomeIcons.eye,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Confirm field
              const Text(
                'تأكيد كلمة المرور',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              CustomTextField(
                controller: _confirmController,
                hintText: 'أعد إدخال كلمة المرور',
                obscureText: _obscureConfirm,
                rightWidget: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FaIcon(FontAwesomeIcons.lockOpen,
                      color: AppColors.primary, size: 18),
                ),
                leftWidget: GestureDetector(
                  onTap: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: FaIcon(
                      _obscureConfirm
                          ? FontAwesomeIcons.eyeSlash
                          : FontAwesomeIcons.eye,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              CustomButton(
                text: 'تحديث كلمة المرور',
                isLoading: _isLoading,
                onPressed: _resetPassword,
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
