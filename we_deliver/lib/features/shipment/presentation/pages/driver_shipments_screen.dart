import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/features/shipment/domain/entities/shipment.dart';
import 'package:we_deliver/features/shipment/presentation/manager/shipment_cubit.dart';
import 'package:we_deliver/features/shipment/presentation/pages/driver_shipment_details_screen.dart';
import '../../../../core/theme/colors.dart';
import '../../../order/domain/entities/order.dart';
import 'driver_order_details_screen.dart';
import '../../../order/presentation/manager/order_cubit.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../../../core/api/end_point.dart';
import '../../../home/widgets/incoming_order_dialog.dart';

class DriverShipmentsScreen extends StatefulWidget {
  const DriverShipmentsScreen({super.key});

  @override
  State<DriverShipmentsScreen> createState() => _DriverShipmentsScreenState();
}

class _DriverShipmentsScreenState extends State<DriverShipmentsScreen> {
  final ShipmentCubit _cubit = sl<ShipmentCubit>();
  final OrderCubit _orderCubit = sl<OrderCubit>();
  int _selectedTabIndex = 0; // 0 = Shipments, 1 = Orders, 2 = History
  String? _myId;
  final Set<String> _rejectedIds = {};
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadMyId();
    _cubit.addListener(_onCubitChange);
    _orderCubit.addListener(_onOrderCubitChange);
    _loadTabContent();
    _connectSocket();
  }

  void _onOrderCubitChange() {
    if (mounted) setState(() {});
  }

  void _loadMyId() async {
    String? id = await SecureCacheHelper().getData(key: ApiKey.id);
    if (id == null || id.isEmpty) {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);
      if (token != null && token.isNotEmpty) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            final normalized = base64Url.normalize(payload);
            final resp = utf8.decode(base64Url.decode(normalized));
            final map = json.decode(resp) as Map<String, dynamic>;
            final userId = map['id']?.toString();
            if (userId != null && userId.isNotEmpty) {
              id = userId;
              await SecureCacheHelper().saveData(key: ApiKey.id, value: userId);
            }
          }
        } catch (e) {
          debugPrint('Error decoding JWT in shipments screen: $e');
        }
      }
    }
    if (mounted) {
      setState(() {
        _myId = id;
      });
    }
  }

  void _onCubitChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disconnectSocket();
    _cubit.removeListener(_onCubitChange);
    _orderCubit.removeListener(_onOrderCubitChange);
    _cubit.dispose();
    _orderCubit.dispose();
    super.dispose();
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
      _socket!.on('shipment_removed', (data) {
        debugPrint('❌ DriverShipments: shipment_removed received: $data');
        if (mounted) {
          _cubit.loadShipments();
          _orderCubit.loadOrders();
        }
      });
      _socket!.on('order_removed', (data) {
        debugPrint('❌ DriverShipments: order_removed received: $data');
        if (mounted) {
          _cubit.loadShipments();
          _orderCubit.loadOrders();
        }
      });
      _socket!.on('statusUpdate', (data) {
        if (mounted) {
          _cubit.loadShipments();
          _orderCubit.loadOrders();
        }
      });
    } catch (e) {
      debugPrint('Error connecting shipments socket: $e');
    }
  }

  void _disconnectSocket() {
    if (_socket != null) {
      _socket!.off('shipment_removed');
      _socket!.off('order_removed');
      _socket!.off('statusUpdate');
      _socket!.disconnect();
      _socket = null;
    }
  }

  void _loadTabContent() {
    if (_selectedTabIndex == 0) {
      _cubit.loadShipments(); // loads available + assigned
    } else if (_selectedTabIndex == 1) {
      _orderCubit.loadOrders(); // loads all orders
    } else if (_selectedTabIndex == 2) {
      _cubit.loadShipments(filter: 'my_trips'); // loads all assigned
      _orderCubit.loadOrders(); // loads all orders
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'رحلاتي',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        body: Column(
          children: [
            _buildSummaryHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final availableShipmentsCount = _cubit.allShipments
        .where((s) => s.status == ShipmentStatus.newShipment)
        .length;
    final availableOrdersCount = _orderCubit.allOrders
        .where((o) => o.status == OrderStatus.pending)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Available Shipments Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F1FF), Color(0xFFD0E3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB8D4FF), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1F4C9B).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Color(0xFF1F4C9B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الشحنات المتاحة',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F4C9B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$availableShipmentsCount شحنة',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Available Orders Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF4E5), Color(0xFFFFE5C4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD59E), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF78710).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Color(0xFFF78710),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الطلبات المتاحة',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF78710),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$availableOrdersCount طلب',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.tajawal(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      {'label': 'الشحنات', 'icon': Icons.local_shipping_outlined},
      {'label': 'الطلبات', 'icon': Icons.shopping_bag_outlined},
      {'label': 'سجل الرحلات', 'icon': Icons.history_rounded},
    ];

    return Container(
      height: 60,
      width: double.infinity,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
                _loadTabContent();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabs[index]['icon'] as IconData,
                        size: 18,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tabs[index]['label'] as String,
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        if (_cubit.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (_cubit.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _cubit.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        final allShipments = _cubit.allShipments;
        final availableShipments = allShipments
            .where((s) => s.status == ShipmentStatus.newShipment)
            .toList();
        final receivedShipments = allShipments
            .where(
              (s) =>
                  s.driverId != null &&
                  s.driverId == _myId &&
                  s.status != ShipmentStatus.newShipment &&
                  s.status != ShipmentStatus.completed &&
                  s.status != ShipmentStatus.cancelled,
            )
            .toList();

        return RefreshIndicator(
          onRefresh: () async => _loadTabContent(),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildSectionHeader(
                'الشحنات المتاحة',
                availableShipments.length,
                AppColors.primary,
              ),
              if (availableShipments
                  .where((s) => !_rejectedIds.contains(s.id))
                  .isEmpty)
                _buildSmallEmptyCard('لا توجد شحنات متاحة حالياً')
              else
                ...availableShipments.map(
                  (s) => _buildAvailableShipmentCard(s),
                ),

              _buildSectionHeader(
                'الشحنات المستلمة',
                receivedShipments.length,
                const Color(0xFF4CAF50),
              ),
              if (receivedShipments.isEmpty)
                _buildSmallEmptyCard('لا توجد شحنات مستلمة حالياً')
              else
                ...receivedShipments.map((s) => _buildShipmentCard(s)),
            ],
          ),
        );
      case 1:
        if (_orderCubit.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (_orderCubit.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _orderCubit.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        final availableOrders = _orderCubit.allOrders
            .where((o) => o.status == OrderStatus.pending)
            .toList();
        final receivedOrders = _orderCubit.allOrders
            .where(
              (o) =>
                  o.captainId == _myId &&
                  o.status != OrderStatus.pending &&
                  o.status != OrderStatus.finished &&
                  o.status != OrderStatus.cancelled &&
                  o.status != OrderStatus.rejected,
            )
            .toList();

        return RefreshIndicator(
          onRefresh: () async => _loadTabContent(),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildSectionHeader(
                'الطلبات المتاحة',
                availableOrders
                    .where((o) => !_rejectedIds.contains(o.id))
                    .length,
                const Color(0xFFF78710),
              ),
              if (availableOrders
                  .where((o) => !_rejectedIds.contains(o.id))
                  .isEmpty)
                _buildSmallEmptyCard('لا توجد طلبات متاحة حالياً')
              else
                ...availableOrders.map((o) => _buildAvailableOrderCard(o)),

              _buildSectionHeader(
                'الطلبات المستلمة',
                receivedOrders.length,
                const Color(0xFF4CAF50),
              ),
              if (receivedOrders.isEmpty)
                _buildSmallEmptyCard('لا توجد طلبات مستلمة حالياً')
              else
                ...receivedOrders.map((o) => _buildOrderCard(o)),
            ],
          ),
        );
      case 2:
        if (_cubit.isLoading || _orderCubit.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (_cubit.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _cubit.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        final finishedShipments = _cubit.allShipments
            .where(
              (s) =>
                  s.driverId != null &&
                  s.driverId == _myId &&
                  (s.status == ShipmentStatus.completed ||
                      s.status == ShipmentStatus.cancelled),
            )
            .map((s) => {'type': 'shipment', 'data': s})
            .toList();
        final finishedOrders = _orderCubit.allOrders
            .where(
              (o) =>
                  o.captainId != null &&
                  o.captainId == _myId &&
                  (o.status == OrderStatus.completed ||
                      o.status == OrderStatus.finished ||
                      o.status == OrderStatus.cancelled ||
                      o.status == OrderStatus.rejected),
            )
            .map((o) => {'type': 'order', 'data': o})
            .toList();
        final historyItems = [...finishedShipments, ...finishedOrders];

        if (historyItems.isEmpty) {
          return _buildEmptyState('سجل الرحلات فارغ');
        }
        return RefreshIndicator(
          onRefresh: () async => _loadTabContent(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: historyItems.length,
            itemBuilder: (context, index) {
              return _buildHistoryCard(historyItems[index]);
            },
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.tajawal(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentCard(Shipment shipment) {
    if (_rejectedIds.contains(shipment.id)) return const SizedBox.shrink();

    final status = shipment.status.trim().toLowerCase();
    final approval = (shipment.captainApprovalStatus ?? '')
        .trim()
        .toLowerCase();

    final isAccepted =
        approval == 'accepted' ||
        status == 'جاري التنفيذ' ||
        status == 'تم القبول' ||
        status == 'in transit' ||
        status == 'picked up' ||
        status == 'completed' ||
        status == 'delivered' ||
        status == 'منتهية';

    // Only show approval prompt if captainApprovalStatus is explicitly 'pending'
    // (not when it's null, which happens after timeout/clearing)
    final isUnaccepted =
        !isAccepted &&
        approval == 'pending' &&
        (status == 'assigned to captain' ||
            status == 'ready for assignment' ||
            status == 'في انتظار القبول' ||
            status == 'بانتظار القبول');

    if (isUnaccepted) {
      return AvailableItemCard(
        itemId: shipment.id,
        timeoutSeconds: 60,
        isOrder: false,
        itemNumber: shipment.shipmentNumber,
        fromAddress: shipment.fromAddress,
        toAddress: shipment.toAddress,
        priceText: '${shipment.price.toInt()} ج.م',
        weightText: shipment.weight != null
            ? '${shipment.weight!.toInt()} كجم'
            : 'غير محدد',
        statusText: ShipmentStatus.getArabicStatus(shipment.status),
        onTimeout: () async {
          // Server-side timeout handles the clearing; just hide locally
          if (mounted) {
            setState(() {
              _rejectedIds.add(shipment.id);
            });
          }
          // Also notify the backend via captain-response (reject) to trigger next assignment
          try {
            await _cubit.captainRespondToAssignment(shipment.id, 'reject');
          } catch (_) {}
        },
        onReject: () async {
          if (mounted) {
            setState(() {
              _rejectedIds.add(shipment.id);
            });
          }
          // Use proper captain-response endpoint to clear captainId and trigger next assignment
          try {
            await _cubit.captainRespondToAssignment(shipment.id, 'reject');
          } catch (_) {}
        },
        onAccept: () async {
          try {
            // Use proper captain-response endpoint to accept
            await _cubit.captainRespondToAssignment(shipment.id, 'accept');
          } catch (_) {}
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverShipmentDetailsScreen(shipment: shipment),
              ),
            );
          }
        },
      );
    }

    return InkWell(
      onTap: () => _navigateToDetails(shipment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                    child: SvgPicture.asset(
                      AppAssets.box,
                      width: 60,
                      height: 60,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Title and Number
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
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
                    onPressed: () => _navigateToDetails(shipment),
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
                          color: const Color(0xFF1F4C9B).withValues(alpha: 0.4),
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
                  _buildInfoColumn(
                    'نوع الدفع',
                    shipment.isWithoutAdvance ? 'بدون مقدم' : 'دفع مقدم',
                  ),
                  _buildInfoColumn(
                    'سعر التوصيل',
                    '${shipment.price.toInt()} ج',
                  ),
                  _buildInfoColumn(
                    'الحالة',
                    ShipmentStatus.getArabicStatus(shipment.status),
                  ),
                ],
              ),
            ),

            // View Details Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _navigateToDetails(shipment),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'عرض التفاصيل',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildOrderCard(OrderEntity order) {
    if (_rejectedIds.contains(order.id)) return const SizedBox.shrink();

    final status = order.status.trim().toLowerCase();
    final approval = (order.captainApprovalStatus ?? '').trim().toLowerCase();

    final isAccepted =
        approval == 'accepted' ||
        status == 'جاري التنفيذ' ||
        status == 'تم القبول' ||
        status == 'in transit' ||
        status == 'picked up' ||
        status == 'completed' ||
        status == 'finished' ||
        status == 'delivered' ||
        status == 'منتهية';

    // Only show approval prompt when captainApprovalStatus is explicitly 'pending'
    final isUnaccepted =
        !isAccepted &&
        approval == 'pending' &&
        (status == 'assigned to captain' ||
            status == 'ready for assignment' ||
            status == 'في انتظار القبول' ||
            status == 'بانتظار القبول');

    if (isUnaccepted) {
      return AvailableItemCard(
        itemId: order.id,
        timeoutSeconds: 60,
        isOrder: true,
        itemNumber: order.orderNumber,
        fromAddress: order.storeDescription,
        toAddress: order.deliveryAddress,
        priceText: '${order.deliveryFee.toInt()} ج.م',
        weightText: 'غير محدد',
        statusText: 'بانتظار القبول',
        onTimeout: () async {
          if (mounted) {
            setState(() {
              _rejectedIds.add(order.id);
            });
          }
          try {
            await _orderCubit.captainRespondToAssignment(order.id, 'reject');
          } catch (_) {}
        },
        onReject: () async {
          if (mounted) {
            setState(() {
              _rejectedIds.add(order.id);
            });
          }
          try {
            await _orderCubit.captainRespondToAssignment(order.id, 'reject');
          } catch (_) {}
        },
        onAccept: () async {
          try {
            await _orderCubit.captainRespondToAssignment(order.id, 'accept');
          } catch (_) {}
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverOrderDetailsScreen(order: order),
              ),
            );
          }
        },
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                        '#طلب رقم: ${order.orderNumber}',
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DriverOrderDetailsScreen(order: order),
                      ),
                    );
                  },
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
                        color: const Color(0xFF1F4C9B).withValues(alpha: 0.4),
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
                        'موقع الاستلام',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        order.pickupAddress,
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DriverOrderDetailsScreen(order: order),
                      ),
                    );
                  },
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

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final isOrder = item['type'] == 'order';
    final dynamic data = item['data'];
    final OrderEntity? order = isOrder ? data as OrderEntity : null;
    final Shipment? shipment = !isOrder ? data as Shipment : null;

    final bool isCompleted = isOrder
        ? order!.status == OrderStatus.completed ||
              order.status == OrderStatus.finished
        : (shipment!.status == ShipmentStatus.finished ||
              shipment.status == ShipmentStatus.cancelled);

    final String title = isOrder
        ? 'طلب #${order!.orderNumber}'
        : 'شحنة #${shipment!.shipmentNumber}';

    final String fromText = isOrder
        ? order!.storeDescription
        : shipment!.fromAddress;

    final String toText = isOrder
        ? order!.deliveryAddress
        : shipment!.toAddress;

    final String feeText = isOrder
        ? '${order!.deliveryFee.toInt()} ج.م'
        : '${shipment!.price.toInt()} ج';

    final String valueText = isOrder
        ? '${order!.orderPrice.toInt()} ج.م'
        : (shipment!.isWithoutAdvance ? 'بدون مقدم' : 'دفع مقدم');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (isOrder) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverOrderDetailsScreen(order: order!),
              ),
            );
          } else {
            _navigateToDetails(shipment!);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: type badge and status badge
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Type Badge
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isOrder
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SvgPicture.asset(
                          isOrder ? AppAssets.orders : AppAssets.box,
                          width: 16,
                          height: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFE8F8F0)
                          : const Color(0xFFE8F1FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCompleted ? 'مكتمل / مغلق' : 'نشط (مع السائق)',
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF1F4C9B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF5F5F5)),

            // Body: Path
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          color: const Color(0xFF1F4C9B).withValues(alpha: 0.4),
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
                          isOrder ? 'مكان الشراء' : 'من',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          fromText,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isOrder ? 'عنوان التوصيل' : 'إلى',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          toText,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF5F5F5)),

            // Footer: Value, delivery fee and details click
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Column(
                        children: [
                          Text(
                            isOrder ? 'قيمة الشحنة: ' : 'الدفع: ',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            valueText,
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          Text(
                            'سعر التوصيل: ',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            feeText,
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF78710),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Row(
                        children: [
                          Text(
                            'عرض التفاصيل',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.background,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: AppColors.background,
                          ),
                        ],
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

  void _navigateToDetails(Shipment shipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverShipmentDetailsScreen(shipment: shipment),
      ),
    ).then((_) {
      _loadTabContent();
    });
  }

  Widget _buildAvailableShipmentCard(Shipment s) {
    if (_rejectedIds.contains(s.id)) return const SizedBox.shrink();

    return AvailableItemCard(
      itemId: s.id,
      timeoutSeconds: 60,
      isOrder: false,
      itemNumber: s.shipmentNumber,
      fromAddress: s.fromAddress,
      toAddress: s.toAddress,
      priceText: '${s.price.toInt()} ج.م',
      weightText: s.weight != null ? '${s.weight!.toInt()} كجم' : 'غير محدد',
      statusText: ShipmentStatus.getArabicStatus(s.status),
      onTimeout: () async {
        if (mounted) {
          setState(() {
            _rejectedIds.add(s.id);
          });
        }
        try {
          await _cubit.updateShipmentStatus(s.id, 'timeout');
        } catch (_) {}
      },
      onReject: () async {
        if (mounted) {
          setState(() {
            _rejectedIds.add(s.id);
          });
        }
        try {
          await _cubit.updateShipmentStatus(s.id, 'rejected');
        } catch (_) {}
      },
      onAccept: () async {
        _showIncomingShipmentPopup(s);
      },
    );
  }

  Widget _buildAvailableOrderCard(OrderEntity o) {
    if (_rejectedIds.contains(o.id)) return const SizedBox.shrink();

    return AvailableItemCard(
      itemId: o.id,
      timeoutSeconds: 60,
      isOrder: true,
      itemNumber: o.orderNumber,
      fromAddress: o.storeDescription,
      toAddress: o.deliveryAddress,
      priceText: '${o.deliveryFee.toInt()} ج.م',
      weightText: 'غير محدد',
      statusText: 'بانتظار القبول',
      onTimeout: () async {
        if (mounted) {
          setState(() {
            _rejectedIds.add(o.id);
          });
        }
        try {
          await _orderCubit.updateOrderStatus(o.id, 'timeout');
        } catch (_) {}
      },
      onReject: () async {
        if (mounted) {
          setState(() {
            _rejectedIds.add(o.id);
          });
        }
        try {
          await _orderCubit.updateOrderStatus(o.id, 'rejected');
        } catch (_) {}
      },
      onAccept: () async {
        _showIncomingOrderPopup(o);
      },
    );
  }

  void _showIncomingShipmentPopup(Shipment s) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingOrderDialog(
        orderId: s.id,
        orderNumber: s.shipmentNumber,
        orderType: 'توصيل شحنة',
        pickupArea: s.fromAddress,
        deliveryArea: s.toAddress,
        distance: '8.4 كم',
        priceText: '${s.price.toInt()} جنيه',
        timeAgo: 'منذ دقيقة',
        notes: s.notes ?? 'يرجى التواصل قبل الاستلام',
        timeoutSeconds: 60,
        onReject: () async {
          Navigator.pop(ctx);
          if (mounted) {
            setState(() {
              _rejectedIds.add(s.id);
            });
          }
          try {
            await _cubit.updateShipmentStatus(s.id, 'rejected');
          } catch (_) {}
        },
        onAccept: () async {
          Navigator.pop(ctx);
          try {
            await _cubit.updateShipmentStatus(
              s.id,
              'جاري التنفيذ',
              negotiatedPrice: s.price,
            );
          } catch (_) {}
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverShipmentDetailsScreen(shipment: s),
              ),
            );
          }
        },
      ),
    );
  }

  void _showIncomingOrderPopup(OrderEntity o) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingOrderDialog(
        orderId: o.id,
        orderNumber: o.orderNumber,
        orderType: 'شراء احتياجات',
        pickupArea: o.storeDescription,
        deliveryArea: o.deliveryAddress,
        distance: '5.2 كم',
        priceText: '${o.deliveryFee.toInt()} جنيه',
        timeAgo: 'منذ دقيقة',
        notes: o.notes ?? 'يرجى التواصل قبل الاستلام',
        timeoutSeconds: 60,
        onReject: () async {
          Navigator.pop(ctx);
          if (mounted) {
            setState(() {
              _rejectedIds.add(o.id);
            });
          }
          try {
            await _orderCubit.updateOrderStatus(o.id, 'rejected');
          } catch (_) {}
        },
        onAccept: () async {
          Navigator.pop(ctx);
          try {
            await _orderCubit.updateOrderStatus(o.id, 'جاري التنفيذ');
          } catch (_) {}
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverOrderDetailsScreen(order: o),
              ),
            );
          }
        },
      ),
    );
  }
}

