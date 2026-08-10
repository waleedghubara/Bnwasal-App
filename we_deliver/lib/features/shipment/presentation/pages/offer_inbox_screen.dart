// ignore_for_file: unused_local_variable, use_null_aware_elements, unused_field, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/di/injection_container.dart';

class OfferInboxScreen extends StatefulWidget {
  final String? shipmentId;
  final String? orderId;
  final String number;
  final String title;
  final double price;

  const OfferInboxScreen({
    super.key,
    this.shipmentId,
    this.orderId,
    required this.number,
    required this.title,
    required this.price,
  });

  @override
  State<OfferInboxScreen> createState() => _OfferInboxScreenState();
}

class _OfferInboxScreenState extends State<OfferInboxScreen> {
  final List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;
  io.Socket? _socket;
  String? _myId;

  String get _roomName => widget.shipmentId != null
      ? 'shipment_${widget.shipmentId}'
      : 'order_${widget.orderId}';

  String get _cacheKey => 'offers_${widget.shipmentId ?? widget.orderId ?? ''}';

  @override
  void initState() {
    super.initState();
    _initMyId();
    _loadOffers();
    _connectSocket();
  }

  @override
  void dispose() {
    _disconnectSocket();
    super.dispose();
  }

  Future<void> _initMyId() async {
    final id = await SecureCacheHelper().getData(key: ApiKey.id);
    if (mounted) setState(() => _myId = id);
  }

