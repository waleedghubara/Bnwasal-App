import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:admin_bnwasal/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';

class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Summary Metrics
  double _totalDeposits = 0;
  double _totalDeliveryFees = 0;
  double _totalWithdrawals = 0;
  double _pendingWithdrawals = 0;
  double _totalUserBalances = 0;
  bool _isSummaryLoading = false;

  // Transactions State
  final List<dynamic> _transactions = [];
  bool _isTxLoading = false;
  String? _txError;
  int _txPage = 1;
  int _txTotalPages = 1;
  String _txTypeFilter = ''; // '' (all), 'deposit', 'withdraw'
  String _txStatusFilter = ''; // '' (all), 'success', 'pending', 'failed'
  final TextEditingController _txSearchController = TextEditingController();

  // Users Balances State
  final List<dynamic> _users = [];
  bool _isUsersLoading = false;
  String? _usersError;
  int _usersPage = 1;
  int _usersTotalPages = 1;
  final TextEditingController _usersSearchController = TextEditingController();

  // All Users (Add Balance) State
  final List<dynamic> _allUsers = [];
  bool _isAllUsersLoading = false;
  String? _allUsersError;
  int _allUsersPage = 1;
  int _allUsersTotalPages = 1;
  final TextEditingController _allUsersSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSummary();
    _loadTransactions();
    _loadUsers();
    _loadAllUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _txSearchController.dispose();
    _usersSearchController.dispose();
    _allUsersSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isSummaryLoading = true;
    });
    try {
      final dioConsumer = sl<DioConsumer>();
      final response = await dioConsumer.get(EndPoint.adminWalletSummary);
      if (response != null && response['status'] == 1) {
        final data = response['data'];
        setState(() {
          _totalDeposits =
              double.tryParse(data['totalDeposits']?.toString() ?? '0') ?? 0;
          _totalDeliveryFees =
              double.tryParse(data['totalDeliveryFees']?.toString() ?? '0') ?? 0;
          _totalWithdrawals =
              double.tryParse(data['totalWithdrawals']?.toString() ?? '0') ?? 0;
          _pendingWithdrawals =
              double.tryParse(data['pendingWithdrawals']?.toString() ?? '0') ??
              0;
          _totalUserBalances =
              double.tryParse(data['totalUserBalances']?.toString() ?? '0') ??
              0;
        });
      }
    } catch (e) {
      debugPrint('Error loading wallet summary: $e');
    } finally {
      setState(() {
        _isSummaryLoading = false;
      });
    }
  }

  Future<void> _loadTransactions({bool loadMore = false}) async {
    if (_isTxLoading) return;
    setState(() {
      _isTxLoading = true;
      if (!loadMore) {
        _txPage = 1;
        _transactions.clear();
        _txError = null;
      }
    });

    try {
      final dioConsumer = sl<DioConsumer>();
      final queryParams = {
        'page': _txPage,
        'limit': 20,
        if (_txTypeFilter.isNotEmpty) 'type': _txTypeFilter,
        if (_txStatusFilter.isNotEmpty) 'status': _txStatusFilter,
        if (_txSearchController.text.trim().isNotEmpty)
          'search': _txSearchController.text.trim(),
      };

      final response = await dioConsumer.get(
        EndPoint.adminWalletTransactions,
        queryParameters: queryParams,
      );

      if (response != null && response['status'] == 1) {
        final data = response['data'];
        final list = data['transactions'] as List;
        final pagination = data['pagination'];

        setState(() {
          _transactions.addAll(list);
          _txTotalPages =
              int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
        });
      } else {
        setState(() {
          _txError = response?['message']?.toString() ?? 'فشل تحميل العمليات';
        });
      }
    } catch (e) {
      setState(() {
        _txError = 'حدث خطأ أثناء تحميل البيانات: $e';
      });
    } finally {
      setState(() {
        _isTxLoading = false;
      });
    }
  }

  Future<void> _loadUsers({bool loadMore = false}) async {
    if (_isUsersLoading) return;
    setState(() {
      _isUsersLoading = true;
      if (!loadMore) {
        _usersPage = 1;
        _users.clear();
        _usersError = null;
      }
    });

    try {
      final dioConsumer = sl<DioConsumer>();
      final queryParams = {
        'page': _usersPage,
        'limit': 20,
        if (_usersSearchController.text.trim().isNotEmpty)
          'search': _usersSearchController.text.trim(),
      };

      final response = await dioConsumer.get(
        EndPoint.adminWalletUsers,
        queryParameters: queryParams,
      );

      if (response != null && response['status'] == 1) {
        final data = response['data'];
        final list = data['users'] as List;
        final pagination = data['pagination'];

        setState(() {
          _users.addAll(list);
          _usersTotalPages =
              int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
        });
      } else {
        setState(() {
          _usersError =
              response?['message']?.toString() ?? 'فشل تحميل قائمة المستخدمين';
        });
      }
    } catch (e) {
      setState(() {
        _usersError = 'حدث خطأ: $e';
      });
    } finally {
      setState(() {
        _isUsersLoading = false;
      });
    }
  }

  Future<void> _loadAllUsers({bool loadMore = false}) async {
    if (_isAllUsersLoading) return;
    setState(() {
      _isAllUsersLoading = true;
      if (!loadMore) {
        _allUsersPage = 1;
        _allUsers.clear();
        _allUsersError = null;
      }
    });

    try {
      final dioConsumer = sl<DioConsumer>();
      final queryParams = {
        'page': _allUsersPage,
        'limit': 20,
        'showAll': 'true',
        if (_allUsersSearchController.text.trim().isNotEmpty)
          'search': _allUsersSearchController.text.trim(),
      };

      final response = await dioConsumer.get(
        EndPoint.adminWalletUsers,
        queryParameters: queryParams,
      );

      if (response != null && response['status'] == 1) {
        final data = response['data'];
        final list = data['users'] as List;
        final pagination = data['pagination'];

        setState(() {
          _allUsers.addAll(list);
          _allUsersTotalPages =
              int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
        });
      } else {
        setState(() {
          _allUsersError =
              response?['message']?.toString() ?? 'فشل تحميل قائمة المستخدمين';
        });
      }
    } catch (e) {
      setState(() {
        _allUsersError = 'حدث خطأ: $e';
      });
    } finally {
      setState(() {
        _isAllUsersLoading = false;
      });
    }
  }

  void _refreshAll() {
    _loadSummary();
    _loadTransactions();
    _loadUsers();
    _loadAllUsers();
  }

  String _getTransactionTypeLabel(Map<String, dynamic> tx) {
    final type = tx['type']?.toString();
    final paymentMethod = tx['paymentMethod']?.toString() ?? '';
    final title = tx['title']?.toString() ?? '';

    if (type == 'deposit') {
      if (title.contains('رسوم') ||
          title.contains('توصيل') ||
          title.contains('طلب') ||
          title.contains('شحنة')) {
        return 'إيداع رسوم دفع';
      } else {
        return 'إيداع شحن محفظة';
      }
    } else if (type == 'withdraw') {
      if (title.contains('رسوم') ||
          title.contains('توصيل') ||
          title.contains('دفع')) {
        return 'إيداع رسوم دفع';
      } else if (paymentMethod == 'wallet' || paymentMethod == 'bank') {
        return 'طلب سحب';
      } else {
        return 'طلب دفع / خصم';
      }
    }
    return type ?? '';
  }

  Color _getTransactionTypeColor(Map<String, dynamic> tx) {
    final type = tx['type']?.toString();
    final paymentMethod = tx['paymentMethod']?.toString() ?? '';
    final title = tx['title']?.toString() ?? '';

    if (type == 'deposit') {
      if (title.contains('رسوم') ||
          title.contains('توصيل') ||
          title.contains('طلب') ||
          title.contains('شحنة')) {
        return AppColors.info;
      } else {
        return AppColors.success;
      }
    } else if (type == 'withdraw') {
      if (title.contains('رسوم') ||
          title.contains('توصيل') ||
          title.contains('دفع')) {
        return AppColors.info;
      } else if (paymentMethod == 'wallet' || paymentMethod == 'bank') {
        return AppColors.secondary;
      } else {
        return AppColors.error;
      }
    }
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0a0a1a) : AppColors.background,
        body: Column(
          children: [
            _buildHeader(isWide),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32.w : 16.w,
                  vertical: 16.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryGrid(isWide),
                    SizedBox(height: 24.h),
                    _buildTabsAndContent(isWide),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14142a).withValues(alpha: 0.4) : AppColors.surface.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        isWide ? 32.w : 20.w,
        isWide ? 28.h : 20.h,
        isWide ? 32.w : 20.w,
        isWide ? 24.h : 16.h,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'المحفظة العامة والعمليات المالية',
              style: TextStyle(
                fontSize: isWide ? 22.sp : 18.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
            ),
            child: IconButton(
              icon: Icon(Icons.analytics_rounded, color: isDark ? Colors.white70 : AppColors.textSecondary),
              tooltip: 'التحليل المالي والتقارير',
              onPressed: _showAnalyticsDashboardDialog,
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : AppColors.textSecondary),
              tooltip: 'تحديث البيانات',
              onPressed: _refreshAll,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(bool isWide) {
    final gridCount = isWide ? 5 : 2;
    final childAspectRatio = isWide ? 2.5 : 1.8;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: gridCount,
      crossAxisSpacing: 16.w,
      mainAxisSpacing: 16.h,
      childAspectRatio: childAspectRatio,
      children: [
        _buildSummaryCard(
          title: 'شحن المحافظ (إيداع)',
          value: '${_totalDeposits.toStringAsFixed(2)} ج.م',
          icon: Icons.arrow_downward_rounded,
          color: AppColors.success,
        ),
        _buildSummaryCard(
          title: 'رسوم التوصيل المحصلة',
          value: '${_totalDeliveryFees.toStringAsFixed(2)} ج.م',
          icon: Icons.currency_exchange_rounded,
          color: AppColors.info,
        ),
        _buildSummaryCard(
          title: 'السحوبات المعتمدة',
          value: '${_totalWithdrawals.toStringAsFixed(2)} ج.م',
          icon: Icons.arrow_upward_rounded,
          color: AppColors.error,
        ),
        _buildSummaryCard(
          title: 'السحوبات المعلقة',
          value: '${_pendingWithdrawals.toStringAsFixed(2)} ج.م',
          icon: Icons.hourglass_empty_rounded,
          color: AppColors.secondary,
        ),
        _buildSummaryCard(
          title: 'أرصدة المستخدمين الحالية',
          value: '${_totalUserBalances.toStringAsFixed(2)} ج.م',
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF14142a), const Color(0xFF0e0e20)]
              : [AppColors.surface, const Color(0xFFF0F2F5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),
                _isSummaryLoading
                    ? SizedBox(
                        width: 60.w,
                        height: 4.h,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            color: color,
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsAndContent(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14142a) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TabBar Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.black.withValues(alpha: 0.01),
              border: Border(
                bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                if (isWide)
                  SizedBox(
                    width: 650.w,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary2,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: isDark ? Colors.white : AppColors.textPrimary,
                      unselectedLabelColor: isDark ? Colors.white54 : AppColors.textSecondary,
                      labelStyle: AppTypography.h5.copyWith(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      tabs: const [
                        Tab(text: 'سجل العمليات المالية'),
                        Tab(text: 'أرصدة حسابات المستخدمين'),
                        Tab(text: 'إضافة رصيد لجميع المستخدمين'),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary2,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: isDark ? Colors.white : AppColors.textPrimary,
                      unselectedLabelColor: isDark ? Colors.white54 : AppColors.textSecondary,
                      labelStyle: AppTypography.h5.copyWith(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      tabs: const [
                        Tab(text: 'سجل العمليات'),
                        Tab(text: 'أرصدة المستخدمين'),
                        Tab(text: 'إضافة رصيد'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Tab Content
          SizedBox(
            height: 600.h,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(isWide),
                _buildUsersBalancesTab(isWide),
                _buildAddBalanceTab(isWide),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TRANSACTIONS TAB ────────────────────────────────────────────────────────
  Widget _buildTransactionsTab(bool isWide) {
    return Column(
      children: [
        _buildTxFilters(isWide),
        Expanded(
          child: _isTxLoading && _transactions.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _txError != null
              ? _buildTxErrorWidget()
              : _transactions.isEmpty
              ? _buildEmptyWidget('لا توجد عمليات مسجلة حالياً')
              : isWide
              ? _buildTxTableView()
              : _buildTxListView(),
        ),
        if (_txPage < _txTotalPages && !_isTxLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _txPage++;
                });
                _loadTransactions(loadMore: true);
              },
              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
              label: const Text('تحميل المزيد من العمليات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTxFilters(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
        ),
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(
                  child: _buildSearchBar(
                    controller: _txSearchController,
                    hint: 'البحث باسم المستخدم، الهاتف، أو الرقم المرجعي...',
                    onSubmitted: (_) => _loadTransactions(),
                  ),
                ),
                SizedBox(width: 16.w),
                _buildDropdownFilter(
                  label: 'النوع:',
                  value: _txTypeFilter,
                  items: const {
                    '': 'الكل',
                    'deposit': 'إيداع فقط',
                    'withdraw': 'سحب فقط',
                  },
                  onChanged: (val) {
                    setState(() {
                      _txTypeFilter = val!;
                    });
                    _loadTransactions();
                  },
                ),
                SizedBox(width: 16.w),
                _buildDropdownFilter(
                  label: 'الحالة:',
                  value: _txStatusFilter,
                  items: const {
                    '': 'الكل',
                    'success': 'ناجحة',
                    'pending': 'معلقة',
                    'failed': 'فاشلة',
                  },
                  onChanged: (val) {
                    setState(() {
                      _txStatusFilter = val!;
                    });
                    _loadTransactions();
                  },
                ),
              ],
            )
          : Column(
              children: [
                _buildSearchBar(
                  controller: _txSearchController,
                  hint: 'البحث بالاسم، الهاتف، المرجع...',
                  onSubmitted: (_) => _loadTransactions(),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownFilter(
                        label: 'النوع:',
                        value: _txTypeFilter,
                        items: const {
                          '': 'الكل',
                          'deposit': 'إيداع',
                          'withdraw': 'سحب',
                        },
                        onChanged: (val) {
                          setState(() {
                            _txTypeFilter = val!;
                          });
                          _loadTransactions();
                        },
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildDropdownFilter(
                        label: 'الحالة:',
                        value: _txStatusFilter,
                        items: const {
                          '': 'الكل',
                          'success': 'ناجحة',
                          'pending': 'معلقة',
                          'failed': 'فاشلة',
                        },
                        onChanged: (val) {
                          setState(() {
                            _txStatusFilter = val!;
                          });
                          _loadTransactions();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildTxTableView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.0),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(3.0),
          4: FlexColumnWidth(1.2),
          5: FlexColumnWidth(1.8),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.black.withValues(alpha: 0.01),
              border: Border(
                bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            children: [
              _th('صاحب المعاملة'),
              _th('النوع'),
              _th('المبلغ'),
              _th('تفاصيل العملية والملاحظات'),
              _th('الحالة'),
              _th('التاريخ والوقت'),
            ],
          ),
          ..._transactions.map((tx) {
            final user = tx['user'] as Map<String, dynamic>? ?? {};
            final userName = user['name'] ?? '';
            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            final typeStr = _getTransactionTypeLabel(tx);
            final typeColor = _getTransactionTypeColor(tx);
            final status = tx['status']?.toString() ?? 'pending';

            return TableRow(
              children: [
                _tdUser(
                  userName,
                  user['role']?.toString() ?? '',
                  user['storeName'] ?? '',
                  (user['walletBalance'] as num?)?.toDouble() ?? 0.0,
                ),
                _tdLabel(typeStr, typeColor),
                _td('$amount ج.م', isMain: true, amountColor: typeColor),
                _tdDetails(tx),
                _tdStatusCapsule(status),
                _td(tx['date'] ?? ''),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTxListView() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final user = tx['user'] as Map<String, dynamic>? ?? {};
        final userName = user['name'] ?? '';
        final role = user['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر';
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final status = tx['status']?.toString() ?? 'pending';
        final isDeposit = tx['type'] == 'deposit';
        final typeStr = _getTransactionTypeLabel(tx);
        final typeColor = _getTransactionTypeColor(tx);

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF14142a), const Color(0xFF0e0e20)]
                  : [AppColors.surface, const Color(0xFFF0F2F5)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                  Text(
                    '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (user['role'] == 'captain'
                                  ? AppColors.primary2
                                  : AppColors.primary)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        color: user['role'] == 'captain'
                            ? AppColors.primary2
                            : AppColors.primary,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      typeStr,
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (user['storeName'] != null &&
                      user['storeName'].toString().isNotEmpty) ...[
                    SizedBox(width: 8.w),
                    Text(
                      'متجر: ${user['storeName']}',
                      style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 10.sp),
                    ),
                  ],
                  const Spacer(),
                  _buildStatusBadge(status),
                ],
              ),
              Divider(color: isDark ? Colors.white10 : Colors.black12, height: 20),
              GestureDetector(
                onTap: () => _showTransactionDetailsDialog(tx),
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description_rounded,
                            size: 13.sp,
                            color: AppColors.primary2,
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              tx['title'] ?? '',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (tx['reference'] != null &&
                          tx['reference'].toString().isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(
                          'الرقم المرجعي: ${tx['reference']}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : AppColors.textSecondary,
                            fontSize: 10.sp,
                          ),
                        ),
                      ],
                      _buildTxDetailsBlock(tx),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 10.sp,
                    color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'التاريخ: ${tx['date']}',
                    style: TextStyle(color: isDark ? Colors.white24 : const Color(0xFFBDBDBD), fontSize: 10.sp),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTxDetailsBlock(Map<String, dynamic> tx) {
    if (tx['paymentMethod'] == null || tx['paymentMethod'].toString().isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final method = tx['paymentMethod'];
    final details = tx['accountDetails'] as Map<String, dynamic>?;
    if (details == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 16),
        Row(
          children: [
            Icon(
              method == 'wallet'
                  ? Icons.phone_android_rounded
                  : Icons.account_balance_rounded,
              size: 12.sp,
              color: AppColors.primary,
            ),
            SizedBox(width: 6.w),
            Text(
              method == 'wallet'
                  ? 'طريقة السحب: محفظة إلكترونية'
                  : 'طريقة السحب: حساب بنكي',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        if (method == 'wallet') ...[
          Text(
            'المزود: ${details['walletProvider'] ?? ""}',
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 10),
          ),
          Text(
            'الرقم: ${details['phone'] ?? ""}',
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 10),
          ),
          Text(
            'الاسم: ${details['name'] ?? ""}',
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 10),
          ),
        ] else ...[
          Text(
            'البنك: ${details['bankName'] ?? ""}',
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 10),
          ),
          Text(
            'رقم الحساب: ${details['bankAccountNumber'] ?? ""}',
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 10),
          ),
          Text(
            'الاسم: ${details['name'] ?? ""}',
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 10),
          ),
        ],
      ],
    );
  }

  Widget _buildTxErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: EdgeInsets.all(24.w),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'فشل تحميل العمليات',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _txError!,
              style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 12.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () => _loadTransactions(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── USERS BALANCES TAB ──────────────────────────────────────────────────────
  Widget _buildUsersBalancesTab(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
            ),
          ),
          child: _buildSearchBar(
            controller: _usersSearchController,
            hint: 'البحث باسم المستخدم، المتجر، أو رقم الهاتف...',
            onSubmitted: (_) => _loadUsers(),
          ),
        ),
        Expanded(
          child: _isUsersLoading && _users.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _usersError != null
              ? _buildUsersErrorWidget()
              : _users.isEmpty
              ? _buildEmptyWidget('لا توجد حسابات بأرصدة موجبة حالياً')
              : isWide
              ? _buildUsersTableView()
              : _buildUsersListView(),
        ),
        if (_usersPage < _usersTotalPages && !_isUsersLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _usersPage++;
                });
                _loadUsers(loadMore: true);
              },
              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
              label: const Text('تحميل المزيد من المستخدمين'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUsersTableView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(2.0),
          4: FlexColumnWidth(1.8),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.black.withValues(alpha: 0.01),
              border: Border(
                bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            children: [
              _th('الاسم الكامل'),
              _th('الدور'),
              _th('اسم المتجر (للتجار)'),
              _th('رقم الهاتف / البريد الإلكتروني'),
              _th('رصيد المحفظة الحالي'),
            ],
          ),
          ..._users.map((u) {
            final userName = u['name'] ?? '';
            final role = u['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر';
            final storeName = u['storeName'] ?? '-';
            final phone = u['phone'] ?? '';
            final email = u['email'] ?? '';
            final balance = (u['walletBalance'] as num?)?.toDouble() ?? 0.0;

            return TableRow(
              children: [
                _tdClickable(
                  u,
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 14.h,
                      horizontal: 8.w,
                    ),
                    child: Text(
                      userName,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _tdClickable(u, _tdText(role)),
                _tdClickable(u, _tdText(storeName)),
                _tdClickable(
                  u,
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phone,
                          style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary),
                        ),
                        Text(
                          email,
                          style: TextStyle(
                            color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _tdClickable(u, _tdText('${balance.toStringAsFixed(2)} ج.م', isMain: true)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUsersListView() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final userName = u['name'] ?? '';
        final role = u['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر';
        final storeName = u['storeName'] ?? '';
        final balance = (u['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final phone = u['phone'] ?? '';

        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          child: InkWell(
            onTap: () => _showUserWalletHistoryDialog(u),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF14142a), const Color(0xFF0e0e20)]
                      : [AppColors.surface, const Color(0xFFF0F2F5)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (u['role'] == 'captain'
                                            ? AppColors.primary2
                                            : AppColors.primary)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  color: u['role'] == 'captain'
                                      ? AppColors.primary2
                                      : AppColors.primary,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (storeName.isNotEmpty) ...[
                              SizedBox(width: 8.w),
                              Text(
                                'متجر: $storeName',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : AppColors.textLight,
                                  fontSize: 10.sp,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 10.sp,
                              color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              phone,
                              style: TextStyle(
                                color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.primary2.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${balance.toStringAsFixed(2)} ج.م',
                      style: TextStyle(
                        color: AppColors.primary2,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildUsersErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: EdgeInsets.all(24.w),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'فشل تحميل المستخدمين',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _usersError!,
              style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 12.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () => _loadUsers(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADD BALANCE TO ALL USERS TAB ──────────────────────────────────────────
  Widget _buildAddBalanceTab(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
            ),
          ),
          child: _buildSearchBar(
            controller: _allUsersSearchController,
            hint: 'البحث باسم المستخدم، المتجر، أو رقم الهاتف لشحن الرصيد...',
            onSubmitted: (_) => _loadAllUsers(),
          ),
        ),
        Expanded(
          child: _isAllUsersLoading && _allUsers.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _allUsersError != null
              ? _buildAllUsersErrorWidget()
              : _allUsers.isEmpty
              ? _buildEmptyWidget('لا توجد حسابات مستخدمين حالياً')
              : isWide
              ? _buildAllUsersTableView()
              : _buildAllUsersListView(),
        ),
        if (_allUsersPage < _allUsersTotalPages && !_isAllUsersLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _allUsersPage++;
                });
                _loadAllUsers(loadMore: true);
              },
              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
              label: const Text('تحميل المزيد من المستخدمين'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllUsersTableView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.0),
          2: FlexColumnWidth(1.3),
          3: FlexColumnWidth(1.8),
          4: FlexColumnWidth(1.5),
          5: FlexColumnWidth(1.2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.black.withValues(alpha: 0.01),
              border: Border(
                bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            children: [
              _th('الاسم الكامل'),
              _th('الدور'),
              _th('اسم المتجر'),
              _th('الهاتف / البريد الإلكتروني'),
              _th('الرصيد الحالي'),
              _th('الإجراء'),
            ],
          ),
          ..._allUsers.map((u) {
            final userName = u['name'] ?? '';
            final role = u['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر';
            final storeName = u['storeName'] ?? '-';
            final phone = u['phone'] ?? '';
            final email = u['email'] ?? '';
            final balance = (u['walletBalance'] as num?)?.toDouble() ?? 0.0;

            return TableRow(
              children: [
                _tdTextClickable(u, userName, isBold: true),
                _tdTextClickable(u, role),
                _tdTextClickable(u, storeName),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
                  child: InkWell(
                    onTap: () => _showAddBalanceDialog(u),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phone,
                          style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary),
                        ),
                        Text(
                          email,
                          style: TextStyle(
                            color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _tdTextClickable(u, '${balance.toStringAsFixed(2)} ج.م', isMain: true),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddBalanceDialog(u),
                      icon: const Icon(Icons.add_card_rounded, size: 14),
                      label: const Text('شحن رصيد', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success.withValues(alpha: 0.8),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllUsersListView() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _allUsers.length,
      itemBuilder: (context, index) {
        final u = _allUsers[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final userName = u['name'] ?? '';
        final role = u['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر';
        final storeName = u['storeName'] ?? '';
        final balance = (u['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final phone = u['phone'] ?? '';

        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          child: InkWell(
            onTap: () => _showAddBalanceDialog(u),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF14142a), const Color(0xFF0e0e20)]
                      : [AppColors.surface, const Color(0xFFF0F2F5)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (u['role'] == 'captain'
                                            ? AppColors.primary2
                                            : AppColors.primary)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  color: u['role'] == 'captain'
                                      ? AppColors.primary2
                                      : AppColors.primary,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (storeName.isNotEmpty) ...[
                              SizedBox(width: 8.w),
                              Text(
                                'متجر: $storeName',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : AppColors.textLight,
                                  fontSize: 10.sp,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 10.sp,
                              color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              phone,
                              style: TextStyle(
                                color: isDark ? Colors.white30 : const Color(0xFF9E9E9E),
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary2.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppColors.primary2.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '${balance.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                            color: AppColors.primary2,
                            fontWeight: FontWeight.w900,
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'اضغط للشحن',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllUsersErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: EdgeInsets.all(24.w),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'فشل تحميل المستخدمين',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _allUsersError!,
              style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 12.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () => _loadAllUsers(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tdTextClickable(Map<String, dynamic> user, String text, {bool isBold = false, bool isMain = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _showAddBalanceDialog(user),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: isBold || isMain ? FontWeight.w800 : FontWeight.normal,
            color: isMain ? AppColors.primary2 : (isDark ? Colors.white70 : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  void _showAddBalanceDialog(Map<String, dynamic> user) {
    showDialog<bool>(
      context: context,
      builder: (context) => _AddBalanceDialog(user: user),
    ).then((success) {
      if (!mounted) return;
      if (success == true) {
        _refreshAll();
        _showSnackBar('تم شحن رصيد المحفظة بنجاح وتحديث البيانات');
      }
    });
  }

  // ─── REUSABLE HELPERS ────────────────────────────────────────────────────────
  Widget _buildSearchBar({
    required TextEditingController controller,
    required String hint,
    required Function(String) onSubmitted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF9E9E9E)),
        prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : AppColors.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(Icons.clear_rounded, color: isDark ? Colors.white54 : AppColors.textSecondary),
          onPressed: () {
            controller.clear();
            onSubmitted('');
          },
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: isDark ? const Color(0xFF14142a) : AppColors.surface,
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 12),
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
              onChanged: onChanged,
              items: items.entries.map((e) {
                return DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWidget(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Icon(
              Icons.inbox_outlined,
              color: isDark ? Colors.white24 : const Color(0xFFBDBDBD),
              size: 48.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  // Table Cell Helpers
  Widget _th(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _td(String text, {bool isMain = false, Color? amountColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: isMain ? FontWeight.w800 : FontWeight.normal,
          color: isMain ? (amountColor ?? AppColors.primary2) : (isDark ? Colors.white70 : AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _tdLabel(String text, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _tdUser(String name, String role, String storeName, double balance) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color:
                      (role == 'captain'
                              ? AppColors.primary2
                              : AppColors.primary)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  role == 'captain' ? 'كابتن / مندوب' : 'تاجر',
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: role == 'captain'
                        ? AppColors.primary2
                        : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (storeName.isNotEmpty) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '($storeName)',
                    style: TextStyle(fontSize: 10.sp, color: isDark ? Colors.white38 : AppColors.textLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tdDetails(Map<String, dynamic> tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final method = tx['paymentMethod'];
    final reference = tx['reference'] ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
      child: InkWell(
        onTap: () => _showTransactionDetailsDialog(tx),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx['title'] ?? '',
              style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (method != null && method.toString().isNotEmpty) ...[
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(
                    method == 'wallet'
                        ? Icons.phone_android_rounded
                        : Icons.account_balance_rounded,
                    size: 11.sp,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    method == 'wallet'
                        ? 'سحب: محفظة إلكترونية'
                        : 'سحب: حساب بنكي',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            if (reference.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                'المرجع: $reference',
                style: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF9E9E9E), fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tdStatusCapsule(String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'success':
        color = AppColors.success;
        label = 'ناجحة';
        icon = Icons.check_circle_rounded;
        break;
      case 'pending':
        color = AppColors.secondary;
        label = 'معلقة';
        icon = Icons.hourglass_empty_rounded;
        break;
      case 'failed':
        color = AppColors.error;
        label = 'فاشلة';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = isDark ? Colors.white24 : const Color(0xFFBDBDBD);
        label = status;
        icon = Icons.info_rounded;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12.sp, color: color),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'success':
        color = AppColors.success;
        label = 'ناجحة';
        icon = Icons.check_circle_rounded;
        break;
      case 'pending':
        color = AppColors.secondary;
        label = 'معلقة';
        icon = Icons.hourglass_empty_rounded;
        break;
      case 'failed':
        color = AppColors.error;
        label = 'فاشلة';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = isDark ? Colors.white24 : const Color(0xFFBDBDBD);
        label = status;
        icon = Icons.info_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetailsDialog(Map<String, dynamic> tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final method = tx['paymentMethod'];
    final reference = tx['reference'] ?? '';
    final details = tx['accountDetails'] as Map<String, dynamic>?;
    final user = tx['user'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: isDark ? const Color(0xFF14142a) : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: 500.w,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14142a) : AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Bar
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary2,
                        size: 22.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          tx['title'] ?? 'تفاصيل العملية المالية',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white60 : AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? Colors.white10 : Colors.black12),
                  SizedBox(height: 12.h),

                  // 1. بيانات صاحب المعاملة
                  _buildDialogInfoSection(
                    title: 'بيانات صاحب المعاملة',
                    icon: Icons.person_rounded,
                    children: [
                      _buildDialogRow(
                        'الاسم بالكامل:',
                        user['name'] ?? 'غير معروف',
                        context,
                        showCopy: true,
                      ),
                      _buildDialogRow(
                        'الصفة / الدور:',
                        user['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر',
                        context,
                      ),
                      if (user['storeName'] != null &&
                          user['storeName'].toString().trim().isNotEmpty)
                        _buildDialogRow(
                          'اسم المتجر:',
                          user['storeName'].toString(),
                          context,
                          showCopy: true,
                        ),
                      if (user['phone'] != null &&
                          user['phone'].toString().trim().isNotEmpty)
                        _buildDialogRow(
                          'رقم الهاتف:',
                          user['phone'].toString(),
                          context,
                          showCopy: true,
                        ),
                      if (user['email'] != null &&
                          user['email'].toString().trim().isNotEmpty)
                        _buildDialogRow(
                          'البريد الإلكتروني:',
                          user['email'].toString(),
                          context,
                          showCopy: true,
                        ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // 2. بيانات المعاملة المالية
                  _buildDialogInfoSection(
                    title: 'بيانات المعاملة المالية',
                    icon: Icons.currency_exchange_rounded,
                    children: [
                      _buildDialogRow(
                        'قيمة العملية:',
                        '${tx['amount']} ج.م',
                        context,
                        showCopy: true,
                      ),
                      _buildDialogRow(
                        'نوع العملية:',
                        _getTransactionTypeLabel(tx),
                        context,
                      ),
                      _buildDialogRow(
                        'حالة العملية:',
                        tx['status'] == 'success'
                            ? 'ناجحة'
                            : tx['status'] == 'pending'
                            ? 'قيد الانتظار'
                            : 'فاشلة/ملغية',
                        context,
                      ),
                      _buildDialogRow(
                        'تاريخ المعاملة:',
                        tx['date'] ?? '',
                        context,
                      ),
                      if (reference.isNotEmpty)
                        _buildDialogRow(
                          'الرقم المرجعي (كاشير):',
                          reference,
                          context,
                          showCopy: true,
                        ),
                    ],
                  ),

                  // 3. Recipient Account Info Block (Only if paymentMethod is wallet or bank)
                  if (method != null &&
                      method.isNotEmpty &&
                      (method == 'wallet' || method == 'bank') &&
                      details != null) ...[
                    SizedBox(height: 16.h),
                    _buildDialogInfoSection(
                      title: method == 'wallet'
                          ? 'بيانات المحفظة الإلكترونية المستلمة'
                          : 'بيانات الحساب البنكي المستلم',
                      icon: method == 'wallet'
                          ? Icons.phone_android_rounded
                          : Icons.account_balance_rounded,
                      children: [
                        if (method == 'wallet') ...[
                          _buildDialogRow(
                            'مزود المحفظة:',
                            details['walletProvider'] ?? '',
                            context,
                          ),
                          _buildDialogRow(
                            'رقم الهاتف:',
                            details['phone'] ?? '',
                            context,
                            showCopy: true,
                          ),
                          _buildDialogRow(
                            'الاسم المسجل:',
                            details['name'] ?? '',
                            context,
                            showCopy: true,
                          ),
                        ] else ...[
                          _buildDialogRow(
                            'اسم البنك:',
                            details['bankName'] ?? '',
                            context,
                          ),
                          _buildDialogRow(
                            'رقم الحساب/IBAN:',
                            details['bankAccountNumber'] ?? '',
                            context,
                            showCopy: true,
                          ),
                          _buildDialogRow(
                            'الاسم بالكامل:',
                            details['name'] ?? '',
                            context,
                            showCopy: true,
                          ),
                        ],
                      ],
                    ),
                  ],
                  SizedBox(height: 24.h),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'إغلاق',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14.sp, color: AppColors.primary2),
              SizedBox(width: 6.w),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.primary2,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          Divider(color: isDark ? Colors.white10 : Colors.black12, height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDialogRow(
    String label,
    String value,
    BuildContext context, {
    bool showCopy = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : AppColors.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 12.sp),
            ),
          ),
          if (showCopy && value.isNotEmpty) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text('تم نسخ: $value'),
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Icon(
                Icons.copy_rounded,
                size: 14.sp,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tdText(String text, {bool isMain = false, Color? amountColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: isMain ? FontWeight.w800 : FontWeight.normal,
          color: isMain ? (amountColor ?? AppColors.primary2) : (isDark ? Colors.white70 : AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _tdClickable(Map<String, dynamic> user, Widget child) {
    return InkWell(
      onTap: () => _showUserWalletHistoryDialog(user),
      child: child,
    );
  }

  void _showUserWalletHistoryDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _UserWalletHistoryDialog(user: user),
    );
  }

  void _showAnalyticsDashboardDialog() {
    final platformProfit = _totalDeliveryFees * 0.20;
    final totalExpense = _totalWithdrawals + _pendingWithdrawals;
    final liquidity = totalExpense > 0 ? _totalDeposits / totalExpense : 10.0;

    String successRating = 'ممتاز ومربح جداً';
    Color ratingColor = AppColors.success;
    String ratingDescription = '';

    if (liquidity >= 1.2) {
      successRating = 'ممتاز ومستقر مالياً';
      ratingColor = AppColors.success;
      ratingDescription = 'يتمتع التطبيق بنسبة سيولة وتغطية مالية ممتازة للتدفقات النقدية الخارجة. رسوم التوصيل تشكل مصدر ربح متنامي للمنصة.';
    } else if (liquidity >= 0.8) {
      successRating = 'أداء مستقر وآمن';
      ratingColor = AppColors.info;
      ratingDescription = 'النظام يحقق أرباحاً تشغيلية مقبولة ومتوازنة، ولكن يوصى بتحفيز عمليات الشحن الذاتي للمحفظة لضمان استقرار أطول.';
    } else {
      successRating = 'تحذير سيولة منخفضة';
      ratingColor = AppColors.error;
      ratingDescription = 'السحوبات تقترب من تخطي الإيداعات، يوصى بزيادة العمولات أو تنشيط تشغيل التطبيق لرفع إيرادات رسوم التوصيل.';
    }

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: isDark ? const Color(0xFF14142a) : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: 550.w,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14142a) : AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_rounded, color: AppColors.primary2, size: 24.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'التحليلات المالية والتقارير العامة',
                          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14.sp),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: isDark ? Colors.white60 : AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? Colors.white10 : Colors.black12),
                  SizedBox(height: 16.h),

                  // 1. Success & Profitability Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أرباح وصحة المنصة التشغيلية',
                          style: TextStyle(color: AppColors.primary2, fontWeight: FontWeight.bold, fontSize: 13.sp),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('صافي أرباح المنصة المقدرة (20%):', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 11.sp)),
                            Text('${platformProfit.toStringAsFixed(2)} ج.م', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 13.sp)),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('مستوى النجاح المالي:', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 11.sp)),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: ratingColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(successRating, style: TextStyle(color: ratingColor, fontWeight: FontWeight.bold, fontSize: 10.sp)),
                            ),
                          ],
                        ),
                        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 20),
                        Text(
                          ratingDescription,
                          style: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight, fontSize: 10.sp, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // 2. Visual Bar Comparison Chart (Deposits, Payouts, Fees)
                  Text(
                    'مقارنة تدفقات المحفظة العامة',
                    style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12.sp),
                  ),
                  SizedBox(height: 12.h),
                  _buildComparisonBar('شحن المحافظ (إيداع)', _totalDeposits, _totalDeposits + _totalDeliveryFees + _totalWithdrawals, AppColors.success),
                  SizedBox(height: 8.h),
                  _buildComparisonBar('رسوم التوصيل المحصلة', _totalDeliveryFees, _totalDeposits + _totalDeliveryFees + _totalWithdrawals, AppColors.info),
                  SizedBox(height: 8.h),
                  _buildComparisonBar('إجمالي السحوبات', _totalWithdrawals, _totalDeposits + _totalDeliveryFees + _totalWithdrawals, AppColors.error),

                  SizedBox(height: 24.h),

                  // 3. Export Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _exportGeneralReport();
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('تحميل تقرير الحسابات والأداء العام (HTML / PDF)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  }

  Widget _buildComparisonBar(String label, double value, double total, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double percent = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 10.sp)),
            Text('${value.toStringAsFixed(2)} ج.م', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 10.sp)),
          ],
        ),
        SizedBox(height: 4.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            color: color,
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            minHeight: 8.h,
          ),
        ),
      ],
    );
  }

  Future<void> _exportGeneralReport() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      final dioConsumer = sl<DioConsumer>();
      final response = await dioConsumer.get(
        EndPoint.adminWalletTransactions,
        queryParameters: {'page': 1, 'limit': 10000},
      );

      if (mounted) {
        Navigator.pop(context);
      }

      if (response != null && response['status'] == 1) {
        final list = response['data']['transactions'] as List;

        final buffer = StringBuffer();
        for (final tx in list) {
          final user = tx['user'] as Map<String, dynamic>? ?? {};
          final userName = user['name'] ?? 'غير معروف';
          final type = _getTransactionTypeLabel(tx);
          final typeColor = tx['type'] == 'deposit' ? '#0fb800' : '#e74c3c';
          final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
          final title = tx['title'] ?? '';
          final status = tx['status'] == 'success' ? 'ناجحة' : tx['status'] == 'pending' ? 'معلقة' : 'فاشلة';
          final date = tx['date'] ?? '';

          buffer.write('''
            <tr>
              <td>$userName</td>
              <td style="color: $typeColor; font-weight: bold;">$type</td>
              <td>$amount ج.م</td>
              <td>$title</td>
              <td>$status</td>
              <td>$date</td>
            </tr>
          ''');
        }

        final platformProfit = _totalDeliveryFees * 0.20;
        final totalExpense = _totalWithdrawals + _pendingWithdrawals;
        final liquidity = totalExpense > 0 ? _totalDeposits / totalExpense : 10.0;

        String analysisClass = 'success';
        String healthStatus = 'ناجح ومستقر للغاية';
        String analysisText = '';

        if (liquidity >= 1.2) {
          analysisText = 'يظهر النظام أداءً مالياً ممتازاً مع تدفقات نقدية مستقرة وعالية الأمان. تشكل رسوم التوصيل المحصلة (${_totalDeliveryFees.toStringAsFixed(2)} ج.م) محركاً أساسياً للأرباح بتقديم صافي عمولة للمنصة تقدر بـ (${platformProfit.toStringAsFixed(2)} ج.م). مؤشر السيولة يوضح أن الودائع تغطي السحوبات بنسبة مريحة، مما يعزز الملاءة المالية للنظام ويؤكد نجاحه الباهر في إدارة التدفقات المالية.';
        } else if (liquidity >= 0.8) {
          analysisClass = 'stable';
          healthStatus = 'مستقر ومستمر';
          analysisText = 'النظام يحقق أرباحاً تشغيلية جيدة من رسوم التوصيل (${_totalDeliveryFees.toStringAsFixed(2)} ج.م)، وصافي أرباح المنصة المكتسبة (${platformProfit.toStringAsFixed(2)} ج.م) تعبر عن نجاح تجاري، لكن مؤشر السيولة يشير إلى تقارب حجم السحوبات مع الإيداعات. يُنصح بتوفير عروض شحن للمحافظ لضمان استمرارية فائض السيولة النقدية.';
        } else {
          analysisClass = 'warning';
          healthStatus = 'حذر ومحتاج زيادة تشغيل';
          analysisText = 'يحتاج النظام لزيادة وتيرة العمليات وتكثيف الشحنات لرفع عوائد التوصيل. تدفقات المحفظة الحالية محدودة، وينبغي تحسين نسب الشحن لضمان توازن أفضل بين التدفقات النقدية الداخلة والخارجة للمنصة.';
        }

        final html = _getReportHtmlTemplate()
            .replaceAll('{{DATE}}', DateTime.now().toString().substring(0, 19))
            .replaceAll('{{TOTAL_DEPOSITS}}', _totalDeposits.toStringAsFixed(2))
            .replaceAll('{{TOTAL_DELIVERY_FEES}}', _totalDeliveryFees.toStringAsFixed(2))
            .replaceAll('{{PLATFORM_PROFIT}}', platformProfit.toStringAsFixed(2))
            .replaceAll('{{TOTAL_WITHDRAWALS}}', _totalWithdrawals.toStringAsFixed(2))
            .replaceAll('{{TOTAL_USER_BALANCES}}', _totalUserBalances.toStringAsFixed(2))
            .replaceAll('{{LIQUIDITY_HEALTH}}', healthStatus)
            .replaceAll('{{ANALYSIS_CLASS}}', analysisClass)
            .replaceAll('{{ANALYSIS_TEXT}}', analysisText)
            .replaceAll('{{ROWS}}', buffer.toString());

        await _exportAndOpenHtmlReport('general_wallet_report.html', html);
      } else {
        _showSnackBar('فشل تحميل العمليات لتصدير التقرير', isError: true);
      }
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء تصدير التقرير: $e', isError: true);
    }
  }

  String _getReportHtmlTemplate() {
    return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
    <meta charset="UTF-8">
    <title>تقرير الأداء المالي العام - We Deliver</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f6fa; color: #2f3640; padding: 30px; }
        .invoice-card { background: #fff; max-width: 1000px; margin: 0 auto; padding: 40px; border-radius: 15px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); border: 1px solid #e1e2e6; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #f1f2f6; padding-bottom: 20px; }
        .header h1 { color: #004aad; margin: 0; font-size: 28px; }
        .header .logo { font-size: 24px; font-weight: 800; color: #004aad; }
        .stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-top: 30px; }
        .stat-box { background: #f8f9fa; border: 1px solid #e1e2e6; padding: 20px; border-radius: 10px; text-align: center; }
        .stat-box h3 { margin: 0; font-size: 14px; color: #718093; }
        .stat-box p { margin: 10px 0 0; font-size: 20px; font-weight: 800; color: #2f3640; }
        .stat-box.highlight { border-color: #004aad; background: rgba(0, 74, 173, 0.02); }
        .stat-box.highlight p { color: #004aad; }
        .analysis-section { margin-top: 30px; padding: 25px; border-radius: 10px; background: rgba(15, 184, 0, 0.05); border: 1px solid rgba(15, 184, 0, 0.15); }
        .analysis-section.stable { background: rgba(247, 135, 16, 0.05); border-color: rgba(247, 135, 16, 0.15); }
        .analysis-section.warning { background: rgba(231, 76, 60, 0.05); border-color: rgba(231, 76, 60, 0.15); }
        .analysis-section h2 { margin: 0 0 10px; font-size: 18px; color: #0fb800; }
        .analysis-section.stable h2 { color: #f78710; }
        .analysis-section.warning h2 { color: #e74c3c; }
        .analysis-section p { margin: 0; line-height: 1.7; font-size: 14px; }
        table { width: 100%; border-collapse: collapse; margin-top: 40px; }
        th, td { padding: 12px 15px; text-align: right; border-bottom: 1px solid #f1f2f6; font-size: 13px; }
        th { background-color: #004aad; color: white; font-weight: 600; }
        .footer { margin-top: 50px; text-align: center; font-size: 12px; color: #a5b1c2; border-top: 1px solid #f1f2f6; padding-top: 20px; }
        @media print {
            body { background-color: white; padding: 0; }
            .invoice-card { box-shadow: none; border: none; padding: 0; }
        }
    </style>
</head>
<body>
    <div class="invoice-card">
        <div class="header">
            <div>
                <h1>تقرير الأداء المالي العام</h1>
                <p style="margin: 5px 0 0; color: #718093; font-size: 13px;">تاريخ استخراج التقرير: {{DATE}}</p>
            </div>
            <div class="logo">We Deliver</div>
        </div>
        <div class="stats-grid">
            <div class="stat-box">
                <h3>إجمالي شحن المحافظ</h3>
                <p>{{TOTAL_DEPOSITS}} ج.م</p>
            </div>
            <div class="stat-box">
                <h3>إجمالي رسوم التوصيل</h3>
                <p>{{TOTAL_DELIVERY_FEES}} ج.م</p>
            </div>
            <div class="stat-box highlight">
                <h3>صافي أرباح المنصة (20%)</h3>
                <p>{{PLATFORM_PROFIT}} ج.م</p>
            </div>
            <div class="stat-box">
                <h3>السحوبات المعتمدة</h3>
                <p>{{TOTAL_WITHDRAWALS}} ج.م</p>
            </div>
            <div class="stat-box">
                <h3>أرصدة المستخدمين الحالية</h3>
                <p>{{TOTAL_USER_BALANCES}} ج.م</p>
            </div>
            <div class="stat-box">
                <h3>تقييم أداء المحفظة</h3>
                <p>{{LIQUIDITY_HEALTH}}</p>
            </div>
        </div>
        <div class="analysis-section {{ANALYSIS_CLASS}}">
            <h2>تحليل نجاح وكفاءة التطبيق</h2>
            <p>{{ANALYSIS_TEXT}}</p>
        </div>
        <table>
            <thead>
                <tr>
                    <th>صاحب المعاملة</th>
                    <th>نوع العملية</th>
                    <th>المبلغ</th>
                    <th>عنوان العملية والملاحظات</th>
                    <th>الحالة</th>
                    <th>التاريخ والوقت</th>
                </tr>
            </thead>
            <tbody>
                {{ROWS}}
            </tbody>
        </table>
        <div class="footer">
            <p>هذا التقرير تم إنشاؤه تلقائياً بواسطة لوحة تحكم We Deliver المالية.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }

  Future<void> _exportAndOpenHtmlReport(String fileName, String htmlContent) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(htmlContent);

      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(Uri.parse('file://${file.path}'));
      }

      _showSnackBar('تم تصدير التقرير وفتحه في المتصفح بنجاح');
    } catch (e) {
      _showSnackBar('فشل تصدير التقرير: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(message),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

}

class _UserWalletHistoryDialog extends StatefulWidget {
  final Map<String, dynamic> user;

  const _UserWalletHistoryDialog({required this.user});

  @override
  State<_UserWalletHistoryDialog> createState() => _UserWalletHistoryDialogState();
}

class _UserWalletHistoryDialogState extends State<_UserWalletHistoryDialog> {
  final List<dynamic> _transactions = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadUserTransactions();
  }

  Future<void> _loadUserTransactions({bool loadMore = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _page = 1;
        _transactions.clear();
        _error = null;
      }
    });

    try {
      final dioConsumer = sl<DioConsumer>();
      final response = await dioConsumer.get(
        EndPoint.adminWalletTransactions,
        queryParameters: {
          'page': _page,
          'limit': 15,
          'userId': widget.user['id'],
        },
      );

      if (response != null && response['status'] == 1) {
        final data = response['data'];
        final list = data['transactions'] as List;
        final pagination = data['pagination'];

        setState(() {
          _transactions.addAll(list);
          _totalPages = int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
        });
      } else {
        setState(() {
          _error = response?['message']?.toString() ?? 'فشل تحميل العمليات';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportUserStatement() async {
    try {
      if (_transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد عمليات ماليّة لتصديرها لهذا المستخدم'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      double totalDeposits = 0;
      double totalFees = 0;
      double totalWithdrawals = 0;

      final buffer = StringBuffer();
      for (final tx in _transactions) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final title = tx['title'] ?? '';
        final type = _getTransactionTypeLabelStatic(tx);
        final date = tx['date'] ?? '';
        final status = tx['status'] == 'success' ? 'ناجحة' : tx['status'] == 'pending' ? 'معلقة' : 'فاشلة';
        final isDeposit = tx['type'] == 'deposit';
        final typeColor = isDeposit ? '#0fb800' : '#e74c3c';

        if (type == 'إيداع شحن محفظة') {
          totalDeposits += amount;
        } else if (type == 'إيداع رسوم دفع') {
          totalFees += amount;
        } else {
          totalWithdrawals += amount;
        }

        buffer.write('''
          <tr>
            <td>$title</td>
            <td style="color: $typeColor; font-weight: bold;">${isDeposit ? '+' : '-'}$amount ج.م</td>
            <td>$type</td>
            <td>$status</td>
            <td>$date</td>
          </tr>
        ''');
      }

      final userName = widget.user['name'] ?? 'غير معروف';
      final role = widget.user['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر';
      final storeName = widget.user['storeName'] ?? 'لا يوجد';
      final phone = widget.user['phone'] ?? 'غير متوفر';
      final email = widget.user['email'] ?? 'غير متوفر';
      final balance = (widget.user['walletBalance'] as num?)?.toDouble() ?? 0.0;

      final html = _getUserStatementHtmlTemplate()
          .replaceAll('{{DATE}}', DateTime.now().toString().substring(0, 19))
          .replaceAll('{{USER_NAME}}', userName)
          .replaceAll('{{USER_ROLE}}', role)
          .replaceAll('{{USER_STORE}}', storeName)
          .replaceAll('{{USER_PHONE}}', phone)
          .replaceAll('{{USER_EMAIL}}', email)
          .replaceAll('{{USER_BALANCE}}', balance.toStringAsFixed(2))
          .replaceAll('{{TOTAL_DEPOSITS}}', totalDeposits.toStringAsFixed(2))
          .replaceAll('{{TOTAL_FEES}}', totalFees.toStringAsFixed(2))
          .replaceAll('{{TOTAL_WITHDRAWALS}}', totalWithdrawals.toStringAsFixed(2))
          .replaceAll('{{ROWS}}', buffer.toString());

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/statement_${widget.user['id']}.html');
      await file.writeAsString(html);

      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(Uri.parse('file://${file.path}'));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير كشف الحساب بنجاح وفتحه في المتصفح للطباعة'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تصدير كشف الحساب: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _getUserStatementHtmlTemplate() {
    return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
    <meta charset="UTF-8">
    <title>كشف الحساب المالي للمستخدم - We Deliver</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f6fa; color: #2f3640; padding: 30px; }
        .invoice-card { background: #fff; max-width: 900px; margin: 0 auto; padding: 40px; border-radius: 15px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); border: 1px solid #e1e2e6; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #f1f2f6; padding-bottom: 20px; }
        .header h1 { color: #004aad; margin: 0; font-size: 26px; }
        .header .logo { font-size: 24px; font-weight: 800; color: #004aad; }
        .user-details { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin-top: 30px; background: #f8f9fa; padding: 20px; border-radius: 10px; border: 1px solid #e1e2e6; }
        .user-details div { font-size: 14px; color: #2f3640; }
        .user-details div span { font-weight: bold; color: #718093; margin-left: 5px; }
        .stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-top: 30px; }
        .stat-box { background: #f8f9fa; border: 1px solid #e1e2e6; padding: 15px; border-radius: 10px; text-align: center; }
        .stat-box h3 { margin: 0; font-size: 12px; color: #718093; }
        .stat-box p { margin: 8px 0 0; font-size: 18px; font-weight: 800; color: #2f3640; }
        .stat-box.highlight { border-color: #f78710; background: rgba(247, 135, 16, 0.02); }
        .stat-box.highlight p { color: #f78710; }
        table { width: 100%; border-collapse: collapse; margin-top: 40px; }
        th, td { padding: 12px 15px; text-align: right; border-bottom: 1px solid #f1f2f6; font-size: 13px; }
        th { background-color: #004aad; color: white; font-weight: 600; }
        .footer { margin-top: 50px; text-align: center; font-size: 12px; color: #a5b1c2; border-top: 1px solid #f1f2f6; padding-top: 20px; }
        @media print {
            body { background-color: white; padding: 0; }
            .invoice-card { box-shadow: none; border: none; padding: 0; }
        }
    </style>
</head>
<body>
    <div class="invoice-card">
        <div class="header">
            <div>
                <h1>كشف حساب المحفظة التفصيلي</h1>
                <p style="margin: 5px 0 0; color: #718093; font-size: 13px;">تاريخ الاستخراج: {{DATE}}</p>
            </div>
            <div class="logo">We Deliver</div>
        </div>
        <div class="user-details">
            <div><span>الاسم بالكامل:</span> {{USER_NAME}}</div>
            <div><span>الصفة / الدور:</span> {{USER_ROLE}}</div>
            <div><span>اسم المتجر:</span> {{USER_STORE}}</div>
            <div><span>رقم الهاتف:</span> {{USER_PHONE}}</div>
            <div><span>البريد الإلكتروني:</span> {{USER_EMAIL}}</div>
            <div><span>رصيد المحفظة الحالي:</span> {{USER_BALANCE}} ج.م</div>
        </div>
        <div class="stats-grid">
            <div class="stat-box">
                <h3>إجمالي شحن المحفظة</h3>
                <p>{{TOTAL_DEPOSITS}} ج.م</p>
            </div>
            <div class="stat-box">
                <h3>إجمالي رسوم العمليات والتوصيل</h3>
                <p>{{TOTAL_FEES}} ج.م</p>
            </div>
            <div class="stat-box highlight">
                <h3>إجمالي عمليات السحب المالي</h3>
                <p>{{TOTAL_WITHDRAWALS}} ج.م</p>
            </div>
        </div>
        <table>
            <thead>
                <tr>
                    <th>تفاصيل الحركة المالية</th>
                    <th>قيمة الحركة</th>
                    <th>نوع الحركة</th>
                    <th>حالة الحركة</th>
                    <th>التاريخ والوقت</th>
                </tr>
            </thead>
            <tbody>
                {{ROWS}}
            </tbody>
        </table>
        <div class="footer">
            <p>هذا الكشف تم إنشاؤه تلقائياً وهو صالح كوثيقة إثبات مالي رسمية لـ We Deliver.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: isDark ? const Color(0xFF14142a) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: isWide ? 600.w : double.infinity,
          height: 650.h,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14142a) : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section (User Profile summary)
              _buildHeader(),
              Divider(color: isDark ? Colors.white10 : Colors.black12, height: 24),
              
              // Transactions History List
              Expanded(
                child: _isLoading && _transactions.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _error != null
                        ? _buildErrorWidget()
                        : _transactions.isEmpty
                            ? _buildEmptyWidget()
                            : _buildTransactionsList(),
              ),

              if (_page < _totalPages && !_isLoading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _page++;
                        });
                        _loadUserTransactions(loadMore: true);
                      },
                      icon: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.primary2),
                      label: const Text('تحميل المزيد', style: TextStyle(color: AppColors.primary2)),
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = widget.user['name'] ?? '';
    final role = widget.user['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر';
    final storeName = widget.user['storeName'] ?? '';
    final balance = (widget.user['walletBalance'] as num?)?.toDouble() ?? 0.0;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.primary2.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary2, size: 24.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
              const SizedBox(height: 4),
              Text(
                storeName.isNotEmpty ? '$role  •  متجر: $storeName' : role,
                style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 10.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.print_rounded, color: AppColors.primary2),
          tooltip: 'تصدير كشف حساب محلي',
          onPressed: _exportUserStatement,
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: Text(
            '${balance.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w900,
              fontSize: 12.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final title = tx['title'] ?? '';
        final date = tx['date'] ?? '';
        final status = tx['status'] ?? 'success';

        final typeStr = _getTransactionTypeLabelStatic(tx);
        final typeColor = _getTransactionTypeColorStatic(tx);
        final isDeposit = tx['type'] == 'deposit';

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
          ),
          child: Row(
            children: [
              Container(
                width: 6.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 11.sp, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          typeStr,
                          style: TextStyle(color: typeColor, fontSize: 9.sp, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: TextStyle(color: isDark ? Colors.white24 : const Color(0xFFBDBDBD), fontSize: 9.sp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.sp,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusBadge(status),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    String label;
    switch (status) {
      case 'success':
        color = AppColors.success;
        label = 'ناجحة';
        break;
      case 'pending':
        color = AppColors.secondary;
        label = 'معلقة';
        break;
      case 'failed':
        color = AppColors.error;
        label = 'فاشلة';
        break;
      default:
        color = isDark ? Colors.white24 : const Color(0xFFBDBDBD);
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Text(
        _error!,
        style: TextStyle(color: AppColors.error, fontSize: 11.sp),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEmptyWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Text(
        'لا توجد عمليات مسجلة لهذه المحفظة.',
        style: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF9E9E9E), fontSize: 11.sp),
      ),
    );
  }

  String _getTransactionTypeLabelStatic(Map<String, dynamic> tx) {
    final type = tx['type']?.toString();
    final paymentMethod = tx['paymentMethod']?.toString() ?? '';
    final title = tx['title']?.toString() ?? '';

    if (type == 'deposit') {
      if (title.contains('رسوم') ||
          title.contains('توصيل') ||
          title.contains('طلب') ||
          title.contains('شحنة')) {
        return 'إيداع رسوم دفع';
      } else {
        return 'إيداع شحن محفظة';
      }
    } else if (type == 'withdraw') {
      if (title.contains('رسوم') ||
          title.contains('توصيل') ||
          title.contains('دفع')) {
        return 'إيداع رسوم دفع';
      } else if (paymentMethod == 'wallet' || paymentMethod == 'bank') {
        return 'طلب سحب';
      } else {
        return 'طلب دفع / خصم';
      }
    }
    return type ?? '';
  }

  Color _getTransactionTypeColorStatic(Map<String, dynamic> tx) {
    final type = tx['type']?.toString();
    final paymentMethod = tx['paymentMethod']?.toString() ?? '';
    final title = tx['title']?.toString() ?? '';

    if (type == 'deposit') {
      if (title.contains('رسوم') ||
          title.contains('توصيل') ||
          title.contains('طلب') ||
          title.contains('شحنة')) {
        return AppColors.info;
      } else {
        return AppColors.success;
      }
    } else if (type == 'withdraw') {
      if (title.contains('رسوم') ||
          title.contains('توصيل') ||
          title.contains('دفع')) {
        return AppColors.info;
      } else if (paymentMethod == 'wallet' || paymentMethod == 'bank') {
        return AppColors.secondary;
      } else {
        return AppColors.error;
      }
    }
    return Colors.white54;
  }
}

class _AddBalanceDialog extends StatefulWidget {
  final Map<String, dynamic> user;

  const _AddBalanceDialog({required this.user});

  @override
  State<_AddBalanceDialog> createState() => _AddBalanceDialogState();
}

class _AddBalanceDialogState extends State<_AddBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final dioConsumer = sl<DioConsumer>();
      final response = await dioConsumer.post(
        EndPoint.adminWalletDeposit,
        data: {
          'userId': widget.user['id'],
          'amount': double.parse(_amountController.text.trim()),
          'notes': _notesController.text.trim(),
        },
      );

      if (response != null && response['status'] == 1) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final msg = response?['message']?.toString() ?? 'حدث خطأ أثناء شحن الرصيد';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(msg),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('حدث خطأ: $e'),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = widget.user['name'] ?? '';
    final role = widget.user['role'] == 'captain' ? 'كابتن / مندوب' : 'تاجر';
    final storeName = widget.user['storeName'] ?? '';
    final balance = (widget.user['walletBalance'] as num?)?.toDouble() ?? 0.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: isDark ? const Color(0xFF14142a) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: isWide ? 500.w : double.infinity,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14142a) : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_card_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'إضافة رصيد للمحفظة',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? Colors.white54 : AppColors.textSecondary),
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? Colors.white10 : Colors.black12, height: 24),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Text(
                              role,
                              style: TextStyle(
                                color: widget.user['role'] == 'captain'
                                    ? AppColors.primary2
                                    : AppColors.primary,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (storeName.isNotEmpty) ...[
                              Text(
                                '  •  متجر: $storeName',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الرصيد الحالي:',
                              style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 11),
                            ),
                            Text(
                              '${balance.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'قيمة الرصيد المراد إضافته (ج.م) *',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'أدخل قيمة المبلغ مثل 150.50',
                      hintStyle: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF9E9E9E)),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.success),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال المبلغ';
                      }
                      final amt = double.tryParse(value);
                      if (amt == null || amt <= 0) {
                        return 'يجب إدخال مبلغ أكبر من الصفر';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'ملاحظات إضافية (اختياري)',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'اكتب سبب إضافة الرصيد أو أي ملاحظات أخرى للعملية...',
                      hintStyle: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF9E9E9E)),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary2),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'تأكيد إضافة الرصيد',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white60 : AppColors.textSecondary,
                            side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
