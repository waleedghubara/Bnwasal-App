// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/features/wallet/presentation/pages/withdraw_screen.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/entities/wallet_entity.dart';
import '../cubit/wallet_cubit.dart';
import '../pages/deposit_screen.dart';

/// Merchant Balance Card (Original UI)
class BalanceCard extends StatelessWidget {
  final WalletEntity wallet;

  const BalanceCard({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'رصيدك الحالي',
            style: TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                wallet.currentBalance.toStringAsFixed(2),
                style: TextStyle(
                  color: const Color(0xFF204CB3),
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8.w),
              SvgPicture.asset(AppAssets.walleth2, width: 48, height: 48),
            ],
          ),
          SizedBox(height: 16.h),

          // Dotted Divider Placeholder
          Row(
            children: List.generate(
              30,
              (index) => Expanded(
                child: Container(
                  height: 1,
                  color: index % 2 == 0
                      ? Colors.transparent
                      : const Color(0xFFE0E0E0),
                ),
              ),
            ),
          ),

          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'الرصيد المعلق',
                        style: TextStyle(
                          color: const Color(0xFF9E9E9E),
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${wallet.pendingBalance.toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5FF),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'الرصيد المتاح',
                        style: TextStyle(
                          color: const Color(0xFF9E9E9E),
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${wallet.availableBalance.toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                          color: const Color(0xFF204CB3),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DepositScreen(),
                      ),
                    );
                    if (context.mounted) {
                      context.read<WalletCubit>().loadWallet();
                    }
                  },
                  icon: Icon(
                    Icons.add,
                    color: const Color(0xFF204CB3),
                    size: 18.sp,
                  ),
                  label: Text(
                    'ايداع',
                    style: AppTypography.h4.copyWith(
                      color: const Color(0xFF204CB3),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final walletCubit = context.read<WalletCubit>();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlocProvider.value(
                          value: walletCubit,
                          child: const WithdrawScreen(),
                        ),
                      ),
                    );
                    if (context.mounted) {
                      walletCubit.loadWallet();
                    }
                  },
                  icon: Icon(
                    Icons.call_made,
                    color: const Color(0xFF204CB3),
                    size: 18.sp,
                  ),
                  label: Text(
                    'سحب',
                    style: AppTypography.h4.copyWith(
                      color: const Color(0xFF204CB3),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Captain Balance Card (Professional White Card Matching User Request)
class CaptainBalanceCard extends StatefulWidget {
  final WalletEntity wallet;

  const CaptainBalanceCard({super.key, required this.wallet});

  @override
  State<CaptainBalanceCard> createState() => _CaptainBalanceCardState();
}

class _CaptainBalanceCardState extends State<CaptainBalanceCard> {
  bool _isBalanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final totalBal = widget.wallet.totalBalance > 0
        ? widget.wallet.totalBalance
        : (widget.wallet.captainEarnings + widget.wallet.duePlatformFees > 0
              ? widget.wallet.captainEarnings + widget.wallet.duePlatformFees
              : widget.wallet.currentBalance);

    final earnings = widget.wallet.captainEarnings;
    final platformFees = widget.wallet.duePlatformFees;

    return Column(
      children: [
        // ─── 1. Main Professional White Balance Card ───────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'إجمالي الرصيد',
                    style: GoogleFonts.tajawal(
                      color: Colors.black87,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isBalanceVisible = !_isBalanceVisible;
                      });
                    },
                    child: FaIcon(
                      _isBalanceVisible
                          ? FontAwesomeIcons.eye
                          : FontAwesomeIcons.eyeSlash,
                      color: AppColors.primary,
                      size: 17.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AppAssets.walleth2,
                    width: 46.w,
                    height: 46.w,
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    _isBalanceVisible ? totalBal.toStringAsFixed(2) : '*****',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFF204CB3),
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'ج.م',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFF204CB3),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade500,
                    size: 14.sp,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'إجمالي الرصيد = أرباحك + الرصيد المستحق لرسوم المنصة',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.tajawal(
                      color: Colors.black,

                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Dotted Line Divider
              Row(
                children: List.generate(
                  30,
                  (index) => Expanded(
                    child: Container(
                      height: 1,
                      color: index % 2 == 0
                          ? Colors.transparent
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // ─── 2. Side-by-Side Cards (أرباحك + الرصيد المستحق لرسوم المنصة)
              Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      // Left Card: أرباحك (Green Accent)
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: const Color(0xFFC8E6C9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'أرباحك',
                                    style: GoogleFonts.tajawal(
                                      color: const Color(0xFF2E7D32),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: const Color(0xFF2E7D32),
                                    size: 16.sp,
                                  ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                children: [
                                  Text(
                                    _isBalanceVisible
                                        ? earnings.toStringAsFixed(2)
                                        : '*****',
                                    style: GoogleFonts.tajawal(
                                      color: const Color(0xFF1B5E20),
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'ج.م',
                                    style: GoogleFonts.tajawal(
                                      color: const Color(0xFF2E7D32),
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'غير قابلة للسحب مباشرة. يتم خصم عمولة المنصة تلقائياً.',
                                style: GoogleFonts.tajawal(
                                  color: Colors.black,
                                  fontSize: 9.sp,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(width: 10.w),

                      // Right Card: الرصيد المستحق لرسوم المنصة (Orange Accent)
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: const Color(0xFFFFE0B2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'رسوم المنصة المستحقة',
                                      style: GoogleFonts.tajawal(
                                        color: const Color(0xFFE65100),
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    color: const Color(0xFFE65100),
                                    size: 16.sp,
                                  ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                children: [
                                  Text(
                                    _isBalanceVisible
                                        ? platformFees.toStringAsFixed(2)
                                        : '*****',
                                    style: GoogleFonts.tajawal(
                                      color: const Color(0xFFE65100),
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'ج.م',
                                    style: GoogleFonts.tajawal(
                                      color: const Color(0xFFE65100),
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'يمكنك سحب المتبقي بعد تغطية عمولة المنصة بالكامل.',
                                style: GoogleFonts.tajawal(
                                  color: Colors.black,
                                  fontSize: 9.sp,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 14.h),

        // ─── 3. Shield Notice Banner ─────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFFD0E1FD)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: const BoxDecoration(
                  color: Color(0xFFD0E1FD),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: const Color(0xFF204CB3),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'يتم خصم رسوم المنصة تلقائياً من محفظتك عند تنفيذ كل طلب أو شحنة. تأكد من شحن الرصيد كافي لتجنب إيقاف الطلبات والحظر.',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFF204CB3),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // ─── 4. Financial Operations Action Buttons ─────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'العمليات المالية',
              style: GoogleFonts.tajawal(
                color: Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                // Right Action Button: شحن رصيد رسوم المنصة
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DepositScreen(),
                        ),
                      );
                      if (context.mounted) {
                        context.read<WalletCubit>().loadWallet();
                      }
                    },
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      padding: EdgeInsets.all(9.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline_rounded,
                            color: const Color(0xFFE65100),
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'شحن رصيد رسوم المنصة',
                                  style: GoogleFonts.tajawal(
                                    color: const Color(0xFFE65100),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  'أضف رصيد لرسوم المنصة لتجنب الإيقاف.',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.black,
                                    fontSize: 9.sp,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 10.w),

                // Left Action Button: سحب رصيدك
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      if (widget.wallet.availableBalance <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'لا يوجد رصيد متاح للسحب حالياً. يرجى تغطية رسوم المنصة أولاً.',
                              style: GoogleFonts.tajawal(),
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final walletCubit = context.read<WalletCubit>();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlocProvider.value(
                            value: walletCubit,
                            child: const WithdrawScreen(),
                          ),
                        ),
                      );
                      if (context.mounted) {
                        walletCubit.loadWallet();
                      }
                    },
                    borderRadius: BorderRadius.circular(9.r),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.downloading,
                            color: const Color(0xFF2E7D32),
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سحب رصيدك',
                                  style: GoogleFonts.tajawal(
                                    color: const Color(0xFF2E7D32),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'اسحب المتبقي بعد تغطية العمولة بالكامل.',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.black,
                                    fontSize: 9.sp,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
