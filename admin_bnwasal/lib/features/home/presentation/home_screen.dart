// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:intl/intl.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/theme/theme_cubit.dart';
import 'package:admin_bnwasal/core/theme/theme_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../auth/presentation/cubit/auth_state.dart';
import 'cubit/navigation_cubit.dart';
import 'cubit/navigation_state.dart';
import 'widgets/side_menu.dart';
import 'pages/placeholder_page.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../merchants/presentation/pages/merchants_list_screen.dart';
import '../../merchants/presentation/pages/merchant_detail_screen.dart';
import '../../captains/presentation/pages/captains_list_screen.dart';
import '../../captains/presentation/pages/captain_detail_screen.dart';
import '../../trips/presentation/pages/trips_list_screen.dart';
import '../../pending_accounts/presentation/pages/pending_accounts_list_screen.dart';
import '../../dashboard/presentation/pages/today_orders_shipments_screen.dart';
import '../../dashboard/presentation/pages/all_orders_shipments_screen.dart';
import '../../dashboard/presentation/pages/order_detail_screen.dart';
import '../../dashboard/presentation/pages/shipment_detail_screen.dart';
import '../../trips/presentation/pages/today_trips_screen.dart';
import '../../complaints/presentation/pages/complaints_screen.dart';
import '../../notifications/presentation/pages/notifications_screen.dart';
import '../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../notifications/presentation/cubit/notifications_state.dart';
import '../../send_notification/presentation/pages/send_notification_screen.dart';
import '../../settings/presentation/pages/settings_screen.dart';
import '../../settings/presentation/cubit/payment_methods_cubit.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart';
import 'pages/profile_screen.dart';
import '../../employees/presentation/pages/employees_list_screen.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../../withdrawals/presentation/pages/admin_withdrawals_screen.dart';
import '../../wallet/presentation/pages/admin_wallet_screen.dart';
import '../../user_messages/presentation/pages/user_messages_screen.dart';
import '../../user_messages/presentation/cubit/user_messages_cubit.dart';
import '../../user_messages/presentation/cubit/user_messages_state.dart';
import '../../payments/presentation/pages/admin_direct_payments_screen.dart';
import '../../coupons/presentation/pages/coupons_screen.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _menuController;
  bool _showNotifDropdown = false;

  // Search Variables
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _searchLayerLink = LayerLink();
  final TextEditingController _searchController = TextEditingController();
  OverlayEntry? _searchOverlayEntry;
  bool _isSearching = false;
  Map<String, List<Map<String, dynamic>>>? _searchResults;
  Timer? _searchDebounceTimer;
  bool _showMobileSearch = false;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _searchController.addListener(_onSearchTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = context.read<AuthCubit>().state;
      final navCubit = context.read<NavigationCubit>();
      final initial = navCubit.initialPageForUser(authState.user);
      navCubit.navigateTo(initial);

      // Load user messages and notifications to populate counters in the top bar
      context.read<UserMessagesCubit>().loadMessages();
    });
  }

  @override
  void dispose() {
    _menuController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.removeListener(_onSearchTextChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _hideSearchOverlay();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      if (_searchController.text.trim().isNotEmpty) {
        _showSearchOverlay();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_searchFocusNode.hasFocus) {
          _hideSearchOverlay();
        }
      });
    }
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    if (_searchDebounceTimer?.isActive ?? false) _searchDebounceTimer!.cancel();

    if (query.isEmpty) {
      _updateSearchState(() {
        _searchResults = null;
        _isSearching = false;
      });
      _hideSearchOverlay();
    } else {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && _searchController.text.trim().isNotEmpty) {
          _performSearch(_searchController.text.trim());
        }
      });
    }
  }

  void _updateSearchState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
      _searchOverlayEntry?.markNeedsBuild();
    }
  }

  void _showSearchOverlay() {
    if (_searchOverlayEntry != null) {
      _searchOverlayEntry!.markNeedsBuild();
      return;
    }
    _searchOverlayEntry = _createSearchOverlayEntry();
    Overlay.of(context).insert(_searchOverlayEntry!);
  }

  void _hideSearchOverlay() {
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
  }

  OverlayEntry _createSearchOverlayEntry() {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Positioned(
          width: isWide ? 450.w : MediaQuery.of(context).size.width - 32.w,
          child: CompositedTransformFollower(
            link: _searchLayerLink,
            showWhenUnlinked: false,
            offset: Offset(isWide ? 0 : -16.w, 50.h),
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface,
              child: Container(
                constraints: BoxConstraints(maxHeight: 450.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.shade300,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildSearchResultsList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _performSearch(String query) async {
    _updateSearchState(() {
      _isSearching = true;
      _searchResults = null;
    });
    _showSearchOverlay();

    try {
      final dio = sl<DioConsumer>();
      final responses = await Future.wait([
        dio.get(
          EndPoint.adminAllOrdersShipments,
          queryParameters: {'search': query, 'limit': 15},
        ),
        dio.get(
          EndPoint.adminMerchants,
          queryParameters: {'search': query, 'limit': 15},
        ),
        dio.get(
          EndPoint.adminCaptains,
          queryParameters: {'search': query, 'limit': 15},
        ),
      ]);

      List<Map<String, dynamic>> orders = [];
      List<Map<String, dynamic>> shipments = [];
      if (responses[0] != null &&
          responses[0]['status'] == 1 &&
          responses[0]['data'] != null) {
        final items = responses[0]['data']['items'] as List<dynamic>? ?? [];
        for (var item in items) {
          final map = Map<String, dynamic>.from(item);
          if (map['itemType'] == 'order') {
            orders.add(map);
          } else {
            shipments.add(map);
          }
        }
      }

      List<Map<String, dynamic>> merchants = [];
      if (responses[1] != null &&
          responses[1]['status'] == 1 &&
          responses[1]['data'] != null) {
        final items = responses[1]['data']['items'] as List<dynamic>? ?? [];
        for (var item in items) {
          merchants.add(Map<String, dynamic>.from(item));
        }
      }

      List<Map<String, dynamic>> captains = [];
      if (responses[2] != null &&
          responses[2]['status'] == 1 &&
          responses[2]['data'] != null) {
        final items = responses[2]['data']['items'] as List<dynamic>? ?? [];
        for (var item in items) {
          captains.add(Map<String, dynamic>.from(item));
        }
      }

      _updateSearchState(() {
        _searchResults = {
          'orders': orders,
          'shipments': shipments,
          'merchants': merchants,
          'captains': captains,
        };
      });
    } catch (e) {
      debugPrint('Error performing search: $e');
      _updateSearchState(() {
        _searchResults = {
          'orders': [],
          'shipments': [],
          'merchants': [],
          'captains': [],
        };
      });
    } finally {
      _updateSearchState(() {
        _isSearching = false;
      });
    }
  }

  Widget _buildSearchResultsList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isSearching) {
      return Container(
        height: 120.h,
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      );
    }

    if (_searchResults == null) {
      return const SizedBox.shrink();
    }

    final orders = _searchResults!['orders'] ?? [];
    final shipments = _searchResults!['shipments'] ?? [];
    final merchants = _searchResults!['merchants'] ?? [];
    final captains = _searchResults!['captains'] ?? [];

    final hasResults =
        orders.isNotEmpty ||
        shipments.isNotEmpty ||
        merchants.isNotEmpty ||
        captains.isNotEmpty;

    if (!hasResults) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40.sp,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            SizedBox(height: 8.h),
            Text(
              'لا توجد نتائج بحث تطابق استعلامك',
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      children: [
        if (orders.isNotEmpty) ...[
          _buildCategoryHeader('الطلبات (${orders.length})'),
          ...orders.map(
            (item) => _buildResultItem(
              icon: Icons.receipt_long_rounded,
              iconColor: AppColors.primary,
              title:
                  'طلب رقم #${item['number'] ?? item['orderNumber'] ?? item['id']}',
              subtitle:
                  'العميل: ${item['clientName'] ?? 'غير معروف'} | التاجر: ${item['merchantName'] ?? 'غير معروف'}',
              status: item['status']?.toString() ?? '',
              onTap: () => _openOrderDetails(item),
            ),
          ),
        ],
        if (shipments.isNotEmpty) ...[
          _buildCategoryHeader('الشحنات (${shipments.length})'),
          ...shipments.map(
            (item) => _buildResultItem(
              icon: Icons.local_shipping_rounded,
              iconColor: AppColors.success,
              title:
                  'شحنة رقم #${item['number'] ?? item['shipmentNumber'] ?? item['id']}',
              subtitle:
                  'المرسل: ${item['merchantName'] ?? 'غير معروف'} | السعر: ${item['price'] ?? 0} ر.س',
              status: item['status']?.toString() ?? '',
              onTap: () => _openShipmentDetails(item),
            ),
          ),
        ],
        if (merchants.isNotEmpty) ...[
          _buildCategoryHeader('التجار (${merchants.length})'),
          ...merchants.map(
            (item) => _buildResultItem(
              icon: Icons.store_rounded,
              iconColor: AppColors.secondary,
              title: item['storeName'] ?? item['name'] ?? 'تاجر بدون اسم',
              subtitle:
                  'الهاتف: ${item['phone'] ?? 'لا يوجد'} | البريد: ${item['email'] ?? 'لا يوجد'}',
              status: item['status']?.toString() ?? '',
              onTap: () => _openMerchantDetails(item),
            ),
          ),
        ],
        if (captains.isNotEmpty) ...[
          _buildCategoryHeader('الكباتن (${captains.length})'),
          ...captains.map(
            (item) => _buildResultItem(
              icon: Icons.directions_car_rounded,
              iconColor: Colors.purple,
              title: item['name'] ?? 'كابتن بدون اسم',
              subtitle:
                  'الهاتف: ${item['phone'] ?? 'لا يوجد'} | اللوحة: ${item['plate'] ?? 'لا يوجد'}',
              status: item['status']?.toString() ?? '',
              onTap: () => _openCaptainDetails(item),
            ),
          ),
        ],
      ],
    );
  }

  void _openOrderDetails(Map<String, dynamic> item) {
    _hideSearchOverlay();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showMobileSearch = false;
    });

    final Map<String, dynamic> order = {
      'id': item['id'],
      'orderNumber': item['number'] ?? item['orderNumber'],
      'details': item['description'] ?? item['details'],
      'clientName': item['clientName'],
      'phone': item['phone'],
      'deliveryAddress': item['address'] ?? item['deliveryAddress'],
      'orderPrice': item['price'] ?? item['orderPrice'],
      'deliveryFee': item['deliveryFee'],
      'status': item['status'],
      'createdAt': item['createdAt'],
      'merchantName': item['merchantName'],
      'captainName': item['captainName'],
    };

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
  }

  void _openShipmentDetails(Map<String, dynamic> item) {
    _hideSearchOverlay();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showMobileSearch = false;
    });

    final Map<String, dynamic> shipment = {
      'id': item['id'],
      'shipmentNumber': item['number'] ?? item['shipmentNumber'],
      'title': item['description'] ?? item['title'],
      'fromAddress': item['fromAddress'] ?? item['address'],
      'toAddress': item['toAddress'],
      'price': item['price'],
      'weight': item['weight'],
      'status': item['status'],
      'createdAt': item['createdAt'],
      'merchantName': item['merchantName'],
      'driverName': item['captainName'] ?? item['driverName'],
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShipmentDetailScreen(shipment: shipment),
      ),
    );
  }

  void _openMerchantDetails(Map<String, dynamic> item) {
    _hideSearchOverlay();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showMobileSearch = false;
    });

    final int? id = int.tryParse(item['id']?.toString() ?? '');
    if (id != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MerchantDetailScreen(merchantId: id)),
      );
    }
  }

  void _openCaptainDetails(Map<String, dynamic> item) {
    _hideSearchOverlay();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showMobileSearch = false;
    });

    final int? id = int.tryParse(item['id']?.toString() ?? '');
    if (id != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CaptainDetailScreen(captainId: id)),
      );
    }
  }

  Widget _buildCategoryHeader(String title) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[100],
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white60 : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildResultItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (status.isNotEmpty) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _getSearchResultStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.bold,
                    color: _getSearchResultStatusColor(status),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getSearchResultStatusColor(String status) {
    status = status.toLowerCase().trim();
    if (status.contains('pending') ||
        status.contains('awaiting') ||
        status.contains('review')) {
      return AppColors.warning;
    }
    if (status.contains('negotiation') ||
        status.contains('assigned') ||
        status.contains('transit') ||
        status.contains('picked') ||
        status.contains('progress')) {
      return AppColors.info;
    }
    if (status.contains('delivered') || status.contains('completed')) {
      return AppColors.success;
    }
    if (status.contains('cancelled') ||
        status.contains('rejected') ||
        status.contains('failed')) {
      return AppColors.error;
    }
    return AppColors.secondary;
  }

  void _toggleMenu() {
    if (_menuController.isCompleted) {
      _menuController.reverse();
    } else {
      _menuController.forward();
    }
  }

  void _toggleNotifDropdown() {
    setState(() {
      _showNotifDropdown = !_showNotifDropdown;
    });
    if (!_showNotifDropdown) {
      context.read<NavigationCubit>().closeMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    if (isWide) {
      return _buildWideLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildWideLayout() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          SideMenu(isRail: false),
          Container(
            width: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildPageContent()),
                  ],
                ),
                _buildNotifOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: BlocListener<NavigationCubit, NavigationState>(
        listenWhen: (prev, next) => prev.isMenuOpen != next.isMenuOpen,
        listener: (context, state) {
          if (state.isMenuOpen) {
            _menuController.forward();
          } else {
            _menuController.reverse();
          }
        },
        child: Stack(
          children: [
            // Content layer
            AnimatedBuilder(
              animation: _menuController,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(
                      -_menuController.value *
                          MediaQuery.of(context).size.width *
                          0.7,
                      0.0,
                      0.0,
                    )
                    ..scale(1.0 - _menuController.value * 0.08),
                  child: child,
                );
              },
              child: RepaintBoundary(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _buildPageContent()),
                  ],
                ),
              ),
            ),
            // Menu overlay
            AnimatedBuilder(
              animation: _menuController,
              builder: (context, child) {
                return IgnorePointer(
                  ignoring:
                      !_menuController.isCompleted &&
                      !_menuController.isAnimating,
                  child: GestureDetector(
                    onTap: _toggleMenu,
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: 0.4 * _menuController.value,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Menu drawer
            AnimatedBuilder(
              animation: _menuController,
              builder: (context, child) {
                return FractionalTranslation(
                  translation: Offset(1.0 - _menuController.value, 0.0),
                  child: child,
                );
              },
              child: RepaintBoundary(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.75,
                  child: SideMenu(onClose: _toggleMenu),
                ),
              ),
            ),
            // Notification dropdown
            _buildNotifOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifOverlay() {
    if (!_showNotifDropdown) return const SizedBox.shrink();
    return Stack(
      children: [
        GestureDetector(
          onTap: _toggleNotifDropdown,
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
        _buildNotifDropdown(),
      ],
    );
  }

  Widget _buildNotifDropdown() {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
        width: isWide ? 420.w : MediaQuery.of(context).size.width - 32.w,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (ctx, state) {
            if (state.isLoading) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                ),
              );
            }
            final notifs = state.notifications.take(10).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNotifHeader(state.unreadCount, notifs.length, ctx),
                if (notifs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.solidBellSlash,
                          size: 36,
                          color: isDark ? Colors.white : Colors.black38,
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          'لا توجد إشعارات',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: notifs.length,
                      itemBuilder: (_, i) => _buildNotifItem(notifs[i], ctx),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotifHeader(int unread, int total, BuildContext ctx) {
    final theme = Theme.of(ctx);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'الإشعارات',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(width: 8.w),
          if (unread > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unread',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const Spacer(),
          if (unread > 0)
            GestureDetector(
              onTap: () => ctx.read<NotificationsCubit>().markAllAsRead(),
              child: Text(
                'تحديد الكل',
                style: TextStyle(fontSize: 11.sp, color: AppColors.primary),
              ),
            ),
          if (total > 0) ...[
            SizedBox(width: 12.w),
            GestureDetector(
              onTap: () {
                ctx.read<NotificationsCubit>().clearAll();
                _toggleNotifDropdown();
              },
              child: Text(
                'حذف الكل',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.red.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotifItem(Map<String, dynamic> notif, BuildContext ctx) {
    final title = notif['title']?.toString() ?? '';
    final body = notif['body']?.toString() ?? '';
    final isRead = notif['isRead'] == 1 || notif['isRead'] == true;
    final id = notif['id'].toString();
    final createdAt = notif['createdAt']?.toString() ?? '';
    final category = notif['category']?.toString() ?? 'system';
    final theme = Theme.of(ctx);
    final isDark = theme.brightness == Brightness.dark;

    FaIconData icon;
    Color iconColor;
    switch (category) {
      case 'warning':
        icon = FontAwesomeIcons.triangleExclamation;
        iconColor = const Color.fromARGB(255, 255, 208, 0);
        break;
      case 'order':
        icon = FontAwesomeIcons.receipt;
        iconColor = AppColors.primary;
        break;
      case 'shipment':
        icon = FontAwesomeIcons.truck;
        iconColor = AppColors.success;
        break;
      case 'complaint':
        icon = FontAwesomeIcons.commentDots;
        iconColor = AppColors.error;
        break;
      default:
        icon = FontAwesomeIcons.solidBell;
        iconColor = const Color.fromARGB(255, 255, 208, 0);
    }

    return GestureDetector(
      onTap: () {
        if (!isRead) ctx.read<NotificationsCubit>().markAsRead(id);
        _showNotifDetail(context, notif);
        _toggleNotifDropdown();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isRead
              ? Colors.transparent
              : theme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: FaIcon(icon, color: iconColor, size: 14.sp),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (createdAt.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        _fmtNotifDate(createdAt),
                        style: TextStyle(
                          fontSize: 8.sp,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () =>
                  ctx.read<NotificationsCubit>().deleteNotification(id),
              child: Icon(Icons.close, size: 14.sp, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifDetail(BuildContext ctx, Map<String, dynamic> notif) {
    final title = notif['title']?.toString() ?? '';
    final body = notif['body']?.toString() ?? '';
    final createdAt = notif['createdAt']?.toString() ?? '';
    final theme = Theme.of(ctx);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              body,
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black.withValues(alpha: 0.7),
                height: 1.6,
              ),
            ),
            if (createdAt.isNotEmpty) ...[
              SizedBox(height: 16.h),
              Text(
                _fmtNotifDate(createdAt),
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  String _fmtNotifDate(String date) {
    try {
      final dt = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
      if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }

  Widget _buildTopBar() {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    if (isWide) {
      return _buildWideTopBar();
    }
    return _buildMobileTopBar();
  }

  Widget _buildWideTopBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Right Side (RTL Start) - Menu & Date
          GestureDetector(
            onTap: _toggleMenu,
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: _menuController,
                builder: (_, _) {
                  return Icon(
                    _menuController.isCompleted
                        ? Icons.close
                        : Icons.menu_rounded,
                    color: isDark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.black.withOpacity(0.6),
                    size: 20.sp,
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 16.w),
          const _DateTimeWidget(),

          const Spacer(),

          // Center - Search Bar
          CompositedTransformTarget(
            link: _searchLayerLink,
            child: SizedBox(
              width: 450.w,
              height: 44.h,

              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white : Colors.black87,
                ),

                decoration: InputDecoration(
                  hintText: 'بحث عن طلب، تاجر، كابتن...',
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white30 : Colors.black,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white60 : Colors.black,
                    size: 20.sp,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _hideSearchOverlay();
                          },
                          child: Icon(
                            Icons.clear_rounded,
                            color: isDark ? Colors.white60 : Colors.grey[300],
                            size: 16.sp,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Left Side (RTL End) - Theme Switcher, Messages, Notifications, User details, Avatar
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, themeState) {
              final currentMode = themeState.themeMode;
              FaIconData iconData;
              if (currentMode == ThemeMode.dark) {
                iconData = FontAwesomeIcons.lightbulb;
              } else if (currentMode == ThemeMode.light) {
                iconData = FontAwesomeIcons.solidLightbulb;
              } else {
                iconData = FontAwesomeIcons.lightbulb;
              }
              return GestureDetector(
                onTap: () => context.read<ThemeCubit>().toggleTheme(),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.03),
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(
                    iconData,
                    color: isDark ? Colors.yellow : Colors.grey[800],
                    size: 20.sp,
                  ),
                ),
              );
            },
          ),
          SizedBox(width: 12.w),

          // Messages icon with badge
          BlocBuilder<UserMessagesCubit, UserMessagesState>(
            builder: (context, msgState) {
              final unreadMessagesCount = msgState.messages.length;
              return GestureDetector(
                onTap: () {
                  context.read<NavigationCubit>().navigateTo(
                    AppPage.userMessages,
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.black.withOpacity(0.03),
                        shape: BoxShape.circle,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.message,
                        color: isDark ? Colors.white : const Color(0xFF1E272E),
                        size: 20.sp,
                      ),
                    ),
                    if (unreadMessagesCount > 0)
                      Positioned(
                        top: -4.h,
                        right: -4.w,
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFef4444),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16.w,
                            minHeight: 16.w,
                          ),
                          child: Center(
                            child: Text(
                              unreadMessagesCount > 99
                                  ? '99+'
                                  : '$unreadMessagesCount',
                              style: TextStyle(
                                fontSize: 8.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 12.w),

          // Notifications Icon with badge
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (ctx, notifState) {
              final unread = notifState.unreadCount;
              return GestureDetector(
                onTap: _toggleNotifDropdown,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: _showNotifDropdown
                            ? AppColors.primary.withOpacity(0.15)
                            : (isDark
                                  ? Colors.white.withOpacity(0.03)
                                  : Colors.black.withOpacity(0.03)),
                        shape: BoxShape.circle,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.bell,
                        color: _showNotifDropdown
                            ? AppColors.primary
                            : (isDark ? Colors.white : const Color(0xFF1E272E)),
                        size: 20.sp,
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -4.h,
                        right: -4.w,
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFef4444),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16.w,
                            minHeight: 16.w,
                          ),
                          child: Center(
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: TextStyle(
                                fontSize: 8.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 16.w),

          // Profile text & Avatar
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final user = authState.user;
              final imgUrl = user?['profileImage']?.toString();
              final name = user != null
                  ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                        .trim()
                  : 'مدير النظام';
              final finalName = name.isEmpty ? 'مدير النظام' : name;
              final role = user?['role']?.toString() ?? 'admin';
              final roleLabel = role == 'admin' ? 'مدير عام' : 'موظف في المنصة';

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        finalName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E272E),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            roleLabel,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14.sp,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(width: 10.w),
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          context.read<NavigationCubit>().navigateTo(
                            AppPage.profile,
                          );
                        },
                        child: Container(
                          width: 38.w,
                          height: 38.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: imgUrl != null && imgUrl.isNotEmpty
                                ? Image.network(
                                    EndPoint.getCleanImageUrl(imgUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.person),
                                  )
                                : const Icon(Icons.person),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.black : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTopBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_showMobileSearch) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                _hideSearchOverlay();
                _searchController.clear();
                setState(() {
                  _showMobileSearch = false;
                });
              },
              child: Container(
                padding: EdgeInsets.all(8.w),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: isDark ? Colors.white60 : Colors.black87,
                  size: 20.sp,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: CompositedTransformTarget(
                link: _searchLayerLink,
                child: Container(
                  height: 38.h,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'بحث...',
                      hintStyle: TextStyle(
                        fontSize: 12.sp,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                        size: 16.sp,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleMenu,
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: _menuController,
                builder: (_, _) {
                  return Icon(
                    _menuController.isCompleted
                        ? Icons.close
                        : Icons.menu_rounded,
                    color: isDark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.black.withOpacity(0.6),
                    size: 20.sp,
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 12.w),
          BlocBuilder<NavigationCubit, NavigationState>(
            builder: (context, state) {
              return Text(
                _pageTitle(state.currentPage),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const Spacer(),
          // Mobile search toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _showMobileSearch = true;
              });
              _searchFocusNode.requestFocus();
            },
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.black.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white : const Color(0xFF1E272E),
                size: 20.sp,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Notification bell
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (ctx, notifState) {
              final unread = notifState.unreadCount;
              return GestureDetector(
                onTap: _toggleNotifDropdown,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: _showNotifDropdown
                            ? AppColors.primary.withOpacity(0.15)
                            : (isDark
                                  ? Colors.white.withOpacity(0.03)
                                  : Colors.black.withOpacity(0.03)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: _showNotifDropdown
                            ? AppColors.primary
                            : (isDark ? Colors.white : const Color(0xFF1E272E)),
                        size: 20.sp,
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -4.h,
                        right: -4.w,
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFef4444),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16.w,
                            minHeight: 16.w,
                          ),
                          child: Center(
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: TextStyle(
                                fontSize: 8.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 8.w),
          // Mobile profile avatar
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final user = authState.user;
              final imgUrl = user?['profileImage']?.toString();
              return GestureDetector(
                onTap: () {
                  context.read<NavigationCubit>().navigateTo(AppPage.profile);
                },
                child: Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: imgUrl != null && imgUrl.isNotEmpty
                        ? Image.network(
                            EndPoint.getCleanImageUrl(imgUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, size: 16),
                          )
                        : const Icon(Icons.person, size: 16),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent() {
    return BlocBuilder<NavigationCubit, NavigationState>(
      builder: (context, state) {
        switch (state.currentPage) {
          case AppPage.dashboard:
            return const DashboardScreen(showHeader: false);
          case AppPage.merchants:
            return const MerchantsListScreen();
          case AppPage.orders:
            return const PlaceholderPage(
              title: 'الطلبات',
              icon: Icons.receipt_long_outlined,
            );
          case AppPage.users:
            return const PlaceholderPage(
              title: 'المستخدمين',
              icon: Icons.people_outline,
            );
          case AppPage.captains:
            return const CaptainsListScreen();
          case AppPage.trips:
            return const TripsListScreen();
          case AppPage.todayOrdersShipments:
            return const TodayOrdersShipmentsScreen();
          case AppPage.allOrdersShipments:
            return const AllOrdersShipmentsScreen();
          case AppPage.coupons:
            return const CouponsScreen();
          case AppPage.todayTrips:
            return const TodayTripsScreen();
          case AppPage.pendingAccounts:
            return const PendingAccountsListScreen();
          case AppPage.complaints:
            return const ComplaintsScreen();
          case AppPage.notifications:
            return const NotificationsScreen();
          case AppPage.sendNotification:
            return const SendNotificationScreen();
          case AppPage.employees:
            return const EmployeesListScreen();
          case AppPage.profile:
            return const ProfileScreen();
          case AppPage.settings:
            return BlocProvider<PaymentMethodsCubit>(
              create: (_) => sl<PaymentMethodsCubit>()..loadMethods(),
              child: const SettingsScreen(),
            );
          case AppPage.withdrawals:
            return const AdminWithdrawalsScreen();
          case AppPage.wallet:
            return const AdminWalletScreen();
          case AppPage.userMessages:
            return const UserMessagesScreen();
          case AppPage.directPayments:
            return const AdminDirectPaymentsScreen();
        }
      },
    );
  }

  String _pageTitle(AppPage page) {
    switch (page) {
      case AppPage.dashboard:
        return 'الإحصائيات';
      case AppPage.merchants:
        return 'التجار';
      case AppPage.orders:
        return 'الطلبات';
      case AppPage.users:
        return 'المستخدمين';
      case AppPage.captains:
        return 'الكباتن';
      case AppPage.trips:
        return 'الرحلات';
      case AppPage.todayOrdersShipments:
        return 'طلبات وشحنات اليوم';
      case AppPage.allOrdersShipments:
        return 'جميع الشحنات والطلبات';
      case AppPage.todayTrips:
        return 'الرحلات اليومية';
      case AppPage.pendingAccounts:
        return 'قبول الحسابات';
      case AppPage.complaints:
        return 'الشكاوى';
      case AppPage.notifications:
        return 'الإشعارات';
      case AppPage.sendNotification:
        return 'إرسال إشعار';
      case AppPage.employees:
        return 'الموظفين';
      case AppPage.profile:
        return 'الملف الشخصي';
      case AppPage.settings:
        return 'الإعدادات';
      case AppPage.withdrawals:
        return 'طلبات السحب';
      case AppPage.wallet:
        return 'المحفظة العامة';
      case AppPage.userMessages:
        return 'رسائل المستخدمين';
      case AppPage.directPayments:
        return 'دفعات الشحنات والطلبات';
      case AppPage.coupons:
        return 'الكوبونات والخصومات';
    }
  }
}

class _DateTimeWidget extends StatefulWidget {
  const _DateTimeWidget();

  @override
  State<_DateTimeWidget> createState() => _DateTimeWidgetState();
}

class _DateTimeWidgetState extends State<_DateTimeWidget> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dateStr = DateFormat('EEEE d MMMM yyyy', 'ar').format(_now);
    final timeStr = DateFormat('hh:mm a', 'en').format(_now);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E272E),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10.sp,
                color: isDark ? Colors.white60 : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
