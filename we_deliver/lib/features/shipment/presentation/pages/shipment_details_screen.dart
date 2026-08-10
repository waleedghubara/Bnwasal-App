// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/services/appsflyer_service.dart';
import 'package:we_deliver/features/shipment/domain/entities/shipment.dart';
import 'package:we_deliver/features/shipment/presentation/manager/shipment_cubit.dart';
import 'package:we_deliver/features/shipment/presentation/pages/add_shipment_screen.dart';
import 'package:we_deliver/features/shipment/presentation/pages/track_shipment_screen.dart';
import 'package:we_deliver/features/profile/presentation/bloc/review_cubit.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/typography.dart';
import 'package:we_deliver/features/order/presentation/pages/direct_payment_page.dart';

class ShipmentDetailsScreen extends StatefulWidget {
  final Shipment shipment;

  const ShipmentDetailsScreen({super.key, required this.shipment});

  @override
  State<ShipmentDetailsScreen> createState() => _ShipmentDetailsScreenState();
}

class _ShipmentDetailsScreenState extends State<ShipmentDetailsScreen> {
  final ShipmentCubit _cubit = sl<ShipmentCubit>();
  final ReviewCubit _reviewCubit = sl<ReviewCubit>();
  late String _currentStatus;
  bool _isDelivery = false;
  late Shipment _localShipment;
  String _driverRating = '—';
  bool _hasReviewed = false;
  bool _ratingDialogShown = false;
  // Cached user data for payment screens
  String? _cachedUserName;
  String? _cachedUserPhone;
  String? _cachedUserImage;

