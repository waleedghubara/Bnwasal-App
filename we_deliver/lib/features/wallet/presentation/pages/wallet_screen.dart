// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/wallet_entity.dart';
import '../cubit/wallet_cubit.dart';
import '../cubit/wallet_state.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_item.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<WalletCubit>()..loadWallet(),
      child: const _WalletScreenBody(),
    );
  }
}

class _WalletScreenBody extends StatefulWidget {
  const _WalletScreenBody();

  @override
  State<_WalletScreenBody> createState() => _WalletScreenBodyState();
}

class _WalletScreenBodyState extends State<_WalletScreenBody> {
  bool _isDelivery = false;
  String _selectedFilter = 'all'; // 'all', 'success', 'pending', 'failed' (Merchant) or 'orders', 'deposits', 'withdrawals', 'platform_fees' (Captain)

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDelivery = prefs.getBool('isDelivery') ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      builder: (context, state) {
        if (state is WalletLoading || state is WalletInitial) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF204CB3)),
            ),
          );
        }

        if (state is WalletError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'حدث خطأ في تحميل المحفظة',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: GoogleFonts.tajawal(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.read<WalletCubit>().loadWallet(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF204CB3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        WalletEntity wallet;
        if (state is WalletLoaded) {
          wallet = state.wallet;
        } else {
          wallet = const WalletEntity(
            currentBalance: 0,
            availableBalance: 0,
            pendingBalance: 0,
            recentTransactions: [],
          );
        }

        if (_isDelivery) {
          return _buildCaptainWalletView(context, wallet);
        } else {
          return _buildMerchantWalletView(context, wallet);
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MERCHANT WALLET VIEW (ORIGINAL CLEAN DESIGN)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMerchantWalletView(BuildContext context, WalletEntity wallet) {
    final allTx = wallet.recentTransactions;
    final filteredTx = _selectedFilter == 'all'
        ? allTx
        : allTx.where((t) => t.status == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: const Color(0xFF204CB3),
        onRefresh: () => context.read<WalletCubit>().loadWallet(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildMerchantHeaderAndCard(context, wallet),
              _buildMerchantTransactionsSection(filteredTx),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMerchantHeaderAndCard(BuildContext context, WalletEntity wallet) {
    return Stack(
      children: [
        // Blue Background Header
        Container(
          height: 260.h,
          width: double.infinity,
          decoration: const BoxDecoration(color: Color(0xFF204CB3)),
          child: Stack(
            children: [
              Positioned(
                top: -50.h,
                right: -50.w,
                child: Container(
                  width: 200.w,
                  height: 200.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                top: 100.h,
                left: -30.w,
                child: Container(
                  width: 150.w,
                  height: 150.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'المحفظة',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // White Card
        Padding(
          padding: EdgeInsets.only(top: 110.h, left: 20.w, right: 20.w),
          child: BalanceCard(wallet: wallet),
        ),
      ],
    );
  }

  Widget _buildMerchantFiltersBar() {
    final filters = [
      {'id': 'all', 'label': 'الكل'},
      {'id': 'success', 'label': 'ناجحة'},
      {'id': 'pending', 'label': 'قيد المراجعة'},
      {'id': 'failed', 'label': 'ملغية'},
    ];

    return Container(
      height: 38.h,
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['id'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter['id']!;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF204CB3)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected ? const Color(0xFF204CB3) : const Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  filter['label']!,
                  style: GoogleFonts.tajawal(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMerchantTransactionsSection(List<TransactionEntity> transactions) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.h),
          Text(
            'المعاملات المالية',
            style: GoogleFonts.tajawal(
              color: Colors.black,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          _buildMerchantFiltersBar(),
          if (transactions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48.sp,
                      color: Colors.grey.shade300,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'لا توجد معاملات تندرج تحت هذا الفلتر',
                      style: GoogleFonts.tajawal(
                        color: Colors.grey.shade500,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                return TransactionItem(transaction: transactions[index]);
              },
            ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CAPTAIN WALLET VIEW (CLEAN ORIGINAL HEADER & MOCKUP DATA)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCaptainWalletView(BuildContext context, WalletEntity wallet) {
    final allTx = wallet.recentTransactions;
    final filteredTx = _filterCaptainTransactions(allTx, _selectedFilter);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: const Color(0xFF204CB3),
        onRefresh: () => context.read<WalletCubit>().loadWallet(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCaptainHeaderAndCard(context, wallet),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20.h),
                    _buildCaptainFilterTabs(),
                    SizedBox(height: 16.h),
                    _buildCaptainTransactionsHeader(),
                    SizedBox(height: 10.h),
                    _buildCaptainTransactionsList(filteredTx),
                    SizedBox(height: 20.h),
                    _buildWhyPlatformFeesCard(),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptainHeaderAndCard(BuildContext context, WalletEntity wallet) {
    return Stack(
      children: [
        // Blue Background Header (Original Clean Blue Banner)
        Container(
          height: 260.h,
          width: double.infinity,
          decoration: const BoxDecoration(color: Color(0xFF204CB3)),
          child: Stack(
            children: [
              Positioned(
                top: -50.h,
                right: -50.w,
                child: Container(
                  width: 200.w,
                  height: 200.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                top: 100.h,
                left: -30.w,
                child: Container(
                  width: 150.w,
                  height: 150.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'المحفظة',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Overlapping Captain Balance Card
        Padding(
          padding: EdgeInsets.only(top: 110.h, left: 16.w, right: 16.w),
          child: CaptainBalanceCard(wallet: wallet),
        ),
      ],
    );
  }

  List<TransactionEntity> _filterCaptainTransactions(
      List<TransactionEntity> list, String filter) {
    if (filter == 'all') return list;

    return list.where((t) {
      final cat = t.category ?? '';
      final title = t.title;

      if (filter == 'orders') {
        return cat == 'orders' ||
            title.contains('طلب') ||
            title.contains('شحنة') ||
            title.contains('توصيل');
      } else if (filter == 'deposits') {
        return cat == 'deposits' ||
            title.contains('شحن') ||
            title.contains('إيداع');
      } else if (filter == 'withdrawals') {
        return cat == 'withdrawals' ||
            (t.type == 'withdraw' && !title.contains('منصة'));
      } else if (filter == 'platform_fees') {
        return cat == 'platform_fees' ||
            title.contains('منصة') ||
            title.contains('عمولة');
      }
      return true;
    }).toList();
  }

  Widget _buildCaptainFilterTabs() {
    final filters = [
      {'id': 'all', 'label': 'الكل'},
      {'id': 'orders', 'label': 'طلبات'},
      {'id': 'deposits', 'label': 'شحن'},
      {'id': 'withdrawals', 'label': 'سحب'},
      {'id': 'platform_fees', 'label': 'رسوم المنصة'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...filters.map((filter) {
            final isSelected = _selectedFilter == filter['id'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter['id']!;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(left: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF204CB3)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF204CB3)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  filter['label']!,
                  style: GoogleFonts.tajawal(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, size: 16.sp, color: Colors.grey.shade700),
                SizedBox(width: 4.w),
                Text(
                  'فلترة',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey.shade700,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptainTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'آخر المعاملات',
          style: GoogleFonts.tajawal(
            color: Colors.black87,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            'عرض الكل >',
            style: GoogleFonts.tajawal(
              color: const Color(0xFF204CB3),
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptainTransactionsList(List<TransactionEntity> transactions) {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 36.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 44.sp,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 10.h),
            Text(
              'لا توجد معاملات تندرج تحت هذا الفلتر',
              style: GoogleFonts.tajawal(
                color: Colors.grey.shade500,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        return TransactionItem(transaction: transactions[index]);
      },
    );
  }

  Widget _buildWhyPlatformFeesCard() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFFFF59D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF59D),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: const Color(0xFFF57F17),
              size: 20.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لماذا يتم خصم رسوم المنصة ؟',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFFF57F17),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'لمساعدة المنصة في استمرارية الخدمة وتطويرها وتقديم تجربة أفضل لك.',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey.shade700,
                    fontSize: 11.sp,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
