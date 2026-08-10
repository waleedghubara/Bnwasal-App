// ignore_for_file: deprecated_member_use, strict_top_level_inference

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:we_deliver/core/routes/routes.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/features/home/widgets/search_bar.dart';
import 'package:we_deliver/features/shipment/presentation/pages/add_shipment_screen.dart';
import 'package:we_deliver/features/shipment/domain/entities/shipment.dart';
import 'package:we_deliver/features/shipment/presentation/pages/shipment_details_screen.dart';
import 'package:we_deliver/features/order/domain/entities/order.dart';
import 'package:we_deliver/features/order/presentation/pages/order_details_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import '../../../core/di/injection_container.dart';
import '../../order/presentation/manager/order_cubit.dart';
import '../../order/presentation/pages/add_order_screen.dart';
import '../../order/presentation/pages/orders_screen.dart';
import '../../shipment/presentation/manager/shipment_cubit.dart';
import '../widgets/banner.dart';
import '../widgets/header.dart';

class HomeUserScreen extends StatefulWidget {
  const HomeUserScreen({super.key});

  @override
  State<HomeUserScreen> createState() => _HomeUserScreenState();
}

class _HomeUserScreenState extends State<HomeUserScreen> {
  final ShipmentCubit _shipmentCubit = sl<ShipmentCubit>();
  final OrderCubit _orderCubit = sl<OrderCubit>();
  final TextEditingController _searchController = TextEditingController();

  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _shipmentCubit.addListener(_onCubitChange);
    _orderCubit.addListener(_onCubitChange);
    _shipmentCubit.loadShipments();
    _orderCubit.loadOrders();
    _connectSocket();
  }

  @override
  void dispose() {
    _disconnectSocket();
    _shipmentCubit.removeListener(_onCubitChange);
    _orderCubit.removeListener(_onCubitChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onCubitChange() {
    if (mounted) {
      setState(() {});
      if (!_shipmentCubit.isLoading && !_orderCubit.isLoading) {
        _joinActiveRooms();
      }
    }
  }

  Future<void> _refreshData() async {
    _shipmentCubit.loadShipments();
    _orderCubit.loadOrders();
  }

  void _connectSocket() async {
    try {
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
        debugPrint('🔌 User Home socket connected');
        _joinActiveRooms();
      });
      _socket!.on('notification', (data) {
        debugPrint('📩 User Home socket notification received');
        _refreshData();
      });
      _socket!.on('statusUpdate', (data) {
        debugPrint('🔄 User Home socket statusUpdate received');
        _refreshData();
      });
      _socket!.onDisconnect((_) {
        debugPrint('🔌 User Home socket disconnected');
      });
    } catch (e) {
      debugPrint('Error connecting user home socket: $e');
    }
  }

  void _joinActiveRooms() {
    if (_socket == null || !_socket!.connected) return;

    final inactiveShipmentStatuses = [
      'Completed',
      'completed',
      'منتهية',
      'منتهي',
      'Cancelled',
      'cancelled',
      'ملغية',
      'ملغي',
    ];

    final inactiveOrderStatuses = [
      'Completed',
      'completed',
      'منتهي',
      'منتهية',
      'مكتملة',
      'Cancelled',
      'cancelled',
      'ملغي',
      'ملغية',
      'Rejected',
      'rejected',
      'مرفوض',
    ];

    final activeShipments = _shipmentCubit.allShipments.where((s) {
      return !inactiveShipmentStatuses.contains(s.status);
    }).toList();

    final activeOrders = _orderCubit.allOrders.where((o) {
      return !inactiveOrderStatuses.contains(o.status);
    }).toList();

    for (var shipment in activeShipments) {
      _socket!.emit('joinRoom', 'shipment_${shipment.id}');
    }
    for (var order in activeOrders) {
      _socket!.emit('joinRoom', 'order_${order.id}');
    }
  }

  void _disconnectSocket() {
    if (_socket != null) {
      _socket!.off('notification');
      _socket!.off('statusUpdate');
      _socket!.disconnect();
      _socket = null;
    }
  }

  void _navigateToShipmentDetails(Shipment shipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShipmentDetailsScreen(shipment: shipment),
      ),
    );
  }

  void _navigateToOrderDetails(OrderEntity order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveShipmentCard(Shipment shipment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
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
          // Top Row: Title, Number, Thumbnail and Back arrow
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Image
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(AppAssets.box, width: 60, height: 60),
                ),
                const SizedBox(width: 8),
                // Title and Number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12),
                      Text(
                        '#رقم الشحنة: ${shipment.shipmentNumber}',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Back Arrow
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.black87,
                    size: 16,
                  ),
                  onPressed: () => _navigateToShipmentDetails(shipment),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),

          // Middle Row: Timeline Route
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline Graphics
                Column(
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1F4C9B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    ...List.generate(
                      4,
                      (i) => Container(
                        width: 1.2,
                        height: 9,
                        margin: const EdgeInsets.symmetric(vertical: 1.5),
                        color: const Color(0xFF1F4C9B).withOpacity(0.4),
                      ),
                    ),
                    Container(
                      width: 7,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFB000),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Addresses
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'من',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        shipment.fromAddress,
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'الي',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        shipment.toAddress,
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),

          // Grid of Details: Shipment Price, Delivery Fee, Arrival Date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('سعر التوصيل', '${shipment.price.toInt()} ج'),
                _buildInfoColumn(
                  'الحالة',
                  ShipmentStatus.getArabicStatus(shipment.status),
                ),
                _buildInfoColumn('المندوب', shipment.driverName ?? 'قيد البحث'),
              ],
            ),
          ),

          // Details Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _navigateToShipmentDetails(shipment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'عرض التفاصيل',
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFF78710),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveOrderCard(OrderEntity order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
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
          // Header: Order Number and Client Name
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(
                    AppAssets.orders,
                    width: 24,
                    height: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#طلب رقم: ${order.id}',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'العميل: ${order.clientName}',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow Icon
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.black87,
                    size: 16,
                  ),
                  onPressed: () => _navigateToOrderDetails(order),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),

          // Body: Store Description & Delivery Address
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual Indicator (Store to Client Address)
                Column(
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1F4C9B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    ...List.generate(
                      4,
                      (i) => Container(
                        width: 1.2,
                        height: 9,
                        margin: const EdgeInsets.symmetric(vertical: 1.5),
                        color: const Color(0xFF1F4C9B).withOpacity(0.4),
                      ),
                    ),
                    Container(
                      width: 7,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFB000),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مكان الشراء',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        order.storeDescription,
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'عنوان التوصيل',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        order.deliveryAddress,
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),

          // Order details summary text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المحتويات: ',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                Expanded(
                  child: Text(
                    order.details,
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),

          // Cost Footer & Action Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سعر الطلب',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.orderPrice.toInt()} ج.م',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF78710),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سعر التوصيل',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.deliveryFee.toInt()} ج.م',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF78710),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _navigateToOrderDetails(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    'عرض التفاصيل',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inactiveShipmentStatuses = [
      'Completed',
      'completed',
      'منتهية',
      'منتهي',
      'Cancelled',
      'cancelled',
      'ملغية',
      'ملغي',
    ];

    final inactiveOrderStatuses = [
      'Completed',
      'completed',
      'منتهي',
      'منتهية',
      'مكتملة',
      'Cancelled',
      'cancelled',
      'ملغي',
      'ملغية',
      'Rejected',
      'rejected',
      'مرفوض',
    ];

    final activeShipments = _shipmentCubit.allShipments.where((s) {
      return !inactiveShipmentStatuses.contains(s.status);
    }).toList();

    final activeOrders = _orderCubit.allOrders.where((o) {
      return !inactiveOrderStatuses.contains(o.status);
    }).toList();

    final previousShipments = _shipmentCubit.allShipments.where((s) {
      return inactiveShipmentStatuses.contains(s.status);
    }).toList();

    final previousOrders = _orderCubit.allOrders.where((o) {
      return inactiveOrderStatuses.contains(o.status);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HomeHeader(),
                  const SizedBox(height: 20),
                  HomeSearchBar(
                    controller: _searchController,
                    readOnly: true,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        Routes.search,
                        arguments: {'isDelivery': false},
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  BannerSection(
                    onTap: () {
                      Navigator.pushNamed(context, Routes.referEarn);
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('خدماتنا', showArrow: true),
                  const SizedBox(height: 12),
                  _buildServices(),
                  const SizedBox(height: 24),
                  _buildSectionHeaderWithBadge(
                    'الطلبات النشطة',
                    (activeShipments.length + activeOrders.length).toString(),
                  ),
                  const SizedBox(height: 12),
                  if (activeShipments.isEmpty && activeOrders.isEmpty)
                    _buildEmptyState('لا توجد طلبات نشطة حالياً')
                  else ...[
                    ...activeShipments.map(
                      (shipment) => _buildActiveShipmentCard(shipment),
                    ),
                    ...activeOrders.map(
                      (order) => _buildActiveOrderCard(order),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionHeader('الطلبات السابقة', showArrow: true),
                  const SizedBox(height: 12),
                  _buildPreviousOrders(previousShipments, previousOrders),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool showArrow = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (showArrow)
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black87),
      ],
    );
  }

  Widget _buildSectionHeaderWithBadge(String title, String badgeCount) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badgeCount,
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServices() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildServiceCard(
            onTap: () {
              _shipmentCubit.closeAddOptions();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddShipmentScreen(cubit: _shipmentCubit),
                ),
              );
            },
            title: 'اشحن اوردر',
            subtitle: 'شحن سريع وآمن وموثوق',
            imageUrl: AppAssets.box,
            backgroundColor: const Color(0xFFFFF8F1),
          ),
          const SizedBox(width: 12),
          _buildServiceCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddOrderScreen(cubit: _orderCubit),
                ),
              );
            },
            title: 'اطلب مندوب',
            subtitle: 'يجيبلك اى حاجه محتاجها فورا',
            imageUrl: AppAssets.delivery,
            backgroundColor: const Color(0xFFF0F5FF),
          ),
          const SizedBox(width: 12),
          _buildServiceCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()),
              );
            },
            title: 'تبع طلبك',
            subtitle: 'اعرف مكان الشحنه',
            imageUrl: AppAssets.location,
            backgroundColor: const Color.fromARGB(255, 246, 255, 240),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required String imageUrl,
    required Function() onTap,
    required Color backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,

        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(imageUrl, width: 70, height: 70),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final itemDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (itemDate == today) {
        return 'اليوم ${DateFormat('hh:mm a', 'ar').format(dateTime)}';
      } else if (itemDate == yesterday) {
        return 'أمس ${DateFormat('hh:mm a', 'ar').format(dateTime)}';
      } else {
        return DateFormat('yyyy-MM-dd hh:mm a', 'ar').format(dateTime);
      }
    } catch (e) {
      return DateFormat('yyyy-MM-dd').format(dateTime);
    }
  }

  Widget _buildPreviousOrders(
    List<Shipment> prevShipments,
    List<OrderEntity> prevOrders,
  ) {
    final List<dynamic> combinedList = [...prevShipments, ...prevOrders];
    combinedList.sort((a, b) {
      DateTime getCreatedAt(dynamic item) {
        if (item is Shipment) return item.createdAt;
        if (item is OrderEntity) return item.createdAt;
        return DateTime.now();
      }

      return getCreatedAt(b).compareTo(getCreatedAt(a));
    });

    if (combinedList.isEmpty) {
      return _buildEmptyState('لا توجد طلبات سابقة');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: combinedList.map((item) {
          return Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: _buildPreviousItemCard(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreviousItemCard(dynamic item) {
    String statusText = '';
    Color statusColor = Colors.green;
    String ratingText = '4.8'; // Default rating
    String fromAddress = '';
    String toAddress = '';
    String timeText = '';
    String priceText = '';
    VoidCallback onTap;

    if (item is Shipment) {
      fromAddress = item.fromAddress;
      toAddress = item.toAddress;
      priceText = '${item.price.toInt()} ج';
      timeText = _formatDateTime(item.createdAt);

      final isFinished =
          item.status == 'Completed' ||
          item.status == 'completed' ||
          item.status == 'منتهية' ||
          item.status == 'Delivered' ||
          item.status == 'delivered' ||
          item.status == 'تم التوصيل' ||
          item.status == 'تم التنفيذ';
      statusText = ShipmentStatus.getArabicStatus(item.status);
      statusColor = isFinished ? Colors.green : Colors.red;
      onTap = () => _navigateToShipmentDetails(item);
    } else if (item is OrderEntity) {
      fromAddress = item.storeDescription;
      toAddress = item.deliveryAddress;
      priceText = '${item.orderPrice.toInt()} ج';
      timeText = _formatDateTime(item.createdAt);

      final isFinished =
          item.status == OrderStatus.completed ||
          item.status == OrderStatus.finished ||
          item.status == 'Completed' ||
          item.status == 'completed' ||
          item.status == 'منتهي' ||
          item.status == 'Delivered' ||
          item.status == 'delivered' ||
          item.status == 'تم التنفيذ' ||
          item.status == 'تم التوصيل';
      statusText = isFinished ? 'تم التنفيذ' : 'ملغي';
      if (item.status == OrderStatus.rejected ||
          item.status == 'Rejected' ||
          item.status == 'مرفوض') {
        statusText = 'مرفوض';
      }
      statusColor = isFinished ? Colors.green : Colors.red;
      onTap = () => _navigateToOrderDetails(item);
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      ratingText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fromAddress,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(
                    Icons.compare_arrows,
                    color: Colors.grey,
                    size: 16,
                  ),
                ),
                Expanded(
                  child: Text(
                    toAddress,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeText,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                Text(
                  priceText,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
