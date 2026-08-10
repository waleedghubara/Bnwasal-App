// ignore_for_file: strict_top_level_inference, deprecated_member_use, use_build_context_synchronously

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/order.dart';
import '../manager/order_cubit.dart';
import 'order_tracking_screen.dart';
import 'add_order_screen.dart';
import '../../../../core/services/appsflyer_service.dart';
import 'package:we_deliver/features/shipment/presentation/pages/offer_inbox_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/features/profile/presentation/bloc/review_cubit.dart';
import 'package:we_deliver/features/order/presentation/pages/direct_payment_page.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderEntity order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderCubit _cubit = sl<OrderCubit>();
  final ReviewCubit _reviewCubit = sl<ReviewCubit>();
  late OrderEntity _localOrder;
  late String _currentStatus;
  io.Socket? _socket;
  bool _hasReviewed = false;
  bool _ratingDialogShown = false;
  String _feeCollectionMode = 'after_agreement';

  bool _isStatusPending(String status) {
    return status == OrderStatus.pending ||
        status == 'Pending Review' ||
        status == 'قيد المراجعة' ||
        status == 'بانتظار القبول';
  }

  bool _isStatusAwaitingPayment(String status) {
    return false;
  }

  // Captain Arrived مخفي من الـ UI - لا يجب عرض زر خاص به
  bool _isStatusDelivered(String status) {
    return status == OrderStatus.delivered ||
        status == 'Delivered' ||
        status == 'تم التوصيل';
  }

  bool _isStatusCompleted(String status) {
    return status == OrderStatus.completed || status == 'Completed';
  }

  bool _isStatusCancelledOrRejected(String status) {
    return status == OrderStatus.cancelled ||
        status == OrderStatus.rejected ||
        status == 'Cancelled' ||
        status == 'Rejected' ||
        status == 'ملغاة' ||
        status == 'ملغي' ||
        status == 'مرفوض';
  }

  // حالات يظهر فيها زر "تتبع الطلب"
  bool _isStatusTrackable(String status) {
    return status == OrderStatus.assignedToCaptain ||
        status == OrderStatus.pickedUp ||
        status == OrderStatus.inTransit ||
        status == 'Assigned To Captain' ||
        status ==
            'Captain Arrived' || // يُعامل كـ Assigned To Captain في الـ UI
        status == 'Picked Up' ||
        status == 'In Transit';
  }

  @override
  void initState() {
    super.initState();
    _localOrder = widget.order;
    _currentStatus = _localOrder.status;
    _initSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderDetails();
    });
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
      debugPrint('🔌 Order Details Socket Connected: ${_socket!.id}');
      _socket!.emit('joinRoom', 'order_${_localOrder.id}');
    });

    _socket!.on('statusUpdate', (data) {
      debugPrint('🔔 Status updated via Socket: $data');
      _loadOrderDetails();
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 Order Details Socket Disconnected');
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
        _currentStatus = order.status;
      });
      _checkReviewStatus();
    }
  }

  Future<void> _checkReviewStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final hasReviewed =
          prefs.getBool('hasReviewed_order_${_localOrder.id}') ?? false;
      final mode = prefs.getString('fee_collection_mode') ?? 'after_agreement';
      setState(() {
        _hasReviewed = hasReviewed;
        _feeCollectionMode = mode;
      });

      if (_isStatusCompleted(_currentStatus) && !hasReviewed && !_ratingDialogShown) {
        final String name = _localOrder.captainName ?? 'المندوب';
        _showRatingDialog(context, name, isRatingDriver: true);
      }
    }
    try {
      final dio = sl<Dio>();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.appConfig}',
      );
      if (response.statusCode == 200 && response.data != null) {
        final configData = response.data['data'] as Map<String, dynamic>;
        final serverMode =
            configData['fee_collection_mode']?.toString() ?? 'after_agreement';
        if (mounted && serverMode != _feeCollectionMode) {
          setState(() {
            _feeCollectionMode = serverMode;
          });
          await prefs.setString('fee_collection_mode', serverMode);
        }
      }
    } catch (e) {
      print('❌ Failed to fetch config on details screen: $e');
    }
  }

  void _showRatingDialog(
    BuildContext context,
    String name, {
    bool isRatingDriver = false,
  }) {
    if (_ratingDialogShown) return;
    _ratingDialogShown = true;
    int currentRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isRatingDriver ? 'تقييم المندوب' : 'تقييم التاجر',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 16),

                      Text(
                        'كيف كانت تجربتك في التعامل مع $name؟',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starVal = index + 1;
                          final isSelected = starVal <= currentRating;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                currentRating = starVal;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Icon(
                                Icons.star_rounded,
                                color: isSelected
                                    ? const Color(0xFFFFB000)
                                    : Colors.grey.shade300,
                                size: 36,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: commentController,
                          maxLines: 3,
                          style: GoogleFonts.tajawal(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'اكتب تعليقك هنا (اختياري)...',
                            hintStyle: GoogleFonts.tajawal(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // close dialog
                            final prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'hasReviewed_order_${_localOrder.id}',
                              true,
                            );

                            try {
                              await _reviewCubit.submitReview(
                                shipmentId: 'order_${_localOrder.id}',
                                rating: currentRating,
                                comment: commentController.text.isEmpty
                                    ? null
                                    : commentController.text,
                                tags: null,
                              );
                            } catch (e) {
                              debugPrint('Error submitting review: $e');
                            }

                            _checkReviewStatus();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isRatingDriver
                                        ? 'شكراً لتقييمك للمندوب! تم حفظ التقييم بنجاح.'
                                        : 'شكراً لتقييمك! تم حفظ التقييم بنجاح.',
                                    style: GoogleFonts.tajawal(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F4C9B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'تأكيد التقييم',
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  ).then((_) {
    _ratingDialogShown = false;
  });
}

  Future<void> _payDeliveryFee() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      await sl<Dio>().post(
        '${EndPoint.baseUrl}${EndPoint.payDelivery}',
        data: {'orderId': _localOrder.id},
      );
      Navigator.pop(context); // pop loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم دفع الرسوم بنجاح من المحفظة'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrderDetails();
      }
    } catch (e) {
      Navigator.pop(context); // pop loader
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data is Map
                  ? (e.response!.data['message'] ?? 'فشل الدفع')
                  : 'فشل الدفع')
            : 'فشل الدفع';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _editOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddOrderScreen(
          cubit: _cubit,
          editingOrder: _localOrder,
        ),
      ),
    ).then((_) => _loadOrderDetails());
  }

  void _deleteOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'حذف الطلب',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('هل أنت متأكد من رغبتك في حذف هذا الطلب نهائيًا؟ لا يمكن التراجع عن هذا الإجراء.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // pop dialog
                showDialog(
                  context: this.context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
                
                final success = await _cubit.deleteOrder(_localOrder.id);
                
                Navigator.pop(this.context); // pop loader
                
                if (success && mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الطلب بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(this.context); // pop details screen
                } else if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(_cubit.errorMessage ?? 'فشل حذف الطلب'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                'حذف',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelivery() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition();
      await sl<Dio>().post(
        '${EndPoint.baseUrl}${EndPoint.confirmOrderDelivery(_localOrder.id)}',
        data: {'latitude': position.latitude, 'longitude': position.longitude},
      );
      Navigator.pop(context); // pop loader
      if (mounted) {
        sl<AppsFlyerService>().logEvent('af_purchase', {
          'order_id': _localOrder.id,
          'price': _localOrder.deliveryFee,
          'currency': 'EGP',
          'items_count': 1,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد استلام الطلب بنجاح واكتمال العملية'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrderDetails();
      }
    } catch (e) {
      Navigator.pop(context); // pop loader
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data is Map
                  ? (e.response!.data['message'] ?? 'فشل التأكيد')
                  : 'فشل التأكيد')
            : 'فشل التأكيد';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDirectPaymentBanner() {
    if (_localOrder.isPaid || _localOrder.directPayment == null) {
      return const SizedBox.shrink();
    }
    final dp = _localOrder.directPayment!;
    final String status = dp['status']?.toString() ?? 'pending';
    final String? adminNote = dp['adminNote']?.toString();

    if (status == 'pending') {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6), // Light warm amber
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade200, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              color: Colors.amber.shade800,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عملية الدفع قيد المراجعة',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تم استلام إيصال الدفع وجاري التحقق من تفاصيله من قبل الإدارة لتفعيل طلبك.',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (status == 'rejected') {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0), // Light red
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade700,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تم رفض إيصال الدفع السابق',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.red.shade900,
                    ),
                  ),
                  if (adminNote != null && adminNote.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'سبب الرفض: $adminNote',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'يرجى النقر على زر الدفع بالأسفل لإعادة إرسال إيصال جديد وصحيح.',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget? _buildBottomButton() {
    if (_isStatusCancelledOrRejected(_currentStatus)) {
      return null;
    }

    String buttonText = 'تتبع الطلب مباشر';
    VoidCallback? onPressed;

    final dp = _localOrder.directPayment;
    final isDpPending = dp != null && dp['status']?.toString() == 'pending';

    if (isDpPending && !_localOrder.isPaid) {
      buttonText = 'عملية الدفع قيد المراجعة';
      onPressed = null;
    } else if (_isStatusPending(_currentStatus)) {
      if (false) {
        // Negotiation is disabled
      } else {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleteOrderDialog,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text(
                    'حذف الطلب',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _editOrder,
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text(
                    'تعديل الطلب',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else if (!_localOrder.isPaid &&
        !_isStatusPending(_currentStatus) &&
        !_isStatusCancelledOrRejected(_currentStatus)) {
      // Payment is bypassed
      return null;
    } else if (_isStatusAwaitingPayment(_currentStatus)) {
      // Payment is bypassed
      return null;
      // Captain Arrived لم يعد موجوداً في الـ Flow الجديد - الكابتن يتحكم مباشرة في Picked Up
    } else if (_isStatusDelivered(_currentStatus)) {
      buttonText = 'تأكيد استلام الطلب وإتمام العملية';
      onPressed = _confirmDelivery;
    } else if (_isStatusCompleted(_currentStatus)) {
      if (!_hasReviewed) {
        buttonText = 'تقييم المندوب';
        onPressed = () {
          final String name = _localOrder.captainName ?? 'المندوب';
          _showRatingDialog(context, name, isRatingDriver: true);
        };
      } else {
        return null;
      }
    } else if (_isStatusTrackable(_currentStatus)) {
      onPressed = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(order: _localOrder),
          ),
        );
      };
    } else {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: onPressed == null
                ? Colors.grey.shade300
                : const Color(0xFF1F4C9B),
            foregroundColor: onPressed == null
                ? Colors.grey.shade600
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            buttonText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'تفاصيل الطلب #${_localOrder.orderNumber}',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 18,
              color: Colors.black87,
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadOrderDetails,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInDown(child: _buildStatusCard()),
                const SizedBox(height: 20),
                _buildDirectPaymentBanner(),
                const SizedBox(height: 20),
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: _buildSectionCard('تفاصيل الطلب', [
                    _buildInfoRow(
                      FontAwesomeIcons.box,
                      'المحتوى',
                      _localOrder.details,
                    ),
                    if (_localOrder.notes != null &&
                        _localOrder.notes!.isNotEmpty)
                      _buildInfoRow(
                        FontAwesomeIcons.noteSticky,
                        'ملاحظات',
                        _localOrder.notes!,
                      ),
                  ]),
                ),
                const SizedBox(height: 20),
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: _buildSectionCard('معلومات التوصيل', [
                    _buildInfoRow(
                      FontAwesomeIcons.store,
                      'مكان الشراء',
                      _localOrder.storeDescription,
                    ),
                    _buildInfoRow(
                      FontAwesomeIcons.locationDot,
                      'عنوان التوصيل',
                      _localOrder.deliveryAddress,
                    ),
                    _buildInfoRow(
                      FontAwesomeIcons.phone,
                      'رقم الهاتف',
                      _localOrder.phone,
                    ),
                    _buildInfoRow(
                      FontAwesomeIcons.user,
                      'اسم العميل',
                      _localOrder.clientName,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: _buildSectionCard('التكلفة', [
                    _buildPriceRow('سعر الطلبات', _localOrder.orderPrice),
                    _buildPriceRow('سعر التوصيل', _localOrder.deliveryFee),
                    const Divider(height: 32),
                    _buildPriceRow(
                      'الإجمالي',
                      _localOrder.orderPrice + _localOrder.deliveryFee,
                      isTotal: true,
                    ),
                  ]),
                ),
                FadeInUp(
                  delay: const Duration(milliseconds: 700),
                  child: _buildDriverSection(),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomButton(),
      ),
    );
  }

  Widget _buildStatusCard() {
    final color = _getStatusColor(_currentStatus);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            OrderStatus.getArabicStatus(_currentStatus),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'تم التحديث في ${_localOrder.createdAt.hour}:${_localOrder.createdAt.minute}',
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FaIcon(icon, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double price, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.black87 : Colors.grey,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${price.toInt()} ج.م',
          style: TextStyle(
            color: isTotal ? AppColors.primary : Colors.black87,
            fontSize: isTotal ? 20 : 16,
            fontWeight: FontWeight.bold,
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
        return Colors.indigo;
      case OrderStatus.awaitingPayment:
        return Colors.purple;
      case OrderStatus.readyForAssignment:
        return Colors.blue;
      case OrderStatus.assignedToCaptain:
      case OrderStatus.captainArrived:
        return Colors.teal;
      case OrderStatus.pickedUp:
      case OrderStatus.inTransit:
        return Colors.amber.shade800;
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

  Widget _buildDriverSection() {
    if (_localOrder.captainId == null || _localOrder.captainName == null) {
      return const SizedBox.shrink();
    }
    final bool isTrackable = _isStatusTrackable(_currentStatus);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المندوب المكلف',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              () {
                final String driverNameStr =
                    _localOrder.captainName ?? 'المندوب';
                final String initials = driverNameStr.isNotEmpty
                    ? driverNameStr
                          .trim()
                          .split(' ')
                          .map((w) => w.isNotEmpty ? w[0] : '')
                          .take(2)
                          .join()
                    : 'م';
                Widget avWidget = CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE8F1FF),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4C9B),
                    ),
                  ),
                );

                final String? driverAvatarPath = _localOrder.captainAvatar;
                if (driverAvatarPath != null && driverAvatarPath.isNotEmpty) {
                  final String fullUrl = driverAvatarPath.startsWith('http')
                      ? driverAvatarPath
                      : '${EndPoint.imageBaseUrl}$driverAvatarPath';
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      children: [
                        avWidget,
                        ClipOval(
                          child: Image.network(
                            fullUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return avWidget;
              }(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localOrder.captainName!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _localOrder.captainPhone ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_localOrder.captainPhone != null &&
                      _localOrder.captainPhone!.isNotEmpty)
                    IconButton(
                      onPressed: () async {
                        final Uri url = Uri.parse(
                          'tel:${_localOrder.captainPhone}',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      icon: const Icon(
                        Icons.phone_forwarded,
                        color: Colors.green,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  if (isTrackable) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OrderTrackingScreen(order: _localOrder),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.map,
                        color: Color(0xFF1F4C9B),
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1F4C9B,
                        ).withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPaymentSelectionBottomSheet(
    BuildContext context,
    double price,
    VoidCallback onWalletPay,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'اختر طريقة دفع رسوم التوصيل',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'قيمة رسوم التوصيل: ${price.toInt()} ج.م',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            // Wallet Pay Option
            InkWell(
              onTap: () {
                Navigator.pop(context);
                onWalletPay();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary.withOpacity(0.05),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الدفع من المحفظة',
                            style: GoogleFonts.tajawal(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'سيتم خصم قيمة الرسوم من رصيد محفظتك المتاح مباشرة',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Direct Pay Now Option
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectPaymentPage(
                      itemId: _localOrder.id,
                      itemType: 'order',
                      itemNumber: _localOrder.orderNumber,
                      amount: _localOrder.deliveryFee,
                      merchantName: _localOrder.merchantName ?? 'التاجر',
                      merchantPhone: _localOrder.merchantPhone ?? '',
                      merchantImage: _localOrder.merchantAvatar,
                    ),
                  ),
                ).then((_) => _loadOrderDetails());
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green.shade50,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smartphone_rounded,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الدفع الآن (تحويل مصرفي)',
                            style: GoogleFonts.tajawal(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'فودافون كاش، انستا باي — وارفع إيصال الدفع',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
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
}
