import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/features/shipment/presentation/manager/shipment_cubit.dart';
import 'package:we_deliver/features/order/presentation/manager/order_cubit.dart';
import 'package:we_deliver/features/shipment/domain/entities/shipment.dart';
import 'package:we_deliver/features/shipment/presentation/pages/shipment_details_screen.dart';
import 'package:we_deliver/features/shipment/presentation/pages/driver_shipment_details_screen.dart';
import 'package:we_deliver/features/order/domain/entities/order.dart';
import 'package:we_deliver/features/order/presentation/pages/order_details_screen.dart';
import 'package:we_deliver/features/shipment/presentation/pages/driver_order_details_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool isDelivery;
  const SearchScreen({super.key, this.isDelivery = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedTab = 'all'; // 'all', 'active', 'completed'
  bool _isLoading = false;
  Timer? _debounceTimer;

  late final ShipmentCubit _shipmentCubit;
  late final OrderCubit _orderCubit;

  @override
  void initState() {
    super.initState();
    _shipmentCubit = sl<ShipmentCubit>();
    _orderCubit = sl<OrderCubit>();

    _shipmentCubit.addListener(_onCubitChange);
    _orderCubit.addListener(_onCubitChange);

    _shipmentCubit.loadShipments();
    _orderCubit.loadOrders();

    // Auto focus the search input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  @override
  void dispose() {
    _shipmentCubit.removeListener(_onCubitChange);
    _orderCubit.removeListener(_onCubitChange);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onCubitChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    setState(() {
      _isLoading = true;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  // Helper logic to check if a shipment status represents active or completed
  bool _isShipmentActive(String status) {
    final s = status.trim().toLowerCase();
    final inactiveStatuses = [
      'completed',
      'منتهية',
      'منتهي',
      'cancelled',
      'ملغية',
      'ملغي',
    ];
    return !inactiveStatuses.contains(s);
  }

  // Helper logic to check if an order status represents active or completed
  bool _isOrderActive(String status) {
    final s = status.trim().toLowerCase();
    final inactiveStatuses = [
      'completed',
      'منتهي',
      'منتهية',
      'مكتملة',
      'cancelled',
      'ملغي',
      'ملغية',
      'rejected',
      'مرفوض',
    ];
    return !inactiveStatuses.contains(s);
  }

  // Filter items matching query and selected tab
  List<dynamic> _getFilteredItems() {
    final List<dynamic> allItems = [];
    allItems.addAll(_shipmentCubit.allShipments.where((s) => s.status != 'Negotiation' && s.status != 'negotiation'));
    allItems.addAll(_orderCubit.allOrders.where((o) => o.status != 'Negotiation' && o.status != 'negotiation'));

    final query = _searchController.text.trim().toLowerCase();

    // 1. Filter by search query
    var list = allItems;
    if (query.isNotEmpty) {
      list = allItems.where((item) {
        if (item is Shipment) {
          return item.shipmentNumber.toLowerCase().contains(query) ||
              (item.clientName?.toLowerCase().contains(query) ?? false) ||
              (item.driverName?.toLowerCase().contains(query) ?? false) ||
              item.fromAddress.toLowerCase().contains(query) ||
              item.toAddress.toLowerCase().contains(query);
        } else if (item is OrderEntity) {
          return item.orderNumber.toLowerCase().contains(query) ||
              item.id.toLowerCase().contains(query) ||
              item.clientName.toLowerCase().contains(query) ||
              item.details.toLowerCase().contains(query) ||
              item.deliveryAddress.toLowerCase().contains(query);
        }
        return false;
      }).toList();
    }

    // 2. Filter by category tab
    if (_selectedTab == 'active') {
      list = list.where((item) {
        if (item is Shipment) {
          return _isShipmentActive(item.status);
        } else if (item is OrderEntity) {
          return _isOrderActive(item.status);
        }
        return false;
      }).toList();
    } else if (_selectedTab == 'completed') {
      list = list.where((item) {
        if (item is Shipment) {
          return !_isShipmentActive(item.status);
        } else if (item is OrderEntity) {
          return !_isOrderActive(item.status);
        }
        return false;
      }).toList();
    }

    // Sort: Active/newer items first
    list.sort((a, b) {
      DateTime getCreatedAt(dynamic item) {
        if (item is Shipment) return item.createdAt;
        if (item is OrderEntity) return item.createdAt;
        return DateTime.now();
      }

      return getCreatedAt(b).compareTo(getCreatedAt(a));
    });

    return list;
  }

  void _navigateToDetails(dynamic item) {
    if (item is Shipment) {
      if (widget.isDelivery) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriverShipmentDetailsScreen(shipment: item),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShipmentDetailsScreen(shipment: item),
          ),
        );
      }
    } else if (item is OrderEntity) {
      if (widget.isDelivery) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriverOrderDetailsScreen(order: item),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(order: item),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final filteredList = _getFilteredItems();

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
            'البحث عن شحنة',
            style: GoogleFonts.tajawal(
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
        body: Column(
          children: [
            // Search Input Section
            Container(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF2C2C2C)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(12.w),
                            child: Icon(
                              Icons.search,
                              color: Colors.grey.shade400,
                              size: 20.sp,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (_) => _onSearchChanged(),
                              style: GoogleFonts.tajawal(
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: 'أدخل رقم الشحنة أو الطلب...',
                                hintStyle: GoogleFonts.tajawal(
                                  color: Colors.grey.shade400,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 18.sp,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Filter Section
            _buildFiltersBar(isDarkMode),

            // Results Section
            Expanded(
              child: _isLoading
                  ? _buildLoader()
                  : filteredList.isEmpty
                  ? _buildEmptyState(isDarkMode)
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        return FadeInUp(
                          duration: const Duration(milliseconds: 300),
                          child: _buildResultCard(item, isDarkMode),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersBar(bool isDarkMode) {
    final tabs = [
      {'id': 'all', 'label': 'الكل'},
      {'id': 'active', 'label': 'شحنات نشطة'},
      {'id': 'completed', 'label': 'المكتملة'},
    ];

    return Container(
      height: 52.h,
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (context, index) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = _selectedTab == tab['id'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = tab['id']!;
                _isLoading = true;
              });
              Timer(const Duration(milliseconds: 200), () {
                setState(() {
                  _isLoading = false;
                });
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDarkMode
                          ? const Color(0xFF2C2C2C)
                          : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDarkMode ? Colors.white10 : Colors.grey.shade200),
                ),
              ),
              child: Center(
                child: Text(
                  tab['label']!,
                  style: GoogleFonts.tajawal(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return FadeIn(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100.w,
                height: 100.w,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1E1E1E)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 48.sp,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'لم نجد أي نتائج تطابق بحثك',
                style: GoogleFonts.tajawal(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'تأكد من كتابة رقم الشحنة أو رقم الطلب بشكل صحيح ومحاولة البحث مرة أخرى.',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 12.sp,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(dynamic item, bool isDarkMode) {
    String title = '';
    String subTitle = '';
    String status = '';
    String amount = '';
    String route = '';
    bool isActive = false;
    String? icon;

    if (item is Shipment) {
      title = 'شحنة رقم #${item.shipmentNumber}';
      subTitle = widget.isDelivery
          ? 'العميل: ${item.clientName ?? "غير محدد"}'
          : 'المندوب: ${item.driverName ?? "قيد البحث"}';
      status = ShipmentStatus.getArabicStatus(item.status);
      isActive = _isShipmentActive(item.status);
      amount = '${item.price.toInt()} ج.م';
      route = '${item.fromAddress} ➔ ${item.toAddress}';
      icon = AppAssets.box;
    } else if (item is OrderEntity) {
      title = 'طلب رقم #${item.orderNumber.isNotEmpty ? item.orderNumber : item.id}';
      subTitle = widget.isDelivery
          ? 'التاجر: ${item.merchantName ?? item.storeDescription}'
          : 'العميل: ${item.clientName}';
      isActive = _isOrderActive(item.status);
      status = OrderStatus.getArabicStatus(item.status);
      amount = '${item.orderPrice.toInt()} ج.م';
      route = item.deliveryAddress;
      icon = AppAssets.orders;
    } else {
      return const SizedBox.shrink();
    }

    final statusColor = isActive ? AppColors.primary2 : AppColors.success;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: () => _navigateToDetails(item),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SvgPicture.asset(icon, width: 24.w, height: 24.w),
                  ),
                ),
                SizedBox(width: 12.w),

                // Info columns
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row & status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.tajawal(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.tajawal(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subTitle,
                        style: GoogleFonts.tajawal(
                          fontSize: 12.sp,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      const Divider(height: 1, color: AppColors.border),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14.sp,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              route,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.tajawal(
                                fontSize: 11.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.monetization_on_outlined,
                                size: 14.sp,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                amount,
                                style: GoogleFonts.tajawal(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'تتبع وتفاصيل',
                                style: GoogleFonts.tajawal(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary2,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10.sp,
                                color: AppColors.primary2,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
