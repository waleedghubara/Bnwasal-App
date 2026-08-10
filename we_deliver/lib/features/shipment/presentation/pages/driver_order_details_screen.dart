import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:we_deliver/core/theme/colors.dart';
import '../../../../core/theme/app_assets.dart';
import '../../../order/domain/entities/order.dart';
import '../../../order/presentation/pages/order_tracking_screen.dart';
import '../../../../core/api/end_point.dart';

import 'package:dio/dio.dart';

import 'package:we_deliver/core/di/injection_container.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:we_deliver/core/cache/cache_helper.dart';
import '../../../order/presentation/manager/order_cubit.dart';
import '../../../../core/utils/text_sanitizer.dart';


class DriverOrderDetailsScreen extends StatefulWidget {
  final OrderEntity order;

  const DriverOrderDetailsScreen({super.key, required this.order});

  @override
  State<DriverOrderDetailsScreen> createState() =>
      _DriverOrderDetailsScreenState();
}

enum OrderNegotiationState {
  initial,
  negotiating,
  pendingMerchant,
  tripStarted,
}

class _DriverOrderDetailsScreenState extends State<DriverOrderDetailsScreen> {
  final OrderCubit _cubit = sl<OrderCubit>();
  late OrderEntity _localOrder;
  io.Socket? _socket;
  late double _originalDeliveryFee;
  late double _currentDeliveryFee;
  double get _driverDeliveryFee => _currentDeliveryFee;

  OrderNegotiationState _negotiationState = OrderNegotiationState.initial;
  bool _showMerchantApprovalBanner = false;

