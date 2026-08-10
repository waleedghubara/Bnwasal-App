// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_button.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import '../../../core/routes/routes.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/appsflyer_service.dart';
import '../logic/auth_cubit.dart';
import '../logic/auth_state.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String otpCode;

  const OtpScreen({super.key, required this.phone, required this.otpCode});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with WidgetsBindingObserver {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _timerSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _checkClipboard();
  }

  void _startTimer() {
    _timerSeconds = 30;
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
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      ClipboardData? clipboardData = await Clipboard.getData(
        Clipboard.kTextPlain,
      );
      if (clipboardData != null && clipboardData.text != null) {
        String text = clipboardData.text!.trim();
        final otpRegex = RegExp(r'^\d{6}$');
        if (otpRegex.hasMatch(text)) {
          // Check if it's already filled with this exact code to prevent repeating
          String currentOtp = _controllers.map((c) => c.text).join();
          if (currentOtp == text) return;

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
                  'تم نسخ كود التحقق تلقائياً من الحافظة',
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
    } catch (e) {
      debugPrint('Error reading clipboard: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
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
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('pending_otp_email');
            await prefs.remove('pending_otp_code');
            if (context.mounted) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, Routes.login);
              }
            }
          },
        ),
        title: const Text(
          'إنشاء حساب',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is VerifyOtpSuccess) {
              // Clear pending OTP on successful verification
              SharedPreferences.getInstance().then((prefs) {
                prefs.remove('pending_otp_email');
                prefs.remove('pending_otp_code');
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم تفعيل الحساب بنجاح',
                    textAlign: TextAlign.right,
                  ),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              final user = state.authResponse.user;
              
              // Log AppsFlyer Complete Registration Event
              sl<AppsFlyerService>().setCustomerUserId(user.id.toString());
              sl<AppsFlyerService>().logEvent('af_complete_registration', {
                'af_registration_method': 'OTP',
                'user_id': user.id.toString(),
                'role': user.role,
              });

              final isCaptain = user.role == 'captain';
              final isProfileComplete = user.isProfileComplete ?? true;

              if (user.role == 'merchant') {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.mainLayout,
                  (route) => false,
                  arguments: {'isDelivery': false},
                );
              } else if (!isProfileComplete) {
                final missingDetailsList = user.missingDetails ?? [];
                if (missingDetailsList.contains('documents')) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.identityVerification,
                    (route) => false,
                    arguments: {'step': 'upload'},
                  );
                } else if (missingDetailsList.contains('vehicle')) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.identityVerification,
                    (route) => false,
                    arguments: {'step': 'selectVehicle'},
                  );
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.identityVerification,
                    (route) => false,
                  );
                }
              } else if (user.status == 'pending_verification') {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.pendingApproval,
                  (route) => false,
                );
              } else {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.mainLayout,
                  (route) => false,
                  arguments: {'isDelivery': isCaptain},
                );
              }
            } else if (state is ResendOtpSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, textAlign: TextAlign.right),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, textAlign: TextAlign.right),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Image.asset(AppAssets.appLogo2, width: 120, height: 120),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'التحقق من رقم الواتساب',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تم ارسال كود التحقق الى رقم الواتساب الخاص بك: ${widget.phone} ، ادخل رمز التحقق لاستكمال انشاء الحساب',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) => _buildOtpBox(index)),
                  ),
                  const SizedBox(height: 50),
                  CustomButton(
                    text: 'التالي',
                    isLoading: state is AuthLoading,
                    onPressed: () {
                      final otp = _controllers.map((c) => c.text).join();
                      if (otp.length == 6) {
                        FocusScope.of(context).unfocus();
                        context.read<AuthCubit>().verifyOtp(
                          phone: widget.phone,
                          otpCode: otp,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('الرجاء إدخال رمز التحقق كاملاً'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    textColor: Colors.white,
                    borderRadius: 16,
                    height: 56,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_timerSeconds > 0)
                        Text(
                          'اعادة ارسال الكود (بعد $_timerSeconds ثواني)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            _startTimer();
                            context.read<AuthCubit>().resendOtp(
                              phone: widget.phone,
                            );
                          },
                          child: const Text(
                            'اعادة ارسال الكود',
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
            );
          },
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
            color: Colors.black.withOpacity(0.02),
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
            String code = value.substring(0, 6);
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
