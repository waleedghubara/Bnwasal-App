// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/features/shipment/domain/entities/shipment.dart';
import 'package:we_deliver/features/shipment/presentation/manager/shipment_cubit.dart';
import 'package:we_deliver/features/shipment/presentation/pages/track_shipment_screen.dart';
import 'package:we_deliver/features/profile/presentation/bloc/review_cubit.dart';
import '../../../../core/api/end_point.dart';
import '../../../../core/theme/app_assets.dart';

import 'package:dio/dio.dart';

class DriverShipmentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? shipmentData;
  final Shipment? shipment;

  const DriverShipmentDetailsScreen({
    super.key,
    this.shipmentData,
    this.shipment,
  });

  @override
  State<DriverShipmentDetailsScreen> createState() =>
      _DriverShipmentDetailsScreenState();
}

enum NegotiationState { initial, negotiating, pendingMerchant, tripStarted }

class _DriverShipmentDetailsScreenState
    extends State<DriverShipmentDetailsScreen> {
  final ShipmentCubit _cubit = sl<ShipmentCubit>();
  final ReviewCubit _reviewCubit = sl<ReviewCubit>();
  String? _merchantRating;
  bool _hasReviewedMerchant = false;
  bool _ratingDialogShown = false;
  late double _originalDeliveryFee;
  late double _currentDeliveryFee;
  double get _driverDeliveryFee => _currentDeliveryFee;
  bool _isNegotiated = false;
  NegotiationState _negotiationState = NegotiationState.initial;
  bool _showMerchantApprovalBanner = false;
  late Map<String, dynamic> _shipmentMap;
  Shipment? _localShipment;

  @override
  void initState() {
    super.initState();
    _localShipment = widget.shipment;
    if (_localShipment != null) {
      _updateShipmentMapFromEntity(_localShipment!);
    } else {
      _shipmentMap = widget.shipmentData ?? {};
      final feeStr = _shipmentMap['deliveryFee']
          .toString()
          .replaceAll(' ج', '')
          .trim();
      _originalDeliveryFee = double.tryParse(feeStr) ?? 250.0;
      _currentDeliveryFee = _originalDeliveryFee;
      _updateNegotiationStateFromStatus(_shipmentMap['status'] ?? 'جديدة');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShipmentDetails();
    });
  }

  void _updateShipmentMapFromEntity(Shipment s) {
    _shipmentMap = {
      'id': s.id,
      'number': s.shipmentNumber,
      'from': s.fromAddress,
      'to': s.toAddress,
      'value': s.isWithoutAdvance ? 'بدون مقدم' : 'دفع مقدم',
      'deliveryFee': '${s.price.toInt()} ج',
      'arrivalDate': s.estimatedTime ?? '2 ساعة, 30 دقيقة',
      'status': s.status,
      'weight': s.weight != null ? '${s.weight!.toInt()} كجم' : 'غير محدد',
      'paymentType': s.isWithoutAdvance ? 'بدون مقدم' : 'دفع مقدم',
      'clientName': s.clientName ?? s.driverName ?? 'العميل',
      'clientAvatar': s.clientAvatar,
      'clientRating': _merchantRating,
      'notes': s.notes ?? 'لا توجد ملاحظات',
      'isFragile': s.isFragile,
      'title': s.title ?? 'شحنة',
      'isPaid': s.isPaid,
    };
    _originalDeliveryFee = s.price;
    if (!_isNegotiated) {
      _currentDeliveryFee = _originalDeliveryFee;
    }
    _updateNegotiationStateFromStatus(s.status);
  }

  void _updateNegotiationStateFromStatus(String status) {
    if (status == ShipmentStatus.newShipment) {
      _negotiationState = NegotiationState.initial;
      _isNegotiated = false;
    } else if (status == ShipmentStatus.assignedToCaptain ||
        status == ShipmentStatus.captainArrived ||
        status == ShipmentStatus.pickedUp ||
        status == ShipmentStatus.inTransit ||
        status == ShipmentStatus.delivered ||
        status == ShipmentStatus.completed) {
      _negotiationState = NegotiationState.tripStarted;
    }
  }

  Future<void> _loadShipmentDetails() async {
    final shipmentId = _shipmentMap['id'] ?? '';
    if (shipmentId.isNotEmpty) {
      final shipment = await _cubit.getShipmentDetails(shipmentId);
      if (shipment != null && mounted) {
        if (shipment.merchantId != null) {
          final summary = await _reviewCubit.getUserRating(
            shipment.merchantId!,
          );
          if (summary != null) {
            _merchantRating = summary.formattedRating;
          }
          // Check if driver already reviewed the merchant for this shipment
          final reviewStatus = await _reviewCubit.checkReviewStatus(
            shipment.id,
          );
          if (reviewStatus != null && mounted) {
            setState(() {
              _hasReviewedMerchant = reviewStatus.hasReviewed;
            });

            final String shipmentStatus = (shipment.status).trim().toLowerCase();
            final bool isFinished = shipmentStatus == 'completed' ||
                shipmentStatus == 'finished' ||
                shipmentStatus == 'منتهية' ||
                shipmentStatus == 'منتهي' ||
                shipmentStatus == 'مكتملة';

            if (isFinished && !_hasReviewedMerchant && !_ratingDialogShown) {
              _ratingDialogShown = true;
              _showMerchantRatingBottomSheet();
            }
          }
        }
        setState(() {
          _localShipment = shipment;
          _updateShipmentMapFromEntity(shipment);
        });
      }
    }
  }

  Shipment _getShipmentEntity() {
    if (_localShipment != null) {
      return _localShipment!;
    }
    return Shipment(
      id: _shipmentMap['id'] ?? '1',
      shipmentNumber: _shipmentMap['number'] ?? '1001',
      title: _shipmentMap['title'] ?? 'شحنة',
      fromAddress: _shipmentMap['from'] ?? 'مكان الاستلام',
      toAddress: _shipmentMap['to'] ?? 'مكان التسليم',
      status: _shipmentMap['status'] ?? 'جديدة',
      price:
          double.tryParse(
            _shipmentMap['deliveryFee'].toString().replaceAll(' ج', '').trim(),
          ) ??
          250.0,
      createdAt: DateTime.now(),
      toLatitude: 30.0074,
      toLongitude: 31.4913,
    );
  }

  void _showMerchantRatingBottomSheet() {
    int currentRating = 0;
    List<String> selectedTags = [];
    final List<String> tags = [
      'سرعة الاستجابة',
      'وضوح التفاصيل',
      'لطف التعامل',
    ];
    final TextEditingController commentController = TextEditingController();

    final String merchantName =
        _localShipment?.clientName ?? _shipmentMap['clientName'] ?? 'التاجر';
    final String? merchantAvatarPath =
        _localShipment?.clientAvatar ?? _shipmentMap['clientAvatar'] as String?;
    final String merchantId = _localShipment?.merchantId ?? '';

    // Build avatar widget: initials base layer + network image overlay
    final String merchantInitials = merchantName
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join();
    Widget avatarWidget = CircleAvatar(
      radius: 40,
      backgroundColor: const Color(0xFFE8F1FF),
      child: Text(
        merchantInitials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F4C9B),
        ),
      ),
    );
    if (merchantAvatarPath != null && merchantAvatarPath.isNotEmpty) {
      final String fullUrl = merchantAvatarPath.startsWith('http')
          ? merchantAvatarPath
          : '${EndPoint.imageBaseUrl}$merchantAvatarPath';
      avatarWidget = SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          children: [
            avatarWidget,
            ClipOval(
              child: Image.network(
                fullUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
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
                    const SizedBox(height: 16),
                    avatarWidget,
                  const SizedBox(height: 12),
                  Text(
                    'قيّم التاجر',
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    merchantName,
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                  // Tags
                  Wrap(
                    spacing: 10,
                    children: tags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(
                          tag,
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
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
                        selectedColor: const Color(
                          0xFF1F4C9B,
                        ).withValues(alpha: 0.1),
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
                  const SizedBox(height: 20),
                  // Comment Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'أضف تعليقاً (اختياري)',
                        hintStyle: GoogleFonts.tajawal(
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
                  const SizedBox(height: 24),
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
                                if (merchantId.isNotEmpty) {
                                  await _reviewCubit.submitReview(
                                    shipmentId: _localShipment!.id,
                                    rating: currentRating,
                                    comment: commentController.text.isEmpty
                                        ? null
                                        : commentController.text,
                                    tags: selectedTags.isEmpty
                                        ? null
                                        : selectedTags,
                                  );
                                }
                                await _loadShipmentDetails();
                                if (mounted) {
                                  setState(() {
                                    _hasReviewedMerchant = true;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'شكراً لتقييمك 🙏',
                                        style: GoogleFonts.tajawal(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF1F4C9B),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F4C9B),
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          currentRating == 0
                              ? 'اختر التقييم أولاً'
                              : 'إرسال التقييم $currentRating/5',
                          style: GoogleFonts.tajawal(
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
    ),
  );
}

  void _showCancellationReasonsDialog() {
    int selectedIndex = 0;
    final reasons = [
      'التاجر مش بيرد علي الرسيل او المكالمات',
      'تفاصيل الشحنة مش واضحة (وزن.سعر.عنوان.....',
      'التاجر عايز يغير الاتفاق او السعر بعد الاتفاق',
      'الطلب مش موثوق فيه',
      'سبب اخر',
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
                      // Header: Title on the right, Close 'x' on the left
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'اختار اسباب الغاء',
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

                      // Radio buttons list
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
                                // Radio circle on the right side of the row in RTL
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF1F4C9B)
                                          : Colors.grey.shade400,
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
                                // Text on the left of the circle
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

                      // Bottom actions row: تاكيد on the right, الغاء on the left
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                                try {
                                  await _cubit.updateShipmentStatus(
                                    _shipmentMap['id'] ?? '',
                                    ShipmentStatus.newShipment,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context); // Pop loader
                                    setState(() {
                                      _negotiationState =
                                          NegotiationState.initial;
                                      _isNegotiated = false;
                                      _currentDeliveryFee =
                                          _originalDeliveryFee;
                                    });
                                    _loadShipmentDetails();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم الغاء العرض بنجاح ورجوع الحالة للبداية.',
                                          style: GoogleFonts.tajawal(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        backgroundColor: Colors.red.shade700,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    Navigator.pop(context); // Pop loader
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
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
                                'تاكيد',
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
                                'الغاء',
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
              // Client avatar
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8F1FF),
                ),
                child: Center(
                  child: Text(
                    'ع',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F4C9B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _shipmentMap['clientName'] ?? 'عبد الرحمن محمد محمد',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        // Rating Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFFB000),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_shipmentMap['clientRating'] ?? 4.8}',
                                style: GoogleFonts.tajawal(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFB000),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'وافق التاجر على عرض السعر المقترح الخاص بك: ${_driverDeliveryFee.toInt()} ج',
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
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                  try {
                    await _cubit.updateShipmentStatus(
                      _shipmentMap['id'] ?? '',
                      ShipmentStatus.pending,
                    );
                    if (mounted) {
                      Navigator.pop(context); // Pop loader
                      setState(() {
                        _showMerchantApprovalBanner = false;
                        _negotiationState = NegotiationState.tripStarted;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم بدء الرحلة بنجاح!',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: const Color(0xFF1F4C9B),
                        ),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackShipmentScreen(
                            shipment: _getShipmentEntity(),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // Pop loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
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
    final shipment = _shipmentMap;

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
            'تفاصيل الشحنة',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        body: Stack(
          children: [
            // Main body
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: _loadShipmentDetails,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Header Card (Thumbnail, Title, Delivery deadline)
                      _buildHeaderCard(shipment),
                      const SizedBox(height: 16),

                      // Client Info Section
                      _buildClientSection(shipment),
                      const SizedBox(height: 16),

                      // Addresses Section
                      _buildAddressesSection(shipment),
                      const SizedBox(height: 16),

                      // Shipment Details Table
                      _buildShipmentDetailsTable(shipment),
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

        // Bottom Actions Panel
        bottomNavigationBar: _buildBottomPanel(),
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> shipment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Thumbnail
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

          // Title & arrival info
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '#رقم الشحنة: ${shipment['number']}',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: shipment['number'].toString()),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        padding: EdgeInsets.all(16),
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
          ),
        ],
      ),
    );
  }

  Widget _buildClientSection(Map<String, dynamic> shipment) {
    final String clientName = shipment['clientName'] ?? 'العميل';
    final String? clientAvatar = shipment['clientAvatar'] as String?;
    // clientRating may be a double, int, String (already formatted), or null.
    // Parse it safely to a double so toStringAsFixed can be called on it.
    double? clientRating;
    final dynamic rawClientRating = shipment['clientRating'];
    if (rawClientRating is double) {
      clientRating = rawClientRating;
    } else if (rawClientRating is int) {
      clientRating = rawClientRating.toDouble();
    } else if (rawClientRating is String) {
      clientRating = double.tryParse(rawClientRating);
    }

    // Build avatar widget: initials base layer + network image overlay
    final String initials = clientName.isNotEmpty
        ? clientName
              .trim()
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
        : '؟';
    Widget avatarWidget = CircleAvatar(
      radius: 22,
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
    if (clientAvatar != null && clientAvatar.isNotEmpty) {
      final String fullUrl = clientAvatar.startsWith('http')
          ? clientAvatar
          : '${EndPoint.imageBaseUrl}$clientAvatar';
      avatarWidget = SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          children: [
            avatarWidget,
            ClipOval(
              child: Image.network(
                fullUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      );
    }

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
            'بيانات العميل',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Avatar
              avatarWidget,
              const SizedBox(width: 12),
              // Name & chat icon
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              // Rating Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFB000), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      clientRating != null
                          ? clientRating.toStringAsFixed(1)
                          : '—',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFB000),
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

  Widget _buildAddressesSection(Map<String, dynamic> shipment) {
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
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.mapLocationDot,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'العناوين',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pickup
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  'مكان الاستلام:',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  shipment['from'],
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

          // Delivery
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  'مكان التسليم',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  shipment['to'],
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

  Widget _buildShipmentDetailsTable(Map<String, dynamic> shipment) {
    final bool isFragile = shipment['isFragile'] == true;

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
          // Section header
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.boxesPacking,
                color: Colors.grey.shade400,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'تفاصيل الشحنة',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildRow('رقم الشحنة', shipment['number']),
          _buildRow('نوع الدفع', shipment['paymentType'] ?? 'دفع مقدما'),
          _buildRow('وزن الشحنة', shipment['weight'] ?? '30 كجم'),
          _buildRow('سعر الطلب', shipment['value'], isHighlighted: true),
          _buildRow(
            'رسوم التوصيل',
            '${_driverDeliveryFee.toInt()} ج',
            isHighlighted: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          // Fragile indicator row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: isFragile
                          ? Colors.orange.shade700
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'قابل للكسر',
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isFragile
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFragile
                          ? Colors.orange.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Text(
                    isFragile ? 'نعم ⚠️' : 'لا ✅',
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isFragile
                          ? Colors.orange.shade800
                          : Colors.green.shade700,
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

  Widget _buildRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.tajawal(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? const Color(0xFF1F4C9B) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final approvalStatus = _localShipment?.captainApprovalStatus;
    if (approvalStatus == 'pending') {
      return _buildApprovalPendingBanner();
    }

    final shipmentStatus =
        _localShipment?.status ?? _shipmentMap['status'] ?? 'جديدة';

    final isPaid =
        _localShipment?.isPaid ??
        (_shipmentMap['isPaid'] == true || _shipmentMap['isPaid'] == 1);

    if (shipmentStatus == ShipmentStatus.finished ||
        shipmentStatus == ShipmentStatus.cancelled) {
      if (shipmentStatus == ShipmentStatus.finished && !_hasReviewedMerchant) {
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
              child: ElevatedButton.icon(
                onPressed: _showMerchantRatingBottomSheet,
                icon: const Icon(
                  Icons.star_border_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                label: Text(
                  'قيّم التاجر',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4C9B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (_negotiationState == NegotiationState.tripStarted) {
      if (shipmentStatus == ShipmentStatus.completed ||
          shipmentStatus == ShipmentStatus.finished) {
        if (!_hasReviewedMerchant) {
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
                child: ElevatedButton.icon(
                  onPressed: _showMerchantRatingBottomSheet,
                  icon: const Icon(
                    Icons.star_border_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    'قيّم التاجر',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4C9B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      }

      // For any other active statuses, show the "ابدأ الرحلة" button directly, without any other buttons or map button.
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
                    builder: (context) =>
                        TrackShipmentScreen(shipment: _getShipmentEntity()),
                  ),
                ).then((_) => _loadShipmentDetails());
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
    final shipment = _localShipment;
    final price = double.tryParse((shipment?.price ?? _shipmentMap['price'] ?? '0').toString()) ?? 0.0;
    final captainShare = (price * 0.8).toInt();
    final fromAddress = shipment?.fromAddress ?? _shipmentMap['fromAddress'] ?? 'غير محدد';
    final toAddress = shipment?.toAddress ?? _shipmentMap['toAddress'] ?? 'غير محدد';

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
                  'تكليف شحنة جديدة 📦',
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
                          fromAddress,
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
                          toAddress,
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
                          'قيمة الشحنة',
                          style: GoogleFonts.tajawal(fontSize: 11, color: Colors.blue.shade800),
                        ),
                        Text(
                          '${price.toInt()} ج.م',
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
      final shipmentId = _shipmentMap['id'] ?? '';
      await sl<Dio>().put(
        '${EndPoint.baseUrl}${EndPoint.getShipments}/$shipmentId/captain-response',
        data: {'response': response},
      );

      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        if (response == 'accept') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم قبول الشحنة بنجاح 🎉'),
              backgroundColor: Colors.green,
            ),
          );
          _loadShipmentDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض الشحنة وإعادتها للإدارة ❌'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context); // Go back to shipments list
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
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
        print(errMsg);
      }
    }
  }
}
