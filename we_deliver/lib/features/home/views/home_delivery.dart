import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/routes/routes.dart';
import 'package:we_deliver/core/theme/typography.dart';
import 'package:we_deliver/features/home/widgets/banner.dart';
import 'package:we_deliver/features/home/widgets/header.dart';
import 'package:we_deliver/features/home/widgets/search_bar.dart';
import '../../shipment/presentation/pages/driver_shipment_details_screen.dart';
import '../../shipment/presentation/pages/driver_order_details_screen.dart';
import '../../order/domain/entities/order.dart';
import '../../shipment/domain/entities/shipment.dart';
import '../../../core/di/injection_container.dart';
import '../../shipment/presentation/manager/shipment_cubit.dart';
import '../../order/presentation/manager/order_cubit.dart';
import '../../shipment/domain/usecases/get_shipments_usecase.dart';
import '../../order/domain/usecases/get_orders_usecase.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';

import '../../../core/theme/app_assets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../trips/presentation/manager/trip_cubit.dart';
import '../../trips/presentation/manager/trip_state.dart';
import '../../trips/domain/entities/trip.dart';
import '../../wallet/domain/usecases/get_wallet_usecase.dart';
import '../../wallet/presentation/pages/deposit_screen.dart';
import '../widgets/incoming_order_dialog.dart';
import '../../shipment/presentation/pages/driver_shipments_screen.dart';

class HomeDelivery extends StatefulWidget {
  const HomeDelivery({super.key});

  @override
  State<HomeDelivery> createState() => _HomeDeliveryState();
}

class _HomeDeliveryState extends State<HomeDelivery> {
  final TextEditingController _searchController = TextEditingController();
  final ShipmentCubit _shipmentCubit = sl<ShipmentCubit>();
  final OrderCubit _orderCubit = sl<OrderCubit>();
  final Set<String> _rejectedIds = {};

  int _availableShipments = 0;
  int _availableOrders = 0;
  int _completedShipments = 0;
  int _completedOrders = 0;
  bool _isLoadingStats = true;

  Future<void> _loadStats() async {
    try {
      final getShipments = sl<GetShipmentsUseCase>();
      final getOrders = sl<GetOrdersUseCase>();

      final results = await Future.wait([
        getShipments(filter: 'available'),
        getOrders(filter: 'available'),
        getShipments(filter: 'history'),
        getOrders(filter: 'history'),
      ]);

      final availableShipments = results[0] as List<Shipment>;
      final availableOrders = results[1] as List<OrderEntity>;
      final historyShipments = results[2] as List<Shipment>;
      final historyOrders = results[3] as List<OrderEntity>;

      if (mounted) {
        setState(() {
          _availableShipments = availableShipments.length;
          _availableOrders = availableOrders.length;
          _completedShipments = historyShipments
              .where(_isShipmentCompleted)
              .length;
          _completedOrders = historyOrders.where(_isOrderCompleted).length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  bool _hasCheckedTrips = false;

  void _checkActiveTrips(List<Trip> trips) {
    if (_hasCheckedTrips) return;

    final activeTrips = trips.where((t) => !t.isExpired).toList();
    if (activeTrips.isEmpty) {
      _hasCheckedTrips = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoActiveTripsDialog();
      });
    }
  }

  void _showNoActiveTripsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.locationDot,
                color: Colors.orange,
                size: 28,
              ),
              SizedBox(width: 8.w),
              Text(
                'لا توجد رحلات نشطة',
                style: AppTypography.h5.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          content: Text(
            'لتتمكن من استقبال طلبات الشحن والتوصيل، يرجى إضافة مسار رحلة جديد.',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'إلغاء',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Navigator.pushNamed(context, Routes.addTrip);
                if (mounted) {
                  context.read<TripCubit>().loadTrips();
                }
              },
              child: Text(
                'إضافة رحلة الآن',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _shipmentCubit.addListener(_onCubitChange);
    _orderCubit.addListener(_onCubitChange);
    _shipmentCubit.loadShipments(filter: 'active');
    _orderCubit.loadOrders(filter: 'active');
    _loadStats();
    _connectSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final tripCubit = context.read<TripCubit>();
        if (tripCubit.state is TripLoaded) {
          _checkActiveTrips((tripCubit.state as TripLoaded).trips);
        }
        _checkPlatformFeeWarning();
      }
    });
  }