  @override
  void initState() {
    super.initState();
    _localOrder = widget.order;
    _originalDeliveryFee = _localOrder.deliveryFee;
    _currentDeliveryFee = _originalDeliveryFee;
    _updateNegotiationState();
    _initSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderDetails();
    });
  }

  void _updateNegotiationState() {
    if (_localOrder.status == OrderStatus.pending) {
      _negotiationState = OrderNegotiationState.initial;
    } else if (_localOrder.status == OrderStatus.negotiation) {
      _negotiationState = OrderNegotiationState.negotiating;
    } else if (_localOrder.status == OrderStatus.awaitingPayment) {
      _negotiationState = OrderNegotiationState.pendingMerchant;
    } else if (_localOrder.status == OrderStatus.assignedToCaptain ||
        _localOrder.status == OrderStatus.captainArrived ||
        _localOrder.status == OrderStatus.pickedUp ||
        _localOrder.status == OrderStatus.inTransit ||
        _localOrder.status == OrderStatus.delivered ||
        _localOrder.status == OrderStatus.completed) {
      _negotiationState = OrderNegotiationState.tripStarted;
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
      debugPrint('🔌 Driver Order Details Socket Connected: ${_socket!.id}');
      _socket!.emit('joinRoom', 'order_${_localOrder.id}');
    });

    _socket!.on('statusUpdate', (data) {
      debugPrint('🔔 Status updated via Socket (Driver): $data');
      _loadOrderDetails();
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 Driver Order Details Socket Disconnected');
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    final order = await _cubit.getOrderById(_localOrder.id);
    if (order != null && mounted) {
      setState(() {
        _localOrder = order;
        _currentDeliveryFee = order.deliveryFee;
        _updateNegotiationState();
      });
    }
  }

  void _showCancellationReasonsDialog() {
    int selectedIndex = 0;
    final reasons = [
      'العميل لا يستجيب للرسائل أو المكالمات',
      'تفاصيل الطلب غير واضحة (محتوى، سعر، عنوان)',
      'العميل يريد تغيير الاتفاق أو السعر بعد الاتفاق',
      'الطلب يبدو غير موثوق فيه',
      'سبب آخر',
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'اختر أسباب الرفض',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(
                              Icons.close,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 12),
                      ...List.generate(reasons.length, (index) {
                        final isSelected = selectedIndex == index;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedIndex = index;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF1F4C9B)
                                          : Colors.grey.shade200,
                                      width: 2,
                                    ),
                                    color: Colors.white,
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF1F4C9B),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    reasons[index],
                                    style: GoogleFonts.tajawal(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.black87
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                // Action confirmed: reset state back to initial and pop back
                                setState(() {
                                  _negotiationState =
                                      OrderNegotiationState.initial;

                                  _currentDeliveryFee = _originalDeliveryFee;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تم رفض الطلب بنجاح.',
                                      style: GoogleFonts.tajawal(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                                Navigator.pop(
                                  context,
                                ); // Go back to shipments screen
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F4C9B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'تأكيد الرفض',
                                style: GoogleFonts.tajawal(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                'إلغاء',
                                style: GoogleFonts.tajawal(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
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
            );
          },
        );
      },
    );
  }

  Widget _buildMerchantApprovalBanner() {
    final avatar = _localOrder.merchantAvatar;
    final name = _localOrder.merchantName ?? _localOrder.clientName;

    final fullAvatarUrl = avatar != null && avatar.isNotEmpty
        ? '${EndPoint.imageBaseUrl}$avatar'
        : 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-1.2.1&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  fullAvatarUrl,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 42,
                    height: 42,
                    color: const Color(0xFFE8F1FF),
                    child: Center(
                      child: Text(
                        safeFirstChar(name, 'ع'),
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F4C9B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Color(0xFFFFB000),
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '4.7',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFB000),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'وافق العميل على عرض السعر المقترح الخاص بك: ${_driverDeliveryFee.toInt()} ج.م',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _showMerchantApprovalBanner = false;
                  });
                  _showCancellationReasonsDialog();
                },
                child: Text(
                  'رفض',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showMerchantApprovalBanner = false;
                    _negotiationState = OrderNegotiationState.tripStarted;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم بدء الرحلة بنجاح!',
                        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: const Color(0xFF1F4C9B),
                    ),
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderTrackingScreen(
                        order: _localOrder,
                        shipmentData: {
                          'clientName': _localOrder.clientName,
                          'number': _localOrder.orderNumber,
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4C9B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'موافق',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _localOrder;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black87,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'تفاصيل الطلب',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: _loadOrderDetails,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Header Card
                      _buildHeaderCard(order),
                      const SizedBox(height: 16),

                      // Client Info Section
                      _buildClientSection(order),
                      const SizedBox(height: 16),

                      // Order details section (Same fields as add order screen)
                      _buildOrderDetailsCard(order),
                      const SizedBox(height: 16),

                      // Addresses Section
                      _buildAddressesSection(order),
                      const SizedBox(height: 16),

                      // Costs Section
                      _buildCostsSection(order),
                      const SizedBox(height: 80), // spacer for bottom panel
                    ],
                  ),
                ),
              ),
            ),

            // Sliding merchant approval notification banner
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.fastOutSlowIn,
              top: 16,
              right: _showMerchantApprovalBanner
                  ? 16
                  : -MediaQuery.of(context).size.width,
              width: MediaQuery.of(context).size.width - 32,
              child: _buildMerchantApprovalBanner(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomPanel(),
      ),
    );
  }

  Widget _buildHeaderCard(OrderEntity order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            height: 65,
            width: 65,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SvgPicture.asset(AppAssets.box, width: 60, height: 60),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#رقم الطلب: ${order.orderNumber}',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'وقت الطلب:',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ' ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildClientSection(OrderEntity order) {
    final avatar = order.merchantAvatar;
    final name = order.merchantName ?? order.clientName;
    final phone = order.merchantPhone ?? order.phone;

    final fullAvatarUrl = avatar != null && avatar.isNotEmpty
        ? '${EndPoint.imageBaseUrl}$avatar'
        : 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-1.2.1&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات العميل',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  fullAvatarUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFFE8F1FF),
                    child: Center(
                      child: Text(
                        safeFirstChar(name, 'ع'),
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F4C9B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFFFFB000), size: 14),
                    SizedBox(width: 4),
                    Text(
                      '4.7',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFB000),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard(OrderEntity order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل الطلبات والمحتوى',
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'تفاصيل الطلبات:',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order.details,
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'الملاحظات:',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              order.notes!,
              style: GoogleFonts.tajawal(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressesSection(OrderEntity order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.mapLocationDot,
                color: Colors.grey.shade400,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'العناوين وموقع التوصيل',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '📍 موقع الاستلام:',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  order.pickupAddress,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  'عنوان التوصيل:',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  order.deliveryAddress,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostsSection(OrderEntity order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.moneyBillWave,
                color: Colors.grey.shade400,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'التكلفة الإجمالية للطلب',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRow('المبلغ (سعر الطلب)', '${order.orderPrice.toInt()} ج.م'),
          _buildRow(
            'رسوم التوصيل المقترحة',
            '${_driverDeliveryFee.toInt()} ج.م',
            isHighlighted: true,
          ),
          const Divider(height: 24, color: Color(0xFFEEEEEE)),
          _buildRow(
            'الإجمالي الكلي',
            '${(order.orderPrice + _driverDeliveryFee).toInt()} ج.م',
            isHighlighted: true,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isHighlighted = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.tajawal(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: isTotal ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: isTotal
                  ? AppColors.primary
                  : (isHighlighted ? const Color(0xFFF78710) : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final approvalStatus = _localOrder.captainApprovalStatus;
    if (approvalStatus == 'pending') {
      return _buildApprovalPendingBanner();
    }

    final orderStatus = _localOrder.status;

    if (orderStatus == OrderStatus.completed ||
        orderStatus == OrderStatus.finished ||
        orderStatus == OrderStatus.cancelled ||
        orderStatus == OrderStatus.rejected) {
      return const SizedBox.shrink();
    }

    if (_negotiationState == OrderNegotiationState.tripStarted) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderTrackingScreen(
                      order: _localOrder,
                      shipmentData: {
                        'clientName': _localOrder.clientName,
                        'number': _localOrder.orderNumber,
                      },
                    ),
                  ),
                ).then((_) {
                  setState(() {});
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4C9B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'ابدأ الرحلة',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // الكابتن لا يرى خيارات التفاوض نهائياً - فقط قبول/رفض (pending) أو خطوات الرحلة (tripStarted)
    return const SizedBox.shrink();
  }

  Widget _buildApprovalPendingBanner() {
    final order = _localOrder;
    final orderPrice = order.orderPrice.toInt();
    final deliveryFee = _driverDeliveryFee.toInt();
    final captainShare = (deliveryFee * 0.8).toInt();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تكليف طلب جديد 📋',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFB000).withOpacity(0.3)),
                  ),
                  child: Text(
                    'بانتظار موافقتك',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFB000),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Locations Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store_rounded, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'موقع الاستلام: ',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          order.pickupAddress,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'موقع التسليم: ',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Financials Grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'سعر الطلب',
                          style: GoogleFonts.tajawal(fontSize: 11, color: Colors.blue.shade800),
                        ),
                        Text(
                          '$orderPrice ج.م',
                          style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'صافي ربحك (80%)',
                          style: GoogleFonts.tajawal(fontSize: 11, color: Colors.green.shade800),
                        ),
                        Text(
                          '$captainShare ج.م',
                          style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'رسوم التوصيل',
                          style: GoogleFonts.tajawal(fontSize: 11, color: Colors.orange.shade800),
                        ),
                        Text(
                          '$deliveryFee ج.م',
                          style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Accept / Reject Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleCaptainResponse('reject'),
                    icon: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                    label: Text(
                      '❌ رفض',
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCaptainResponse('accept'),
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    label: Text(
                      '✅ قبول',
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F4C9B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
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

  Future<void> _handleCaptainResponse(String response) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      final orderId = _localOrder.id;
      await sl<Dio>().put(
        '${EndPoint.baseUrl}${EndPoint.getOrders}/$orderId/captain-response',
        data: {'response': response},
      );
      Navigator.pop(context); // pop loader
      if (mounted) {
        if (response == 'accept') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم قبول الطلب بنجاح 🎉'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض الطلب وإعادته للإدارة ❌'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context); // Go back to orders list
        }
      }
    } catch (e) {
      Navigator.pop(context); // pop loader
      if (mounted) {
        String errMsg = e.toString();
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errMsg = data['message'].toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $errMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
