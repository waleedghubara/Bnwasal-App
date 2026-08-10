// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import '../cubit/payment_methods_cubit.dart';
import '../cubit/payment_methods_state.dart';
import '../widgets/update_download_screen.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  final _versionCtrl = TextEditingController();
  final _maintenanceMsgCtrl = TextEditingController();
  final _playStoreUrlCtrl = TextEditingController();
  final _appStoreUrlCtrl = TextEditingController();
  final _supportPhoneCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  final _merchantVideoUrlCtrl = TextEditingController();
  final _captainVideoUrlCtrl = TextEditingController();
  final _mobileVersionCtrl = TextEditingController();
  final _timeoutCtrl = TextEditingController();
  final _maxAttemptsCtrl = TextEditingController();
  final _maxAttemptsPerCaptainCtrl = TextEditingController();
  final _captainTimeoutCtrl = TextEditingController();
  final Map<String, TextEditingController> _socialControllers = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
    context.read<SettingsCubit>().loadSettings();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _versionCtrl.dispose();
    _maintenanceMsgCtrl.dispose();
    _playStoreUrlCtrl.dispose();
    _appStoreUrlCtrl.dispose();
    _supportPhoneCtrl.dispose();
    _supportEmailCtrl.dispose();
    _merchantVideoUrlCtrl.dispose();
    _captainVideoUrlCtrl.dispose();
    _mobileVersionCtrl.dispose();
    _timeoutCtrl.dispose();
    _maxAttemptsCtrl.dispose();
    _maxAttemptsPerCaptainCtrl.dispose();
    _captainTimeoutCtrl.dispose();
    for (final c in _socialControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
            ),
        child: BlocConsumer<SettingsCubit, SettingsState>(
          listener: (ctx, state) {
            if (!state.isLoading && _socialControllers.isEmpty) {
              _socialControllers['facebook'] = TextEditingController(
                text: state.facebook,
              );
              _socialControllers['instagram'] = TextEditingController(
                text: state.instagram,
              );
              _socialControllers['twitter'] = TextEditingController(
                text: state.twitter,
              );
              _socialControllers['whatsapp'] = TextEditingController(
                text: state.whatsapp,
              );
              _socialControllers['linkedin'] = TextEditingController(
                text: state.linkedin,
              );
              _socialControllers['youtube'] = TextEditingController(
                text: state.youtube,
              );
            }
            if (state.updateVersion.isNotEmpty && _versionCtrl.text.isEmpty) {
              _versionCtrl.text = state.updateVersion;
            }
            if (_maintenanceMsgCtrl.text.isEmpty &&
                state.maintenanceMessage.isNotEmpty) {
              _maintenanceMsgCtrl.text = state.maintenanceMessage;
            }
            if (_playStoreUrlCtrl.text.isEmpty &&
                state.playStoreUrl.isNotEmpty) {
              _playStoreUrlCtrl.text = state.playStoreUrl;
            }
            if (_appStoreUrlCtrl.text.isEmpty && state.appStoreUrl.isNotEmpty) {
              _appStoreUrlCtrl.text = state.appStoreUrl;
            }
            if (_supportPhoneCtrl.text.isEmpty &&
                state.supportPhone.isNotEmpty) {
              _supportPhoneCtrl.text = state.supportPhone;
            }
            if (_supportEmailCtrl.text.isEmpty &&
                state.supportEmail.isNotEmpty) {
              _supportEmailCtrl.text = state.supportEmail;
            }
            if (_merchantVideoUrlCtrl.text.isEmpty &&
                state.merchantVideoUrl.isNotEmpty) {
              _merchantVideoUrlCtrl.text = state.merchantVideoUrl;
            }
            if (_captainVideoUrlCtrl.text.isEmpty &&
                state.captainVideoUrl.isNotEmpty) {
              _captainVideoUrlCtrl.text = state.captainVideoUrl;
            }
            if (_mobileVersionCtrl.text.isEmpty &&
                state.mobileUpdateVersion.isNotEmpty) {
              _mobileVersionCtrl.text = state.mobileUpdateVersion;
            }
            if (_timeoutCtrl.text.isEmpty && state.autoAssignmentTimeout > 0) {
              _timeoutCtrl.text = state.autoAssignmentTimeout.toString();
            }
            if (_maxAttemptsCtrl.text.isEmpty &&
                state.maxReassignmentAttempts > 0) {
              _maxAttemptsCtrl.text = state.maxReassignmentAttempts.toString();
            }
            if (_maxAttemptsPerCaptainCtrl.text.isEmpty &&
                state.maxAttemptsPerCaptain > 0) {
              _maxAttemptsPerCaptainCtrl.text = state.maxAttemptsPerCaptain.toString();
            }
            if (_captainTimeoutCtrl.text.isEmpty &&
                state.captainAcceptanceTimeout > 0) {
              _captainTimeoutCtrl.text = state.captainAcceptanceTimeout.toString();
            }

            if (state.successMessage != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    state.successMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              context.read<SettingsCubit>().clearMessages();
            }
            if (state.error != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    state.error!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              context.read<SettingsCubit>().clearMessages();
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 24.w : 16.w,
                vertical: 20.h,
              ),
              child: Center(
                child: SizedBox(
                  width: isWide ? 1000.w : double.infinity,
                  child: state.isLoading
                      ? const SizedBox(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : _buildContent(state, isWide),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(SettingsState state, bool isWide) {
    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isWide),
          SizedBox(height: 24.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Social Links
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildSectionCard(
                      icon: Icons.share_outlined,
                      title: 'روابط التواصل الاجتماعي',
                      subtitle: 'روابط حسابات المنصة الرسمية على مواقع التواصل',
                      child: _buildSocialLinks(state, isWide),
                    ),
                    SizedBox(height: 20.h),
                    // Payment Methods Card
                    BlocConsumer<PaymentMethodsCubit, PaymentMethodsState>(
                      listener: (ctx, pmState) {
                        if (pmState.successMessage != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                pmState.successMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          ctx.read<PaymentMethodsCubit>().clearMessages();
                        }
                        if (pmState.error != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                pmState.error!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          ctx.read<PaymentMethodsCubit>().clearMessages();
                        }
                      },
                      builder: (ctx, pmState) => _buildSectionCard(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'وسائل الدفع المباشر',
                        subtitle:
                            'إدارة وسائل الدفع المتاحة للتجار (فودافون كاش، انستا باي...)',
                        child: _buildPaymentMethodsSection(pmState, isWide),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    _buildSectionCard(
                      icon: Icons.assignment_ind_outlined,
                      title: 'إعدادات الإسناد التلقائي للكباتن',
                      subtitle:
                          'تحديد مهلات انتظار رد المندوب وقواعد مطابقة رحلاتهم بالكامل',
                      child: _buildAutoAssignmentSection(state, isWide),
                    ),
                    SizedBox(height: 20.h),
                    _buildSectionCard(
                      icon: Icons.timer_outlined,
                      title: 'مهلة قبول الطلبات للكباتن (عداد الثواني)',
                      subtitle:
                          'التحكم في الوقت المتاح للكابتن لقبول أو رفض الطلب (بالثواني)',
                      child: _buildCaptainTimeoutSection(state, isWide),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 24.w),
              // Right Column: App Update & Maintenance Mode
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildSectionCard(
                      icon: Icons.cloud_upload_outlined,
                      title: 'تحديث التطبيق (ويندوز)',
                      subtitle: 'إعداد إصدار جديد للمنصة ورفع ملف النظام',
                      child: _buildUpdateSection(state, isWide),
                    ),
                    SizedBox(height: 20.h),
                    _buildSectionCard(
                      icon: Icons.storefront_outlined,
                      title: 'روابط المتاجر وقنوات الدعم',
                      subtitle:
                          'روابط متجر Google Play ومتجر Apple App Store وقنوات الدعم',
                      child: _buildStoreUrlsSection(state, isWide),
                    ),
                    SizedBox(height: 20.h),
                    _buildSectionCard(
                      icon: Icons.video_library_outlined,
                      title: 'فيديوهات شرح التطبيق',
                      subtitle:
                          'الروابط الخاصة بفيديوهات شرح التطبيق للتجار والمناديب',
                      child: _buildVideoUrlsSection(state, isWide),
                    ),
                    SizedBox(height: 20.h),
                    _buildSectionCard(
                      icon: Icons.engineering_outlined,
                      title: 'وضع صيانة النظام',
                      subtitle:
                          'تعطيل النظام مؤقتاً وعرض رسالة صيانة للمستخدمين',
                      child: _buildMaintenanceSection(state, isWide),
                    ),
                    SizedBox(height: 20.h),
                    _buildSectionCard(
                      icon: Icons.payments_outlined,
                      title: 'إعدادات تحصيل رسوم الشحن',
                      subtitle: 'تحديد وقت تحصيل رسوم التوصيل من محفظة التاجر',
                      child: _buildFeeCollectionSection(state, isWide),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Mobile Stack
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isWide),
          SizedBox(height: 20.h),
          _buildSectionCard(
            icon: Icons.share_outlined,
            title: 'روابط التواصل الاجتماعي',
            subtitle: 'روابط حسابات المنصة الرسمية على مواقع التواصل',
            child: _buildSocialLinks(state, isWide),
          ),
          SizedBox(height: 20.h),
          _buildSectionCard(
            icon: Icons.cloud_upload_outlined,
            title: 'تحديث التطبيق (ويندوز)',
            subtitle: 'إعداد إصدار جديد للمنصة ورفع ملف النظام',
            child: _buildUpdateSection(state, isWide),
          ),
          SizedBox(height: 20.h),
          _buildSectionCard(
            icon: Icons.storefront_outlined,
            title: 'روابط المتاجر وقنوات الدعم',
            subtitle:
                'روابط متجر Google Play ومتجر Apple App Store وقنوات الدعم',
            child: _buildStoreUrlsSection(state, isWide),
          ),
          SizedBox(height: 20.h),
          _buildSectionCard(
            icon: Icons.video_library_outlined,
            title: 'فيديوهات شرح التطبيق',
            subtitle: 'الروابط الخاصة بفيديوهات شرح التطبيق للتجار والمناديب',
            child: _buildVideoUrlsSection(state, isWide),
          ),
          SizedBox(height: 20.h),
          _buildSectionCard(
            icon: Icons.engineering_outlined,
            title: 'وضع صيانة النظام',
            subtitle: 'تعطيل النظام مؤقتاً وعرض رسالة صيانة للمستخدمين',
            child: _buildMaintenanceSection(state, isWide),
          ),
          SizedBox(height: 20.h),
          _buildSectionCard(
            icon: Icons.payments_outlined,
            title: 'إعدادات تحصيل رسوم الشحن',
            subtitle: 'تحديد وقت تحصيل رسوم التوصيل من محفظة التاجر',
            child: _buildFeeCollectionSection(state, isWide),
          ),
          SizedBox(height: 20.h),
          BlocConsumer<PaymentMethodsCubit, PaymentMethodsState>(
            listener: (ctx, pmState) {
              if (pmState.successMessage != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      pmState.successMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                ctx.read<PaymentMethodsCubit>().clearMessages();
              }
              if (pmState.error != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      pmState.error!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                ctx.read<PaymentMethodsCubit>().clearMessages();
              }
            },
            builder: (ctx, pmState) => _buildSectionCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'وسائل الدفع المباشر',
              subtitle:
                  'إدارة وسائل الدفع المتاحة للتجار (فودافون كاش، انستا باي...)',
              child: _buildPaymentMethodsSection(pmState, isWide),
            ),
          ),
          SizedBox(height: 20.h),
          _buildSectionCard(
            icon: Icons.assignment_ind_outlined,
            title: 'إعدادات الإسناد التلقائي للكباتن',
            subtitle:
                'تحديد مهلات انتظار رد المندوب وقواعد مطابقة رحلاتهم بالكامل',
            child: _buildAutoAssignmentSection(state, isWide),
          ),
        ],
      );
    }
  }

  Widget _buildHeader(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.settings_rounded,
            color: AppColors.primary,
            size: 22.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          'إعدادات النظام العامة',
          style: GoogleFonts.tajawal(
            fontSize: isWide ? 22.sp : 19.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade300,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.tajawal(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.tajawal(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          child,
        ],
      ),
    );
  }

  Widget _buildSocialLinks(SettingsState state, bool isWide) {
    final fields = [
      {
        'key': 'facebook',
        'label': 'فيسبوك',
        'hint': 'https://facebook.com/...',
        'icon': FontAwesomeIcons.facebook,
      },
      {
        'key': 'instagram',
        'label': 'إنستغرام',
        'hint': 'https://instagram.com/...',
        'icon': FontAwesomeIcons.instagram,
      },
      {
        'key': 'twitter',
        'label': 'تويتر / X',
        'hint': 'https://twitter.com/...',
        'icon': FontAwesomeIcons.twitter,
      },
      {
        'key': 'whatsapp',
        'label': 'واتساب',
        'hint': 'https://wa.me/...',
        'icon': FontAwesomeIcons.whatsapp,
      },
      {
        'key': 'linkedin',
        'label': 'لينكد إن',
        'hint': 'https://linkedin.com/...',
        'icon': FontAwesomeIcons.linkedin,
      },
      {
        'key': 'youtube',
        'label': 'يوتيوب',
        'hint': 'https://youtube.com/@...',
        'icon': FontAwesomeIcons.youtube,
      },
    ];

    final brandColors = {
      'facebook': const Color(0xFF1877F2),
      'instagram': const Color(0xFFE1306C),
      'twitter': Colors.black87,
      'whatsapp': const Color(0xFF25D366),
      'linkedin': const Color(0xFF0A66C2),
      'youtube': const Color(0xFFFF0000),
    };
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        Wrap(
          spacing: 12.w,
          runSpacing: 14.h,
          children: fields.map((f) {
            final key = f['key'] as String;
            final controller =
                _socialControllers[key] ?? TextEditingController();
            final brandColor = brandColors[key] ?? AppColors.primary;
            return SizedBox(
              width: isWide
                  ? 250.w
                  : (MediaQuery.of(context).size.width - 84.w),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade300,
                  ),
                ),
                child: TextFormField(
                  controller: controller,
                  onChanged: (v) =>
                      context.read<SettingsCubit>().updateSocialField(key, v),
                  style: GoogleFonts.tajawal(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    fillColor: Colors.transparent,
                    labelText: f['label'] as String,
                    hintText: f['hint'] as String,
                    labelStyle: GoogleFonts.tajawal(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black87,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    hintStyle: GoogleFonts.tajawal(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(10),
                      child: FaIcon(
                        f['icon'] as FaIconData,
                        color: brandColor,
                        size: 18.sp,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 20.h),
        _buildActionButton(
          label: 'حفظ روابط التواصل الاجتماعي',
          icon: Icons.save_rounded,
          isLoading: state.isSaving,
          onTap: () => context.read<SettingsCubit>().saveSocialLinks(),
        ),
      ],
    );
  }

  Widget _buildUpdateSection(SettingsState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade300,
                  ),
                ),
                child: TextFormField(
                  controller: _versionCtrl,
                  onChanged: (v) =>
                      context.read<SettingsCubit>().setUpdateVersion(v),
                  style: GoogleFonts.tajawal(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    fillColor: Colors.transparent,
                    labelText: 'رقم الإصدار الجديد',
                    hintText: 'مثال: 2.0.0',
                    labelStyle: GoogleFonts.tajawal(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black87,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    hintStyle: GoogleFonts.tajawal(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(10),
                      child: FaIcon(
                        FontAwesomeIcons.neuter,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            GestureDetector(
              onTap: () => context.read<SettingsCubit>().setUpdateRequired(
                !state.updateRequired,
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    color: state.updateRequired
                        ? AppColors.error
                        : AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.updateRequired
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.updateRequired
                            ? Icons.lock_outline
                            : Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        state.updateRequired ? 'إجباري' : 'اختياري',
                        style: GoogleFonts.tajawal(
                          fontSize: 13.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        if (state.hasUpdateFile)
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'ملف التحديث متوفر حالياً',
                  style: GoogleFonts.tajawal(
                    fontSize: 14.sp,
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'إصدار: ${state.updateVersion}',
                  style: GoogleFonts.tajawal(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        if (state.hasUpdateFile) SizedBox(height: 12.h),
        _buildActionButton(
          label: state.hasUpdateFile
              ? 'تحديث ملف النظام المرفوع'
              : 'رفع ملف تحديث جديد',
          icon: Icons.cloud_upload_rounded,
          isLoading: state.isUploading,
          onTap: () => context.read<SettingsCubit>().pickAndUploadUpdate(),
        ),
        if (state.hasUpdateFile) ...[
          SizedBox(height: 10.h),
          _buildActionButton(
            label: 'تثبيت التحديث الآن',
            icon: Icons.system_update_rounded,
            isLoading: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      UpdateDownloadScreen(version: state.updateVersion),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMaintenanceSection(SettingsState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'حالة تشغيل المنصة',
                style: GoogleFonts.tajawal(
                  fontSize: 15.sp,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.read<SettingsCubit>().toggleMaintenance(
                !state.maintenanceEnabled,
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: state.maintenanceEnabled
                        ? AppColors.error
                        : AppColors.success,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.maintenanceEnabled
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: const [
                            BoxShadow(color: Colors.white, blurRadius: 4),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        state.maintenanceEnabled
                            ? 'وضع الصيانة مُفعل'
                            : 'المنصة نشطة وتعمل',
                        style: GoogleFonts.tajawal(
                          fontSize: 14.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (state.maintenanceEnabled) ...[
          SizedBox(height: 14.h),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade300,
              ),
            ),
            child: TextFormField(
              controller: _maintenanceMsgCtrl,
              onChanged: (v) =>
                  context.read<SettingsCubit>().setMaintenanceMessage(v),
              maxLines: 3,
              style: GoogleFonts.tajawal(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                fillColor: Colors.transparent,
                labelText: 'رسالة الصيانة للمستخدمين',
                hintText:
                    'النظام قيد الصيانة المجدولة حالياً، يرجى المحاولة لاحقاً...',
                labelStyle: GoogleFonts.tajawal(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black87,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
                hintStyle: GoogleFonts.tajawal(
                  color: isDark ? Colors.white30 : Colors.black38,
                  fontSize: 14.sp,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          _buildActionButton(
            label: 'حفظ رسالة الصيانة',
            icon: Icons.save_rounded,
            isLoading: state.isSaving,
            onTap: () => context.read<SettingsCubit>().toggleMaintenance(true),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStoreUrlsSection(SettingsState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade300,
            ),
          ),
          child: TextFormField(
            controller: _playStoreUrlCtrl,
            onChanged: (v) => context.read<SettingsCubit>().setPlayStoreUrl(v),
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              fillColor: Colors.transparent,
              labelText: 'رابط تطبيق الأندرويد (Google Play)',
              hintText: 'https://play.google.com/store/apps/...',
              labelStyle: GoogleFonts.tajawal(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              hintStyle: GoogleFonts.tajawal(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 14.sp,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: FaIcon(
                  FontAwesomeIcons.googlePlay,
                  color: const Color(0xFF34A853),
                  size: 18.sp,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade300,
            ),
          ),
          child: TextFormField(
            controller: _appStoreUrlCtrl,
            onChanged: (v) => context.read<SettingsCubit>().setAppStoreUrl(v),
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              fillColor: Colors.transparent,
              labelText: 'رابط تطبيق الآيفون (Apple App Store)',
              hintText: 'https://apps.apple.com/app/...',
              labelStyle: GoogleFonts.tajawal(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              hintStyle: GoogleFonts.tajawal(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 14.sp,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: FaIcon(
                  FontAwesomeIcons.apple,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 20.sp,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade300,
            ),
          ),
          child: TextFormField(
            controller: _supportPhoneCtrl,
            onChanged: (v) => context.read<SettingsCubit>().setSupportPhone(v),
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              fillColor: Colors.transparent,
              labelText: 'رقم هاتف الدعم الفني (اتصال)',
              hintText: 'مثال: +966500000000',
              labelStyle: GoogleFonts.tajawal(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              hintStyle: GoogleFonts.tajawal(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 14.sp,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.phone_callback_rounded,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade300,
            ),
          ),
          child: TextFormField(
            controller: _supportEmailCtrl,
            onChanged: (v) => context.read<SettingsCubit>().setSupportEmail(v),
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              fillColor: Colors.transparent,
              labelText: 'البريد الإلكتروني للدعم الفني',
              hintText: 'مثال: support@binwasal.com',
              labelStyle: GoogleFonts.tajawal(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              hintStyle: GoogleFonts.tajawal(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 14.sp,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.alternate_email_rounded,
                  color: Colors.redAccent,
                  size: 20.sp,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade300,
                  ),
                ),
                child: TextFormField(
                  controller: _mobileVersionCtrl,
                  onChanged: (v) =>
                      context.read<SettingsCubit>().setMobileUpdateVersion(v),
                  style: GoogleFonts.tajawal(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    fillColor: Colors.transparent,
                    labelText: 'رقم إصدار تطبيق الهواتف (Android/iOS)',
                    hintText: 'مثال: 1.0.0',
                    labelStyle: GoogleFonts.tajawal(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black87,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    hintStyle: GoogleFonts.tajawal(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.phone_android_rounded,
                        color: AppColors.primary,
                        size: 20.sp,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            GestureDetector(
              onTap: () => context
                  .read<SettingsCubit>()
                  .setMobileUpdateRequired(!state.mobileUpdateRequired),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    color: state.mobileUpdateRequired
                        ? AppColors.error
                        : AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.mobileUpdateRequired
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.mobileUpdateRequired
                            ? Icons.lock_outline
                            : Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        state.mobileUpdateRequired ? 'إجباري' : 'اختياري',
                        style: GoogleFonts.tajawal(
                          fontSize: 13.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        _buildActionButton(
          label: 'حفظ المتاجر وقنوات الدعم',
          icon: Icons.save_rounded,
          isLoading: state.isSaving,
          onTap: () => context.read<SettingsCubit>().saveStoreUrls(),
        ),
      ],
    );
  }

  Widget _buildVideoUrlsSection(SettingsState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade300,
            ),
          ),
          child: TextFormField(
            controller: _merchantVideoUrlCtrl,
            onChanged: (v) =>
                context.read<SettingsCubit>().setMerchantVideoUrl(v),
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              fillColor: Colors.transparent,
              labelText: 'رابط فيديو شرح التاجر (YouTube أو مباشر)',
              hintText: 'https://youtube.com/watch?v=... أو رابط مباشر',
              labelStyle: GoogleFonts.tajawal(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              hintStyle: GoogleFonts.tajawal(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 14.sp,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.store_rounded,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade300,
            ),
          ),
          child: TextFormField(
            controller: _captainVideoUrlCtrl,
            onChanged: (v) =>
                context.read<SettingsCubit>().setCaptainVideoUrl(v),
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              fillColor: Colors.transparent,
              labelText: 'رابط فيديو شرح الكابتن/المندوب (YouTube أو مباشر)',
              hintText: 'https://youtube.com/watch?v=... أو رابط مباشر',
              labelStyle: GoogleFonts.tajawal(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              hintStyle: GoogleFonts.tajawal(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 14.sp,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.delivery_dining_rounded,
                  color: Colors.amber,
                  size: 20.sp,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
            ),
          ),
        ),
        SizedBox(height: 20.h),
        _buildActionButton(
          label: 'حفظ فيديوهات شرح التطبيق',
          icon: Icons.save_rounded,
          isLoading: state.isSaving,
          onTap: () => context.read<SettingsCubit>().saveVideoUrls(),
        ),
      ],
    );
  }

  Widget _buildFeeCollectionSection(SettingsState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'وقت تحصيل الرسوم',
          style: GoogleFonts.tajawal(
            fontSize: 15.sp,
            color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context
                    .read<SettingsCubit>()
                    .updateFeeCollectionMode('after_agreement'),
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: state.feeCollectionMode == 'after_agreement'
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.feeCollectionMode == 'after_agreement'
                          ? AppColors.primary
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.grey.shade300),
                    ),
                    boxShadow:
                        state.feeCollectionMode == 'after_agreement' || isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.handshake_outlined,
                        color: state.feeCollectionMode == 'after_agreement'
                            ? AppColors.primary
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.black38),
                        size: 26.sp,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'بعد الاتفاق مباشرة',
                        style: GoogleFonts.tajawal(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'دفع الرسوم بعد الاتفاق على سعر التوصيل',
                        style: GoogleFonts.tajawal(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: InkWell(
                onTap: () => context
                    .read<SettingsCubit>()
                    .updateFeeCollectionMode('after_assignment'),
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: state.feeCollectionMode == 'after_assignment'
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.feeCollectionMode == 'after_assignment'
                          ? AppColors.primary
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.grey.shade300),
                    ),
                    boxShadow:
                        state.feeCollectionMode == 'after_assignment' || isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.sports_motorsports_outlined,
                        color: state.feeCollectionMode == 'after_assignment'
                            ? AppColors.primary
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.black38),
                        size: 26.sp,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'بعد توجيه المندوب',
                        style: GoogleFonts.tajawal(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'دفع الرسوم بعد اختيار المندوب المناسب',
                        style: GoogleFonts.tajawal(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Payment Methods Section ──────────────────────────────────────────────────
  Widget _buildPaymentMethodsSection(PaymentMethodsState state, bool isWide) {
    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Methods list
        if (state.methods.isEmpty)
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black54,
                  size: 20.sp,
                ),
                SizedBox(width: 10.w),
                Text(
                  'لا توجد وسائل دفع مضافة بعد. اضغط «إضافة وسيلة» للبدء.',
                  style: GoogleFonts.tajawal(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(state.methods.length, (i) {
            final method = state.methods[i];
            final isUploadingThis =
                state.isUploadingIcon && state.uploadingIndex == i;
            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.grey.shade300,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: icon + delete button
                  Row(
                    children: [
                      // Icon preview / upload button
                      GestureDetector(
                        onTap: () => context
                            .read<PaymentMethodsCubit>()
                            .pickAndUploadIcon(i),
                        child: isUploadingThis
                            ? Container(
                                width: 52.w,
                                height: 52.w,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 52.w,
                                    height: 52.w,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child:
                                        method.imageUrl != null &&
                                            method.imageUrl!.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                            child: Image.network(
                                              '${EndPoint.imageBaseUrl}${method.imageUrl}',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.5),
                                                size: 22.sp,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: AppColors.primary.withValues(
                                              alpha: 0.6,
                                            ),
                                            size: 22.sp,
                                          ),
                                  ),
                                  if (method.imageUrl != null &&
                                      method.imageUrl!.isNotEmpty)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 10.sp,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'اضغط لرفع أيقونة',
                        style: GoogleFonts.tajawal(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      // Delete button
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: isDark
                                  ? const Color(0xFF16213E)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300,
                                ),
                              ),
                              title: Text(
                                'حذف وسيلة الدفع',
                                style: GoogleFonts.tajawal(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
                              ),
                              content: Text(
                                'هل تريد حذف «${method.name.isEmpty ? 'وسيلة بلا اسم' : method.name}»؟',
                                style: GoogleFonts.tajawal(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : Colors.black54,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'إلغاء',
                                    style: GoogleFonts.tajawal(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : Colors.black54,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context
                                        .read<PaymentMethodsCubit>()
                                        .removeMethod(i);
                                  },
                                  child: Text(
                                    'حذف',
                                    style: GoogleFonts.tajawal(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                            size: 18.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Name field
                  _buildMethodTextField(
                    label: 'اسم وسيلة الدفع',
                    hint: 'مثال: فودافون كاش',
                    icon: Icons.payment_outlined,
                    initialValue: method.name,
                    onChanged: (v) =>
                        context.read<PaymentMethodsCubit>().updateName(i, v),
                  ),
                  SizedBox(height: 8.h),
                  // Phone/account number field
                  _buildMethodTextField(
                    label: 'رقم الحساب / التحويل',
                    hint: 'مثال: 01XXXXXXXXX',
                    icon: Icons.phone_outlined,
                    initialValue: method.phone,
                    onChanged: (v) =>
                        context.read<PaymentMethodsCubit>().updatePhone(i, v),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            );
          }),

        SizedBox(height: 14.h),

        // Add method button
        InkWell(
          onTap: () => context.read<PaymentMethodsCubit>().addMethod(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'إضافة وسيلة دفع جديدة',
                  style: GoogleFonts.tajawal(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 16.h),

        // Save button
        _buildActionButton(
          label: 'حفظ وسائل الدفع',
          icon: Icons.save_rounded,
          isLoading: state.isSaving,
          onTap: () => context.read<PaymentMethodsCubit>().saveMethods(),
        ),
      ],
    );
  }

  Widget _buildMethodTextField({
    required String label,
    required String hint,
    required IconData icon,
    required String initialValue,
    required void Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade300,
        ),
      ),
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == TextInputType.phone
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: GoogleFonts.tajawal(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          fillColor: Colors.transparent,
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.tajawal(
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black87,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
          hintStyle: GoogleFonts.tajawal(
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black38,
            fontSize: 14.sp,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AppColors.primary, size: 18.sp),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 10.h,
          ),
        ),
      ),
    );
  }

  Widget _buildAutoAssignmentSection(SettingsState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: state.enableAutoAssignment,
            onChanged: (v) =>
                context.read<SettingsCubit>().setEnableAutoAssignment(v),
            title: Text(
              'تفعيل الإسناد التلقائي',
              style: GoogleFonts.tajawal(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'تشغيل أو إيقاف إسناد الشحنات والطلبات للكباتن تلقائياً',
              style: GoogleFonts.tajawal(
                fontSize: 12.sp,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          SizedBox(height: 12.h),

          if (isWide)
            Row(
              children: [
                Expanded(
                  child: _buildNumberTextField(
                    controller: _maxAttemptsPerCaptainCtrl,
                    label: 'عدد محاولات الإعادة لكل كابتن',
                    hint: 'مثال: 3 (إعادة الطلب لنفس الكابتن 3 مرات)',
                    icon: Icons.replay_circle_filled_outlined,
                    onChanged: (v) {
                      final val = int.tryParse(v) ?? 3;
                      context.read<SettingsCubit>().setMaxAttemptsPerCaptain(
                        val,
                      );
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildNumberTextField(
                    controller: _maxAttemptsCtrl,
                    label: 'إجمالي الحد الأقصى لمحاولات التوجيه',
                    hint: 'مثال: 10',
                    icon: Icons.loop_outlined,
                    onChanged: (v) {
                      final val = int.tryParse(v) ?? 10;
                      context.read<SettingsCubit>().setMaxReassignmentAttempts(
                        val,
                      );
                    },
                  ),
                ),
              ],
            )
          else ...[
            _buildNumberTextField(
              controller: _maxAttemptsPerCaptainCtrl,
              label: 'عدد محاولات الإعادة لكل كابتن',
              hint: 'مثال: 3 (إعادة الطلب لنفس الكابتن 3 مرات)',
              icon: Icons.replay_circle_filled_outlined,
              onChanged: (v) {
                final val = int.tryParse(v) ?? 3;
                context.read<SettingsCubit>().setMaxAttemptsPerCaptain(val);
              },
            ),
            SizedBox(height: 12.h),
            _buildNumberTextField(
              controller: _maxAttemptsCtrl,
              label: 'إجمالي الحد الأقصى لمحاولات التوجيه',
              hint: 'مثال: 10',
              icon: Icons.loop_outlined,
              onChanged: (v) {
                final val = int.tryParse(v) ?? 10;
                context.read<SettingsCubit>().setMaxReassignmentAttempts(val);
              },
            ),
          ],
          SizedBox(height: 16.h),

          Text(
            'قاعدة مطابقة مسار الرحلة والشحنة',
            style: GoogleFonts.tajawal(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildMatchingRuleCard(
                  title: 'مطابقة مرنة (Flexible)',
                  description:
                      'مطابقة المحافظات والمناطق والمدن الفرعية للتسهيل',
                  isSelected: state.routeMatchingRule == 'flexible',
                  onTap: () => context
                      .read<SettingsCubit>()
                      .setRouteMatchingRule('flexible'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildMatchingRuleCard(
                  title: 'مطابقة صارمة (Strict)',
                  description:
                      'مطابقة مدينتي البداية والنهاية للرحلة والشحنة تماماً',
                  isSelected: state.routeMatchingRule == 'strict',
                  onTap: () => context
                      .read<SettingsCubit>()
                      .setRouteMatchingRule('strict'),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          SwitchListTile(
            value: state.allowAutoAssignmentAfterReject,
            onChanged: (v) => context
                .read<SettingsCubit>()
                .setAllowAutoAssignmentAfterReject(v),
            title: Text(
              'السماح بالتحويل الآلي بعد رفض الكابتن',
              style: GoogleFonts.tajawal(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'إذا رفض الكابتن الشحنة، يستمر النظام في البحث والتحويل تلقائياً للكابتن التالي',
              style: GoogleFonts.tajawal(
                fontSize: 12.sp,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),

          SwitchListTile(
            value: state.allowAutoAssignmentAfterTimeout,
            onChanged: (v) => context
                .read<SettingsCubit>()
                .setAllowAutoAssignmentAfterTimeout(v),
            title: Text(
              'السماح بالتحويل الآلي بعد انتهاء المهلة (عدم الرد)',
              style: GoogleFonts.tajawal(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'إذا انتهت مهلة الكابتن دون رد، يستمر النظام في البحث والتحويل تلقائياً للكابتن التالي',
              style: GoogleFonts.tajawal(
                fontSize: 12.sp,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          SizedBox(height: 20.h),

          _buildActionButton(
            label: 'حفظ إعدادات الإسناد التلقائي',
            icon: Icons.save_rounded,
            isLoading: state.isSaving,
            onTap: () =>
                context.read<SettingsCubit>().saveAutoAssignmentSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required void Function(String) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade300,
        ),
      ),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.tajawal(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          fillColor: Colors.transparent,
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.tajawal(
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black87,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
          hintStyle: GoogleFonts.tajawal(
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black38,
            fontSize: 13.sp,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AppColors.primary, size: 18.sp),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 10.h,
          ),
        ),
      ),
    );
  }

  Widget _buildMatchingRuleCard({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade300),
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.tajawal(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Text(
              description,
              style: GoogleFonts.tajawal(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptainTimeoutSection(SettingsState state, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presets = [30, 45, 60, 90, 120];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مهلة القبول الحالية بالثواني',
          style: GoogleFonts.tajawal(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        SizedBox(height: 10.h),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade300,
            ),
          ),
          child: TextFormField(
            controller: _captainTimeoutCtrl,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final val = int.tryParse(v);
              if (val != null && val > 0) {
                context.read<SettingsCubit>().setCaptainAcceptanceTimeout(val);
              }
            },
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              fillColor: Colors.transparent,
              labelText: 'الوقت بالثواني (مثال: 60 يعني دقيقة واحدة)',
              hintText: '60',
              labelStyle: GoogleFonts.tajawal(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black87,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.timer_rounded,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Text(
          'اختيارات سريعة:',
          style: GoogleFonts.tajawal(
            fontSize: 13.sp,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: presets.map((seconds) {
            final isSelected = state.captainAcceptanceTimeout == seconds;
            return ChoiceChip(
              label: Text(
                '$seconds ثانية${seconds == 60 ? ' (دقيقة)' : ''}',
                style: GoogleFonts.tajawal(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
              onSelected: (selected) {
                if (selected) {
                  _captainTimeoutCtrl.text = seconds.toString();
                  context
                      .read<SettingsCubit>()
                      .setCaptainAcceptanceTimeout(seconds);
                }
              },
            );
          }).toList(),
        ),
        SizedBox(height: 20.h),
        _buildActionButton(
          label: 'حفظ مهلة قبول الكباتن',
          icon: Icons.save_rounded,
          isLoading: state.isSaving,
          onTap: () =>
              context.read<SettingsCubit>().saveAutoAssignmentSettings(),
        ),
      ],
    );
  }
}
