import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/services/security_guard.dart';
import 'package:we_deliver/core/routes/routes.dart';

class SecurityWarningScreen extends StatefulWidget {
  final String reason;

  const SecurityWarningScreen({super.key, required this.reason});

  @override
  State<SecurityWarningScreen> createState() => _SecurityWarningScreenState();
}

class _SecurityWarningScreenState extends State<SecurityWarningScreen> {
  bool _isScanning = false;

  Future<void> _handleRecheck() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    // Simulate scanning delay to give users satisfying visual feedback
    await Future.delayed(const Duration(milliseconds: 1500));

    final status = await SecurityGuard.checkSecurity();

    if (mounted) {
      setState(() {
        _isScanning = false;
      });

      if (status == SecurityStatus.secure) {
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم التحقق بنجاح! يتم الآن تشغيل التطبيق...',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Replace route to Splash to continue booting
        Navigator.pushReplacementNamed(context, Routes.splash);
      } else {
        // Show failure snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لم يتم حل المشكلة الأمنية بعد. يرجى اتباع التعليمات.',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parse steps dynamically from SecurityGuard or fallback
    final solutionStepsStr = SecurityGuard.solutionSteps ?? 
        '1. افتح إعدادات أمان الهاتف الخاص بك.\n2. اتبع إرشادات الأمان لإلغاء تفعيل بيئة التشغيل غير الآمنة.\n3. أعد المحاولة أو تواصل مع الدعم الفني.';
    final steps = solutionStepsStr
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return PopScope(
      canPop: false, // Prevent bypass
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Header / Logo area
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: AppColors.primary.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'بنوصل - نظام الحماية والأمان',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Dynamic Security Illustration
                  SecurityIllustration(isScanning: _isScanning),

                  const SizedBox(height: 20),

                  // Title
                  FadeInDown(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      'تنبيه أمني هام',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Detected Threat Info Card
                  FadeIn(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تنبيه الحماية المكتشف:',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.reason,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stepper Solution Steps Container
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'خطوات حل التنبيه لتأمين التطبيق:',
                            style: GoogleFonts.tajawal(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(steps.length, (index) {
                            return StepItem(
                              index: index,
                              text: steps[index],
                              isLast: index == steps.length - 1,
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: Column(
                      children: [
                        // Retry / Recheck button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isScanning ? null : _handleRecheck,
                            child: _isScanning
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.refresh_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'إعادة الفحص والتحقق الآن',
                                        style: GoogleFonts.tajawal(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Exit button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              backgroundColor: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              SystemNavigator.pop();
                            },
                            child: Text(
                              'إغلاق التطبيق',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecurityIllustration extends StatelessWidget {
  final bool isScanning;

  const SecurityIllustration({super.key, this.isScanning = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer concentric circles
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: isScanning ? 150 : 130,
            height: isScanning ? 150 : 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.04),
            ),
          ),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.06),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
          ),
          // Inner core circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isScanning
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : const Icon(
                    Icons.security_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
          ),
          // Warning badge (only if not scanning)
          if (!isScanning)
            Positioned(
              right: 38,
              top: 38,
              child: ZoomIn(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StepItem extends StatelessWidget {
  final int index;
  final String text;
  final bool isLast;

  const StepItem({
    super.key,
    required this.index,
    required this.text,
    this.isLast = false,
  });

  IconData _getIconForText(String text) {
    if (text.contains('إعدادات') || text.contains('Settings')) {
      return Icons.settings_rounded;
    } else if (text.contains('مطور') || text.contains('Developer')) {
      return Icons.developer_mode_rounded;
    } else if (text.contains('إيقاف') || text.contains('تعطيل') || text.contains('بإيقاف')) {
      return Icons.toggle_off_rounded;
    } else if (text.contains('إغلاق') || text.contains('أغلق')) {
      return Icons.cancel_rounded;
    } else if (text.contains('تثبيت') || text.contains('تحميل')) {
      return Icons.download_rounded;
    } else if (text.contains('روت') || text.contains('Magisk')) {
      return Icons.security_rounded;
    } else if (text.contains('بناء') || text.contains('الأمر')) {
      return Icons.terminal_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cleanText = text.replaceFirst(RegExp(r'^\d+[\.\-\u2013]\s*'), '');
    final icon = _getIconForText(cleanText);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step timeline vertical line & icon
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: AppColors.primary.withValues(alpha: 0.15),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Step text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                cleanText,
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