  bool _hasCheckedPlatformFee = false;

  Future<void> _checkPlatformFeeWarning() async {
    if (_hasCheckedPlatformFee) return;
    _hasCheckedPlatformFee = true;
    try {
      final getWalletUseCase = sl<GetWalletUseCase>();
      final result = await getWalletUseCase();
      result.fold((_) {}, (wallet) {
        if (wallet.duePlatformFees > 0 && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPlatformFeeWarningDialog(wallet.duePlatformFees);
          });
        }
      });
    } catch (_) {}
  }

  void _showPlatformFeeWarningDialog(double dueFees) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'تنبيه رسوم المنصة المستحقة',
                  style: GoogleFonts.tajawal(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'عزيزي الكابتن، بلغت رسوم المنصة المستحقة على محفظتك (${dueFees.toStringAsFixed(2)} ج.م).',
                style: GoogleFonts.tajawal(
                  fontSize: 14.sp,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'يرجى شحن رصيد رسوم المنصة لتجنب إيقاف استقبال الطلبات وحظر الحساب.',
                style: GoogleFonts.tajawal(
                  fontSize: 13.sp,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'متابعة العمل',
                style: GoogleFonts.tajawal(
                  fontSize: 13.sp,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DepositScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF204CB3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'شحن الرصيد الآن',
                style: GoogleFonts.tajawal(
                  fontSize: 13.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
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
        _loadStats();
        _joinActiveRooms();
      }
    }
  }

  Future<void> _refreshData() async {
    _shipmentCubit.loadShipments(filter: 'active');
    _orderCubit.loadOrders(filter: 'active');
    await _loadStats();
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
        debugPrint('🔌 Home socket connected');
        _joinActiveRooms();
      });
      _socket!.on('notification', (data) {
        debugPrint('📩 Home socket notification received');
        _refreshData();
      });
      _socket!.on('statusUpdate', (data) {
        debugPrint('🔄 Home socket statusUpdate received');
        _refreshData();
      });
      // ✅ Handle server-side timeout: captain's assignment was cleared
      _socket!.on('shipment_removed', (data) {
        debugPrint('❌ Home socket shipment_removed received: $data');
        _refreshData();
      });
      _socket!.on('order_removed', (data) {
        debugPrint('❌ Home socket order_removed received: $data');
        _refreshData();
      });
      _socket!.on('incoming_order', (data) {
        debugPrint('📩 Home socket incoming_order received: $data');
        _refreshData();
        if (mounted && data != null) {
          try {
            final payload = Map<String, dynamic>.from(data as Map);
            _showIncomingOrderDialogFromPayload(payload);
          } catch (_) {}
        }
      });
      _socket!.onDisconnect((_) {
        debugPrint('🔌 Home socket disconnected');
      });
    } catch (e) {
      debugPrint('Error connecting home socket: $e');
    }
  }

  void _showIncomingOrderDialogFromPayload(Map<String, dynamic> data) {
    final itemId = data['id']?.toString() ?? '';
    if (itemId.isEmpty || _rejectedIds.contains(itemId)) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingOrderDialog(
        orderId: itemId,
        orderNumber: data['orderNumber']?.toString() ?? data['shipmentNumber']?.toString() ?? '',
        orderType: data['orderType']?.toString() ?? 'توصيل طلب',
        pickupArea: data['pickupArea']?.toString() ?? 'منطقة الاستلام',
        deliveryArea: data['deliveryArea']?.toString() ?? 'منطقة التسليم',
        distance: '8.4 كم',
        priceText: data['priceText']?.toString() ?? '55 جنيه',
        timeAgo: 'الآن',
        notes: data['notes']?.toString() ?? 'يرجى التواصل قبل الاستلام',
        timeoutSeconds: data['timeoutSeconds'] is int ? data['timeoutSeconds'] : 60,
        onReject: () async {
          Navigator.pop(ctx);
          if (mounted) {
            setState(() {
              _rejectedIds.add(itemId);
            });
          }
          final isShipment = data['isShipment'] == true;
          if (isShipment) {
            try {
              // Use dedicated captain-response endpoint to properly clear captainId
              // and trigger auto-assignment for the next captain
              await _shipmentCubit.captainRespondToAssignment(itemId, 'reject');
            } catch (_) {}
          } else {
            try {
              // Use dedicated captain-response endpoint for orders too
              await _orderCubit.captainRespondToAssignment(itemId, 'reject');
            } catch (_) {}
          }
        },
        onAccept: () async {
          Navigator.pop(ctx);
          final isShipment = data['isShipment'] == true;
          if (isShipment) {
            try {
              // Use dedicated captain-response endpoint to accept
              await _shipmentCubit.captainRespondToAssignment(itemId, 'accept');
              if (mounted) {
                final shipment = await _shipmentCubit.getShipmentDetails(itemId);
                if (shipment != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DriverShipmentDetailsScreen(shipment: shipment),
                    ),
                  );
                }
              }
            } catch (_) {}
          } else {
            try {
              // Use dedicated captain-response endpoint for orders too
              await _orderCubit.captainRespondToAssignment(itemId, 'accept');
            } catch (_) {}
          }
        },
      ),
    );
  }

  bool _isShipmentActive(Shipment s) {
    final status = s.status.trim().toLowerCase();
    final inactiveStatuses = [
      'completed',
      'منتهية',
      'منتهي',
      'cancelled',
      'ملغية',
      'ملغي',
      'جديدة',
      'new',
      'في انتظار القبول',
      'pending',
    ];
    return !inactiveStatuses.contains(status);
  }

  bool _isOrderActive(OrderEntity o) {
    final status = o.status.trim().toLowerCase();
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
      'بانتظار القبول',
      'pending',
    ];
    return !inactiveStatuses.contains(status);
  }

  bool _isShipmentCompleted(Shipment s) {
    final status = s.status.trim().toLowerCase();
    return status == 'completed' || status == 'منتهية' || status == 'منتهي';
  }

  bool _isOrderCompleted(OrderEntity o) {
    final status = o.status.trim().toLowerCase();
    return status == 'completed' ||
        status == 'منتهي' ||
        status == 'منتهية' ||
        status == 'مكتملة';
  }

  void _joinActiveRooms() {
    if (_socket == null || !_socket!.connected) return;

    final activeShipments = _shipmentCubit.allShipments
        .where(_isShipmentActive)
        .toList();
    final activeOrders = _orderCubit.allOrders.where(_isOrderActive).toList();

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
      _socket!.off('shipment_removed');
      _socket!.off('order_removed');
      _socket!.disconnect();
      _socket = null;
    }
  }

  void _navigateToShipmentDetails(Shipment shipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverShipmentDetailsScreen(shipment: shipment),
      ),
    );
  }

  void _navigateToOrderDetails(OrderEntity order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DriverOrderDetailsScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeShipments = _shipmentCubit.allShipments
        .where(_isShipmentActive)
        .toList();
    final activeOrders = _orderCubit.allOrders.where(_isOrderActive).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: BlocListener<TripCubit, TripState>(
          listener: (context, state) {
            if (state is TripLoaded) {
              _checkActiveTrips(state.trips);
            }
          },
          child: SafeArea(
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
                          arguments: {'isDelivery': true},
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
                    _buildSectionHeader('الطلبات النشطة'),
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
                    _buildSectionHeader('الاحصائيات'),
                    const SizedBox(height: 12),
                    _isLoadingStats
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              _buildStatCard(
                                title: 'الطلبات المتاحة',
                                count:
                                    '$_availableShipments شحنة، $_availableOrders طلب',
                                icon: AppAssets.orderta,
                                iconColor: const Color(0xFF204CB3),
                                bgColor: const Color(0xFFF0F5FF),
                              ),
                              const SizedBox(height: 12),
                              _buildStatCard(
                                title: 'الطلبات المنتهية',
                                count:
                                    '$_completedShipments شحنة، $_completedOrders طلب',
                                icon: AppAssets.ordersa,
                                iconColor: const Color(0xFF4CAF50),
                                bgColor: const Color(0xFFE8F5E9),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
    if (_rejectedIds.contains(shipment.id)) return const SizedBox.shrink();

    final status = shipment.status.trim().toLowerCase();
    final approval = (shipment.captainApprovalStatus ?? '').trim().toLowerCase();

    final isAccepted = approval == 'accepted' ||
        status == 'جاري التنفيذ' ||
        status == 'تم القبول' ||
        status == 'in transit' ||
        status == 'picked up' ||
        status == 'completed' ||
        status == 'delivered' ||
        status == 'منتهية';

    final isUnaccepted = !isAccepted && (
        status == 'assigned to captain' ||
        status == 'ready for assignment' ||
        status == 'في انتظار القبول' ||
        status == 'بانتظار القبول' ||
        status == 'pending' ||
        status == 'new' ||
        status == 'جديد' ||
        status == 'جديدة'
    );

    if (isUnaccepted) {
      return AvailableItemCard(
        itemId: shipment.id,
        timeoutSeconds: 60,
        isOrder: false,
        itemNumber: shipment.shipmentNumber,
        fromAddress: shipment.fromAddress,
        toAddress: shipment.toAddress,
        priceText: '${shipment.price.toInt()} ج.م',
        weightText:
            shipment.weight != null ? '${shipment.weight!.toInt()} كجم' : 'غير محدد',
        statusText: ShipmentStatus.getArabicStatus(shipment.status),
        onTimeout: () async {
          if (mounted) {
            setState(() {
              _rejectedIds.add(shipment.id);
            });
          }
          try {
            await _shipmentCubit.updateShipmentStatus(shipment.id, 'timeout');
          } catch (_) {}
        },
        onReject: () async {
          if (mounted) {
            setState(() {
              _rejectedIds.add(shipment.id);
            });
          }
          try {
            await _shipmentCubit.updateShipmentStatus(shipment.id, 'rejected');
          } catch (_) {}
        },
        onAccept: () async {
          try {
            await _shipmentCubit.updateShipmentStatus(
              shipment.id,
              'جاري التنفيذ',
              negotiatedPrice: shipment.price,
            );
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
                  'سعر التوصيل',
                  '${shipment.negotiatedPrice ?? shipment.price} ج',
                ),
                _buildInfoColumn('الوزن', '${shipment.weight ?? 0} كجم'),
                _buildInfoColumn(
                  'الحالة',
                  ShipmentStatus.getArabicStatus(shipment.status),
                ),
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
    if (_rejectedIds.contains(order.id)) return const SizedBox.shrink();

    final status = order.status.trim().toLowerCase();
    final approval = (order.captainApprovalStatus ?? '').trim().toLowerCase();

    final isAccepted = approval == 'accepted' ||
        status == 'جاري التنفيذ' ||
        status == 'تم القبول' ||
        status == 'in transit' ||
        status == 'picked up' ||
        status == 'completed' ||
        status == 'finished' ||
        status == 'delivered' ||
        status == 'منتهية';

    final isUnaccepted = !isAccepted && (
        status == 'assigned to captain' ||
        status == 'ready for assignment' ||
        status == 'في انتظار القبول' ||
        status == 'بانتظار القبول' ||
        status == 'pending' ||
        status == 'new' ||
        status == 'جديد' ||
        status == 'جديدة'
    );

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
            await _orderCubit.updateOrderStatus(order.id, 'timeout');
          } catch (_) {}
        },
        onReject: () async {
          if (mounted) {
            setState(() {
              _rejectedIds.add(order.id);
            });
          }
          try {
            await _orderCubit.updateOrderStatus(order.id, 'rejected');
          } catch (_) {}
        },
        onAccept: () async {
          try {
            await _orderCubit.updateOrderStatus(order.id, 'جاري التنفيذ');
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
                        '#طلب رقم: ${order.id}',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'العميل: ${order.merchantName ?? order.clientName}',
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

  Widget _buildStatCard({
    required String title,
    required String count,
    required String icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SvgPicture.asset(icon, height: 48, width: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
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
}
