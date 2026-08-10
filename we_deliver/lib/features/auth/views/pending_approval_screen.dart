// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/widgets/custom_button.dart';
import '../../../../core/utils/prefs_helper.dart';
import '../../../core/routes/routes.dart';

class PendingApprovalScreen extends StatefulWidget {
  final String message;

  const PendingApprovalScreen({super.key, required this.message});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await PrefsHelper.clearSessionKeepCredentials();
    await SecureCacheHelper().clearData();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.login,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Logo
              FadeInDown(
                child: Image.asset(AppAssets.appLogo2, width: 90, height: 90),
              ),

              const SizedBox(height: 48),

              // Animated clock icon
              FadeIn(
                delay: const Duration(milliseconds: 200),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Title
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: const Text(
                  'حسابك قيد المراجعة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Message from server
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.7,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Info cards
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.verified_user_outlined,
                        text: 'تم استلام مستنداتك بنجاح',
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow(
                        icon: Icons.supervisor_account_outlined,
                        text: 'فريق الإدارة يراجع حسابك حالياً',
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow(
                        icon: Icons.notifications_active_outlined,
                        text: 'سيتم إشعارك فور تفعيل الحساب',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 56),

              // Logout button
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: CustomButton(
                  text: 'تسجيل الخروج',
                  onPressed: _logout,
                  textColor: Colors.white,
                  borderRadius: 16,
                  height: 56,
                  width: double.infinity,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
