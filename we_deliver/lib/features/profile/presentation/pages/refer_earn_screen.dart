// ignore_for_file: strict_top_level_inference, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:we_deliver/core/theme/colors.dart';

import '../../../../core/theme/app_assets.dart';
import '../../../../core/api/end_point.dart';
import '../../data/models/referral_summary_model.dart';
import '../bloc/referral_cubit.dart';
import '../bloc/referral_state.dart';
import '../../../../core/utils/text_sanitizer.dart';

class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  bool _copied = false;

  void _copyReferralCode(String referralCode) {
    Clipboard.setData(ClipboardData(text: referralCode));
    setState(() {
      _copied = true;
    });

    // Reset copy indicator state after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 22.sp),
            SizedBox(width: 8.w),
            const Text('تم نسخ كود الدعوة بنجاح!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  void _shareReferral(String referralCode) {
    final String inviteUrl = '${EndPoint.imageBaseUrl}/invite/$referralCode';
    final String shareMessage =
        'سجل في تطبيق GEBLI - جيبلي باستخدام كود الدعوة الخاص بي: $referralCode واحصل على مكافأة فورية في محفظتك! رابط التسجيل: $inviteUrl';
    SharePlus.instance.share(ShareParams(text: shareMessage));
  }

  String formatDate(DateTime? date) {
    if (date == null) return '';
    try {
      return DateFormat('dd MMMM yyyy', 'ar').format(date);
    } catch (e) {
      return DateFormat('yyyy/MM/dd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'دعوة صديق واربح',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 20.sp,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          automaticallyImplyLeading: false,
        ),
        body: BlocConsumer<ReferralCubit, ReferralState>(
          listener: (context, state) {
            if (state is ReferralConvertSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 22.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          state.message,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              );
            } else if (state is ReferralConvertError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.error_rounded,
                        color: Colors.white,
                        size: 22.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          state.message,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ReferralLoading || state is ReferralConvertingPoints) {
              return _buildSkeletonLoader(isDarkMode);
            } else if (state is ReferralError) {
              return _buildErrorState(state.message, isDarkMode);
            }

            ReferralSummaryModel? summary;
            if (state is ReferralLoaded) {
              summary = state.summary;
            } else if (context.read<ReferralCubit>().state is ReferralLoaded) {
              summary = (context.read<ReferralCubit>().state as ReferralLoaded)
                  .summary;
            }

            if (summary == null) {
              return _buildSkeletonLoader(isDarkMode);
            }

            return RefreshIndicator(
              onRefresh: () =>
                  context.read<ReferralCubit>().loadReferralSummary(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  children: [
                    // Hero Section
                    FadeInDown(
                      duration: const Duration(milliseconds: 400),
                      child: _buildHeroSection(isDarkMode),
                    ),
                    SizedBox(height: 20.h),

                    // Points conversion card
                    FadeInUp(
                      duration: const Duration(milliseconds: 420),
                      child: _buildPointsConvertCard(summary, isDarkMode),
                    ),
                    SizedBox(height: 16.h),

                    // Milestone reward card
                    FadeInUp(
                      duration: const Duration(milliseconds: 450),
                      child: _buildMilestoneRewardCard(
                        summary.statistics,
                        isDarkMode,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Referral Code Card
                    FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      child: _buildReferralCodeCard(
                        summary.referralCode,
                        isDarkMode,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Steps Timeline
                    FadeInUp(
                      duration: const Duration(milliseconds: 550),
                      child: _buildStepsTimeline(isDarkMode),
                    ),
                    SizedBox(height: 20.h),

                    // Statistics Section
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      child: _buildStatisticsGrid(
                        summary.statistics,
                        isDarkMode,
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Invited Friends List Section
                    FadeInUp(
                      duration: const Duration(milliseconds: 650),
                      child: _buildInvitedFriendsSection(
                        summary.referrals,
                        isDarkMode,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SpinContainer(child: SvgPicture.asset(AppAssets.gift, height: 120.h)),
          SizedBox(height: 20.h),
          Text(
            'ادعُ أصدقاءك واربح المكافآت',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: isDarkMode ? Colors.white : AppColors.primary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'احصل على 15 ج.م فوراً في محفظتك عن كل صديق يقوم بتحميل التطبيق والتسجيل برمز دعوتك!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF888888),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneRewardCard(
    ReferralStatsModel statistics,
    bool isDarkMode,
  ) {
    final successCount = statistics.successCount;
    const int target = 5;
    final double progress = (successCount / target).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Colors.white, size: 24.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'مكافأة الإنجاز الكبرى',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '50 ج.م إضافية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            successCount < target
                ? 'ادعُ ${target - successCount} أصدقاء إضافيين للحصول على مكافأة الإنجاز بعد تسجيل $target أصدقاء بنجاح.'
                : 'تهانينا! لقد حققت مكافأة الإنجاز الكبرى وتم إيداع المكافأة في محفظتك.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التقدم الحالي: $successCount من $target أصدقاء',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: SizedBox(
              height: 8.h,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeCard(String referralCode, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDarkMode ? Colors.transparent : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رمز الدعوة الخاص بك',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : const Color(0xFF555555),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 45.h,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white10
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          referralCode,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _copyReferralCode(referralCode),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _copied
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  key: const ValueKey('check'),
                                  color: Colors.green,
                                  size: 22.sp,
                                )
                              : Icon(
                                  Icons.copy_rounded,
                                  key: const ValueKey('copy'),
                                  color: AppColors.primary2,
                                  size: 22.sp,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 7.w),
              ElevatedButton(
                onPressed: () => _shareReferral(referralCode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(60.w, 45.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Icon(Icons.share_rounded, size: 20.sp),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildShareChannelButton(
                icon: FontAwesomeIcons.whatsapp,
                label: 'واتساب',
                color: Colors.green,
                onTap: () => _shareReferral(referralCode),
              ),
              _buildShareChannelButton(
                icon: FontAwesomeIcons.telegram,
                label: 'تيليجرام',
                color: Colors.blue,
                onTap: () => _shareReferral(referralCode),
              ),
              _buildShareChannelButton(
                icon: FontAwesomeIcons.facebookMessenger,
                label: 'ماسينجر',
                color: Colors.purple,
                onTap: () => _shareReferral(referralCode),
              ),
              _buildShareChannelButton(
                icon: FontAwesomeIcons.envelope,
                label: 'البريد',
                color: Colors.redAccent,
                onTap: () => _shareReferral(referralCode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareChannelButton({
    required FaIconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: FaIcon(icon, color: color, size: 24.sp),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStepsTimeline(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDarkMode ? Colors.transparent : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'كيف تعمل الإحالة ودعوة الأصدقاء؟',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF333333),
            ),
          ),
          SizedBox(height: 20.h),
          _buildTimelineStep(
            stepNumber: '1',
            title: 'الخطوة 1: شارك رابط الدعوة',
            description:
                'شارك الكود المخصص أو رابط الإحالة مع أصدقائك عبر برامج التواصل الاجتماعي بنقرة واحدة.',
            icon: Icons.share_outlined,
            isLast: false,
            isDarkMode: isDarkMode,
          ),
          _buildTimelineStep(
            stepNumber: '2',
            title: 'الخطوة 2: يقوم صديقك بالتسجيل',
            description:
                'يقوم صديقك بإنشاء حساب جديد في منصة GEBLI - جيبلي وإدخال كود الدعوة في خانة رمز الإحالة.',
            icon: Icons.person_add_alt_outlined,
            isLast: false,
            isDarkMode: isDarkMode,
          ),
          _buildTimelineStep(
            stepNumber: '3',
            title: 'الخطوة 3: نزول 15 ج.م فوراً بمحفظتك',
            description:
                'يتم إضافة 15 ج.م مباشرة إلى رصيد محفظتك مع إشعار فوري بمجرد أن يقوم صديقك بإنشاء حسابه بنجاح!',
            icon: Icons.wallet_outlined,
            isLast: true,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required bool isLast,
    required bool isDarkMode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: 18.sp),
              ),
            ),
            if (!isLast)
              Container(
                width: 2.w,
                height: 48.h,
                color: AppColors.primary.withOpacity(0.2),
              ),
          ],
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF333333),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF888888),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsGrid(ReferralStatsModel statistics, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات إحالاتك',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF333333),
          ),
        ),
        SizedBox(height: 12.h),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 1.22,
          children: [
            _buildStatCard(
              title: 'إجمالي المكافآت',
              value: '${statistics.totalRewards.toStringAsFixed(2)} ج.م',
              icon: FontAwesomeIcons.wallet,
              color: Colors.green,
              isDarkMode: isDarkMode,
            ),
            _buildStatCard(
              title: 'الأصدقاء المدعوون',
              value: '${statistics.invitedCount} صديق',
              icon: FontAwesomeIcons.userGroup,
              color: AppColors.primary,
              isDarkMode: isDarkMode,
            ),
            _buildStatCard(
              title: 'التسجيل الناجح',
              value: '${statistics.successCount} دعوات',
              icon: FontAwesomeIcons.userCheck,
              color: Colors.teal,
              isDarkMode: isDarkMode,
            ),
            _buildStatCard(
              title: 'دعوات معلقة',
              value: '${statistics.pendingCount} معلقين',
              icon: FontAwesomeIcons.hourglassHalf,
              color: Colors.orange,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required FaIconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDarkMode ? Colors.transparent : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, color: color, size: 16.sp),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: isDarkMode ? Colors.white : const Color(0xFF333333),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFF888888),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvitedFriendsSection(
    List<ReferralFriendModel> referrals,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'سجل الأصدقاء المدعوين',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF333333),
              ),
            ),
            if (referrals.isNotEmpty)
              Text(
                '(${referrals.length} دعوات)',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF888888),
                ),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        referrals.isEmpty
            ? _buildEmptyState(isDarkMode)
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: referrals.length,
                separatorBuilder: (context, index) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final item = referrals[index];
                  return _buildFriendItem(item, isDarkMode);
                },
              ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDarkMode ? Colors.transparent : Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 54.sp,
            color: const Color(0xFFBDBDBD),
          ),
          SizedBox(height: 14.h),
          Text(
            'لم تقم بدعوة أي صديق بعد',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF333333),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'انسخ كود الدعوة الآن وابدأ بمشاركته مع أصدقائك لربح أول مكافأة!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: const Color(0xFF888888)),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(ReferralFriendModel item, bool isDarkMode) {
    Color statusColor;
    String statusText;

    switch (item.status) {
      case 'rewarded':
        statusColor = Colors.green;
        statusText = 'تم احتساب المكافأة';
        break;
      case 'completed':
        statusColor = AppColors.primary;
        statusText = 'مكتملة';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusText = 'بانتظار التسجيل والطلب';
        break;
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDarkMode ? Colors.transparent : Colors.grey.shade100,
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22.r,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  safeFirstChar(item.name, '?'),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.isNotEmpty ? item.name : 'مستخدم جيبلي',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF333333),
                  ),
                ),
                if (item.date != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'تاريخ التسجيل: ${formatDate(item.date)}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF888888),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              if (item.amount > 0) ...[
                SizedBox(height: 4.h),
                Text(
                  '+${item.amount.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(bool isDarkMode) {
    return Shimmer.fromColors(
      baseColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade300,
      highlightColor: isDarkMode
          ? const Color(0xFF3D3D3D)
          : Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 200.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              width: double.infinity,
              height: 120.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              height: 150.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            SizedBox(height: 20.h),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 1.22,
              children: List.generate(
                4,
                (index) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 60.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'حدث خطأ ما',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<ReferralCubit>().loadReferralSummary(),
              icon: Icon(
                Icons.refresh_rounded,
                size: 18.sp,
                color: Colors.white,
              ),
              label: Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsConvertCard(
    ReferralSummaryModel summary,
    bool isDarkMode,
  ) {
    final points = summary.points;
    final double cashValue = points * 1.0; // 1 point = 1.00 ج.م
    final bool canConvert = points >= 1000;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDarkMode ? Colors.transparent : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
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
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.stars_rounded,
                  color: AppColors.primary,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'نقاط الدعوة والمكافآت',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF333333),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رصيد النقاط الحالي',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF888888),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$points نقطة',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'القيمة التقريبية بالرصيد',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF888888),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${cashValue.toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          const Divider(),
          SizedBox(height: 12.h),
          Text(
            'كل 1000 نقطة تساوي 1000 ج.م رصيد محفظة. يمكنك تحويل نقاطك بمجرد وصولها إلى 1000 نقطة أو أكثر.',
            style: TextStyle(
              fontSize: 11.sp,
              color: const Color(0xFF999999),
              height: 1.4,
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 45.h,
            child: ElevatedButton(
              onPressed: canConvert
                  ? () => context.read<ReferralCubit>().convertPoints()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canConvert
                    ? AppColors.primary
                    : Colors.grey.shade300,
                disabledBackgroundColor: isDarkMode
                    ? Colors.white10
                    : Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              child: Text(
                canConvert
                    ? 'تحويل النقاط إلى رصيد المحفظة'
                    : 'تحتاج إلى 1000 نقطة على الأقل للتحويل',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: canConvert ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpinContainer extends StatefulWidget {
  final Widget child;
  const SpinContainer({super.key, required this.child});

  @override
  State<SpinContainer> createState() => _SpinContainerState();
}

class _SpinContainerState extends State<SpinContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double angle = _controller.value * 2.0 * 3.14159265;
        final double offset = (1 - (_controller.value - 0.5).abs() * 2) * 8;
        return Transform.translate(
          offset: Offset(0, -offset),
          child: Transform.rotate(
            angle: angle * 0.05 - 0.1,
            child: widget.child,
          ),
        );
      },
    );
  }
}