  void _connectSocket() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);
    _socket = io.io(
      EndPoint.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );
    _socket!.connect();
    _socket!.onConnect((_) => _socket!.emit('joinRoom', _roomName));
    _socket!.on('new_offer', _handleNewOffer);
    _socket!.on('offer_accepted', _handleOfferAccepted);
    _socket!.on('offer_rejected', _handleOfferRejected);
    _socket!.on('statusUpdate', _handleStatusUpdate);
  }

  void _disconnectSocket() {
    _socket?.emit('leaveRoom', _roomName);
    _socket?.off('new_offer');
    _socket?.off('offer_accepted');
    _socket?.off('offer_rejected');
    _socket?.off('statusUpdate');
    _socket?.disconnect();
  }

  void _handleNewOffer(dynamic data) {
    if (data is Map && mounted) {
      setState(() => _offers.add(Map<String, dynamic>.from(data)));
      _saveToLocalCache();
    }
  }

  void _handleOfferAccepted(dynamic data) {
    if (data is Map && mounted) {
      final msgId = data['messageId']?.toString();
      setState(() {
        for (var o in _offers) {
          if (o['id']?.toString() == msgId) {
            o['offerStatus'] = 'accepted';
          } else if (o['offerStatus'] == 'pending') {
            o['offerStatus'] = 'rejected';
          }
        }
      });
      _saveToLocalCache();
    }
  }

  void _handleOfferRejected(dynamic data) {
    if (data is Map && mounted) {
      final msgId = data['messageId']?.toString();
      setState(() {
        for (var o in _offers) {
          if (o['id']?.toString() == msgId) o['offerStatus'] = 'rejected';
        }
      });
      _saveToLocalCache();
    }
  }

  void _handleStatusUpdate(dynamic data) {
    // Trigger a refresh when status changes
    if (mounted) _loadOffers();
  }

  Future<void> _saveToLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_offers);
    await prefs.setString(_cacheKey, json);
  }

  Future<List<Map<String, dynamic>>?> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;
      final list = (jsonDecode(cached) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return list.isNotEmpty ? list : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadOffers() async {
    try {
      final queryParam = widget.shipmentId != null
          ? 'shipmentId=${widget.shipmentId}'
          : 'orderId=${widget.orderId}';

      final response = await sl<Dio>().get(
        '${EndPoint.baseUrl}${EndPoint.getOffers}?$queryParam',
      );
      final list = response.data['data'] as List<dynamic>? ?? [];

      if (mounted) {
        if (list.isNotEmpty) {
          setState(() {
            _offers
              ..clear()
              ..addAll(list.map((e) => Map<String, dynamic>.from(e)));
            _isLoading = false;
          });
          _saveToLocalCache();
        } else if (_offers.isEmpty) {
          final cached = await _loadFromLocalCache();
          if (cached != null && mounted) {
            setState(() {
              _offers
                ..clear()
                ..addAll(cached);
              _isLoading = false;
            });
          } else if (mounted) {
            setState(() => _isLoading = false);
          }
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (_) {
      if (_offers.isEmpty && mounted) {
        final cached = await _loadFromLocalCache();
        if (cached != null && mounted) {
          setState(() {
            _offers
              ..clear()
              ..addAll(cached);
          });
        }
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptOffer(String offerId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      await sl<Dio>().post(
        '${EndPoint.baseUrl}${EndPoint.acceptOffer}',
        data: {'messageId': offerId},
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم قبول عرض السعر بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadOffers();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل قبول العرض'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectOffer(String offerId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      await sl<Dio>().post(
        '${EndPoint.baseUrl}${EndPoint.rejectOffer}',
        data: {'messageId': offerId},
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض العرض. سيتم إعادة مراجعة الطلب من الإدارة'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      await _loadOffers();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفض العرض'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCounterOfferDialog(String offerId) {
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'اقتراح سعر جديد',
                  style: GoogleFonts.cairo(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'سيصل اقتراحك مباشرةً للإدارة مع إشعار فوري',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                ),
                SizedBox(height: 20.h),

                // Price field
                Text(
                  'السعر المقترح',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 6.h),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  style: GoogleFonts.cairo(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.grey.shade300),
                    suffixText: 'ج.م',
                    suffixStyle: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: AppColors.primary.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 14.h,
                      horizontal: 16.w,
                    ),
                  ),
                ),
                SizedBox(height: 14.h),

                // Note field
                Text(
                  'ملاحظة للإدارة (اختياري)',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 6.h),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  style: TextStyle(fontSize: 13.sp),
                  decoration: InputDecoration(
                    hintText: 'مثال: السعر المناسب بسبب...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12.sp,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 12.h,
                      horizontal: 16.w,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final priceVal = double.tryParse(priceCtrl.text.trim());
                      if (priceVal == null || priceVal <= 0) return;
                      Navigator.pop(ctx);
                      await _submitCounterOffer(
                        offerId,
                        priceVal,
                        noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
                    },
                    child: Text(
                      'إرسال العرض للإدارة',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _safeText(String? text) {
    if (text == null || text.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if (codeUnit >= 0xD800 && codeUnit <= 0xDFFF) {
        if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF && i + 1 < text.length) {
          final next = text.codeUnitAt(i + 1);
          if (next >= 0xDC00 && next <= 0xDFFF) {
            buffer.writeCharCode(codeUnit);
            buffer.writeCharCode(next);
            i++;
            continue;
          }
        }
        buffer.writeCharCode(0xFFFD);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  Future<void> _submitCounterOffer(
    String offerId,
    double price,
    String? note,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);

      final url = '${EndPoint.baseUrl}negotiation/counter-offer';
      final body = <String, dynamic>{
        'messageId': offerId,
        if (widget.shipmentId != null) 'shipmentId': widget.shipmentId,
        if (widget.orderId != null) 'orderId': widget.orderId,
        'price': price,
        if (note != null) 'note': note,
      };

      final response = await sl<Dio>().post(url, data: body);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال عرضك للإدارة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadOffers();
    } catch (e) {
      Navigator.pop(context);

      if (e is DioException) {}
      String errorMsg = 'فشل إرسال العرض';
      if (e is DioException && e.response?.data is Map) {
        errorMsg = e.response?.data['message'] ?? errorMsg;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'عروض الأسعار',
              style: GoogleFonts.cairo(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '${widget.shipmentId != null ? "شحنة" : "طلب"} #${widget.number}',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadOffers,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _offers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                  itemCount: _offers.length,
                  itemBuilder: (ctx, i) => _buildOfferCard(
                    _offers[i],
                    isLast: i == _offers.length - 1,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 64.sp,
                color: Colors.grey.shade300,
              ),
              SizedBox(height: 16.h),
              Text(
                'لا توجد عروض أسعار بعد',
                style: GoogleFonts.cairo(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'سيظهر هنا عرض سعر التوصيل من الإدارة',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer, {bool isLast = false}) {
    final status = offer['offerStatus']?.toString() ?? 'pending';
    final price = offer['offerPrice'];
    final note = offer['note']?.toString();
    final senderRole = offer['senderRole']?.toString() ?? '';
    final createdAt = offer['createdAt']?.toString() ?? '';
    final offerId = offer['id']?.toString() ?? '';
    final isFromAdmin = senderRole == 'admin' || senderRole == 'employee';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusLabel = 'مقبول';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'مرفوض';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'بانتظار ردك';
        statusIcon = Icons.hourglass_top_rounded;
    }

    String formattedDate = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      formattedDate =
          '${dt.day}/${dt.month} — ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        Column(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: isFromAdmin
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFromAdmin
                      ? AppColors.primary.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isFromAdmin
                    ? Icons.admin_panel_settings_rounded
                    : Icons.storefront_rounded,
                size: 16.sp,
                color: isFromAdmin ? AppColors.primary : Colors.orange,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 50.h, color: Colors.grey.shade200),
          ],
        ),
        SizedBox(width: 12.w),

        // Card
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: isFromAdmin
                        ? AppColors.primary.withOpacity(0.04)
                        : Colors.orange.withOpacity(0.04),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isFromAdmin ? 'الإدارة' : 'أنت',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: isFromAdmin
                              ? AppColors.primary
                              : Colors.orange,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 10.sp, color: statusColor),
                            SizedBox(width: 4.w),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 9.sp, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تم اقتراح سعر توصيل جديد',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$price ج.م',
                        style: GoogleFonts.cairo(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),

                      if (note != null && note.isNotEmpty) ...[
                        SizedBox(height: 10.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.notes_rounded,
                                size: 14.sp,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  _safeText(note),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey.shade700,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Action buttons — only on pending offers from admin
                      if (status == 'pending' && isFromAdmin) ...[
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  elevation: 0,
                                ),
                                onPressed: () => _acceptOffer(offerId),
                                child: Text(
                                  'موافقة',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.primary.withOpacity(0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                ),
                                onPressed: () =>
                                    _showCounterOfferDialog(offerId),
                                child: Text(
                                  'تعديل السعر',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                ),
                                onPressed: () => _rejectOffer(offerId),
                                child: Text(
                                  'رفض',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
