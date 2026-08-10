// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/utils/translation_helper.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart' as di;
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_detail_screen.dart';
import 'shipment_detail_screen.dart';

class AllOrdersShipmentsScreen extends StatefulWidget {
  const AllOrdersShipmentsScreen({super.key});

  @override
  State<AllOrdersShipmentsScreen> createState() =>
      _AllOrdersShipmentsScreenState();
}

class _AllOrdersShipmentsScreenState extends State<AllOrdersShipmentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _currentPage = 1;
  final int _limit = 30;
  String _searchQuery = '';
  String _selectedType = ''; // '', 'order', 'shipment'
  String _selectedStatus = ''; // '', 'Pending Review', etc.
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _sortBy = 'newest';

  bool _isLoading = false;
  List<dynamic> _items = [];
  int _totalItems = 0;
  int _totalPages = 1;
  int _totalOrders = 0;
  int _totalShipments = 0;

  final Map<String, String> _statuses = {
    '': 'جميع الحالات',
    'Pending Review': 'قيد المراجعة',
    'Ready For Assignment': 'بانتظار تعيين مندوب',
    'Assigned To Captain': 'تم تعيين مندوب',
    'Picked Up': 'تم استلام الشحنة/شراء الطلب',
    'In Transit': 'جاري التوصيل',
    'Delivered': 'تم التوصيل',
    'Completed': 'مكتمل',
    'Cancelled': 'ملغاة',
    'Rejected': 'مرفوض',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final dio = di.sl<DioConsumer>();

      final Map<String, dynamic> queryParams = {
        'page': _currentPage,
        'limit': _limit,
        'search': _searchQuery,
        'type': _selectedType,
        'status': _selectedStatus,
        'sortBy': _sortBy,
      };

      if (_dateFrom != null) {
        queryParams['dateFrom'] =
            '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2, '0')}-${_dateFrom!.day.toString().padLeft(2, '0')}';
      }
      if (_dateTo != null) {
        queryParams['dateTo'] =
            '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2, '0')}-${_dateTo!.day.toString().padLeft(2, '0')}';
      }

      final response = await dio.get(
        EndPoint.adminAllOrdersShipments,
        queryParameters: queryParams,
      );

      if (response != null &&
          response['status'] == 1 &&
          response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        setState(() {
          _items = data['items'] as List<dynamic>;
          _totalItems = data['total'] ?? 0;
          _totalOrders = data['totalOrders'] ?? 0;
          _totalShipments = data['totalShipments'] ?? 0;
          _currentPage = data['page'] ?? 1;
          _totalPages = data['pages'] ?? 1;
        });
      }
    } catch (e) {
      debugPrint('Error loading all orders & shipments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تحميل البيانات: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      // Scroll to top on new page load
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedType = '';
      _selectedStatus = '';
      _dateFrom = null;
      _dateTo = null;
      _sortBy = 'newest';
      _currentPage = 1;
    });
    _loadData();
  }

  Future<void> _selectDateRange() async {
    final Map<String, DateTime?>? result =
        await showDialog<Map<String, DateTime?>>(
          context: context,
          builder: (BuildContext context) {
            return _CustomDateRangeDialog(
              initialDateFrom: _dateFrom,
              initialDateTo: _dateTo,
            );
          },
        );

    if (result != null) {
      setState(() {
        _dateFrom = result['dateFrom'];
        _dateTo = result['dateTo'];
        _currentPage = 1;
      });
      _loadData();
    }
  }

  Color _getStatusColor(String status) {
    status = status.trim();
    if (status == 'بانتظار القبول' ||
        status == 'قيد الانتظار' ||
        status == 'جديدة' ||
        status == 'pending' ||
        status == 'Pending Review') {
      return AppColors.warning;
    } else if (status == 'تم قبول العرض' ||
        status == 'تم القبول' ||
        status == 'جاري التوصيل' ||
        status == 'جاري التنفيذ' ||
        status == 'تم التنفيذ' ||
        status == 'ongoing' ||
        status == 'in_progress' ||
        status == 'Ready For Assignment' ||
        status == 'Assigned To Captain' ||
        status == 'Captain Arrived' ||
        status == 'Picked Up' ||
        status == 'In Transit') {
      return AppColors.info;
    } else if (status == 'منتهي' ||
        status == 'منتهية' ||
        status == 'تم التسليم' ||
        status == 'completed' ||
        status == 'Completed' ||
        status == 'Delivered') {
      return AppColors.success;
    } else if (status == 'ملغي' ||
        status == 'ملغية' ||
        status == 'مرفوض' ||
        status == 'cancelled' ||
        status == 'Cancelled' ||
        status == 'Rejected') {
      return AppColors.error;
    }
    return AppColors.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF041930)
            : const Color(0xFFf8f9fa),
        body: Column(
          children: [
            _buildHeader(isWide),
            _buildStatsGrid(),
            _buildFiltersPanel(isWide),
            Expanded(
              child: _isLoading && _items.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.secondary,
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.secondary,
                      backgroundColor: isDark
                          ? const Color(0xFF0d0d1f)
                          : Colors.white,
                      onRefresh: () async {
                        _currentPage = 1;
                        await _loadData();
                      },
                      child: _items.isEmpty
                          ? _buildEmptyState()
                          : CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 2,
                                          mainAxisExtent: MediaQuery.of(context).size.width < 600 ? 200 : 220,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                        ),
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      i,
                                    ) {
                                      final item =
                                          _items[i] as Map<String, dynamic>;
                                      if (item['itemType'] == 'order') {
                                        return _buildOrderCard(item);
                                      } else {
                                        return _buildShipmentCard(item);
                                      }
                                    }, childCount: _items.length),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: _buildPaginationControls(),
                                  ),
                                ),
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
      padding: EdgeInsets.fromLTRB(
        isWide ? 32.w : 16.w,
        20.h,
        isWide ? 32.w : 16.w,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جميع الشحنات والطلبات',
                  style: TextStyle(
                    fontSize: isWide ? 22.sp : 18.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          // Refresh indicator / status
          GestureDetector(
            onTap: _loadData,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade300,
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.secondary,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 16.sp,
                      color: isDark
                          ? Colors.white.withOpacity(0.5)
                          : Colors.black45,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _buildStatCard(
              'إجمالي السجلات',
              _totalItems.toString(),
              Icons.receipt_long_rounded,
              AppColors.secondary,
            ),
            const SizedBox(height: 8),
            _buildStatCard(
              'الطلبات الكلية',
              _totalOrders.toString(),
              Icons.receipt_long_rounded,
              AppColors.primary,
            ),
            const SizedBox(height: 8),
            _buildStatCard(
              'الشحنات الكلية',
              _totalShipments.toString(),
              Icons.local_shipping_rounded,
              AppColors.success,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'إجمالي السجلات',
              _totalItems.toString(),
              Icons.receipt_long_rounded,
              AppColors.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              'الطلبات الكلية',
              _totalOrders.toString(),
              Icons.receipt_long_rounded,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              'الشحنات الكلية',
              _totalShipments.toString(),
              Icons.local_shipping_rounded,
              AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.4)
                        : Colors.black,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14.sp, color: color),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.primary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          // Search row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: GoogleFonts.tajawal().fontFamily,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 18,
                    ),
                    fillColor: Colors.transparent,
                    hintText: 'البحث برقم السجل، اسم العميل، أو التاجر...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                  onSubmitted: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    });
                    _loadData();
                  },
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = _searchController.text.trim();
                    _currentPage = 1;
                  });
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 30.w,
                    vertical: 20.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'بحث',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // Filter options row
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Type filter
              _buildDropdown<String>(
                value: _selectedType,
                items: const {
                  '': 'الكل (طلبات وشحنات)',
                  'order': 'الطلبات فقط',
                  'shipment': 'الشحنات فقط',
                },
                onChanged: (val) {
                  setState(() {
                    _selectedType = val!;
                    _currentPage = 1;
                  });
                  _loadData();
                },
              ),

              // Status filter
              _buildDropdown<String>(
                value: _selectedStatus,
                items: _statuses,
                onChanged: (val) {
                  setState(() {
                    _selectedStatus = val!;
                    _currentPage = 1;
                  });
                  _loadData();
                },
              ),

              // Sort dropdown
              _buildDropdown<String>(
                value: _sortBy,
                items: const {
                  'newest': 'الأحدث أولاً',
                  'oldest': 'الأقدم أولاً',
                },
                onChanged: (val) {
                  setState(() {
                    _sortBy = val!;
                    _currentPage = 1;
                  });
                  _loadData();
                },
              ),

              // Date Range Selector
              GestureDetector(
                onTap: _selectDateRange,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: _dateFrom != null
                        ? AppColors.secondary.withOpacity(0.15)
                        : (isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _dateFrom != null
                          ? AppColors.secondary.withOpacity(0.3)
                          : (isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14.sp,
                        color: _dateFrom != null
                            ? AppColors.secondary
                            : (isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.black45),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _dateFrom == null
                            ? 'تصفية بالتاريخ'
                            : '${_dateFrom!.year}/${_dateFrom!.month}/${_dateFrom!.day} - ${_dateTo!.year}/${_dateTo!.month}/${_dateTo!.day}',
                        style: TextStyle(
                          color: _dateFrom != null
                              ? AppColors.secondary
                              : (isDark
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.black87),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Reset filters button
              IconButton(
                onPressed: _resetFilters,
                icon: const Icon(
                  Icons.filter_alt_off_rounded,
                  color: AppColors.error,
                ),
                tooltip: 'إعادة تعيين الفلاتر',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF0d0d1f) : Colors.white,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
          ),
          style: GoogleFonts.tajawal(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          items: items.entries.map((e) {
            return DropdownMenuItem<T>(
              value: e.key,
              child: Text(
                e.value,
                style: GoogleFonts.tajawal(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64.sp,
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black12,
          ),
          SizedBox(height: 12.h),
          Text(
            'لا توجد نتائج مطابقة للفلاتر المحددة',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10.h),
          TextButton(
            onPressed: _resetFilters,
            child: const Text(
              'إعادة تعيين الفلاتر',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final merchant = order['merchantName'] ?? '';
    final client = order['clientName'] ?? '';
    final phone = order['phone'] ?? '';
    final number = order['number'] ?? '';
    final details = order['description'] ?? '';
    final price = '${order['price'] ?? 0}';
    final fee = '${order['deliveryFee'] ?? 0}';
    final status = order['status'] ?? '';
    final statusColor = _getStatusColor(status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _HoverCardWrapper(
      onTap: () => _openOrderDetail(order),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 18.sp,
                    color: AppColors.secondary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب رقم',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isDark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        number.toString(),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showStatusChangerDialog(order, isOrder: true),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statusBadge(status, statusColor),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_rounded,
                          size: 12.sp,
                          color: isDark
                              ? Colors.white.withOpacity(0.4)
                              : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14.sp,
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black26,
                ),
              ],
            ),
            SizedBox(height: 14.h),
            if (client.isNotEmpty)
              _infoChip(
                Icons.person_outline_rounded,
                client,
                Colors.white.withOpacity(0.8),
              ),
            if (phone.isNotEmpty)
              _infoChip(
                Icons.phone_iphone_rounded,
                phone,
                Colors.white.withOpacity(0.6),
              ),
            if (details.isNotEmpty)
              _infoChip(
                Icons.description_outlined,
                details.toString().length > 60
                    ? '${details.toString().substring(0, 60)}...'
                    : details,
                Colors.white.withOpacity(0.4),
              ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _priceTag('$price ج', const Color(0xFF10b981)),
                      if (fee != '0') ...[
                        SizedBox(width: 6.w),
                        _priceTag('توصيل: $fee ج', const Color(0xFF06b6d4)),
                      ],
                    ],
                  ),
                ),
                if (merchant.isNotEmpty) ...[
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.storefront_rounded,
                    size: 12.sp,
                    color: isDark
                        ? Colors.white.withOpacity(0.25)
                        : AppColors.primary,
                  ),
                  SizedBox(width: 4.w),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      merchant.toString(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.white.withOpacity(0.35)
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentCard(Map<String, dynamic> ship) {
    final merchant = ship['merchantName'] ?? '';
    final title = ship['description'] ?? '';
    final number = ship['number'] ?? '';
    final from = ship['fromAddress'] ?? '';
    final to = ship['toAddress'] ?? '';
    final price = '${ship['price'] ?? 0}';
    final status = ship['status'] ?? '';
    final statusColor = _getStatusColor(status);
    final weight = ship['weight']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _HoverCardWrapper(
      onTap: () => _openShipmentDetail(ship),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    size: 18.sp,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شحنة رقم',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        title.isNotEmpty ? title.toString() : number.toString(),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showStatusChangerDialog(ship, isOrder: false),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statusBadge(status, statusColor),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_rounded,
                          size: 12.sp,
                          color: isDark
                              ? Colors.white.withOpacity(0.4)
                              : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14.sp,
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black26,
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _routeLine(from, to),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _priceTag('$price ج', const Color(0xFF10b981)),
                      if (weight.isNotEmpty) ...[
                        SizedBox(width: 6.w),
                        _priceTag('$weight كجم', const Color(0xFF8b5cf6)),
                      ],
                    ],
                  ),
                ),
                if (merchant.isNotEmpty) ...[
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.storefront_rounded,
                    size: 12.sp,
                    color: isDark
                        ? Colors.white.withOpacity(0.25)
                        : AppColors.primary,
                  ),
                  SizedBox(width: 4.w),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      merchant.toString(),
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.white.withOpacity(0.35)
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeLine(String from, String to) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.01) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.circle, size: 6.sp, color: AppColors.secondary),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(
                    from.isNotEmpty ? from.toString() : 'غير محدد',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark
                          ? Colors.white.withOpacity(0.55)
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Icon(
              Icons.east_rounded,
              size: 14.sp,
              color: isDark ? Colors.white.withOpacity(0.15) : Colors.black26,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 10.sp,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6.w),
                Flexible(
                  child: Text(
                    to.isNotEmpty ? to.toString() : 'غير محدد',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark
                          ? Colors.white.withOpacity(0.55)
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        TranslationHelper.getArabicStatus(status),
        style: GoogleFonts.cairo(
          fontSize: 11.sp,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14.sp,
            color: isDark ? Colors.white.withOpacity(0.25) : Colors.black,
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 12.sp,
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous Button
          IconButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                    _loadData();
                  }
                : null,
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: isDark ? Colors.white : Colors.black87,
            ),
            disabledColor: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.black12,
          ),
          SizedBox(width: 20.w),
          // Page Text
          Text(
            'صفحة $_currentPage من $_totalPages',
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 20.w),
          // Next Button
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                    _loadData();
                  }
                : null,
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? Colors.white : Colors.black87,
            ),
            disabledColor: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.black12,
          ),
        ],
      ),
    );
  }

  Future<void> _changeItemStatus(
    String id,
    String type,
    String newStatus,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      ),
    );

    try {
      final dio = di.sl<DioConsumer>();
      final url = type == 'order'
          ? EndPoint.updateOrderStatus(id)
          : EndPoint.updateShipmentStatus(id);

      await dio.put(url, data: {'status': newStatus});

      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديث الحالة إلى "${TranslationHelper.getArabicStatus(newStatus)}" بنجاح',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
        ),
      );

      _loadData();
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل تحديث الحالة: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showStatusChangerDialog(
    Map<String, dynamic> item, {
    required bool isOrder,
  }) {
    final id = item['id'].toString();
    final currentStatus = item['status'] ?? '';
    final type = isOrder ? 'order' : 'shipment';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<String> statuses = [
      'Pending Review',
      'Ready For Assignment',
      'Assigned To Captain',
      'Picked Up',
      'In Transit',
      'Delivered',
      'Completed',
      'Cancelled',
      'Rejected',
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0d0d1f) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade300,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  isOrder
                      ? Icons.receipt_long_rounded
                      : Icons.local_shipping_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'تغيير حالة السجل',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: statuses.map((status) {
                    final isCurrent = status == currentStatus;
                    final statusColor = _getStatusColor(status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? statusColor.withOpacity(0.12)
                            : (isDark
                                  ? Colors.white.withOpacity(0.02)
                                  : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? statusColor
                              : (isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.shade300),
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          TranslationHelper.getArabicStatus(status),
                          style: TextStyle(
                            color: isCurrent
                                ? (isDark
                                      ? Colors.white
                                      : AppColors.textPrimary)
                                : (isDark ? Colors.white70 : Colors.black),
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        leading: Icon(
                          isCurrent
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isCurrent
                              ? statusColor
                              : (isDark ? Colors.white30 : Colors.black),
                          size: 18,
                        ),
                        trailing: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _changeItemStatus(id, type, status);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openOrderDetail(Map<String, dynamic> item) {
    // Standardize key names to match OrderDetailScreen expected schema
    final Map<String, dynamic> order = {
      'id': item['id'],
      'orderNumber': item['number'],
      'details': item['description'],
      'clientName': item['clientName'],
      'phone': item['phone'],
      'deliveryAddress': item['address'],
      'orderPrice': item['price'],
      'deliveryFee': item['deliveryFee'],
      'status': item['status'],
      'createdAt': item['createdAt'],
      'merchantName': item['merchantName'],
      'captainName': item['captainName'],
    };

    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => OrderDetailScreen(order: order),
            transitionsBuilder: (_, a, _, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        )
        .then((_) => _loadData());
  }

  void _openShipmentDetail(Map<String, dynamic> item) {
    // Standardize key names to match ShipmentDetailScreen expected schema
    final Map<String, dynamic> shipment = {
      'id': item['id'],
      'shipmentNumber': item['number'],
      'title': item['description'],
      'fromAddress': item['fromAddress'] ?? item['address'],
      'toAddress': item['toAddress'],
      'price': item['price'],
      'weight': item['weight'],
      'status': item['status'],
      'createdAt': item['createdAt'],
      'merchantName': item['merchantName'],
      'driverName': item['captainName'],
    };

    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => ShipmentDetailScreen(shipment: shipment),
            transitionsBuilder: (_, a, _, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        )
        .then((_) => _loadData());
  }
}

// ويدجت مخصصة لإضافة تأثير التحويم (Hover) الاحترافي والتكبير البسيط عند تمرير مؤشر الماوس
class _HoverCardWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HoverCardWrapper({required this.child, required this.onTap});

  @override
  State<_HoverCardWrapper> createState() => _HoverCardWrapperState();
}

class _HoverCardWrapperState extends State<_HoverCardWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? AppColors.secondary.withOpacity(0.5)
                  : (isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.grey.shade300),
              width: _isHovered ? 1.5 : 1.0,
            ),
            gradient: LinearGradient(
              colors: [
                _isHovered
                    ? AppColors.secondary.withOpacity(0.08)
                    : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
                _isHovered
                    ? Colors.white.withOpacity(0.01)
                    : (isDark ? Colors.white.withOpacity(0.005) : Colors.white),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppColors.secondary.withOpacity(0.1)
                    : (isDark
                          ? Colors.black.withOpacity(0.12)
                          : Colors.black.withOpacity(0.04)),
                blurRadius: _isHovered ? 16 : 12,
                offset: _isHovered ? const Offset(0, 6) : const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// نافذة تصفية التاريخ المخصصة والجميلة المتوافقة مع ألوان وهوية التطبيق
class _CustomDateRangeDialog extends StatefulWidget {
  final DateTime? initialDateFrom;
  final DateTime? initialDateTo;

  const _CustomDateRangeDialog({this.initialDateFrom, this.initialDateTo});

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog> {
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initialDateFrom;
    _dateTo = widget.initialDateTo;
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      switch (preset) {
        case 'today':
          _dateFrom = today;
          _dateTo = today;
          break;
        case 'yesterday':
          _dateFrom = today.subtract(const Duration(days: 1));
          _dateTo = today.subtract(const Duration(days: 1));
          break;
        case 'last7':
          _dateFrom = today.subtract(const Duration(days: 6));
          _dateTo = today;
          break;
        case 'last30':
          _dateFrom = today.subtract(const Duration(days: 29));
          _dateTo = today;
          break;
        case 'thisMonth':
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = today;
          break;
        case 'clear':
          _dateFrom = null;
          _dateTo = null;
          break;
      }
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final initialDate = isFrom
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar'),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.secondary,
                    onPrimary: Color(0xFF070715),
                    surface: Color(0xFF0d0d1f),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppColors.secondary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.textPrimary,
                  ),
            dialogBackgroundColor: isDark
                ? const Color(0xFF0d0d1f)
                : Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
          if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
            _dateTo = _dateFrom;
          }
        } else {
          _dateTo = picked;
          if (_dateFrom != null && _dateFrom!.isAfter(_dateTo!)) {
            _dateFrom = _dateTo;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String formattedRange;
    if (_dateFrom == null) {
      formattedRange = 'لم يتم تحديد فترة زمنية بعد';
    } else if (_dateTo == null) {
      formattedRange =
          'من  ${_dateFrom!.year}/${_dateFrom!.month}/${_dateFrom!.day}  إلى  ...';
    } else {
      formattedRange =
          'من  ${_dateFrom!.year}/${_dateFrom!.month}/${_dateFrom!.day}  إلى  ${_dateTo!.year}/${_dateTo!.month}/${_dateTo!.day}';
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0d0d1f) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade300,
        ),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85 > 420
            ? 420
            : MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.secondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'تصفية حسب التاريخ',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Presets Label
            Text(
              'اختيار سريع:',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Preset Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _presetChip('اليوم', 'today'),
                _presetChip('أمس', 'yesterday'),
                _presetChip('آخر 7 أيام', 'last7'),
                _presetChip('آخر 30 يوم', 'last30'),
                _presetChip('هذا الشهر', 'thisMonth'),
              ],
            ),
            const SizedBox(height: 20),
            Divider(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade300,
            ),
            const SizedBox(height: 15),

            // Custom Range Label
            Text(
              'أو حدد فترة مخصصة:',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Custom Range Selection Row
            Row(
              children: [
                Expanded(
                  child: _datePickerButton(
                    'من تاريخ',
                    _dateFrom,
                    () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _datePickerButton(
                    'إلى تاريخ',
                    _dateTo,
                    () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current selection indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: _dateFrom != null
                    ? AppColors.secondary.withOpacity(0.05)
                    : (isDark
                          ? Colors.white.withOpacity(0.02)
                          : Colors.grey.shade50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dateFrom != null
                      ? AppColors.secondary.withOpacity(0.15)
                      : (isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.grey.shade300),
                ),
              ),
              child: Text(
                formattedRange,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _dateFrom != null
                      ? AppColors.secondary
                      : (isDark ? Colors.white60 : Colors.black),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop({'dateFrom': _dateFrom, 'dateTo': _dateTo});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: const Color(0xFF070715),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'تطبيق التصفية',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Clear / Cancel Button
                if (_dateFrom != null || _dateTo != null) ...[
                  IconButton(
                    onPressed: () {
                      _setPreset('clear');
                    },
                    icon: const Icon(Icons.delete_sweep_rounded),
                    color: AppColors.error,
                    tooltip: 'مسح التصفية',
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white60 : Colors.black54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, String presetKey) {
    bool isSelected = false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_dateFrom != null && _dateTo != null) {
      if (presetKey == 'today') {
        isSelected = _dateFrom == today && _dateTo == today;
      } else if (presetKey == 'yesterday') {
        final yesterday = today.subtract(const Duration(days: 1));
        isSelected = _dateFrom == yesterday && _dateTo == yesterday;
      } else if (presetKey == 'last7') {
        isSelected =
            _dateFrom == today.subtract(const Duration(days: 6)) &&
            _dateTo == today;
      } else if (presetKey == 'last30') {
        isSelected =
            _dateFrom == today.subtract(const Duration(days: 29)) &&
            _dateTo == today;
      } else if (presetKey == 'thisMonth') {
        isSelected =
            _dateFrom == DateTime(now.year, now.month, 1) && _dateTo == today;
      }
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _setPreset(presetKey),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary
              : (isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade300),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF070715)
                : (isDark ? Colors.white.withOpacity(0.7) : Colors.black87),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _datePickerButton(String label, DateTime? date, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? AppColors.secondary.withOpacity(0.4)
                : (isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: date != null
                  ? AppColors.secondary
                  : (isDark ? Colors.white38 : Colors.black38),
              size: 16,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  date != null
                      ? '${date.year}/${date.month}/${date.day}'
                      : 'حدد تاريخ',
                  style: TextStyle(
                    color: date != null
                        ? (isDark ? Colors.white : AppColors.textPrimary)
                        : (isDark ? Colors.white54 : Colors.black),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
