// ignore_for_file: use_build_context_synchronously

import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:admin_bnwasal/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:admin_bnwasal/features/settings/presentation/widgets/update_download_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/config/app_config.dart';
import '../../../core/routes/routes.dart';
import '../../../core/routes/app_router.dart';

import 'widgets/splash_background.dart';
import 'widgets/splash_logo.dart';
import 'widgets/splash_loading.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterController;
  late Animation<double> _enterAnim;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _enterAnim = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutCubic,
    );

    _checkAuthThenNavigate();
  }

  Future<void> _checkAuthThenNavigate() async {
    await context.read<AuthCubit>().checkAuth();
    if (!mounted) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
    } catch (_) {
      _appVersion = AppConfig.appVersion;
    }

    try {
      await context.read<SettingsCubit>().loadSettings();
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {});

    final settingsState = context.read<SettingsCubit>().state;

    if (settingsState.hasUpdateFile &&
        _isUpdateNeeded(settingsState.updateVersion)) {
      _showUpdateDialog(required: settingsState.updateRequired);
      return;
    }

    _navigateToHome();
  }

  bool _isUpdateNeeded(String serverVersion) {
    if (serverVersion.isEmpty || _appVersion.isEmpty) return false;
    try {
      final current = _parseVersion(_appVersion);
      final server = _parseVersion(serverVersion);
      for (int i = 0; i < 3; i++) {
        if (server[i] > current[i]) return true;
        if (server[i] < current[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  List<int> _parseVersion(String v) {
    final cleaned = v.trim().replaceFirst(
      RegExp(r'^v', caseSensitive: false),
      '',
    );
    final parts = cleaned.split('.');
    return [
      int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0,
    ];
  }

  void _showUpdateDialog({required bool required}) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: !required,
      builder: (ctx) => PopScope(
        canPop: !required,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(isWide ? 40.w : 24.w),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxWidth: isWide ? 480.w : 420.w),
              padding: EdgeInsets.all(isWide ? 32.w : 24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1e1e3a), const Color(0xFF16162e)]
                      : [Colors.white, const Color(0xFFf8f9fa)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? const Color(0xFF06b6d4) : AppColors.primary).withValues(alpha: 0.15),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF8b5cf6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  // Title
                  Text(
                    'تحديث جديد متاح',
                    style: TextStyle(
                      fontSize: isWide ? 22.sp : 20.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Description
                  Text(
                    required
                        ? 'يوجد تحديث إجباري جديد يُحسّن الأداء ويُصلح بعض المشاكل. يجب تحديث التطبيق للمتابعة.'
                        : 'يوجد تحديث اختياري جديد. يمكنك التحديث الآن أو لاحقاً للاستفادة من المميزات الجديدة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isWide ? 14.sp : 13.sp,
                      color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54,
                      height: 1.6,
                    ),
                  ),
                  if (required) ...[
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFef4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFef4444).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFef4444),
                            size: 16,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'لن تتمكن من استخدام التطبيق بدون تحديث',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: const Color(0xFFef4444),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 24.h),
                  // Update button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UpdateDownloadScreen(
                              version: context
                                  .read<SettingsCubit>()
                                  .state
                                  .updateVersion,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          vertical: isWide ? 16.h : 14.h,
                        ),
                      ),
                      child: Text(
                        'تحديث الآن',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isWide ? 16.sp : 15.sp,
                        ),
                      ),
                    ),
                  ),
                  // Skip button for optional update
                  if (!required) ...[
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                        child: Text(
                          'تذكير لاحقاً',
                          style: TextStyle(
                            color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black54,
                            fontSize: isWide ? 14.sp : 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToHome() {
    if (!mounted) return;
    final state = context.read<AuthCubit>().state;
    if (state.isAuthenticated) {
      AppRouter.navigateAndReplace(context, Routes.home);
    } else {
      AppRouter.navigateAndReplace(context, Routes.login);
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sw = mediaQuery.size.width;
    final sh = mediaQuery.size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0a0a1a),
                    const Color(0xFF0d0d2b),
                    const Color(0xFF1a0a2e),
                    const Color(0xFF0a0a1a),
                  ]
                : [
                    const Color(0xFFf8f9fa),
                    const Color(0xFFe9ecef),
                    const Color(0xFFdee2e6),
                    const Color(0xFFf8f9fa),
                  ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            const SplashBackground(),
            Positioned(
              top: -sh * 0.15,
              right: -(sw * 0.15).clamp(40.0, 100.0),
              child: _buildGlassCircle((sw * 0.7).clamp(240.0, 480.0), 0.03),
            ),
            Positioned(
              bottom: -sh * 0.12,
              left: -(sw * 0.12).clamp(30.0, 80.0),
              child: _buildGlassCircle((sw * 0.55).clamp(180.0, 360.0), 0.04),
            ),
            Positioned(
              top: sh * 0.4,
              left: -(sw * 0.08).clamp(20.0, 50.0),
              child: _buildGlassCircle((sw * 0.3).clamp(100.0, 200.0), 0.02),
            ),
            Positioned(
              top: sh * 0.1,
              left: (sw * 0.1).clamp(24.0, 80.0),
              child: _buildFloatingIcon(
                Icons.local_shipping_outlined,
                0.15,
                sw,
              ),
            ),
            Positioned(
              bottom: sh * 0.2,
              right: (sw * 0.12).clamp(30.0, 90.0),
              child: _buildFloatingIcon(Icons.location_on_outlined, 0.10, sw),
            ),
            Positioned(
              top: sh * 0.35,
              right: (sw * 0.15).clamp(35.0, 100.0),
              child: _buildFloatingIcon(Icons.inventory_2_outlined, 0.12, sw),
            ),
            Positioned.fill(
              child: FadeTransition(
                opacity: _enterAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    const SplashLogo(),
                    const Spacer(flex: 2),
                    const SplashLoading(),
                    SizedBox(height: (sh * 0.05).clamp(20.0, 40.0)),
                    Text(
                      _appVersion.isNotEmpty ? 'v$_appVersion' : 'v1.0.0',
                      style: TextStyle(
                        fontSize: (sw * 0.03).clamp(11.0, 13.0),
                        color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black26,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: (sh * 0.03).clamp(16.0, 24.0)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCircle(double size, double opacity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.cyan : AppColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
        border: Border.all(
          color: color.withValues(alpha: opacity * 0.5),
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, double opacity, double sw) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      icon,
      color: (isDark ? Colors.cyan : AppColors.primary).withValues(alpha: opacity),
      size: (sw * 0.07).clamp(22.0, 32.0),
    );
  }
}