  @override
  void initState() {
    super.initState();
    _localShipment = widget.shipment;
    _currentStatus = _localShipment.status;
    _loadUserRole();
    _loadCachedUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShipmentDetails();
    });
  }

  Future<void> _loadCachedUser() async {
    final cache = SecureCacheHelper();
    final name = await cache.getData(key: 'firstName') ?? '';
    final lastName = await cache.getData(key: 'lastName') ?? '';
    final phone = await cache.getData(key: ApiKey.phone) ?? '';
    final image = await cache.getData(key: ApiKey.profileImage);
    if (mounted) {
      setState(() {
        _cachedUserName = '$name $lastName'.trim().isEmpty
            ? 'التاجر'
            : '$name $lastName'.trim();
        _cachedUserPhone = phone;
        _cachedUserImage = image;
      });
    }
  }

  Future<void> _loadRatingsAndReviewStatus() async {
    if (!mounted) return;

    // 1. Fetch driver's average rating (only if we have a driverId)
    if (_localShipment.driverId != null) {
      final summary = await _reviewCubit.getUserRating(
        _localShipment.driverId!,
      );
      if (summary != null && mounted) {
        setState(() {
          _driverRating = summary.formattedRating;
        });
      }
    }

    // 2. Check if the current shipment has already been reviewed
    final status = await _reviewCubit.checkReviewStatus(_localShipment.id);
    if (status != null && mounted) {
      setState(() {
        _hasReviewed = status.hasReviewed;
      });

      final String statusLower = (_localShipment.status).trim().toLowerCase();
      final bool isCompleted =
          statusLower == 'completed' ||
          statusLower == 'finished' ||
          statusLower == 'منتهية' ||
          statusLower == 'منتهي' ||
          statusLower == 'مكتملة';

      if (isCompleted && !_isDelivery && !_hasReviewed && !_ratingDialogShown) {
        _ratingDialogShown = true;
        _showRatingBottomSheet();
      }
    }
  }

  Future<void> _loadShipmentDetails() async {
    final shipment = await _cubit.getShipmentDetails(_localShipment.id);
    if (shipment != null && mounted) {
      setState(() {
        _localShipment = shipment;
        _currentStatus = shipment.status;
      });
      _loadRatingsAndReviewStatus();
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDelivery = prefs.getBool('isDelivery') ?? false;
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      await _cubit.updateShipmentStatus(_localShipment.id, status);
      if (mounted) {
        Navigator.pop(context); // Pop loader
        if (_cubit.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cubit.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          setState(() {
            _currentStatus = status;
          });
          _loadShipmentDetails();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Extracts a readable Arabic error message from a DioException response.
  String _extractErrorMessage(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      switch (e.response?.statusCode) {
        case 400:
          return 'العملية غير متاحة حالياً. تحقق من حالة الشحنة';
        case 403:
          return 'غير مصرح لك بتنفيذ هذه العملية';
        case 404:
          return 'الشحنة غير موجودة';
      }
    }
    return e.toString();
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
        data: {'shipmentId': _localShipment.id},
      );
      Navigator.pop(context); // pop loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم دفع الرسوم بنجاح من المحفظة'),
            backgroundColor: Colors.green,
          ),
        );
        _loadShipmentDetails();
      }
    } catch (e) {
      Navigator.pop(context); // pop loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الدفع: ${_extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editShipment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddShipmentScreen(cubit: _cubit, editingShipment: _localShipment),
      ),
    ).then((_) => _loadShipmentDetails());
  }

  void _deleteShipmentDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'حذف الشحنة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في حذف هذه الشحنة نهائيًا؟ لا يمكن التراجع عن هذا الإجراء.',
          ),
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

                final success = await _cubit.deleteShipment(_localShipment.id);

                Navigator.pop(this.context); // pop loader

                if (success && mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الشحنة بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(this.context); // pop details screen
                } else if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(_cubit.errorMessage ?? 'فشل حذف الشحنة'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                'حذف',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPickup() async {
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
        '${EndPoint.baseUrl}${EndPoint.confirmShipmentPickup(_localShipment.id)}',
        data: {'latitude': position.latitude, 'longitude': position.longitude},
      );
      Navigator.pop(context); // pop loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد تسليم الشحنة للمندوب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadShipmentDetails();
      }
    } catch (e) {
      Navigator.pop(context); // pop loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التأكيد: ${_extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        '${EndPoint.baseUrl}${EndPoint.confirmShipmentDelivery(_localShipment.id)}',
        data: {'latitude': position.latitude, 'longitude': position.longitude},
      );
      Navigator.pop(context); // pop loader
      if (mounted) {
        sl<AppsFlyerService>().logEvent('af_purchase', {
          'order_id': _localShipment.id,
          'price': _localShipment.price,
          'currency': 'EGP',
          'items_count': 1,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد استلام الشحنة بنجاح واكتمال الطلب'),
            backgroundColor: Colors.green,
          ),
        );
        _loadShipmentDetails();
      }
    } catch (e) {
      Navigator.pop(context); // pop loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التأكيد: ${_extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDirectPaymentBanner() {
    if (_localShipment.isPaid || _localShipment.directPayment == null) {
      return const SizedBox.shrink();
    }
    final dp = _localShipment.directPayment!;
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
    final String statusLower = _currentStatus.trim().toLowerCase();
    if (statusLower == 'completed' ||
        statusLower == 'finished' ||
        statusLower == 'cancelled' ||
        statusLower == 'منتهية' ||
        statusLower == 'منتهي' ||
        statusLower == 'مكتملة' ||
        statusLower == 'ملغية' ||
        statusLower == 'ملغي') {
      return null;
    }

    String buttonText = 'تتبع الشحنة';
    VoidCallback? onPressed;

    if (_isDelivery) {
      if (statusLower == 'pending review' ||
          statusLower == 'pending_review' ||
          statusLower == 'newshipment') {
        buttonText = 'قبول الشحنة';
        onPressed = () => _updateStatus(ShipmentStatus.pending);
      } else if (statusLower == 'pending review' ||
          statusLower == 'pending_review' ||
          statusLower == 'assigned to captain' ||
          statusLower == 'assigned_to_captain') {
        buttonText = 'بدء التوصيل (قيد التنفيذ)';
        onPressed = () => _updateStatus(ShipmentStatus.inExecution);
      } else if (statusLower == 'picked up' ||
          statusLower == 'picked_up' ||
          statusLower == 'in transit' ||
          statusLower == 'in_transit') {
        buttonText = 'تأكيد إتمام التوصيل';
        onPressed = () => _updateStatus(ShipmentStatus.delivered);
      } else {
        return null;
      }
    } else {
      final dp = _localShipment.directPayment;
      final isDpPending = dp != null && dp['status']?.toString() == 'pending';

      if (isDpPending && !_localShipment.isPaid) {
        buttonText = 'عملية الدفع قيد المراجعة';
        onPressed = null;
      } else if ((statusLower == 'pending review' ||
              statusLower == 'pending_review' ||
              statusLower == 'newshipment') &&
          _localShipment.driverId == null) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleteShipmentDialog,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text(
                    'حذف الشحنة',
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
                  onPressed: _editShipment,
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text(
                    'تعديل الشحنة',
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
      if (statusLower == 'negotiation') {
        // Negotiation is disabled
        return null;
      } else if (!_localShipment.isPaid &&
          statusLower != 'pending review' &&
          statusLower != 'pending_review' &&
          statusLower != 'cancelled') {
        // Payment is bypassed
        return null;
      } else if (statusLower == 'awaiting payment' ||
          statusLower == 'awaiting_payment') {
        // Payment is bypassed
        return null;
      } else if (statusLower == 'captain arrived' ||
          statusLower == 'captain_arrived') {
        buttonText = 'تأكيد تسليم الشحنة للمندوب';
        onPressed = _confirmPickup;
      } else if (statusLower == 'delivered') {
        buttonText = 'تأكيد استلام الشحنة واكتمال الطلب';
        onPressed = _confirmDelivery;
      } else if (statusLower == 'pending review' ||
          statusLower == 'pending_review' ||
          statusLower == 'pending') {
        final proposedPrice =
            _localShipment.negotiatedPrice ?? _localShipment.price;
        final hasNegotiation =
            _localShipment.negotiatedPrice != null &&
            _localShipment.negotiatedPrice != _localShipment.price;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFB000).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFFFB000)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasNegotiation
                            ? 'يقترح المندوب ${_localShipment.driverName ?? "عبد الرحمن"} سعر توصيل جديد: ${proposedPrice.toInt()} ج بدلاً من ${_localShipment.price.toInt()} ج'
                            : 'طلب المندوب ${_localShipment.driverName ?? "عبد الرحمن"} توصيل الشحنة بالسعر الأصلي: ${_localShipment.price.toInt()} ج',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _updateStatus(ShipmentStatus.newShipment),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'رفض العرض',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _updateStatus(ShipmentStatus.offerAccepted),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F4C9B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        'قبول العرض',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      } else if (statusLower == 'ready for assignment' ||
          statusLower == 'ready_for_assignment') {
        buttonText = 'بانتظار تعيين مندوب من الإدارة';
        onPressed = null;
      } else {
        onPressed = () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrackShipmentScreen(shipment: _localShipment),
            ),
          );
        };
      }
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
              fontSize: 16,
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
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تفاصيل الشحنة',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadShipmentDetails,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              // Header Card
              _buildHeaderCard(),
              const SizedBox(height: 10),
              _buildDirectPaymentBanner(),
              const SizedBox(height: 10),
              _buildDriverSection(),
              const SizedBox(height: 10),
              // Timeline progress
              _buildRouteTimeline(),
              const SizedBox(height: 24),
              // Order details
              _buildSection(
                title: 'تفاصيل الطلب',
                icon: FontAwesomeIcons.boxOpen,
                child: _buildOrderDetails(),
              ),
              const SizedBox(height: 16),
              // Addresses
              _buildSection(
                title: 'العناوين',
                icon: FontAwesomeIcons.locationDot,
                trailing: '',
                child: _buildAddresses(),
              ),
              const SizedBox(height: 16),
              // Statuses
              _buildSection(
                title: 'حالة الشحنة',
                icon: FontAwesomeIcons.timeline,
                child: _buildStatuses(),
              ),
              const SizedBox(height: 16),
              // Images
              _buildSection(
                title: 'صورة الشحنة',
                icon: FontAwesomeIcons.image,
                child: _buildImages(),
              ),
              const SizedBox(height: 16),
              // Notes
              _buildSection(
                title: 'ملاحظات',
                icon: FontAwesomeIcons.noteSticky,
                child: Text(
                  _localShipment.notes ?? 'لا توجد ملاحظات',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 100), // Space for bottom button
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildBottomButton(),
    );
  }

  Widget _buildDriverSection() {
    if (_localShipment.driverName == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المندوب المكلف',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              () {
                final String driverNameStr =
                    _localShipment.driverName ?? 'المندوب';
                final String initials = driverNameStr.isNotEmpty
                    ? driverNameStr
                          .trim()
                          .split(' ')
                          .map((w) => w.isNotEmpty ? w[0] : '')
                          .take(2)
                          .join()
                    : 'م';
                Widget avWidget = CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE8F1FF),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4C9B),
                    ),
                  ),
                );

                final String? driverAvatarPath = _localShipment.driverAvatar;
                if (driverAvatarPath != null && driverAvatarPath.isNotEmpty) {
                  final String fullUrl = driverAvatarPath.startsWith('http')
                      ? driverAvatarPath
                      : '${EndPoint.imageBaseUrl}$driverAvatarPath';
                  return SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      children: [
                        avWidget,
                        ClipOval(
                          child: Image.network(
                            fullUrl,
                            width: 40,
                            height: 40,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localShipment.driverName!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFB000),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _driverRating,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(
                      AppAssets.boxn,
                      width: 24,
                      height: 24,
                    ),
                  ),

                  const SizedBox(width: 8),
                  Column(
                    children: [
                      SelectableText(
                        'رقم الشحنة: ${_localShipment.shipmentNumber}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(text: _localShipment.shipmentNumber),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  padding: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Text(
                    'تم نسخ رقم الشحنة بنجاح',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: FaIcon(
              FontAwesomeIcons.copy,
              size: 24,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 2),
                color: Colors.white,
              ),
            ),
            Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: const FaIcon(
                FontAwesomeIcons.truckFast,
                size: 16,
                color: Colors.grey,
              ),
            ),
            Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _localShipment.fromArea ??
                  _localShipment.fromGovernorate ??
                  'مكان الاستلام',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _localShipment.toArea ??
                  _localShipment.toGovernorate ??
                  'مكان التسليم',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required icon,
    required Widget child,
    String? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FaIcon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Column(
      children: [
        _buildDetailRow(
          'رقم الشحنة',
          _localShipment.shipmentNumber,
          isPrice: true,
        ),
        _buildDetailRow(
          'نوع الدفع',
          _localShipment.isWithoutAdvance ? 'بدون مقدم' : 'دفع مقدم',
        ),
        _buildDetailRow(
          'رسوم التوصيل',
          '${_localShipment.price.toInt()} ج',
          isPrice: true,
        ),
        if (_localShipment.weight != null)
          _buildDetailRow('الوزن', '${_localShipment.weight!.toInt()} كجم'),
        _buildDetailRow('قابل للكسر', _localShipment.isFragile ? 'نعم' : 'لا'),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPrice = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 116, 116, 116),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPrice ? AppColors.primary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddresses() {
    return Column(
      children: [
        _buildAddressRow('مكان الاستلام:', _localShipment.fromAddress),
        const SizedBox(height: 12),
        _buildAddressRow('مكان التسليم:', _localShipment.toAddress),
      ],
    );
  }

  Widget _buildAddressRow(String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),

        Expanded(
          child: Text(
            address,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatuses() {
    final String statusLower = _currentStatus.trim().toLowerCase();

    final bool isOfferAccepted =
        statusLower == 'assigned to captain' ||
        statusLower == 'assigned_to_captain';
    final bool isInExecution =
        statusLower == 'picked up' || statusLower == 'picked_up';
    final bool isFinished =
        statusLower == 'completed' ||
        statusLower == 'finished' ||
        statusLower == 'منتهية' ||
        statusLower == 'منتهي' ||
        statusLower == 'مكتملة';
    final bool isCancelled =
        statusLower == 'cancelled' ||
        statusLower == 'ملغية' ||
        statusLower == 'ملغي';

    final bool isAccepted =
        _localShipment.driverId != null ||
        isOfferAccepted ||
        isInExecution ||
        isFinished ||
        statusLower == 'awaiting payment' ||
        statusLower == 'awaiting_payment' ||
        statusLower == 'ready for assignment' ||
        statusLower == 'ready_for_assignment' ||
        statusLower == 'assigned to captain' ||
        statusLower == 'assigned_to_captain' ||
        statusLower == 'captain arrived' ||
        statusLower == 'captain_arrived' ||
        statusLower == 'picked up' ||
        statusLower == 'picked_up' ||
        statusLower == 'in transit' ||
        statusLower == 'in_transit' ||
        statusLower == 'delivered';

    final bool isDelivering =
        isInExecution ||
        isFinished ||
        statusLower == 'picked up' ||
        statusLower == 'picked_up' ||
        statusLower == 'in transit' ||
        statusLower == 'in_transit' ||
        statusLower == 'delivered' ||
        statusLower == 'completed';

    final bool isCompleted = isFinished || statusLower == 'completed';

    return Column(
      children: [
        _buildStatusItem(
          time: '',
          title: 'تم ارسال الطلب',
          subtitle: 'تم ارسال طلبك بنجاح',
          isCompleted: true,
          isFirst: true,
        ),
        _buildStatusItem(
          time: '',
          title: 'تم قبول الطلب',
          subtitle: isAccepted
              ? 'تم قبول الطلب من قبل المندوب'
              : 'في انتظار قبول المندوب',
          isCompleted: isAccepted,
        ),
        _buildStatusItem(
          time: '',
          title: 'قيد التنفيذ / التوصيل',
          subtitle: isDelivering ? 'الشحنة مع المندوب وفي الطريق للتسليم' : '',
          isCompleted: isDelivering,
          hasButtons:
              (isOfferAccepted ||
                  isInExecution ||
                  statusLower == 'assigned to captain' ||
                  statusLower == 'assigned_to_captain' ||
                  statusLower == 'captain arrived' ||
                  statusLower == 'captain_arrived' ||
                  statusLower == 'picked up' ||
                  statusLower == 'picked_up' ||
                  statusLower == 'in transit' ||
                  statusLower == 'in_transit') &&
              !_isDelivery,
          onConfirm: _showDeliveryConfirmation,
          onCancel: _showCancellationReasonDialog,
        ),
        _buildStatusItem(
          time: '',
          title: isCancelled ? 'تم إلغاء الشحنة' : 'تم التوصيل بنجاح',
          subtitle: isCompleted
              ? 'تم تسليم الشحنة بنجاح للوجهة المطلوبة'
              : isCancelled
              ? 'تم إلغاء الشحنة'
              : 'في انتظار التوصيل',
          isCompleted: isCompleted || isCancelled,
          isLast: true,
          extraContent: (isCompleted && !_isDelivery && !_hasReviewed)
              ? 'اضغط هنا لتقييم المندوب'
              : (isCompleted && !_isDelivery && _hasReviewed)
              ? 'تم تقييم المندوب بنجاح ✅'
              : null,
          onConfirm: (isCompleted && !_isDelivery && !_hasReviewed)
              ? _showRatingBottomSheet
              : null,
        ),
      ],
    );
  }

  Widget _buildStatusItem({
    required String time,
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isFirst = false,
    bool isLast = false,
    bool hasButtons = false,
    String? extraContent,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          const SizedBox(width: 8),
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? const Color(0xFFE05B3A)
                      : Colors.grey.shade300,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isCompleted
                        ? const Color(0xFFE05B3A).withOpacity(0.5)
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? Colors.black87
                          : Colors.grey.shade400,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (hasButtons) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F4C9B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              onTap: onConfirm,
                              borderRadius: BorderRadius.circular(8),
                              child: const Center(
                                child: Text(
                                  'تاكيد',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              onTap: onCancel,
                              borderRadius: BorderRadius.circular(8),
                              child: const Center(
                                child: Text(
                                  'مرتجع',
                                  style: TextStyle(
                                    color: Color(0xFFE05B3A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (extraContent != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onConfirm,
                      child: Text(
                        extraContent,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1F4C9B),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              time,
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 11, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImages() {
    final urls = _localShipment.imageUrls;
    if (urls == null || urls.isEmpty) {
      return const Text(
        'لا توجد صور متوفرة لهذه الشحنة',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final imageUrl = urls[index];
          final fullUrl = imageUrl.startsWith('http')
              ? imageUrl
              : '${EndPoint.imageBaseUrl}$imageUrl';
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              fullUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showDeliveryConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'هل انت متأكد من تسليم الشحنة للمندوب؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCancellationReasonDialog();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: const Text(
                      'الغاء',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _updateStatus(ShipmentStatus.pickedUp);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F4C9B),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'تاكيد',
                      style: TextStyle(color: Colors.white),
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

  void _showCancellationReasonDialog() {
    String? selectedReason;
    final List<String> reasons = [
      'المندوب مش بيرد على الرسائل',
      'المندوب قال انه مش هيقدر يسلم في الميعاد',
      'المندوب طلب زيادة في سعر التوصيل المتفق عليه',
      'المندوب رفض يدفع قيمة الشحنة مقدما',
      'سبب اخر',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'اختار اسياب الغاء',
                  style: AppTypography.h5.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map(
                  (reason) => RadioListTile<String>(
                    title: Text(
                      reason,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    value: reason,
                    groupValue: selectedReason,
                    activeColor: const Color(0xFF1F4C9B),
                    onChanged: (val) {
                      setDialogState(() => selectedReason = val);
                    },
                  ),
                )
                .toList(),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: const Text(
                      'الغاء',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedReason == null
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await _updateStatus(ShipmentStatus.cancelled);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم إلغاء الشحنة وتحديث الحالة',
                                  ),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F4C9B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'تاكيد',
                      style: TextStyle(color: Colors.white),
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

  void _showRatingBottomSheet() {
    int currentRating = 0;
    List<String> selectedTags = [];
    final List<String> tags = [
      'التزام بالمواعيد',
      'لطف التعامل',
      'سرعة التوصيل',
    ];
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setSheetState) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Driver Avatar – real photo or initials fallback
                  Builder(
                    builder: (_) {
                      final String? avatarPath = _localShipment.driverAvatar;
                      final String driverName =
                          _localShipment.driverName ?? 'السائق';
                      final String initials = driverName
                          .trim()
                          .split(' ')
                          .map((w) => w.isNotEmpty ? w[0] : '')
                          .take(2)
                          .join();
                      if (avatarPath != null && avatarPath.isNotEmpty) {
                        final String fullUrl = avatarPath.startsWith('http')
                            ? avatarPath
                            : '${EndPoint.imageBaseUrl}$avatarPath';
                        return CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(fullUrl),
                          onBackgroundImageError: (_, _) {},
                          backgroundColor: const Color(0xFFE8F1FF),
                        );
                      }
                      return CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFFE8F1FF),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F4C9B),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'قيم تجربتك',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _localShipment.driverName ?? 'عبد الرحمن محمد محمد',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() => currentRating = index + 1);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < currentRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 36,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 25),
                  // Tags
                  Wrap(
                    spacing: 10,
                    children: tags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(
                          tag,
                          style: AppTypography.h5.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setSheetState(() {
                            if (selected) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                        selectedColor: const Color(0xFF1F4C9B).withOpacity(0.1),
                        checkmarkColor: const Color(0xFF1F4C9B),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF1F4C9B)
                              : Colors.grey,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF1F4C9B)
                                : Colors.transparent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 25),
                  // Comment Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'اضف تعليقا (اختياري)',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade100),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Submit Button
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: currentRating == 0
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await _reviewCubit.submitReview(
                                  shipmentId: _localShipment.id,
                                  rating: currentRating,
                                  comment: commentController.text.isEmpty
                                      ? null
                                      : commentController.text,
                                  tags: selectedTags.isEmpty
                                      ? null
                                      : selectedTags,
                                );
                                await _loadRatingsAndReviewStatus();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('شكراً لتقييمك 🙏'),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F4C9B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          currentRating == 0
                              ? 'اختر التقييم اولا'
                              : 'ارسال التقييم $currentRating/5',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                      itemId: _localShipment.id,
                      itemType: 'shipment',
                      itemNumber: _localShipment.shipmentNumber,
                      amount: _localShipment.price,
                      merchantName: _cachedUserName ?? 'التاجر',
                      merchantPhone: _cachedUserPhone ?? '',
                      merchantImage: _cachedUserImage,
                    ),
                  ),
                ).then((_) => _loadShipmentDetails());
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
