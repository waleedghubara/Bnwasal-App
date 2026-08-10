// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/di/injection_container.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/routes/routes.dart';
import 'package:we_deliver/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'maintenance_screen.dart';
import '../../core/theme/app_assets.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/prefs_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _loaderController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _loadingFade;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _setupAnimations();
    _navigateToNext();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();

    await Permission.location.request();
  }

  void _setupAnimations() {
    /// 🔥 لوجو (مرة واحدة بس)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    /// 🔥 اللودينج (بيكرر)
    _loaderController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _loadingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    /// تشغيل
    _logoController.forward(); // مرة واحدة
    _loaderController.repeat(); // يفضل شغال
  }

  void _navigateToNext() {
    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;

      try {
        final response = await sl<Dio>().get(
          '${EndPoint.baseUrl}${EndPoint.appConfig}',
        );
        if (response.statusCode == 200 && response.data != null) {
          final configData = response.data['data'] as Map<String, dynamic>;
          final maintenanceMode = configData['maintenance_mode'] == '1';
          final maintenanceMessage =
              configData['maintenance_message'] ??
              'التطبيق في وضع الصيانة حالياً.';
          final serverVersion = configData['update_version'] ?? '1.0.0';
          final updateRequired =
              configData['update_required'] == true ||
              configData['update_required'] == '1';
          final playStoreUrl =
              configData['play_store_url'] ??
              'https://play.google.com/store/apps/details?id=com.wedeliver.app';
          final appStoreUrl =
              configData['app_store_url'] ??
              'https://apps.apple.com/app/we-deliver/id1234567890';

          // Save social media links to SharedPreferences for ContactUsScreen
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'social_facebook',
            configData['social_facebook'] ?? '',
          );
          await prefs.setString(
            'social_instagram',
            configData['social_instagram'] ?? '',
          );
          await prefs.setString(
            'social_twitter',
            configData['social_twitter'] ?? '',
          );
          await prefs.setString(
            'social_whatsapp',
            configData['social_whatsapp'] ?? '',
          );
          await prefs.setString(
            'social_linkedin',
            configData['social_linkedin'] ?? '',
          );
          await prefs.setString(
            'social_youtube',
            configData['social_youtube'] ?? '',
          );
          await prefs.setString(
            'support_phone',
            configData['support_phone'] ?? '+966500000000',
          );
          await prefs.setString(
            'support_email',
            configData['support_email'] ?? 'support@binwasal.com',
          );
          await prefs.setString('play_store_url', playStoreUrl);
          await prefs.setString('app_store_url', appStoreUrl);

          // 1. Check Maintenance Mode
          if (maintenanceMode) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MaintenanceScreen(message: maintenanceMessage),
                ),
              );
            }
            return;
          }

          // 2. Check Update
          final packageInfo = await PackageInfo.fromPlatform();
          final String currentAppVersion = packageInfo.version;
          final String updateUrl = Platform.isIOS ? appStoreUrl : playStoreUrl;

          if (_isUpdateNeeded(currentAppVersion, serverVersion)) {
            if (mounted) {
              _showUpdateDialog(context, updateUrl, updateRequired);
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Error loading app config: $e');
      }

      // 3. Fallback to normal navigation
      _navigateToNextNormal();
    });
  }

  Future<void> _navigateToNextNormal() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if there is a pending OTP verification from registration
    final pendingOtpEmail = prefs.getString('pending_otp_email');
    final pendingOtpCode = prefs.getString('pending_otp_code');
    if (pendingOtpEmail != null && pendingOtpEmail.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          Routes.otp,
          arguments: {
            'email': pendingOtpEmail,
            'otpCode': pendingOtpCode ?? '',
          },
        );
      }
      return;
    }

    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final isDelivery = prefs.getBool('isDelivery') ?? false;

    if (!mounted) return;

    if (!isLoggedIn) {
      Navigator.pushReplacementNamed(context, Routes.login);
      return;
    }

    try {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);
      if (token == null || token.isEmpty) {
        await PrefsHelper.clearSessionKeepCredentials();
        if (mounted) Navigator.pushReplacementNamed(context, Routes.login);
        return;
      }

      final response = await sl<Dio>().get(
        '${EndPoint.baseUrl}${EndPoint.getProfile}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>;
      final user = data['data']['user'] as Map<String, dynamic>;
      final status = user['status'] as String? ?? '';

      if (status == 'active') {
        Navigator.pushReplacementNamed(
          context,
          Routes.mainLayout,
          arguments: {'isDelivery': isDelivery},
        );
      } else if (status == 'pending_verification') {
        final docs = data['data']['documents'];
        if (docs != null) {
          Navigator.pushReplacementNamed(
            context,
            Routes.pendingApproval,
            arguments: {
              'message':
                  'حسابك قيد المراجعة من قبل الإدارة. يرجى الانتظار حتى يتم تفعيل حسابك.',
            },
          );
        } else {
          Navigator.pushReplacementNamed(context, Routes.identityVerification);
        }
      } else {
        await PrefsHelper.clearSessionKeepCredentials();
        await SecureCacheHelper().clearData();
        if (mounted) Navigator.pushReplacementNamed(context, Routes.login);
      }
    } catch (_) {
      if (mounted) Navigator.pushReplacementNamed(context, Routes.login);
    }
  }

  bool _isUpdateNeeded(String current, String latest) {
    try {
      List<int> currentParts = current
          .split('+')
          .first
          .split('.')
          .map(int.parse)
          .toList();
      List<int> latestParts = latest
          .split('+')
          .first
          .split('.')
          .map(int.parse)
          .toList();

      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (latestParts.length < 3) {
        latestParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return current != latest;
    }
  }

  void _showUpdateDialog(
    BuildContext context,
    String updateUrl,
    bool isRequired,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !isRequired,
      builder: (context) {
        final storeName = Platform.isIOS ? 'آب ستور' : 'متجر بلاي';
        return PopScope(
          canPop: !isRequired,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary2.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      color: AppColors.primary2,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'تحديث جديد متاح',
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRequired
                        ? 'يتوفر تحديث إجباري جديد للتطبيق على متجر $storeName. يرجى التحديث لمتابعة استخدام التطبيق.'
                        : 'يتوفر تحديث جديد للتطبيق على متجر $storeName. يرجى التحديث للحصول على آخر التحسينات والميزات.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (!isRequired) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _navigateToNextNormal();
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'لاحقاً',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final Uri url = Uri.parse(updateUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: Text(
                            'تحديث الآن',
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
        );
      },
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  /// 🔥 Loader احترافي (نقط بتطلع وتنزل)
  Widget _buildLoadingIndicator() {
    return FadeTransition(
      opacity: _loadingFade,
      child: Column(
        children: [
          const SizedBox(height: 24),

          AnimatedBuilder(
            animation: _loaderController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  double delay = index * 0.2;
                  double value = (_loaderController.value - delay).clamp(
                    0.0,
                    1.0,
                  );

                  return Transform.translate(
                    offset: Offset(0, -12 * value),
                    child: Opacity(
                      opacity: 0.5 + (value * 0.5),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              /// 🔥 اللوجو
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Image.asset(AppAssets.appLogo, fit: BoxFit.contain),
                  ),
                ),
              ),

              /// 🔥 اللودينج
              _buildLoadingIndicator(),

              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "1.0.2",
                    style: AppTypography.h6.copyWith(
                      color: AppColors.background.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    "V",
                    style: AppTypography.h6.copyWith(
                      color: AppColors.primary2,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
}
