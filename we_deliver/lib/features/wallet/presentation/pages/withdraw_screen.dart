// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../cubit/wallet_cubit.dart';
import '../cubit/wallet_state.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/wallet_entity.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankAccountNumberController =
      TextEditingController();

  String _paymentMethod = 'wallet'; // 'wallet' or 'bank'
  String _walletProvider =
      'Vodafone Cash'; // Vodafone Cash, Orange Cash, Etisalat Cash, WE Pay

  Timer? _countdownTimer;
  Duration _remainingDuration = Duration.zero;
  bool _isTimerActive = false;

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime createdAt) {
    _countdownTimer?.cancel();
    final elapsed = DateTime.now().difference(createdAt);
    final limit = const Duration(minutes: 15);
    final remaining = limit - elapsed;

    if (remaining <= Duration.zero) {
      setState(() {
        _remainingDuration = Duration.zero;
        _isTimerActive = true;
      });
      return;
    }

    setState(() {
      _remainingDuration = remaining;
      _isTimerActive = true;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingDuration.inSeconds > 0) {
            _remainingDuration =
                _remainingDuration - const Duration(seconds: 1);
            if (_remainingDuration.inSeconds % 10 == 0) {
              context.read<WalletCubit>().pollWallet();
            }
          } else {
            _countdownTimer?.cancel();
            _isTimerActive = true;
          }
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletCubit, WalletState>(
      listener: (context, state) {
        if (state is WithdrawSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم تقديم طلب السحب بنجاح وهو قيد المراجعة',
                style: GoogleFonts.tajawal(),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        } else if (state is WithdrawError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.tajawal()),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        } else if (state is WalletLoaded) {
          final wallet = state.wallet;
          final pending = wallet.pendingWithdrawal;
          if (_isTimerActive && pending == null) {
            TransactionEntity? recentTx;
            for (final tx in wallet.recentTransactions) {
              if (tx.type == 'withdraw') {
                recentTx = tx;
                break;
              }
            }
            if (recentTx != null) {
              if (recentTx.status == 'success') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تمت الموافقة على طلب السحب بقيمة ${recentTx.amount} ج.م بنجاح 🎉',
                      style: GoogleFonts.tajawal(),
                    ),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              } else if (recentTx.status == 'failed') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم رفض طلب السحب بقيمة ${recentTx.amount} ج.م وإعادة المبلغ لمحفظتك ❌',
                      style: GoogleFonts.tajawal(),
                    ),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            }
          }
        }
      },
      builder: (context, state) {
        WalletEntity? wallet;
        TransactionEntity? pendingWithdrawal;

        if (state is WalletLoaded) {
          wallet = state.wallet;
          pendingWithdrawal = wallet.pendingWithdrawal;
        }

        // If there is a pending withdrawal request, check or start countdown
        if (pendingWithdrawal != null) {
          final createdTime = pendingWithdrawal.createdAt != null
              ? DateTime.parse(pendingWithdrawal.createdAt!).toLocal()
              : DateTime.now();
          if (!_isTimerActive) {
            _isTimerActive = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _startTimer(createdTime);
              }
            });
          }
          return _buildWaitingScreen(pendingWithdrawal);
        }

        // If timer was active but pendingWithdrawal is now null, we should stop it
        if (_isTimerActive && pendingWithdrawal == null) {
          _countdownTimer?.cancel();
          _isTimerActive = false;
        }

        final double balance = wallet?.availableBalance ?? 0.0;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'سحب الرصيد',
              style: GoogleFonts.tajawal(
                color: Colors.black,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Colors.black,
                size: 20.sp,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            automaticallyImplyLeading: false,
          ),
          body: state is WithdrawLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF204CB3)),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'الرصيد المتاح للسحب',
                                style: GoogleFonts.tajawal(
                                  color: const Color(0xFF9E9E9E),
                                  fontSize: 14.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                '${balance.toStringAsFixed(2)} ج.م',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 30.h),
                        Text(
                          'المبلغ المراد سحبه',
                          style: GoogleFonts.tajawal(
                            color: Colors.black,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        CustomTextField(
                          hintText: 'المبلغ بالجنيه المصري',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'يرجى إدخال المبلغ';
                            }
                            final val = double.tryParse(v);
                            if (val == null || val <= 0) {
                              return 'المبلغ غير صالح';
                            }
                            if (val < 5) {
                              return 'الحد الأدنى للسحب هو 5 جنيهات';
                            }
                            if (val > balance) {
                              return 'المبلغ يتجاوز رصيد محفظتك المتاح';
                            }
                            return null;
                          },
                          rightWidget: Padding(
                            padding: EdgeInsets.only(right: 6.w),
                            child: FaIcon(
                              FontAwesomeIcons.coins,
                              color: const Color(0xFF204CB3),
                              size: 20.sp,
                            ),
                          ),
                          leftWidget: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Text(
                              'ج.م',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          controller: _amountController,
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          'طريقة السحب',
                          style: GoogleFonts.tajawal(
                            color: Colors.black,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          initialValue: _paymentMethod,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 16.h,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: Color(0xFFF0F0F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: Color(0xFFF0F0F0),
                              ),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'wallet',
                              child: Text(
                                'محفظة إلكترونية (فودافون كاش، إلخ)',
                                style: AppTypography.h5,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'bank',
                              child: Text('حساب بنكي', style: AppTypography.h5),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _paymentMethod = val;
                              });
                            }
                          },
                        ),
                        SizedBox(height: 20.h),
                        if (_paymentMethod == 'wallet') ...[
                          Text(
                            'مزود المحفظة الإلكترونية',
                            style: GoogleFonts.tajawal(
                              color: Colors.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          DropdownButtonFormField<String>(
                            initialValue: _walletProvider,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFFAFAFA),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 16.h,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(
                                  color: Color(0xFFF0F0F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(
                                  color: Color(0xFFF0F0F0),
                                ),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'Vodafone Cash',
                                child: Text(
                                  'فودافون كاش (Vodafone Cash)',
                                  style: AppTypography.h5,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Orange Cash',
                                child: Text(
                                  'أورنج كاش (Orange Cash)',
                                  style: AppTypography.h5,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Etisalat Cash',
                                child: Text(
                                  'اتصالات كاش (Etisalat Cash)',
                                  style: AppTypography.h5,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'WE Pay',
                                child: Text(
                                  'وي باي (WE Pay)',
                                  style: AppTypography.h5,
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _walletProvider = val;
                                });
                              }
                            },
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            'رقم الهاتف المسجل بالمحفظة',
                            style: GoogleFonts.tajawal(
                              color: Colors.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          CustomTextField(
                            hintText: 'مثال: 01012345678',
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (_paymentMethod == 'wallet') {
                                if (v == null || v.trim().isEmpty) {
                                  return 'يرجى إدخال رقم المحفظة';
                                }
                                if (v.trim().length != 11 ||
                                    !RegExp(r'^[0-9]+$').hasMatch(v.trim())) {
                                  return 'رقم الهاتف غير صالح (يجب أن يكون 11 رقماً)';
                                }
                              }
                              return null;
                            },
                            rightWidget: Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: FaIcon(
                                FontAwesomeIcons.phone,
                                color: const Color(0xFF204CB3),
                                size: 20.sp,
                              ),
                            ),
                            controller: _phoneController,
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            'الاسم المسجل في المحفظة',
                            style: GoogleFonts.tajawal(
                              color: Colors.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          CustomTextField(
                            hintText: 'الاسم بالكامل',
                            validator: (v) {
                              if (_paymentMethod == 'wallet') {
                                if (v == null || v.trim().isEmpty) {
                                  return 'يرجى إدخال الاسم';
                                }
                              }
                              return null;
                            },
                            rightWidget: Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: FaIcon(
                                FontAwesomeIcons.user,
                                color: const Color(0xFF204CB3),
                                size: 20.sp,
                              ),
                            ),
                            controller: _nameController,
                          ),
                        ] else ...[
                          Text(
                            'اسم البنك',
                            style: GoogleFonts.tajawal(
                              color: Colors.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          CustomTextField(
                            hintText: 'مثال: البنك الأهلي المصري، CIB',
                            validator: (v) {
                              if (_paymentMethod == 'bank') {
                                if (v == null || v.trim().isEmpty) {
                                  return 'يرجى إدخال اسم البنك';
                                }
                              }
                              return null;
                            },
                            rightWidget: Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: FaIcon(
                                FontAwesomeIcons.buildingColumns,
                                color: const Color(0xFF204CB3),
                                size: 20.sp,
                              ),
                            ),
                            controller: _bankNameController,
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            'رقم الحساب البنكي / IBAN',
                            style: GoogleFonts.tajawal(
                              color: Colors.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          CustomTextField(
                            hintText: 'رقم الحساب أو الآيبان بالكامل',
                            validator: (v) {
                              if (_paymentMethod == 'bank') {
                                if (v == null || v.trim().isEmpty) {
                                  return 'يرجى إدخال رقم الحساب البنكي';
                                }
                              }
                              return null;
                            },
                            rightWidget: Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: FaIcon(
                                FontAwesomeIcons.moneyCheck,
                                color: const Color(0xFF204CB3),
                                size: 20.sp,
                              ),
                            ),
                            controller: _bankAccountNumberController,
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            'الاسم المسجل في البنك',
                            style: GoogleFonts.tajawal(
                              color: Colors.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          CustomTextField(
                            hintText:
                                'الاسم بالكامل كما هو مسجل في حسابك البنكي',
                            validator: (v) {
                              if (_paymentMethod == 'bank') {
                                if (v == null || v.trim().isEmpty) {
                                  return 'يرجى إدخال الاسم المسجل بالبنك';
                                }
                              }
                              return null;
                            },
                            rightWidget: Padding(
                              padding: EdgeInsets.only(right: 12.w),
                              child: FaIcon(
                                FontAwesomeIcons.signature,
                                color: const Color(0xFF204CB3),
                                size: 20.sp,
                              ),
                            ),
                            controller: _nameController,
                          ),
                        ],
                        SizedBox(height: 40.h),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                final amount = double.parse(
                                  _amountController.text,
                                );
                                context.read<WalletCubit>().withdrawMoney(
                                  amount: amount,
                                  paymentMethod: _paymentMethod,
                                  name: _nameController.text.trim(),
                                  phone: _paymentMethod == 'wallet'
                                      ? _phoneController.text.trim()
                                      : null,
                                  walletProvider: _paymentMethod == 'wallet'
                                      ? _walletProvider
                                      : null,
                                  bankName: _paymentMethod == 'bank'
                                      ? _bankNameController.text.trim()
                                      : null,
                                  bankAccountNumber: _paymentMethod == 'bank'
                                      ? _bankAccountNumberController.text.trim()
                                      : null,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF204CB3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'تقديم طلب السحب',
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildWaitingScreen(TransactionEntity pending) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B29),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 28,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140.w,
                      height: 140.w,
                      child: CircularProgressIndicator(
                        value: _isTimerActive
                            ? (_remainingDuration.inSeconds / 900)
                            : 0,
                        strokeWidth: 6,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(_remainingDuration),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'متبقي',
                          style: GoogleFonts.tajawal(
                            color: Colors.white70,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40.h),
              Text(
                'طلب السحب قيد المراجعة',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  'يتم مراجعة ومعالجة طلب السحب الخاص بك من قبل الإدارة. سيتم تحويل المبلغ خلال 15 دقيقة كحد أقصى.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    color: Colors.white70,
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 40.h),
              Card(
                color: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المبلغ المطلوب سحبه',
                            style: GoogleFonts.tajawal(color: Colors.white60),
                          ),
                          Text(
                            '${pending.amount.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'طريقة التحويل',
                            style: GoogleFonts.tajawal(color: Colors.white60),
                          ),
                          Text(
                            pending.paymentMethod == 'wallet'
                                ? 'محفظة إلكترونية'
                                : 'حساب بنكي',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'تاريخ الطلب',
                            style: GoogleFonts.tajawal(color: Colors.white60),
                          ),
                          Text(
                            pending.date,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<WalletCubit>().loadWallet();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  label: Text(
                    'تحديث الحالة',
                    style: GoogleFonts.tajawal(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