class AvailableItemCard extends StatefulWidget {
  final String itemId;
  final int timeoutSeconds;
  final VoidCallback onTimeout;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final String itemNumber;
  final String fromAddress;
  final String toAddress;
  final String priceText;
  final String weightText;
  final String statusText;
  final bool isOrder;

  const AvailableItemCard({
    super.key,
    required this.itemId,
    required this.timeoutSeconds,
    required this.onTimeout,
    required this.onAccept,
    required this.onReject,
    required this.itemNumber,
    required this.fromAddress,
    required this.toAddress,
    required this.priceText,
    required this.weightText,
    required this.statusText,
    this.isOrder = false,
  });

  @override
  State<AvailableItemCard> createState() => _AvailableItemCardState();
}

class _AvailableItemCardState extends State<AvailableItemCard> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeoutSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      } else {
        _timer?.cancel();
        if (mounted) {
          widget.onTimeout();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _remainingSeconds <= 15
              ? Colors.red.shade300
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Timer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _remainingSeconds <= 15
                  ? Colors.red.shade50
                  : const Color(0xFFFFF8E1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: _remainingSeconds <= 15
                      ? Colors.red
                      : Colors.orange.shade800,
                ),
                const SizedBox(width: 6),
                Text(
                  'مهلة القبول: $minutes:$seconds ثانية',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds <= 15
                        ? Colors.red
                        : Colors.orange.shade900,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.isOrder ? 'طلب جديد' : 'شحنة جديدة',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Main Body Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        widget.isOrder ? AppAssets.orders : AppAssets.box,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '#رقم: ${widget.itemNumber}',
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF5F5F5)),
                const SizedBox(height: 10),

                // From & To Route
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          3,
                          (i) => Container(
                            width: 1.2,
                            height: 7,
                            margin: const EdgeInsets.symmetric(vertical: 1),
                            color: const Color(
                              0xFF1F4C9B,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFB000),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'من: ${widget.fromAddress}',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'إلى: ${widget.toAddress}',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF5F5F5)),
                const SizedBox(height: 10),

                // Info Row: Price, Weight, Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سعر التوصيل',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          widget.priceText,
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F4C9B),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الوزن',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          widget.weightText,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحالة',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          widget.statusText,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Action Buttons: Accept & Reject (NO View Details button!)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: widget.onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'قبول الطلب',
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: widget.onReject,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.red.shade400,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'رفض',
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
