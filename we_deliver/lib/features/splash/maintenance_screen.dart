// ignore_for_file: deprecated_member_use, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/routes/routes.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import '../../core/utils/prefs_helper.dart';

class MaintenanceScreen extends StatefulWidget {
  final String message;

  const MaintenanceScreen({super.key, required this.message});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _isLoading = false;

  Future<void> _checkMaintenanceStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await sl<Dio>().get(
        '${EndPoint.baseUrl}${EndPoint.appConfig}',
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>;
        final maintenanceMode = data['maintenance_mode'] == '1';

        if (!maintenanceMode) {
          // Maintenance mode has been disabled! Proceed to check auth & navigate
          if (mounted) {
            _navigateToNext();
          }
          return;
        }
      }

      // Still under maintenance
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'التطبيق ما زال في وضع الصيانة حالياً.',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            backgroundColor: AppColors.primary2,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ في الاتصال بالخادم. يرجى المحاولة لاحقاً.',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToNext() async {
    final prefs = await SharedPreferences.getInstance();
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

      final profileData = response.data as Map<String, dynamic>;
      final user = profileData['data']['user'] as Map<String, dynamic>;
      final status = user['status'] as String? ?? '';

      if (status == 'active') {
        Navigator.pushReplacementNamed(
          context,
          Routes.mainLayout,
          arguments: {'isDelivery': isDelivery},
        );
      } else if (status == 'pending_verification') {
        final docs = profileData['data']['documents'];
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

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = 24.0;
    final double verticalPadding = 32.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF001b3f), // Rich deep dark blue
                Color(0xFF004aad), // App primary blue
                Color(0xFF101827), // Modern dark slate
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        // Lottie Animation Container
                        FadeInDown(
                          duration: const Duration(milliseconds: 1000),
                          child: SizedBox(
                            height: 200,
                            child: Lottie.asset(
                              AppAssets.maintenance,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback in case of missing asset
                                return Container(
                                  padding: const EdgeInsets.all(24.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary2.withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: const FaIcon(
                                    FontAwesomeIcons.gears,
                                    color: AppColors.primary2,
                                    size: 70,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Title
                        FadeInUp(
                          duration: const Duration(milliseconds: 1000),
                          child: Text(
                            'التطبيق في وضع الصيانة',
                            style: GoogleFonts.tajawal(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Glassmorphic Maintenance Message Card
                        FadeInUp(
                          duration: const Duration(milliseconds: 1200),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.tajawal(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.7,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 32),
                        // Retry Action Button
                        FadeInUp(
                          duration: const Duration(milliseconds: 1400),
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : _checkMaintenanceStatus,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                    ),
                              label: Text(
                                _isLoading
                                    ? 'جاري التحقق...'
                                    : 'إعادة المحاولة',
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary2,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: AppColors.primary2.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
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
    );
  }
}
