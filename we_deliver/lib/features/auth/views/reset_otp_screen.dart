// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_button.dart';
import '../../../core/routes/routes.dart';

class ResetOtpScreen extends StatefulWidget {
  final String phone;
  final String resetOtp;

  const ResetOtpScreen({
    super.key,
    required this.phone,
    required this.resetOtp,
  });

  @override
  State<ResetOtpScreen> createState() => _ResetOtpScreenState();
}

class _ResetOtpScreenState extends State<ResetOtpScreen>
    with WidgetsBindingObserver {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _timerSeconds = 60;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _checkClipboard();
  }

  void _startTimer() {
    _timerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        final text = clipboardData!.text!.trim();
        if (RegExp(r'^\d{6}$').hasMatch(text)) {
          final current = _controllers.map((c) => c.text).join();
          if (current == text) return;
          setState(() {
            for (int i = 0; i < 6; i++) {
              _controllers[i].text = text[i];
            }
          });
          _focusNodes[5].requestFocus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تم نسخ كود التحقق من الحافظة',
                  textAlign: TextAlign.right,
                ),
                backgroundColor: AppColors.primary,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showSnack('يرجى إدخال الكود كاملاً (6 أرقام)', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dio = sl<Dio>();
      final response = await dio.post(
        '${EndPoint.baseUrl}${EndPoint.verifyResetOtp}',
        data: {'email': widget.phone, 'otp_code': otp},
      );

      final data = response.data as Map<String, dynamic>;
      final resetToken = data['data']?['resetToken'] as String? ?? '';

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.resetPassword,
        (route) => route.settings.name == Routes.login,
        arguments: {'resetToken': resetToken},
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?.containsKey('message') == true
          ? e.response!.data['message'] as String
          : 'الكود غير صحيح';
      _showSnack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    try {
      final dio = sl<Dio>();
      await dio.post(
        '${EndPoint.baseUrl}${EndPoint.forgotPassword}',
        data: {'email': widget.phone},
      );
      _startTimer();
      _showSnack('تم إعادة إرسال الكود', isError: false);
    } catch (_) {
      _showSnack('فشل إعادة الإرسال. حاول مجدداً', isError: true);
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
        title: const Text(
          'التحقق من الهوية',
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Image.asset(AppAssets.appLogo2, width: 110, height: 110),
              const SizedBox(height: 28),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'أدخل كود التحقق',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تم إرسال كود التحقق إلى حساب الواتساب الخاص بك: ${widget.phone}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),

              const SizedBox(height: 50),

              CustomButton(
                text: 'تأكيد',
                isLoading: _isLoading,
                onPressed: _verifyOtp,
                textColor: Colors.white,
                borderRadius: 16,
                height: 56,
                width: double.infinity,
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_timerSeconds > 0)
                    Text(
                      'إعادة الإرسال بعد $_timerSeconds ثانية',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _resendOtp,
                      child: const Text(
                        'إعادة إرسال الكود',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: index == 0 ? 6 : 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.length >= 6) {
            final code = value.substring(0, 6);
            for (int i = 0; i < 6; i++) {
              _controllers[i].text = code[i];
            }
            _focusNodes[5].requestFocus();
            return;
          }
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
