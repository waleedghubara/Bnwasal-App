// ignore_for_file: unused_field, unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart' as di;
import 'package:admin_bnwasal/core/services/notification_service.dart';
import 'package:admin_bnwasal/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class OfferNegotiationScreen extends StatefulWidget {
  final String? shipmentId;
  final String? orderId;
  final String number;
  final String title;
  final double price;

  const OfferNegotiationScreen({
    super.key,
    this.shipmentId,
    this.orderId,
    required this.number,
    required this.title,
    required this.price,
  });

  @override
  State<OfferNegotiationScreen> createState() => _OfferNegotiationScreenState();
}

class _OfferNegotiationScreenState extends State<OfferNegotiationScreen> {
  final List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;
  String? _currentStatus;
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;
  final _priceFocusNode = FocusNode();

  String get _roomName => widget.shipmentId != null
      ? 'shipment_${widget.shipmentId}'
      : 'order_${widget.orderId}';

  @override
  void initState() {
    super.initState();
    _loadOffers();
    _connectSocket();
  }

  @override
  void dispose() {
    _disconnectSocket();
    _priceController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  void _connectSocket() {
    final ns = NotificationService();
    ns.joinRoom(_roomName);
    final socket = ns.socket;
    if (socket != null) {
      socket.on('new_offer', _handleNewOffer);
      socket.on('offer_accepted', _handleOfferAccepted);
      socket.on('offer_rejected', _handleOfferRejected);
      socket.on('statusUpdate', _handleStatusUpdate);
    }
  }

  void _disconnectSocket() {
    final ns = NotificationService();
    ns.leaveRoom(_roomName);
    final socket = ns.socket;
    if (socket != null) {
      socket.off('new_offer', _handleNewOffer);
      socket.off('offer_accepted', _handleOfferAccepted);
      socket.off('offer_rejected', _handleOfferRejected);
      socket.off('statusUpdate', _handleStatusUpdate);
    }
  }

  void _handleNewOffer(dynamic data) {
    if (data is Map && mounted) {
      setState(() => _offers.add(Map<String, dynamic>.from(data)));
      _scrollToBottom();
      final senderRole = data['senderRole']?.toString() ?? '';
      final isFromMerchant = senderRole != 'admin' && senderRole != 'employee';
      if (isFromMerchant) {
        final price = data['offerPrice']?.toString() ?? '';
        final note = data['note']?.toString();
        final msg =
            '📩 عرض سعر جديد من التاجر: $price ج.م${note != null && note.isNotEmpty ? ' — $note' : ''}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(fontSize: 13)),
            backgroundColor: const Color(0xFF8b5cf6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(12.w),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'عرض',
              textColor: Colors.white,
              onPressed: () => _scrollToBottom(),
            ),
          ),
        );
        NotificationService().showLocalNotification(
          '💰 عرض سعر من التاجر',
          'قيمة العرض: $price ج.م',
        );
      }
    }
  }

  void _handleOfferAccepted(dynamic data) {
    if (data is Map && mounted) {
      final msgId = data['messageId']?.toString();
      setState(() {
        for (var o in _offers) {
          if (o['id'] == msgId) {
            o['offerStatus'] = 'accepted';
          } else if (o['offerStatus'] == 'pending') {
            o['offerStatus'] = 'rejected';
          }
        }
      });
    }
  }

  void _handleOfferRejected(dynamic data) {
    if (data is Map && mounted) {
      final msgId = data['messageId']?.toString();
      setState(() {
        for (var o in _offers) {
          if (o['id'] == msgId) o['offerStatus'] = 'rejected';
        }
        _currentStatus = 'Pending Review';
      });
    }
  }

  void _handleStatusUpdate(dynamic data) {
    if (data is Map && mounted) {
      setState(() => _currentStatus = data['status']?.toString());
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadOffers() async {
    try {
      final dio = di.sl<DioConsumer>();
      final path = widget.shipmentId != null
          ? 'negotiation/offers?shipmentId=${widget.shipmentId}'
          : 'negotiation/offers?orderId=${widget.orderId}';
      final response = await dio.get(path);
      final list = response['data'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _offers.clear();
          _offers.addAll(list.map((e) => Map<String, dynamic>.from(e)));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitOffer(double price, String? note) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = di.sl<DioConsumer>();
      await dio.post(
        'negotiation/offer',
        data: {
          if (widget.shipmentId != null) 'shipmentId': widget.shipmentId,
          if (widget.orderId != null) 'orderId': widget.orderId,
          'price': price,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      di.sl<DashboardCubit>().loadDashboard();
      await _loadOffers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال العرض: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _submitFromInput() {
    final price = double.tryParse(_priceController.text.trim());
    if (price != null && price > 0) {
      _submitOffer(
        price,
        _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      _priceController.clear();
      _noteController.clear();
      _priceFocusNode.unfocus();
    }
  }

  Future<void> _acceptOffer(String offerId) async {
    try {
      final dio = di.sl<DioConsumer>();
      await dio.post('negotiation/accept', data: {'messageId': offerId});
      di.sl<DashboardCubit>().loadDashboard();
      await _loadOffers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول عرض السعر بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل قبول العرض: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _counterOffer(String senderName, double currentPrice) {
    _priceController.text = currentPrice.toStringAsFixed(0);
    _scrollToBottom();
    final isWide = MediaQuery.of(context).size.width >= 700;
    if (!isWide) {
      _showOfferBottomSheet();
    } else {
      _priceFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF041930) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF041930) : Colors.white,
        elevation: 0,
        title: Column(
          children: [
            Text(
              'عروض الأسعار',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              '${widget.shipmentId != null ? "شحنة" : "طلب"} #${widget.number}',
              style: TextStyle(
                fontSize: 11.sp,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            return Column(
              children: [
                _buildInfoBanner(),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              )
                            : _offers.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 12.h,
                                ),
                                itemCount: _offers.length,
                                itemBuilder: (ctx, i) =>
                                    _buildOfferCard(_offers[i]),
                              ),
                      ),
                      if (isWide) _buildSidePanel(),
                    ],
                  ),
                ),
                if (!isWide) _buildMobileBottomBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidePanel() {
    final isSendEnabled =
        _priceController.text.trim().isNotEmpty &&
        double.tryParse(_priceController.text.trim()) != null &&
        double.parse(_priceController.text.trim()) > 0 &&
        !_isSubmitting;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 400.w,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF041930) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10.h),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                Center(
                  child: FaIcon(
                    FontAwesomeIcons.moneyBill,
                    size: 14.sp,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'إرسال عرض',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سعر العرض',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _priceController,
                    focusNode: _priceFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      fillColor: Colors.transparent,
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 13.sp,
                      ),
                      border: InputBorder.none,
                      suffixText: 'ج.م',
                      suffixStyle: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                    ),
                    textAlign: TextAlign.right,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submitFromInput(),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'ملاحظة (اختياري)',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _noteController,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 13.sp,
                    ),
                    maxLines: 3,
                    decoration: InputDecoration(
                      fillColor: Colors.transparent,
                      hintText: 'اكتب ملاحظتك هنا...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 12.sp,
                      ),
                      border: InputBorder.none,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.06),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    height: 44.h,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            isSendEnabled ? AppColors.primary : Colors.white12,
                            isSendEnabled ? AppColors.primary : Colors.white10,
                          ],
                        ),
                        boxShadow: isSendEnabled
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: isSendEnabled ? _submitFromInput : null,
                          child: Center(
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.send_rounded,
                                        size: 16.sp,
                                        color: isSendEnabled
                                            ? Colors.white
                                            : Colors.white24,
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        'إرسال العرض',
                                        style: TextStyle(
                                          color: isSendEnabled
                                              ? Colors.white
                                              : Colors.white24,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
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

  void _showOfferBottomSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF111129) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isSendEnabled =
                _priceController.text.trim().isNotEmpty &&
                double.tryParse(_priceController.text.trim()) != null &&
                double.parse(_priceController.text.trim()) > 0 &&
                !_isSubmitting;

            return Padding(
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                top: 16.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        color: AppColors.success,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'إرسال عرض سعر جديد',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'سعر العرض',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    autofocus: true,
                    decoration: InputDecoration(
                      fillColor: Colors.transparent,
                      filled: true,
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black26,
                        fontSize: 14.sp,
                      ),
                      suffixText: 'ج.م',
                      suffixStyle: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                      border: InputBorder.none,
                    ),
                    textAlign: TextAlign.right,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'ملاحظة (اختياري)',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _noteController,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black,
                      fontSize: 13.sp,
                    ),
                    maxLines: 2,
                    decoration: InputDecoration(
                      fillColor: Colors.transparent,
                      hintText: 'اكتب ملاحظتك هنا...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black26,
                        fontSize: 12.sp,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    height: 44.h,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            isSendEnabled ? AppColors.primary : Colors.white12,
                            isSendEnabled ? AppColors.primary : Colors.white10,
                          ],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: isSendEnabled
                              ? () {
                                  _submitFromInput();
                                  Navigator.pop(context);
                                }
                              : null,
                          child: Center(
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.send_rounded,
                                        size: 16.sp,
                                        color: isSendEnabled
                                            ? Colors.white
                                            : Colors.white24,
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        'إرسال العرض',
                                        style: TextStyle(
                                          color: isSendEnabled
                                              ? Colors.white
                                              : Colors.white24,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileBottomBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF041930) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 44.h,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF00bcd4)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _showOfferBottomSheet,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        size: 16.sp,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'تقديم عرض سعر جديد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF041930) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.shipmentId != null ? "شحنة" : "طلب"} #${widget.number}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.title.isNotEmpty) ...[
                  SizedBox(height: 1.h),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.price.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 13.sp,
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

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_offer_outlined,
              size: 28.sp,
              color: Colors.white12,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'لا توجد عروض بعد',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final status = offer['offerStatus']?.toString() ?? 'pending';
    final price = offer['offerPrice'];
    final note = offer['note']?.toString();
    final senderName = offer['senderName']?.toString() ?? 'مجهول';
    final senderRole = offer['senderRole']?.toString() ?? '';
    final createdAt = offer['createdAt']?.toString() ?? '';
    final offerId = offer['id']?.toString() ?? '';
    final isFromAdmin = senderRole == 'admin' || senderRole == 'employee';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'accepted':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'مقبول';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'مرفوض';
        break;
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = 'قيد الانتظار';
    }

    String formattedDate = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      formattedDate =
          '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151532) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'accepted'
              ? AppColors.success.withOpacity(0.2)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      color: isFromAdmin
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isFromAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.store_rounded,
                      size: 12.sp,
                      color: isFromAdmin
                          ? AppColors.primary
                          : AppColors.secondary,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    isFromAdmin ? 'الإدارة' : 'التاجر',
                    style: TextStyle(
                      color: isFromAdmin
                          ? AppColors.primary
                          : AppColors.secondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 8.sp, color: statusColor),
                    SizedBox(width: 3.w),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$price',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              SizedBox(width: 3.w),
              Text(
                'ج.م',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),

              Text(
                formattedDate,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(width: 3.w),
              FaIcon(
                FontAwesomeIcons.clock,
                size: 16.sp,
                color: isDark ? Colors.white : Colors.black,
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF151532)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FaIcon(
                    FontAwesomeIcons.noteSticky,
                    size: 14.sp,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 10.sp,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status == 'pending' && !isFromAdmin) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 32.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [AppColors.success, const Color(0xFF00b894)],
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _acceptOffer(offerId),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 12.sp,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              'قبول',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Container(
                    height: 32.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.4),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _counterOffer(
                          senderName,
                          price is num ? price.toDouble() : widget.price,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 12.sp,
                              color: AppColors.secondary,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              'عرض مضاد',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
