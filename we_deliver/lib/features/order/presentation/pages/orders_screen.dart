// ignore_for_file: deprecated_member_use

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import '../../../../core/theme/typography.dart';
import '../manager/order_cubit.dart';
import '../../domain/entities/order.dart';
import 'package:we_deliver/features/shipment/presentation/manager/shipment_cubit.dart';
import 'package:we_deliver/features/shipment/domain/entities/shipment.dart';
import 'package:we_deliver/features/shipment/presentation/pages/shipment_details_screen.dart';
import 'package:we_deliver/features/shipment/presentation/pages/add_shipment_screen.dart';
import 'add_order_screen.dart';
import 'order_details_screen.dart';
import 'package:we_deliver/features/stores/presentation/pages/client_store_orders_screen.dart';
import 'package:we_deliver/core/utils/image_helper.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/api/end_point.dart';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../../core/services/auth_guard.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderCubit _cubit = sl<OrderCubit>();
  final ShipmentCubit _shipmentCubit = sl<ShipmentCubit>();
  final _searchController = TextEditingController();
  io.Socket? _socket;
  String _categoryFilter = 'all'; // 'all', 'store', 'normal', 'shipment'

  final List<String> _filters = [
    'الكل',
    OrderStatus.pending,
    OrderStatus.awaitingPayment,
    OrderStatus.readyForAssignment,
    OrderStatus.assignedToCaptain,
    OrderStatus.pickedUp,
    OrderStatus.inTransit,
    OrderStatus.delivered,
    OrderStatus.completed,
    OrderStatus.cancelled,
  ];

  String _filterLabel(String filter) {
    if (filter == 'الكل') return 'الكل';
    return OrderStatus.getArabicStatus(filter);
  }

  bool _isStore(OrderEntity order) {
    return order.isStoreOrder ||
        order.orderType == 'store' ||
        (order.storeId != null && order.storeId!.isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    _cubit.addListener(_onCubitChange);
    _shipmentCubit.addListener(_onCubitChange);
    if (AuthGuard.isAuthenticated) {
      _initSocket();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cubit.loadOrders();
        _shipmentCubit.loadShipments();
      });
    }
  }

  void _initSocket() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);

    _socket = io.io(
      EndPoint.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setAuth({'token': token ?? ''})
          .build(),
    );
    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('🔌 Orders Screen Socket Connected');
    });

    _socket!.on('notification', (data) {
      debugPrint('🔔 Notification received on Orders Screen: $data');
      if (mounted) {
        _cubit.loadOrders();
        _shipmentCubit.loadShipments();
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 Orders Screen Socket Disconnected');
    });
  }

  void _onCubitChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _searchController.dispose();
    _cubit.removeListener(_onCubitChange);
    _shipmentCubit.removeListener(_onCubitChange);
    super.dispose();
  }

  bool _matchesShipmentFilter(Shipment shipment, String selectedFilter) {
    if (selectedFilter == 'الكل') return true;
    final s = shipment.status.toLowerCase();

    if (selectedFilter == OrderStatus.pending) {
      return s == 'pending' || s == 'معلق';
    }
    if (selectedFilter == OrderStatus.awaitingPayment) {
      return s == 'awaiting_payment' || (!shipment.isPaid && s == 'pending');
    }
    if (selectedFilter == OrderStatus.readyForAssignment ||
        selectedFilter == OrderStatus.assignedToCaptain) {
      return s == 'accepted' || s == 'assigned' || s == 'ready' || shipment.driverId != null;
    }
    if (selectedFilter == OrderStatus.pickedUp) {
      return s == 'pickedup' || s == 'picked_up' || s == 'تم الاستلام';
    }
    if (selectedFilter == OrderStatus.inTransit) {
      return s == 'intransit' || s == 'indelivery' || s == 'في الطريق';
    }
    if (selectedFilter == OrderStatus.delivered) {
      return s == 'delivered' || s == 'تم التوصيل' || s == 'تم التسليم';
    }
    if (selectedFilter == OrderStatus.completed) {
      return s == 'completed' || s == 'منتهية' || s == 'delivered' || s == 'تم التوصيل';
    }
    if (selectedFilter == OrderStatus.cancelled) {
      return s == 'cancelled' || s == 'ملغي' || s == 'ملغية' || s == 'rejected';
    }
    return true;
  }

  bool _matchesShipmentSearch(Shipment shipment, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase().trim();
    return shipment.shipmentNumber.toLowerCase().contains(q) ||
        shipment.fromAddress.toLowerCase().contains(q) ||
        shipment.toAddress.toLowerCase().contains(q) ||
        (shipment.title?.toLowerCase().contains(q) ?? false) ||
        (shipment.notes?.toLowerCase().contains(q) ?? false) ||
        (shipment.driverName?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final allBaseOrders = _cubit.filteredOrders
        .where((o) => o.status != 'Negotiation' && o.status != 'negotiation')
        .toList();

    final allShipments = _shipmentCubit.allShipments
        .where((s) => s.status != 'Negotiation' && s.status != 'negotiation')
        .toList();

    final filteredShipments = allShipments.where((s) {
      return _matchesShipmentFilter(s, _cubit.selectedFilter) &&
          _matchesShipmentSearch(s, _searchController.text);
    }).toList();

    final List<dynamic> displayItems = [];
    if (_categoryFilter == 'all') {
      displayItems.addAll(allBaseOrders);
      displayItems.addAll(filteredShipments);
    } else if (_categoryFilter == 'store') {
      displayItems.addAll(allBaseOrders.where(_isStore));
    } else if (_categoryFilter == 'normal') {
      displayItems.addAll(allBaseOrders.where((o) => !_isStore(o)));
    } else if (_categoryFilter == 'shipment') {
      displayItems.addAll(filteredShipments);
    }

    displayItems.sort((a, b) {
      DateTime getCreatedAt(dynamic item) {
        if (item is Shipment) return item.createdAt;
        if (item is OrderEntity) return item.createdAt;
        return DateTime.now();
      }
      return getCreatedAt(b).compareTo(getCreatedAt(a));
    });

    final isLoading = (_cubit.isLoading || _shipmentCubit.isLoading) && displayItems.isEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'طلباتي',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(180),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: CustomTextField(
                    controller: _searchController,
                    hintText: 'ابحث برقم الطلب، الشحنة، المتجر، العنوان...',
                    height: 48,
                    onChanged: (v) {
                      _cubit.setSearchQuery(v);
                      setState(() {});
                    },
                    rightWidget: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.search, color: Colors.grey, size: 20),
                    ),
                  ),
                ),
                _buildCategoryFilterBar(allBaseOrders, allShipments),
                const SizedBox(height: 8),
                _buildFilterChips(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        body: AuthGuard.isGuest
            ? _buildGuestOrdersView()
            : isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _cubit.errorMessage != null && displayItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'حدث خطأ: ${_cubit.errorMessage}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _cubit.loadOrders();
                        _shipmentCubit.loadShipments();
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _cubit.loadOrders(),
                    _shipmentCubit.loadShipments(),
                  ]);
                },
                color: AppColors.primary,
                child: displayItems.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                        itemCount: displayItems.length,
                        itemBuilder: (context, index) {
                          final item = displayItems[index];
                          return FadeInUp(
                            duration: Duration(
                              milliseconds: 250 + (index * 60).clamp(0, 400),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: item is Shipment
                                  ? _buildShipmentCard(item)
                                  : _buildOrderCard(item as OrderEntity),
                            ),
                          );
                        },
                      ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            AuthGuard.requireAuth(
              context,
              reason: 'يرجى تسجيل الدخول لإنشاء ومتابعة طلباتك.',
              onAuthenticated: () {
                if (_categoryFilter == 'shipment') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddShipmentScreen(cubit: _shipmentCubit),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddOrderScreen(cubit: _cubit),
                    ),
                  );
                }
              },
            );
          },
          backgroundColor: _categoryFilter == 'shipment'
              ? const Color(0xFF6366F1)
              : (_categoryFilter == 'store' ? const Color(0xFFFF5200) : AppColors.primary),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGuestOrdersView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 46,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'orders_guest_title'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'orders_guest_subtitle'.tr(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  AuthGuard.requireAuth(
                    context,
                    reason: 'orders_guest_subtitle'.tr(),
                    onAuthenticated: () {
                      _initSocket();
                      _cubit.loadOrders();
                    },
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: Text(
                  'login_btn'.tr(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar(List<OrderEntity> allOrders, List<Shipment> allShipments) {
    final totalCount = allOrders.length + allShipments.length;
    final storeCount = allOrders.where(_isStore).length;
    final normalCount = allOrders.where((o) => !_isStore(o)).length;
    final shipmentCount = allShipments.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCategoryTabItem(
                label: 'الكل',
                count: totalCount,
                key: 'all',
                activeColor: AppColors.primary,
              ),
              const SizedBox(width: 4),
              _buildCategoryTabItem(
                label: 'طلبات المتاجر',
                count: storeCount,
                key: 'store',
                activeColor: const Color(0xFFFF5200),
                imageAsset: AppAssets.serviceStore,
              ),
              const SizedBox(width: 4),
              _buildCategoryTabItem(
                label: 'اطلب مندوب',
                count: normalCount,
                key: 'normal',
                activeColor: const Color(0xFF1E60E8),
                svgAsset: AppAssets.delivery,
              ),
              const SizedBox(width: 4),
              _buildCategoryTabItem(
                label: 'اشحن اوردر',
                count: shipmentCount,
                key: 'shipment',
                activeColor: const Color(0xFF6366F1),
                imageAsset: AppAssets.serviceShip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabItem({
    required String label,
    required int count,
    required String key,
    required Color activeColor,
    String? imageAsset,
    String? svgAsset,
  }) {
    final isSelected = _categoryFilter == key;
    return GestureDetector(
      onTap: () {
        if (_categoryFilter != key) {
          setState(() {
            _categoryFilter = key;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageAsset != null) ...[
              Image.asset(
                imageAsset,
                width: 14,
                height: 14,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 4),
            ] else if (svgAsset != null) ...[
              SvgPicture.asset(
                svgAsset,
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(
                  isSelected ? activeColor : Colors.grey.shade600,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : Colors.grey.shade600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? activeColor : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final isSelected = _cubit.selectedFilter == _filters[index];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(
                _filterLabel(_filters[index]),
                style: AppTypography.h6.copyWith(fontSize: 12),
              ),
              selected: isSelected,
              onSelected: (_) => _cubit.selectFilter(_filters[index]),
              selectedColor: _categoryFilter == 'store'
                  ? const Color(0xFFFF5200)
                  : AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              pressElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? (_categoryFilter == 'store'
                          ? const Color(0xFFFF5200)
                          : AppColors.primary)
                      : Colors.grey.shade200,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderEntity order) {
    if (_isStore(order)) {
      return _buildStoreOrderCard(order);
    }
    return _buildNormalOrderCard(order);
  }

  String _getStoreOrderDisplayStatus(OrderEntity order) {
    final status = (order.storeOrderStatus ?? order.status).toUpperCase();
    final tripStatus = (order.captainTripStatus ?? '').toUpperCase();

    if (tripStatus == 'DELIVERED_SUCCESSFULLY' ||
        status == 'DELIVERED' ||
        status == 'COMPLETED' ||
        order.status == OrderStatus.completed ||
        order.status == OrderStatus.delivered ||
        order.status == 'تم التوصيل' ||
        order.status == 'تم التسليم' ||
        order.status == 'مكتمل' ||
        order.status == 'مكتملة') {
      return 'تم التوصيل بنجاح';
    }
    if (status == 'CANCELLED' ||
        status == 'REJECTED' ||
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.rejected ||
        order.status == 'ملغي' ||
        order.status == 'ملغاة') {
      return 'ملغي';
    }
    if (tripStatus == 'HEADING_TO_CLIENT' ||
        tripStatus == 'IN_TRANSIT' ||
        status == 'OUT_FOR_DELIVERY') {
      return 'المندوب في الطريق إليك';
    }
    if (tripStatus == 'PICKED_UP' ||
        tripStatus == 'HEADING_TO_STORE' ||
        tripStatus == 'ASSIGNED') {
      return 'تم تعيين مندوب';
    }
    if (status == 'READY_FOR_PICKUP' || status == 'READY') {
      return 'جاهز • بانتظار الكابتن';
    }
    if (status == 'PREPARING' || status == 'ACCEPTED') {
      return 'جاري تجهيز الطلب';
    }
    if (status == 'PENDING_REVIEW' || status == 'UNDER_REVIEW') {
      return 'قيد مراجعة الإدارة';
    }
    if (status == 'PENDING' || status == 'NEW') {
      return 'في انتظار قبول المتجر';
    }

    return OrderStatus.getArabicStatus(order.status);
  }

  Color _getStoreOrderDisplayStatusColor(OrderEntity order) {
    final status = (order.storeOrderStatus ?? order.status).toUpperCase();
    final tripStatus = (order.captainTripStatus ?? '').toUpperCase();

    if (tripStatus == 'DELIVERED_SUCCESSFULLY' ||
        status == 'DELIVERED' ||
        status == 'COMPLETED' ||
        order.status == OrderStatus.completed ||
        order.status == OrderStatus.delivered ||
        order.status == 'تم التوصيل' ||
        order.status == 'تم التسليم' ||
        order.status == 'مكتمل' ||
        order.status == 'مكتملة') {
      return const Color(0xFF10B981); // Emerald green
    }
    if (status == 'CANCELLED' ||
        status == 'REJECTED' ||
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.rejected) {
      return Colors.red;
    }
    if (tripStatus == 'HEADING_TO_CLIENT' ||
        tripStatus == 'IN_TRANSIT' ||
        status == 'OUT_FOR_DELIVERY') {
      return Colors.teal;
    }
    if (tripStatus == 'PICKED_UP' ||
        tripStatus == 'HEADING_TO_STORE' ||
        tripStatus == 'ASSIGNED') {
      return Colors.blue;
    }
    if (status == 'READY_FOR_PICKUP' || status == 'READY') {
      return Colors.indigo;
    }
    if (status == 'PREPARING' || status == 'ACCEPTED') {
      return const Color(0xFF1E60E8);
    }
    if (status == 'PENDING_REVIEW' || status == 'UNDER_REVIEW') {
      return Colors.deepPurple;
    }
    if (status == 'PENDING' || status == 'NEW') {
      return const Color(0xFFFF9500);
    }

    return _getStatusColor(order.status);
  }

  Widget _buildStoreOrderCard(OrderEntity order) {
    final statusText = _getStoreOrderDisplayStatus(order);
    final statusColor = _getStoreOrderDisplayStatusColor(order);
    final storeName = order.merchantName != null && order.merchantName!.trim().isNotEmpty
        ? order.merchantName!
        : (order.storeDescription.isNotEmpty ? order.storeDescription : 'متجر');

    return InkWell(
      onTap: () {
        ClientStoreOrdersScreen.showOrderDetails(
          context,
          orderId: int.tryParse(order.id),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFF5200).withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Store Badge + Status Badge + Order Number
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5200).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFF5200).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  AppAssets.serviceStore,
                                  width: 14,
                                  height: 14,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'طلب متجر',
                                  style: TextStyle(
                                    color: Color(0xFFFF5200),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '#${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Store Header: Logo / PNG Image + Store Name + Items
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final avatarUrl = formatImageUrl(order.merchantAvatar);
                          final hasAvatar = avatarUrl != null &&
                              (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

                          return Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5200).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFF5200).withValues(alpha: 0.15),
                              ),
                              image: hasAvatar
                                  ? DecorationImage(
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover,
                                      onError: (exception, stackTrace) {},
                                    )
                                  : null,
                            ),
                            child: !hasAvatar
                                ? Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Image.asset(
                                      AppAssets.serviceStore,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.details.isNotEmpty
                                  ? order.details
                                  : 'تفاصيل الطلب من المتجر',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Locations: Store Location -> Delivery Address
                  if (order.pickupAddress.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.storefront_rounded,
                      order.pickupAddress,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (order.deliveryAddress.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.location_on_rounded,
                      order.deliveryAddress,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (order.phone.isNotEmpty) ...[
                    _buildInfoRow(Icons.phone_rounded, order.phone),
                  ],
                ],
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFB),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إجمالي الطلب',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      Text(
                        '${(order.orderPrice + order.deliveryFee).toInt()} ج.م',
                        style: const TextStyle(
                          color: Color(0xFFFF5200),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ClientStoreOrdersScreen.showOrderDetails(
                        context,
                        orderId: int.tryParse(order.id),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text(
                      'تفاصيل المتجر',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5200),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalOrderCard(OrderEntity order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          order.status,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        OrderStatus.getArabicStatus(order.status),
                        style: TextStyle(
                          color: _getStatusColor(order.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '#${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  order.details,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.store_rounded, order.storeDescription),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on_rounded, order.deliveryAddress),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone_rounded, order.phone),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFBFBFB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إجمالي الطلب',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    Text(
                      '${(order.orderPrice + order.deliveryFee).toInt()} ج.م',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailsScreen(order: order),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'عرض التفاصيل',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentCard(Shipment shipment) {
    final statusText = ShipmentStatus.getArabicStatus(shipment.status);
    final statusColor = _getShipmentStatusColor(shipment.status);
    final title = shipment.title?.isNotEmpty == true
        ? shipment.title!
        : (shipment.notes?.isNotEmpty == true
            ? shipment.notes!
            : 'شحنة طرد / طلب شحن');

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShipmentDetailsScreen(shipment: shipment),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Service Badge + Status Badge + Shipment Number
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  AppAssets.serviceShip,
                                  width: 15,
                                  height: 15,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'اشحن اوردر',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '#${shipment.shipmentNumber}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Header row: Icon box + Title + Notes
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            AppAssets.serviceShip,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shipment.fromAddress.isNotEmpty
                                  ? 'من: ${shipment.fromAddress}'
                                  : 'تفاصيل الشحنة',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Route: Pickup -> Delivery Address
                  if (shipment.fromAddress.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.trip_origin_rounded,
                      shipment.fromAddress,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (shipment.toAddress.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.location_on_rounded,
                      shipment.toAddress,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (shipment.driverName != null && shipment.driverName!.trim().isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.delivery_dining_rounded,
                      'المندوب: ${shipment.driverName}',
                    ),
                    const SizedBox(height: 6),
                  ],
                  _buildInfoRow(
                    Icons.access_time_rounded,
                    DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(shipment.createdAt),
                  ),
                ],
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFB),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تكلفة الشحن',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      Text(
                        '${shipment.price.toInt()} ج.م',
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShipmentDetailsScreen(shipment: shipment),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_shipping_rounded, size: 16),
                    label: const Text(
                      'تفاصيل الشحنة',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getShipmentStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'delivered' || s == 'منتهية' || s == 'تم التوصيل' || s == 'تم التسليم') {
      return const Color(0xFF10B981);
    }
    if (s == 'cancelled' || s == 'ملغية' || s == 'ملغي' || s == 'rejected') {
      return Colors.red;
    }
    if (s == 'intransit' || s == 'indelivery' || s == 'في الطريق') {
      return Colors.teal;
    }
    if (s == 'accepted' || s == 'pickedup' || s == 'تم القبول' || s == 'تم الاستلام') {
      return const Color(0xFF1E60E8);
    }
    return const Color(0xFFFF9500);
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.negotiation:
        return Colors.deepPurple;
      case OrderStatus.awaitingPayment:
        return Colors.amber.shade700;
      case OrderStatus.readyForAssignment:
      case OrderStatus.assignedToCaptain:
        return Colors.blue;
      case OrderStatus.captainArrived:
      case OrderStatus.pickedUp:
        return Colors.teal;
      case OrderStatus.inTransit:
        return Colors.purple;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: _categoryFilter == 'store'
                    ? Image.asset(
                        AppAssets.serviceStore,
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                      )
                    : SvgPicture.asset(
                        AppAssets.orders,
                        width: 120,
                        height: 120,
                      ),
              ),
              const SizedBox(height: 24),
              FadeInUp(
                child: Column(
                  children: [
                    Text(
                      _categoryFilter == 'store'
                          ? 'لا توجد طلبات متاجر'
                          : 'لا توجد نتائج مطابقة',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _categoryFilter == 'store'
                          ? 'يمكنك تصفح المتاجر والمطاعم وإجراء طلبك الأول الآن'
                          : 'جرب البحث بكلمات أخرى أو تغيير الفلتر',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

