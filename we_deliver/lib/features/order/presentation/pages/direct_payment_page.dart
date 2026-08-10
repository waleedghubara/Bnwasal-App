// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/di/injection_container.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class PaymentMethod {
  final String name;
  final String icon; // legacy field: 'vodafone' | 'instapay' | etc.
  final String phone;
  final String? imageUrl; // uploaded icon URL from backend

  const PaymentMethod({
    required this.name,
    required this.icon,
    required this.phone,
    this.imageUrl,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN 1 – PAYMENT METHOD SELECTION
// ═══════════════════════════════════════════════════════════════════════════════

class DirectPaymentPage extends StatefulWidget {
  final String itemId; // orderId or shipmentId
  final String itemType; // 'order' | 'shipment'
  final String itemNumber;
  final double amount;
  final String merchantName;
  final String merchantPhone;
  final String? merchantImage;

  const DirectPaymentPage({
    super.key,
    required this.itemId,
    required this.itemType,
    required this.itemNumber,
    required this.amount,
    required this.merchantName,
    required this.merchantPhone,
    this.merchantImage,
  });

  @override
  State<DirectPaymentPage> createState() => _DirectPaymentPageState();
}

class _DirectPaymentPageState extends State<DirectPaymentPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
  List<PaymentMethod> _methods = [];
  int? _selectedIndex;
  late AnimationController _listAnim;

  late String _merchantName;
  late String _merchantPhone;
  String? _merchantImage;

  @override
  void initState() {
    super.initState();
    _merchantName = widget.merchantName;
    _merchantPhone = widget.merchantPhone;
    _merchantImage = widget.merchantImage;
    _listAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchMethods();
  }

  @override
  void dispose() {
    _listAnim.dispose();
    super.dispose();
  }

  String _cleanUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final baseUrl = EndPoint.imageBaseUrl.endsWith('/')
        ? EndPoint.imageBaseUrl.substring(0, EndPoint.imageBaseUrl.length - 1)
        : EndPoint.imageBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  Future<void> _fetchMethods() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      // 1. Fetch payment methods
      final res = await sl<Dio>().get(
        '${EndPoint.baseUrl}${EndPoint.directPaymentMethods}',
      );
      final data = res.data as Map<String, dynamic>;

      // 2. Fetch logged-in user profile to get correct name/phone
      final profileRes = await sl<Dio>().get(
        '${EndPoint.baseUrl}${EndPoint.getProfile}',
      );
      final profileData = profileRes.data as Map<String, dynamic>;

      if (data['status'] == 1 && profileData['status'] == 1) {
        final list = (data['data']['methods'] as List)
            .cast<Map<String, dynamic>>();

        final user = profileData['data']['user'] as Map<String, dynamic>;
        final String firstName = user['firstName']?.toString() ?? '';
        final String lastName = user['lastName']?.toString() ?? '';
        final String fullName = '$firstName $lastName'.trim();
        final String phone = user['phone']?.toString() ?? '';
        final String? image = user['profileImage']?.toString();

        setState(() {
          _methods = list.map(PaymentMethod.fromJson).toList();
          if (fullName.isNotEmpty) _merchantName = fullName;
          if (phone.isNotEmpty) _merchantPhone = phone;
          if (image != null && image.isNotEmpty) _merchantImage = image;
          _isLoading = false;
        });
        _listAnim.forward();
      } else {
        _setError();
      }
    } catch (_) {
      _setError();
    }
  }

  void _setError() {
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  void _onMethodTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedIndex = index);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      final method = _methods[index];
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, _) => FadeTransition(
            opacity: anim,
            child: UploadReceiptPage(
              itemId: widget.itemId,
              itemType: widget.itemType,
              itemNumber: widget.itemNumber,
              amount: widget.amount,
              method: method,
              merchantName: _merchantName,
              merchantPhone: _merchantPhone,
              merchantImage: _merchantImage,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ).then((_) {
        if (mounted) setState(() => _selectedIndex = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(child: _buildOrderSummaryCard()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'اختر وسيلة الدفع',
                      style: GoogleFonts.tajawal(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(child: _MethodsLoadingSkeleton())
            else if (_hasError)
              SliverFillRemaining(child: _buildErrorState())
            else if (_methods.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildMethodCard(i),
                    childCount: _methods.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withOpacity(0.08),
      centerTitle: true,
      title: Text(
        'الدفع المباشر',
        style: GoogleFonts.tajawal(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: const Color(0xFF1A1A2E),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: const Color(0xFF1A1A2E),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primary, Color(0xFF0055D4)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Merchant avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: _merchantImage != null && _merchantImage!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _cleanUrl(_merchantImage),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _merchantName,
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _merchantPhone,
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Amount badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  '${widget.amount.toStringAsFixed(0)} ج.م',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.tag_rounded,
                label: 'رقم ${widget.itemType == 'order' ? 'الطلب' : 'الشحنة'}',
                value: '#${widget.itemNumber}',
              ),
              const Spacer(),
              _buildInfoChip(
                icon: Icons.receipt_long_outlined,
                label: 'رسوم التوصيل',
                value: '${widget.amount.toStringAsFixed(0)} ج.م',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.tajawal(
                fontSize: 10,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.tajawal(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodCard(int index) {
    final method = _methods[index];
    final isSelected = _selectedIndex == index;

    return AnimatedBuilder(
      animation: _listAnim,
      builder: (_, child) {
        final delay = index * 0.15;
        final t = Curves.easeOutCubic.transform(
          ((_listAnim.value - delay) / (1 - delay)).clamp(0.0, 1.0),
        );
        return Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: Opacity(opacity: t.clamp(0, 1), child: child),
        );
      },
      child: GestureDetector(
        onTap: () => _onMethodTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE8EEF8),
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon / image
              _buildMethodIcon(method),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name,
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'رقم التحويل: ${method.phone}',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFF0F4FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodIcon(PaymentMethod method) {
    // Priority: uploaded imageUrl > built-in icon rendering
    if (method.imageUrl != null && method.imageUrl!.isNotEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EEF8)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.network(
            _cleanUrl(method.imageUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackIcon(method.icon),
          ),
        ),
      );
    }
    return _buildFallbackIcon(method.icon);
  }

  Widget _buildFallbackIcon(String iconType) {
    switch (iconType.toLowerCase()) {
      case 'vodafone':
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE60000),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              'V',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      case 'instapay':
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B2D8E), Color(0xFF9B59B6)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              'iP',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      default:
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.payment_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        );
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'تعذّر تحميل وسائل الدفع',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تحقق من الاتصال بالإنترنت وأعد المحاولة',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchMethods,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'إعادة المحاولة',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.payment_outlined,
                size: 40,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد وسائل دفع متاحة',
              style: GoogleFonts.tajawal(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم إضافة وسائل الدفع قريباً من قِبَل الإدارة',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Loading skeleton widget
class _MethodsLoadingSkeleton extends StatefulWidget {
  const _MethodsLoadingSkeleton();

  @override
  State<_MethodsLoadingSkeleton> createState() =>
      _MethodsLoadingSkeletonState();
}

class _MethodsLoadingSkeletonState extends State<_MethodsLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (_, _) {
          final opacity = 0.05 + 0.08 * _shimmer.value;
          return Column(
            children: List.generate(
              3,
              (i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8EEF8)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(opacity * 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(opacity),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 11,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(opacity * 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN 2 – UPLOAD RECEIPT
// ═══════════════════════════════════════════════════════════════════════════════

class UploadReceiptPage extends StatefulWidget {
  final String itemId;
  final String itemType;
  final String itemNumber;
  final double amount;
  final PaymentMethod method;
  final String merchantName;
  final String merchantPhone;
  final String? merchantImage;

  const UploadReceiptPage({
    super.key,
    required this.itemId,
    required this.itemType,
    required this.itemNumber,
    required this.amount,
    required this.method,
    required this.merchantName,
    required this.merchantPhone,
    this.merchantImage,
  });

  @override
  State<UploadReceiptPage> createState() => _UploadReceiptPageState();
}

class _UploadReceiptPageState extends State<UploadReceiptPage>
    with SingleTickerProviderStateMixin {
  final _fromPhoneController = TextEditingController();
  final _fromNameController = TextEditingController();
  File? _receiptImage;
  bool _isSubmitting = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fromPhoneController.text = widget.merchantPhone;
    _fromNameController.text = widget.merchantName;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _fromPhoneController.dispose();
    _fromNameController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (result != null) {
      HapticFeedback.selectionClick();
      setState(() => _receiptImage = File(result.path));
    }
  }

  Future<void> _submit() async {
    final phone = _fromPhoneController.text.trim();
    final name = _fromNameController.text.trim();
    if (name.isEmpty || phone.isEmpty || _receiptImage == null) {
      _showSnack(
        message: 'يرجى تعبئة جميع الحقول ورفع صورة الإيصال',
        isError: true,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final formData = FormData.fromMap({
        widget.itemType == 'order' ? 'orderId' : 'shipmentId': widget.itemId,
        'paymentMethod': widget.method.name,
        'fromPhone': phone,
        'fromName': name,
        'receiptImage': await MultipartFile.fromFile(_receiptImage!.path),
      });

      final res = await sl<Dio>().post(
        '${EndPoint.baseUrl}${EndPoint.directPaymentSubmit}',
        data: formData,
      );

      if (res.data['status'] == 1) {
        final paymentRef = res.data['data']['paymentRef'] as String;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) => FadeTransition(
                opacity: anim,
                child: PaymentWaitingPage(
                  paymentRef: paymentRef,
                  amount: widget.amount,
                  itemNumber: widget.itemNumber,
                  itemType: widget.itemType,
                ),
              ),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data is Map
                  ? (e.response!.data['message'] ?? 'فشل الإرسال')
                  : 'فشل الإرسال')
            : 'فشل الإرسال';
        _showSnack(
          message: msg,
          isError: true,
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack({
    required String message,
    required bool isError,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.tajawal(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'رفع إيصال الدفع',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Color(0xFF1A1A2E),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMethodInfoCard(),
                const SizedBox(height: 20),
                _buildStepsGuide(),
                const SizedBox(height: 20),
                _buildFormSection(),
                const SizedBox(height: 20),
                _buildReceiptSection(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchTransferApp() async {
    final methodName = widget.method.name.toLowerCase();
    final methodIcon = widget.method.icon.toLowerCase();

    if (methodName.contains('vodafone') ||
        methodIcon.contains('vodafone') ||
        methodName.contains('فودافون')) {
      // Vodafone Cash USSD code: *9*7*number*amount#
      final ussd =
          '*9*7*${widget.method.phone}*${widget.amount.toStringAsFixed(0)}#';
      final url = Uri.parse('tel:${Uri.encodeComponent(ussd)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        final phoneUrl = Uri.parse('tel:${widget.method.phone}');
        if (await canLaunchUrl(phoneUrl)) {
          await launchUrl(phoneUrl);
        }
      }
    } else if (methodName.contains('instapay') ||
        methodIcon.contains('instapay') ||
        methodName.contains('انستا')) {
      // Instapay deep link
      final androidUrl = Uri.parse(
        'intent://#Intent;scheme=instapay;package=com.instapay;end',
      );
      final fallbackUrl = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.instapay',
      );
      if (await canLaunchUrl(androidUrl)) {
        await launchUrl(androidUrl);
      } else if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl);
      }
    } else {
      final phoneUrl = Uri.parse('tel:${widget.method.phone}');
      if (await canLaunchUrl(phoneUrl)) {
        await launchUrl(phoneUrl);
      }
    }
  }

  String _cleanUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final baseUrl = EndPoint.imageBaseUrl.endsWith('/')
        ? EndPoint.imageBaseUrl.substring(0, EndPoint.imageBaseUrl.length - 1)
        : EndPoint.imageBaseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  Widget _buildMethodInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Payment method icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child:
                    widget.method.imageUrl != null &&
                        widget.method.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          _cleanUrl(widget.method.imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.payment_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.payment_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حوّل عبر ${widget.method.name}',
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.method.phone),
                        );
                        _showSnack(
                          message: 'تم نسخ رقم التحويل بنجاح',
                          isError: false,
                          icon: Icons.check_circle_rounded,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.method.phone,
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Text(
                  '${widget.amount.toStringAsFixed(0)} ج.م',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.method.phone));
                    _showSnack(
                      message: 'تم نسخ رقم التحويل بنجاح',
                      isError: false,
                      icon: Icons.check_circle_rounded,
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(
                    'نسخ الرقم',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _launchTransferApp,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    'انتقال للتحويل',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3C72),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepsGuide() {
    final steps = [
      (icon: Icons.swap_horiz_rounded, text: 'حوّل المبلغ إلى الرقم المذكور'),
      (icon: Icons.camera_alt_outlined, text: 'التقط صورة للإيصال'),
      (icon: Icons.send_rounded, text: 'أرسل الإيصال للتحقق'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خطوات إتمام الدفع',
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((e) {
            final i = e.key;
            final step = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    step.icon,
                    size: 16,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.text,
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: const Color(0xFF555E73),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بيانات المُحوِّل',
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _fromNameController,
            label: 'اسم صاحب رقم الهاتف',
            hint: 'أدخل الاسم الكامل',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _fromPhoneController,
            label: 'رقم الهاتف المُحوَّل منه',
            hint: '01XXXXXXXXX',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF555E73),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textDirection: TextDirection.rtl,
          inputFormatters: inputFormatters,
          style: GoogleFonts.tajawal(
            fontSize: 14,
            color: const Color(0xFF1A1A2E),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.tajawal(
              color: const Color(0xFFB0B8CA),
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: const Color(0xFFF7F9FF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8EEF8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE8EEF8),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'صورة الإيصال',
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 170,
              decoration: BoxDecoration(
                color: _receiptImage != null
                    ? Colors.transparent
                    : const Color(0xFFF7F9FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _receiptImage != null
                      ? AppColors.primary
                      : const Color(0xFFCDD5E8),
                  width: _receiptImage != null ? 2 : 1.5,
                ),
              ),
              child: _receiptImage != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_receiptImage!, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Text(
                              '✓ تم اختيار الصورة',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.07),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.upload_file_rounded,
                            size: 34,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'اضغط لرفع صورة الإيصال',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF555E73),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'JPG · PNG · WEBP — حتى 10 ميجا',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            color: const Color(0xFFB0B8CA),
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

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      decoration: BoxDecoration(
        gradient: _isSubmitting
            ? null
            : const LinearGradient(
                colors: [AppColors.primary, Color(0xFF0055D4)],
              ),
        color: _isSubmitting ? AppColors.primary.withOpacity(0.5) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isSubmitting
            ? []
            : [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSubmitting ? null : _submit,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'إرسال الإيصال',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN 3 – PAYMENT WAITING (15-min timer + polling)
// ═══════════════════════════════════════════════════════════════════════════════

class PaymentWaitingPage extends StatefulWidget {
  final String paymentRef;
  final double amount;
  final String itemNumber;
  final String itemType;

  const PaymentWaitingPage({
    super.key,
    required this.paymentRef,
    required this.amount,
    required this.itemNumber,
    required this.itemType,
  });

  @override
  State<PaymentWaitingPage> createState() => _PaymentWaitingPageState();
}

class _PaymentWaitingPageState extends State<PaymentWaitingPage>
    with TickerProviderStateMixin {
  static const _waitDuration = Duration(minutes: 15);
  static const _pollInterval = Duration(seconds: 10);

  late DateTime _deadline;
  late Timer _countdownTimer;
  Timer? _pollTimer;
  String _timeLeft = '15:00';
  double _progress = 1.0;
  String _paymentStatus = 'pending';
  bool _isDone = false;

  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _resultCtrl;
  late Animation<double> _resultAnim;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(_waitDuration);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _resultAnim = CurvedAnimation(
      parent: _resultCtrl,
      curve: Curves.elasticOut,
    );

    _startCountdown();
    _startPolling();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDone) return;
      final remaining = _deadline.difference(DateTime.now());
      if (remaining.isNegative) {
        setState(() {
          _timeLeft = '00:00';
          _progress = 0;
        });
        _countdownTimer.cancel();
        _pollTimer?.cancel();
        _markDone();
      } else {
        final total = _waitDuration.inSeconds;
        final left = remaining.inSeconds;
        final mins = remaining.inMinutes
            .remainder(60)
            .toString()
            .padLeft(2, '0');
        final secs = remaining.inSeconds
            .remainder(60)
            .toString()
            .padLeft(2, '0');
        setState(() {
          _timeLeft = '$mins:$secs';
          _progress = left / total;
        });
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      if (_isDone) return;
      await _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    try {
      final res = await sl<Dio>().get(
        '${EndPoint.baseUrl}${EndPoint.directPaymentStatus(widget.paymentRef)}',
      );
      if (res.data['status'] == 1) {
        final newStatus = res.data['data']['status'] as String;
        if (newStatus != 'pending') {
          setState(() {
            _paymentStatus = newStatus;
          });
          _countdownTimer.cancel();
          _pollTimer?.cancel();
          _markDone();
        }
      }
    } catch (_) {}
  }

  void _markDone() {
    setState(() => _isDone = true);
    _pulseCtrl.stop();
    _resultCtrl.forward();
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: _isDone,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final result = await showDialog<bool>(
            context: context,
            builder: (_) => _buildExitDialog(),
          );
          if (result == true && mounted) {
            int count = 0;
            Navigator.of(context).popUntil((_) => count++ >= 3);
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          body: SafeArea(
            child: _isDone ? _buildResultView() : _buildWaitingView(),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                Text(
                  'بانتظار مراجعة الإدارة',
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يتم مراجعة إيصال الدفع من قِبَل الإدارة\nسيصلك إشعار فور الموافقة',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    color: const Color(0xFF6B7691),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // Clock Timer card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(170, 170),
                              painter: _TimerClockPainter(
                                progress: _progress,
                                color: _progress < 0.2
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.hourglassHalf,
                                  size: 20,
                                  color:
                                      (_progress < 0.2
                                              ? AppColors.error
                                              : AppColors.primary)
                                          .withOpacity(0.55),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _timeLeft,
                                  style: GoogleFonts.shareTechMono(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1A2E),
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'دقائق متبقية',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 10,
                                    color: const Color(0xFF9AA3B8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'الوقت المتبقي لمراجعة الإيصال تلقائياً',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          color: const Color(0xFF6B7691),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Info tile
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFDC7A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tips_and_updates_rounded,
                        color: Color(0xFFF0A800),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'يتم تفعيل طلبك تلقائياً فور موافقة الإدارة على الإيصال',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: const Color(0xFF7A5800),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Order info chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8EEF8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoPair(
                        label:
                            'رقم ${widget.itemType == 'order' ? 'الطلب' : 'الشحنة'}',
                        value: '#${widget.itemNumber}',
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: const Color(0xFFE8EEF8),
                      ),
                      _buildInfoPair(
                        label: 'المبلغ المدفوع',
                        value: '${widget.amount.toStringAsFixed(0)} ج.م',
                        valueColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Exit button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (_) => _buildExitDialog(),
              );
              if (result == true && mounted) {
                int count = 0;
                Navigator.of(context).popUntil((_) => count++ >= 3);
              }
            },
            icon: const Icon(Icons.exit_to_app_rounded, size: 18),
            label: Text(
              'الخروج',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7691),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: const BorderSide(color: Color(0xFFCDD5E8), width: 1.5),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPair({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 11,
            color: const Color(0xFF9AA3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final isApproved = _paymentStatus == 'approved';
    final isTimeout = _paymentStatus == 'pending';

    final Color mainColor = isApproved
        ? AppColors.success
        : isTimeout
        ? const Color(0xFFF0A800)
        : AppColors.error;
    final IconData mainIcon = isApproved
        ? Icons.check_circle_rounded
        : isTimeout
        ? Icons.timer_off_rounded
        : Icons.cancel_rounded;
    final String title = isApproved
        ? ' تم تأكيد الدفع!'
        : isTimeout
        ? ' انتهى وقت الانتظار'
        : ' تم رفض الإيصال';
    final String subtitle = isApproved
        ? 'تمت الموافقة على إيصالك وتم تفعيل طلبك بنجاح'
        : isTimeout
        ? 'لم يتم الرد خلال المهلة. يمكنك مراجعة الحالة لاحقاً من تفاصيل الطلب'
        : 'لم تتم الموافقة على الإيصال. تواصل مع الإدارة للاستفسار';

    return ScaleTransition(
      scale: _resultAnim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(mainIcon, size: 60, color: mainColor),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: GoogleFonts.tajawal(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: mainColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  color: const Color(0xFF6B7691),
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    int count = 0;
                    Navigator.of(context).popUntil((_) => count++ >= 3);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isApproved
                        ? AppColors.success
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'العودة للطلب',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExitDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'الخروج من الانتظار',
        style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      content: Text(
        'طلبك قيد المراجعة. يمكنك متابعة الحالة لاحقاً من تفاصيل الطلب.',
        style: GoogleFonts.tajawal(
          fontSize: 13,
          color: Colors.grey.shade600,
          height: 1.6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'البقاء',
            style: GoogleFonts.tajawal(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'خروج',
            style: GoogleFonts.tajawal(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerClockPainter extends CustomPainter {
  final double progress;
  final Color color;

  _TimerClockPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw background track line
    final trackPaint = Paint()
      ..color = const Color(0xFFF0F4FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 6, trackPaint);

    // Draw elapsed/remaining arc with nice gradient
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );

    // Draw inner ticks to make it look like a watch/clock dial
    final tickPaint = Paint()
      ..color = const Color(0xFFCDD5E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final startOffset = Offset(
        center.dx + (radius - 20) * math.cos(angle),
        center.dy + (radius - 20) * math.sin(angle),
      );
      final endOffset = Offset(
        center.dx + (radius - 14) * math.cos(angle),
        center.dy + (radius - 14) * math.sin(angle),
      );
      canvas.drawLine(startOffset, endOffset, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimerClockPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
