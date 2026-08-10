import 'dart:math' as math;

import 'package:admin_bnwasal/core/theme/app_assets.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:flutter/material.dart';

class SplashLoading extends StatefulWidget {
  const SplashLoading({super.key});

  @override
  State<SplashLoading> createState() => _SplashLoadingState();
}

class _SplashLoadingState extends State<SplashLoading>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;

  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _fadeAnim = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeInOut),
    );

    _scaleAnim = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutBack),
    );

    _slideAnim = Tween<double>(begin: -1, end: 1.2).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final sw = mediaQuery.size.width;
    final sh = mediaQuery.size.height;

    final double loaderSize = (sw * 0.14).clamp(55.0, 80.0);
    final double barWidth = (sw * 0.5).clamp(200.0, 320.0);
    final double barHeight = (sh * 0.008).clamp(4.0, 6.0);
    final double spacing = (sh * 0.025).clamp(16.0, 24.0);
    final double textSize = (sw * 0.037).clamp(13.0, 15.0);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _rotationController]),
      builder: (context, _) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Opacity(
            opacity: _fadeAnim.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated glowing circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: loaderSize + 25,
                      height: loaderSize + 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    Transform.rotate(
                      angle: _rotationController.value * math.pi * 2,
                      child: Container(
                        width: loaderSize,
                        height: loaderSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary2,
                              Colors.transparent,
                              AppColors.primary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      width: loaderSize - 10,
                      height: loaderSize - 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xff111827) : Colors.white,
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          AppAssets.appLogo2,
                          height: 40,
                          width: 40,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: spacing),

                // Loading bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: barWidth,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: _slideAnim.value * barWidth,
                          child: Container(
                            width: barWidth * 0.35,
                            height: barHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.primary,
                                  AppColors.primary2,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: spacing),

                // Text
                ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: isDark
                          ? [Colors.white, AppColors.primary2]
                          : [AppColors.textPrimary, AppColors.primary2],
                    ).createShader(bounds);
                  },
                  child: Text(
                    'جاري تحميل لوحة التحكم...',
                    style: TextStyle(
                      fontSize: textSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Please wait a moment',
                  style: TextStyle(
                    fontSize: textSize - 2,
                    color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black45,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
