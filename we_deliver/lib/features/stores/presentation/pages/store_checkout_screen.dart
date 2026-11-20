import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/api/end_point.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../../../core/di/injection_container.dart';
import '../../../profile/presentation/bloc/profile_cubit.dart';
import '../../../profile/presentation/bloc/profile_state.dart';
import '../../../order/presentation/pages/direct_payment_page.dart';
import '../../data/models/store_models.dart';
import '../../data/services/zone_delivery_pricing.dart';
import '../manager/stores_cubit.dart';
import '../manager/stores_state.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../../core/services/auth_guard.dart';

class StoreCheckoutScreen extends StatefulWidget {
  final StoreModel store;

  const StoreCheckoutScreen({super.key, required this.store});

  @override
  State<StoreCheckoutScreen> createState() => _StoreCheckoutScreenState();
}

class _StoreCheckoutScreenState extends State<StoreCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Direct payment controllers & receipt
  final TextEditingController _fromPhoneController = TextEditingController();
  final TextEditingController _fromNameController = TextEditingController();
  File? _receiptImage;

  // Scheduling state
  String _scheduleType = 'now'; // 'now' or 'scheduled'
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 14, minute: 0);

  // Driver Tip state
  double _driverTip = 0.0;
  final List<double> _tipOptions = [
    0.0,
    5.0,
    10.0,
    15.0,
    20.0,
    25.0,
    30.0,
    35.0,
    40.0,
    45.0,
    50.0,
  ];

  // Service fee (dynamically loaded from admin settings, default 5.0 EGP)
  double _serviceFee = 5.0;

  // Coupon state
  final TextEditingController _couponController = TextEditingController();
  bool _isCouponValid = false;
  String? _couponError;
  bool _isValidatingCoupon = false;
  double _discountApplied = 0.0;
  String? _appliedCouponCode;

  // Payment Method state: 'cash' or 'wallet'
  String _selectedPaymentMethod = 'cash';
  String _selectedWalletType = 'vodafone'; // 'vodafone' or 'instapay'

  // Available transfer accounts
  static const String _vodafoneNumber = '01033190080';
  static const String _instapayNumber = '01210633600';

  String? _selectedZone;
  late String _storeZone;

  @override
  void initState() {
    super.initState();
    _storeZone = _resolveStoreZone();
    _prefillUserData();
    _loadDynamicServiceFee();
  }

  String _resolveStoreZone() {
    if (widget.store.city != null && widget.store.city!.trim().isNotEmpty) {
      final matched = ZoneDeliveryPricing.matchZone(widget.store.city);
      if (matched != null) return matched;
    }
    if (widget.store.storeAddress.trim().isNotEmpty) {
      final matched = ZoneDeliveryPricing.matchZone(widget.store.storeAddress);
      if (matched != null) return matched;
    }
    return 'الهانوفيل';
  }

  void _prefillUserData() {
    try {
      final profileState = context.read<ProfileCubit>().state;
      if (profileState is ProfileLoaded) {
        final user = profileState.user;
        final fullName = '${user.firstName} ${user.lastName}'.trim();
        if (fullName.isNotEmpty) {
          _nameController.text = fullName;
          _fromNameController.text = fullName;
        }
        if (user.phone.isNotEmpty) {
          _phoneController.text = user.phone;
          _fromPhoneController.text = user.phone;
        }
        if (user.city != null && user.city!.isNotEmpty) {
          final matched = ZoneDeliveryPricing.matchZone(user.city);
          if (matched != null) {
            _selectedZone = matched;
          }
        }
      }
    } catch (_) {}

    _selectedZone ??= _storeZone;
  }

  Future<void> _loadDynamicServiceFee() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedFee = prefs.getString('store_service_fee');
      if (cachedFee != null) {
        final parsed = double.tryParse(cachedFee);
        if (parsed != null && mounted) {
          setState(() {
            _serviceFee = parsed;
          });
        }
      }

      // Fetch live config in background to dynamically reflect changes made from admin panel
      final response = await sl<Dio>().get(
        '${EndPoint.baseUrl}${EndPoint.appConfig}',
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null && data['store_service_fee'] != null) {
          final liveFee = double.tryParse(data['store_service_fee'].toString());
          if (liveFee != null && mounted) {
            setState(() {
              _serviceFee = liveFee;
            });
            await prefs.setString('store_service_fee', liveFee.toString());
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _fromPhoneController.dispose();
    _fromNameController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  double get _deliveryFee {
    return ZoneDeliveryPricing.calculateFee(
      fromZone: _storeZone,
      toZone: _selectedZone,
      defaultFee: 35.0,
    );
  }

  Future<void> _pickReceiptImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        HapticFeedback.selectionClick();
        setState(() {
          _receiptImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر اختيار الصورة: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickScheduledDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate.isBefore(now) ? now : _scheduledDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF5B00),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickScheduledTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF5B00),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('تم نسخ $label بنجاح ($text)', style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (AuthGuard.isGuest) {
      final authenticated = await AuthGuard.requireAuth(
        context,
        reason: 'يرجى تسجيل الدخول لإتمام عملية الشراء ومتابعة الطلب',
      );
      if (!authenticated || !mounted) return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (!widget.store.isCurrentlyOpen && _scheduleType == 'now') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.access_time_filled_rounded, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Text(
                'المتجر مغلق حالياً',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'عذراً، المتجر مغلق الآن وخارج مواعيد العمل الرسمية (${widget.store.openingHours}).\n\nيمكنك تبديل موعد الاستلام إلى "جدولة لوقت لاحق" واختيار موعد ضمن ساعات العمل.',
            style: GoogleFonts.cairo(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('حسناً', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (_selectedZone == null || _selectedZone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى اختيار المدينة / المنطقة لتحديد سعر التوصيل',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedPaymentMethod == 'wallet') {
      if (_fromPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'يرجى إدخال رقم الهاتف أو الحساب المُحوَّل منه',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_receiptImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'يرجى إرفاق صورة إيصال التحويل لإتمام الطلب',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    final fee = _deliveryFee;
    final cubit = context.read<StoresCubit>();

    String? scheduledDateStr;
    String? scheduledTimeStr;
    String? scheduledAtStr;

    if (_scheduleType == 'scheduled') {
      scheduledDateStr = DateFormat('yyyy-MM-dd').format(_scheduledDate);
      final hourStr = _scheduledTime.hour.toString().padLeft(2, '0');
      final minuteStr = _scheduledTime.minute.toString().padLeft(2, '0');
      scheduledTimeStr = '$hourStr:$minuteStr:00';
      scheduledAtStr = '$scheduledDateStr $scheduledTimeStr';
    }

    final paymentMethodName = _selectedPaymentMethod == 'cash'
        ? 'cash'
        : (_selectedWalletType == 'instapay' ? 'إنستا باي' : 'فودافون كاش');

    await cubit.placeOrder(
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      deliveryLocation: _selectedZone!,
      deliveryAddress: _addressController.text.trim(),
      deliveryFee: fee,
      serviceFee: _serviceFee,
      tip: _driverTip,
      couponCode: _isCouponValid ? (_appliedCouponCode ?? _couponController.text.trim()) : null,
      scheduleType: _scheduleType,
      scheduledDate: scheduledDateStr,
      scheduledTime: scheduledTimeStr,
      scheduledAt: scheduledAtStr,
      paymentMethod: paymentMethodName,
      fromPhone: _selectedPaymentMethod == 'wallet' ? _fromPhoneController.text.trim() : null,
      fromName: _selectedPaymentMethod == 'wallet' ? _fromNameController.text.trim() : null,
      receiptImage: _selectedPaymentMethod == 'wallet' ? _receiptImage : null,
      isPaid: false,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );
  }

  void _openZonePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ZonePickerBottomSheet(
        selectedZone: _selectedZone,
        storeZone: _storeZone,
        onZoneSelected: (zone) {
          setState(() {
            _selectedZone = zone;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<StoresCubit, StoresState>(
        listener: (context, state) {
          if (state is PlaceOrderSuccess) {
            final dataObj = state.data['data'] is Map ? state.data['data'] : state.data;
            final isDirect = dataObj['isDirectPayment'] == true || state.data['isDirectPayment'] == true;
            if (isDirect) {
              final paymentRef = dataObj['paymentRef']?.toString() ?? '';
              final orderNumber = dataObj['orderNumber']?.toString() ?? '';
              final orderId = dataObj['orderId']?.toString() ?? '';
              final total = (dataObj['total'] as num?)?.toDouble() ??
                  (dataObj['totalAmount'] as num?)?.toDouble() ??
                  0.0;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (waitCtx) => PaymentWaitingPage(
                    paymentRef: paymentRef,
                    amount: total,
                    itemNumber: orderNumber,
                    itemType: 'order',
                    itemId: orderId,
                    onFinish: () {
                      Navigator.of(waitCtx).popUntil((route) => route.isFirst);
                    },
                  ),
                ),
              );
            } else {
              _showSuccessDialog(state.data);
            }
          } else if (state is PlaceOrderError) {
            final msg = state.message.trim();
            final safeMsg = msg.isNotEmpty ? msg : 'تعذر إتمام الطلب، يرجى المحاولة مرة أخرى';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(safeMsg, style: GoogleFonts.cairo()),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<StoresCubit>();
          final items = cubit.cart;
          final itemsTotal = cubit.cartTotal;
          final deliveryFee = _deliveryFee;
          final subtotal = itemsTotal + deliveryFee + _serviceFee;
          final finalTotal = math.max((subtotal - _discountApplied) + _driverTip, 0.0);
          final isLoading = state is PlaceOrderLoading;

          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              title: Text(
                'إتمام الطلب',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF0F172A),
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF0F172A),
                  size: 19,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            bottomNavigationBar: _buildBottomSubmitBar(
              cubit: cubit,
              itemsTotal: itemsTotal,
              deliveryFee: deliveryFee,
              finalTotal: finalTotal,
              isLoading: isLoading,
            ),
            body: items.isEmpty
                ? Center(
                    child: Text(
                      'السلة فارغة',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Info Banner
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5B00).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.storefront_rounded,
                                    color: Color(0xFFFF5B00),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.store.storeName,
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            'منطقة المتجر: $_storeZone',
                                            style: GoogleFonts.cairo(
                                              fontSize: 12,
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Section 1: Order Items
                          _buildSectionHeader('الأصناف المطلوبة (${items.length})'),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: item.fullProductImage != null &&
                                                item.fullProductImage!.isNotEmpty
                                            ? Image.network(
                                                item.fullProductImage!,
                                                width: 52,
                                                height: 52,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    _buildItemPlaceholder(),
                                              )
                                            : _buildItemPlaceholder(),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.product.name,
                                              style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (item.selectedSize != null)
                                              Text(
                                                'الحجم: ${item.selectedSize!.name}',
                                                style: GoogleFonts.cairo(
                                                  fontSize: 12,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                            if (item.selectedAddons.isNotEmpty)
                                              Text(
                                                'إضافات: ${item.selectedAddons.map((a) => a.name).join(', ')}',
                                                style: GoogleFonts.cairo(
                                                  fontSize: 12,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                            if (item.notes != null &&
                                                item.notes!.isNotEmpty)
                                              Text(
                                                'ملاحظة: ${item.notes}',
                                                style: GoogleFonts.cairo(
                                                  fontSize: 11,
                                                  color: const Color(0xFFFF5B00),
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.totalPrice.toStringAsFixed(0)} ج.م',
                                              style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                                color: const Color(0xFFFF5B00),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () => cubit.updateCartItemQuantity(
                                              index,
                                              item.quantity - 1,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.remove,
                                                size: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              '${item.quantity}',
                                              style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => cubit.updateCartItemQuantity(
                                              index,
                                              item.quantity + 1,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF5B00),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 15,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Section 2: Recipient Details & City Selection
                          _buildSectionHeader('بيانات المستلم وعنوان التوصيل'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Full Name
                                _buildFieldLabel('الاسم بالكامل *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameController,
                                  style: GoogleFonts.cairo(fontSize: 14),
                                  decoration: _inputDecoration(
                                    'اكتب اسمك بالكامل',
                                    Icons.person_outline_rounded,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'يرجى إدخال اسم المستلم';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Phone Number
                                _buildFieldLabel('رقم الهاتف للتواصل *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.cairo(fontSize: 14),
                                  decoration: _inputDecoration(
                                    'مثال: 01012345678',
                                    Icons.phone_outlined,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'يرجى إدخال رقم الهاتف';
                                    }
                                    if (val.trim().length < 10) {
                                      return 'يرجى إدخال رقم هاتف صحيح';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // City / Zone Selection (اختيار المدينة / المنطقة)
                                _buildFieldLabel('المدينة / المنطقة (حساب سعر التوصيل) *'),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _openZonePicker,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.location_city_rounded,
                                          color: Color(0xFFFF5B00),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _selectedZone ?? 'اضغط لاختيار منطقتك...',
                                            style: GoogleFonts.cairo(
                                              fontSize: 14,
                                              fontWeight: _selectedZone != null
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: _selectedZone != null
                                                  ? const Color(0xFF0F172A)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF5B00)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'تغيير',
                                            style: GoogleFonts.cairo(
                                              color: const Color(0xFFFF5B00),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Delivery Route Price Card
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.delivery_dining_rounded,
                                        color: Color(0xFF3B82F6),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'مسار التوصيل: من $_storeZone إلى ${_selectedZone ?? "..."}',
                                              style: GoogleFonts.cairo(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                            Text(
                                              'حسب تسعيرة زون العجمي والإسكندرية',
                                              style: GoogleFonts.cairo(
                                                fontSize: 11,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${deliveryFee.toStringAsFixed(0)} ج.م',
                                        style: GoogleFonts.cairo(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Detailed Address
                                _buildFieldLabel('العنوان بالتفصيل *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _addressController,
                                  maxLines: 2,
                                  style: GoogleFonts.cairo(fontSize: 14),
                                  decoration: _inputDecoration(
                                    'اسم الشارع، رقم العمارة، الطابق، رقم الشقة، علامة مميزة...',
                                    Icons.location_on_outlined,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'يرجى إدخال العنوان بالتفصيل';
                                    }
                                    return null;
                                  },
                                ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Section 3: Order Scheduling (جدولة الطلب)
                            _buildSectionHeader('جدولة الطلب'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                // الآن
                                Expanded(
                                  child: _buildScheduleCard(
                                    title: 'الآن',
                                    icon: Icons.bolt_rounded,
                                    isSelected: _scheduleType == 'now',
                                    onTap: () => setState(() => _scheduleType = 'now'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // مجدول
                                Expanded(
                                  child: _buildScheduleCard(
                                    title: 'مجدول',
                                    icon: Icons.calendar_month_rounded,
                                    isSelected: _scheduleType == 'scheduled',
                                    onTap: () => setState(() => _scheduleType = 'scheduled'),
                                  ),
                                ),
                              ],
                            ),

                            // Date & Time pickers if scheduled
                            if (_scheduleType == 'scheduled') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDateTimePickerBox(
                                      title: 'تاريخ الطلب',
                                      value: DateFormat('yyyy-MM-dd').format(_scheduledDate),
                                      icon: Icons.calendar_today_rounded,
                                      onTap: _pickScheduledDate,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDateTimePickerBox(
                                      title: 'ساعة الطلب',
                                      value: _scheduledTime.format(context),
                                      icon: Icons.access_time_rounded,
                                      onTap: _pickScheduledTime,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 22),

                            // Section 4: Driver Tip (إكرامية المندوب)
                            _buildSectionHeader('إكرامية المندوب'),
                            const SizedBox(height: 3),
                            Text(
                              'عبّر عن تقديرك بإضافة إكرامية للمندوب.',
                              style: GoogleFonts.cairo(
                                fontSize: 12.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _tipOptions.map((tip) {
                                  final isSelected = _driverTip == tip;
                                  final label = tip == 0
                                      ? 'بدون إكرامية'
                                      : '${tip.toStringAsFixed(0)} جنية';
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: InkWell(
                                      onTap: () => setState(() => _driverTip = tip),
                                      borderRadius: BorderRadius.circular(20),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFFF5B00)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFFFF5B00)
                                                : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Section 5: Special Notes (ملاحظات خاصة)
                            _buildSectionHeader('ملاحظات خاصة'),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: TextFormField(
                                controller: _notesController,
                                maxLines: 3,
                                style: GoogleFonts.cairo(fontSize: 13.5),
                                decoration: InputDecoration(
                                  hintText: 'أضف ملاحظات',
                                  hintStyle: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(14),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Section 6: Payment Method (طريقة الدفع)
                            _buildSectionHeader('طريقة الدفع'),
                            const SizedBox(height: 10),

                            // Option 1: Cash on Delivery (كاش عند الاستلام)
                            _buildPaymentMethodTile(
                              title: 'كاش عند الاستلام',
                              subtitle: 'ادفع قيمة الطلب والتوصيل نقداً عند وصول المندوب إليك',
                              badgeText: 'نقداً للمندوب',
                              icon: Icons.payments_rounded,
                              isSelected: _selectedPaymentMethod == 'cash',
                              onTap: () => setState(() => _selectedPaymentMethod = 'cash'),
                            ),

                            const SizedBox(height: 12),

                            // Option 2: Electronic Wallets / InstaPay (المحافظ الإلكترونية أو إنستاباي)
                            _buildPaymentMethodTile(
                              title: 'المحافظ الإلكترونية أو إنستاباي',
                              subtitle: 'تحويل عبر فودافون كاش، محافظ المحمول، أو إنستاباي',
                              badgeText: 'تحويل مباشر',
                              icon: Icons.account_balance_wallet_rounded,
                              isSelected: _selectedPaymentMethod == 'wallet',
                              onTap: () => setState(() => _selectedPaymentMethod = 'wallet'),
                            ),

                            // Details when Wallet/InstaPay is selected
                            if (_selectedPaymentMethod == 'wallet') ...[
                              const SizedBox(height: 14),
                              _buildWalletTransferBox(),
                            ],

                            const SizedBox(height: 22),

                            // Section: Discount Coupon (كود الخصم)
                            _buildCouponSection(subtotal),

                            const SizedBox(height: 22),

                            // Section 7: Order Invoice (فاتورة الطلب)
                            _buildSectionHeader('فاتورة الطلب'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  _buildCostRow(
                                    'ثمن المنتجات',
                                    '${itemsTotal.toStringAsFixed(0)} ج.م',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCostRow(
                                    'مصاريف التوصيل ($_storeZone ⬅ $_selectedZone)',
                                    '${deliveryFee.toStringAsFixed(0)} ج.م',
                                    color: const Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCostRow(
                                    'رسوم الخدمة',
                                    '${_serviceFee.toStringAsFixed(0)} ج.م',
                                    color: const Color(0xFF64748B),
                                  ),
                                  if (_isCouponValid && _discountApplied > 0) ...[
                                    const SizedBox(height: 8),
                                    _buildCostRow(
                                      'خصم الكوبون (${_appliedCouponCode ?? _couponController.text.trim()})',
                                      '- ${_discountApplied.toStringAsFixed(0)} ج.م',
                                      color: const Color(0xFF10B981),
                                      isBold: true,
                                    ),
                                  ],
                                  if (_driverTip > 0) ...[
                                    const SizedBox(height: 8),
                                    _buildCostRow(
                                      'إكرامية المندوب',
                                      '${_driverTip.toStringAsFixed(0)} ج.م',
                                      color: const Color(0xFFFF5B00),
                                    ),
                                  ],
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(
                                      height: 1,
                                      color: Color(0xFFF1F5F9),
                                    ),
                                  ),
                                  _buildCostRow(
                                    'الإجمالي النهائي',
                                    '${finalTotal.toStringAsFixed(0)} ج.م',
                                    isBold: true,
                                    color: const Color(0xFFFF5B00),
                                  ),
                                ],
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
    }

  Future<void> _validateCoupon(double subtotal) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    try {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);
      final response = await sl<Dio>().get(
        '${EndPoint.baseUrl}coupons/validate',
        queryParameters: {'code': code, 'price': subtotal},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] == 1 && responseData['valid'] == true) {
        final data = responseData['data'] as Map<String, dynamic>;
        setState(() {
          _isCouponValid = true;
          _discountApplied = (data['discountApplied'] as num).toDouble();
          _appliedCouponCode = data['code']?.toString() ?? code;
          _couponError = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 تم تطبيق الكوبون بنجاح! خصم ${_discountApplied.toStringAsFixed(0)} ج.م',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        setState(() {
          _isCouponValid = false;
          _discountApplied = 0.0;
          _appliedCouponCode = null;
          _couponError = responseData['message']?.toString() ?? 'كوبون غير صالح';
        });
      }
    } on DioException catch (e) {
      final errorData = e.response?.data;
      setState(() {
        _isCouponValid = false;
        _discountApplied = 0.0;
        _appliedCouponCode = null;
        if (errorData is Map && errorData['message'] != null) {
          _couponError = errorData['message'].toString();
        } else {
          _couponError = 'كود الخصم غير صالح أو منتهي الصلاحية';
        }
      });
    } catch (_) {
      setState(() {
        _isCouponValid = false;
        _discountApplied = 0.0;
        _appliedCouponCode = null;
        _couponError = 'تعذر التحقق من كود الخصم';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingCoupon = false;
        });
      }
    }
  }

  void _removeCoupon() {
    setState(() {
      _isCouponValid = false;
      _discountApplied = 0.0;
      _appliedCouponCode = null;
      _couponError = null;
      _couponController.clear();
    });
  }

  Widget _buildCouponSection(double subtotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCouponValid
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
          width: _isCouponValid ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5B00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: Color(0xFFFF5B00),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'كود الخصم (كوبون التخفيض)',
                style: GoogleFonts.cairo(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (_isCouponValid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'مُفعَّل ✅',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  readOnly: _isCouponValid,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'أدخل كود الخصم هنا (مثال: BNWASAL)',
                    hintStyle: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.normal,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0,
                    ),
                    filled: true,
                    fillColor: _isCouponValid
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _isCouponValid
                            ? const Color(0xFF10B981)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF5B00),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isValidatingCoupon
                      ? null
                      : (_isCouponValid
                          ? _removeCoupon
                          : () => _validateCoupon(subtotal)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCouponValid
                        ? Colors.red.shade50
                        : const Color(0xFFFF5B00),
                    foregroundColor: _isCouponValid
                        ? Colors.red.shade700
                        : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: _isCouponValid
                          ? BorderSide(color: Colors.red.shade200)
                          : BorderSide.none,
                    ),
                  ),
                  child: _isValidatingCoupon
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isCouponValid ? 'إلغاء' : 'تطبيق',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_couponError != null && _couponError!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _couponError!,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_isCouponValid && _discountApplied > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'تم تطبيق الخصم بنجاح! تم توفير ${_discountApplied.toStringAsFixed(0)} ج.م على هذا الطلب 🎉',
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.cairo(
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 15.5,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0F172A),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.cairo(
        fontSize: 13,
        color: const Color(0xFF94A3B8),
      ),
      prefixIcon: Icon(icon, color: const Color(0xFFFF5B00), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF5B00), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildCostRow(
    String title,
    String amount, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: isBold ? 15 : 13.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.cairo(
            fontSize: isBold ? 18 : 14.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.bold,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5B00) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5B00) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5B00).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.white : const Color(0xFF1E293B),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePickerBox({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5B00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFFFF5B00)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5B00) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFFFF5B00).withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF5B00).withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFFFF5B00) : const Color(0xFF64748B),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF5B00).withValues(alpha: 0.1)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFFFF5B00)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFFFF5B00) : const Color(0xFFCBD5E1),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletTransferBox() {
    final isVodafone = _selectedWalletType == 'vodafone';
    final targetNumber = isVodafone ? _vodafoneNumber : _instapayNumber;
    final providerTitle = isVodafone ? 'فودافون كاش' : 'إنستا باي (InstaPay)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF5B00).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5B00).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-channel selector (فودافون كاش / إنستا باي)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedWalletType = 'vodafone'),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isVodafone ? const Color(0xFFE60000) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isVodafone ? const Color(0xFFE60000) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'فودافون كاش',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isVodafone ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedWalletType = 'instapay'),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: !isVodafone
                          ? const LinearGradient(
                              colors: [Color(0xFF5B2D8E), Color(0xFF9B59B6)],
                            )
                          : null,
                      color: !isVodafone ? null : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !isVodafone ? const Color(0xFF5B2D8E) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'إنستا باي (InstaPay)',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: !isVodafone ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Transfer Number Display Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'رقم التحويل ($providerTitle):',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    InkWell(
                      onTap: () => _copyToClipboard(targetNumber, providerTitle),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5B00).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: Color(0xFFFF5B00),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'نسخ الرقم',
                              style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF5B00),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  targetNumber,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'يرجى تحويل قيمة الطلب ثم إدخال رقم هاتفك المحول منه ورفع صورة الإيصال لتأكيد الطلب فوراً.',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sender Phone Field
          _buildFieldLabel('رقم الهاتف المحول منه *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _fromPhoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.cairo(fontSize: 14),
            decoration: _inputDecoration(
              'مثال: 01012345678',
              Icons.phone_iphone_rounded,
            ),
            validator: (val) {
              if (_selectedPaymentMethod == 'wallet' && (val == null || val.trim().isEmpty)) {
                return 'يرجى إدخال رقم الهاتف المحول منه';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Sender Name Field
          _buildFieldLabel('اسم صاحب الحساب المحول منه (اختياري)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _fromNameController,
            style: GoogleFonts.cairo(fontSize: 14),
            decoration: _inputDecoration(
              'اسم المحول كما يظهر في التطبيق',
              Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: 16),

          // Receipt Upload Section
          _buildFieldLabel('صورة إيصال التحويل (سكرين شوت) *'),
          const SizedBox(height: 8),
          if (_receiptImage == null) ...[
            InkWell(
              onTap: _pickReceiptImage,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5B00).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: Color(0xFFFF5B00),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'اضغط لإرفاق صورة إيصال التحويل',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'سكرين شوت من تطبيق المحفظة أو إنستاباي',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _receiptImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'تم إرفاق صورة الإيصال',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _receiptImage!.path.split(Platform.pathSeparator).last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Color(0xFFFF5B00), size: 20),
                    tooltip: 'تغيير الصورة',
                    onPressed: _pickReceiptImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    tooltip: 'حذف',
                    onPressed: () => setState(() => _receiptImage = null),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSubmitBar({
    required StoresCubit cubit,
    required double itemsTotal,
    required double deliveryFee,
    required double finalTotal,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المبلغ الإجمالي',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  '${finalTotal.toStringAsFixed(0)} ج.م',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF5B00),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5B00),
                  minimumSize: const Size(double.infinity, 52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isLoading ? null : _submitOrder,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'إتمام الطلب',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildItemPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFFF1F5F9),
      child: const Icon(
        Icons.fastfood_rounded,
        size: 24,
        color: Color(0xFFCBD5E1),
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تم إرسال الطلب بنجاح!',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تم تحويل طلبك إلى ${widget.store.storeName} وسيتولى كابتن التوصيل إيصال طلبك قريباً.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5B00),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx); // pop dialog
                  Navigator.pop(context); // pop checkout screen
                },
                child: Text(
                  'حسناً، متابعة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Searchable Zone Picker Bottom Sheet
// ---------------------------------------------------------
class _ZonePickerBottomSheet extends StatefulWidget {
  final String? selectedZone;
  final String storeZone;
  final ValueChanged<String> onZoneSelected;

  const _ZonePickerBottomSheet({
    required this.selectedZone,
    required this.storeZone,
    required this.onZoneSelected,
  });

  @override
  State<_ZonePickerBottomSheet> createState() => _ZonePickerBottomSheetState();
}

class _ZonePickerBottomSheetState extends State<_ZonePickerBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filteredZones = [];

  @override
  void initState() {
    super.initState();
    _filteredZones = ZoneDeliveryPricing.allZones;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredZones = ZoneDeliveryPricing.allZones);
      return;
    }
    final normQuery = ZoneDeliveryPricing.normalizeZone(query);
    setState(() {
      _filteredZones = ZoneDeliveryPricing.allZones.where((zone) {
        final normZone = ZoneDeliveryPricing.normalizeZone(zone);
        return normZone.contains(normQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'اختر مدينة / منطقة التوصيل',
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search box
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filter,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ابحث عن المنطقة (مثال: الهانوفيل، البيطاش، الكيلو 21...)',
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFFF5B00),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Zones list
            Expanded(
              child: _filteredZones.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد منطقة مطابقة للبحث',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _filteredZones.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFF8FAFC)),
                      itemBuilder: (context, index) {
                        final zone = _filteredZones[index];
                        final isSelected = widget.selectedZone == zone;
                        final fee = ZoneDeliveryPricing.calculateFee(
                          fromZone: widget.storeZone,
                          toZone: zone,
                        );

                        return InkWell(
                          onTap: () => widget.onZoneSelected(zone),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF5B00).withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.location_on_outlined,
                                  color: isSelected
                                      ? const Color(0xFFFF5B00)
                                      : const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    zone,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14.5,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFFFF5B00)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${fee.toStringAsFixed(0)} ج.م توصيل',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
