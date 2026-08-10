// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';
import 'package:admin_bnwasal/core/di/injection_container.dart' as di;
import 'package:admin_bnwasal/core/api/dio_consumer.dart';
import 'package:admin_bnwasal/features/settings/data/settings_api.dart';
import 'package:admin_bnwasal/core/api/end_point.dart';
import 'package:admin_bnwasal/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:admin_bnwasal/core/utils/translation_helper.dart';
import 'package:admin_bnwasal/core/services/notification_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import 'offer_negotiation_screen.dart';
import 'captain_dispatcher_screen.dart';

class ShipmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> shipment;

  const ShipmentDetailScreen({super.key, required this.shipment});

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  late Map<String, dynamic> _shipment;
  bool _isRefreshing = false;
  bool _isClaiming = false;

  static const List<String> _allStatuses = [
    'Pending Review',
    'Ready For Assignment',
    'Assigned To Captain',
    'Picked Up',
    'In Transit',
    'Delivered',
    'Completed',
  ];

  int _getStatusIndex(String status) {
    if (status == 'Captain Arrived') {
      return _allStatuses.indexOf('Assigned To Captain');
    }
    return _allStatuses.indexOf(status);
  }

  String _getArabicStatus(String status) {
    status = status.trim();
    switch (status) {
      case 'Pending Review':
        return 'قيد المراجعة';
      case 'Ready For Assignment':
        return 'بانتظار تعيين مندوب';
      case 'Assigned To Captain':
      case 'Captain Arrived':
        return 'تم تعيين مندوب';
      case 'Picked Up':
        return 'تم استلام الشحنة من التاجر';
      case 'In Transit':
        return 'جاري توصيل الشحنة';
      case 'Delivered':
        return 'تم التوصيل';
      case 'Completed':
        return 'مكتمل';
      case 'Cancelled':
        return 'ملغاة';
      case 'Rejected':
        return 'مرفوض';
      default:
        return TranslationHelper.getArabicStatus(status);
    }
  }

  @override
  void initState() {
    super.initState();
    _shipment = widget.shipment;
    _connectSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _disconnectSocket();
    super.dispose();
  }

  void _connectSocket() {
    final ns = NotificationService();
    ns.joinRoom('shipment_${_shipment['id']}');
    final socket = ns.socket;
    if (socket != null) {
      socket.on('statusUpdate', _handleSocketEvent);
      socket.on('captain_response', _handleSocketEvent);
      socket.on('payment_received', _handleSocketEvent);
      socket.on('payment_submitted', _handleSocketEvent);
    }
  }

  void _disconnectSocket() {
    final ns = NotificationService();
    ns.leaveRoom('shipment_${_shipment['id']}');
    final socket = ns.socket;
    if (socket != null) {
      socket.off('statusUpdate', _handleSocketEvent);
      socket.off('captain_response', _handleSocketEvent);
      socket.off('payment_received', _handleSocketEvent);
      socket.off('payment_submitted', _handleSocketEvent);
    }
  }

  void _handleSocketEvent(dynamic data) {
    if (mounted) {
      _refreshData();
    }
  }

  List<Map<String, dynamic>> _activityLogs = [];

  Future<void> _fetchLogs() async {
    try {
      final dio = di.sl<DioConsumer>();
      final response = await dio.get('${EndPoint.createShipment}/${_shipment['id']}/logs');
      if (response != null && response['status'] == 1 && response['data'] != null) {
        if (mounted) {
          setState(() {
            _activityLogs = List<Map<String, dynamic>>.from(response['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching shipment logs: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      final dio = di.sl<DioConsumer>();
      final response = await dio.get(
        '${EndPoint.createShipment}/${_shipment['id']}',
      );
      if (response != null &&
          response['status'] == 1 &&
          response['data'] != null) {
        if (mounted) {
          setState(() {
            _shipment = Map<String, dynamic>.from(response['data']);
          });
        }
      }
      await _fetchLogs();
    } catch (e) {
      debugPrint('Error refreshing shipment details: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    status = status.trim();
    switch (status) {
      case 'Pending Review':
      case 'pending':
        return AppColors.warning;
      case 'Ready For Assignment':
      case 'Assigned To Captain':
      case 'Captain Arrived':
      case 'Picked Up':
      case 'In Transit':
      case 'ongoing':
      case 'in_progress':
        return AppColors.info;
      case 'Delivered':
      case 'Completed':
      case 'completed':
        return AppColors.success;
      case 'Cancelled':
      case 'cancelled':
      case 'Rejected':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.secondary;
    }
  }

  IconData _getStatusIcon(String status) {
    status = status.trim();
    switch (status) {
      case 'Pending Review':
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'Ready For Assignment':
        return Icons.person_add_rounded;
      case 'Assigned To Captain':
        return Icons.sports_motorsports_rounded;
      case 'Captain Arrived':
        return Icons.hail_rounded;
      case 'Picked Up':
        return Icons.inventory_2_rounded;
      case 'In Transit':
      case 'ongoing':
      case 'in_progress':
        return Icons.local_shipping_rounded;
      case 'Delivered':
        return Icons.check_circle_outline_rounded;
      case 'Completed':
      case 'completed':
        return Icons.task_alt_rounded;
      case 'Cancelled':
      case 'cancelled':
      case 'Rejected':
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildApprovalStatusBadge(String? status) {
    status = status?.toLowerCase();
    if (status == 'pending') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 14.sp,
              color: AppColors.warning,
            ),
            SizedBox(width: 6.w),
            Text(
              'بانتظار قبول الكابتن',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'accepted') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 14.sp,
              color: AppColors.success,
            ),
            SizedBox(width: 6.w),
            Text(
              'تم قبول التكليف',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Text(
          'غير محدد',
          style: TextStyle(
            fontSize: 11.sp,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF041930) : Colors.white,
      appBar: _buildAppBar(context),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: isWide
              ? _buildWideLayout(context)
              : _buildMobileLayout(context),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      children: [
        _buildHeader(context),
        SizedBox(height: 20.h),
        _buildRouteTimeline(context),
        SizedBox(height: 16.h),
        _buildPricingAndWeightCard(context),
        SizedBox(height: 16.h),
        _buildMerchantInfoCard(context),
        if (_shipment['driverName'] != null) ...[
          SizedBox(height: 16.h),
          _buildCaptainInfoCard(context),
        ],
        SizedBox(height: 16.h),
        _buildPaymentSection(context),
        _buildReceiptImageCard(context),
        SizedBox(height: 16.h),
        _buildPremiumSection(
          context,
          'تفاصيل إضافية',
          Icons.description_rounded,
          [
            _detailRow(
              context,
              'ملاحظات الشحنة',
              _shipment['notes'] ?? 'لا يوجد',
            ),
          ],
        ),
        SizedBox(height: 16.h),
        _buildPremiumSection(
          context,
          'معلومات النظام',
          Icons.settings_rounded,
          [
            _detailRow(
              context,
              'تاريخ الإنشاء',
              _shipment['createdAt'] != null
                  ? _fmtDate(_shipment['createdAt'].toString())
                  : '',
            ),
          ],
        ),
        _buildActionCard(context),
        _buildStatusControl(context),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Primary descriptive information & timeline
        Expanded(
          flex: 3,
          child: ListView(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
            children: [
              _buildHeader(context),
              SizedBox(height: 20.h),
              _buildRouteTimeline(context),
              SizedBox(height: 16.h),
              _buildPremiumSection(
                context,
                'تفاصيل إضافية',
                Icons.description_rounded,
                [
                  _detailRow(
                    context,
                    'ملاحظات الشحنة',
                    _shipment['notes'] ?? 'لا يوجد',
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              _buildPremiumSection(
                context,
                'معلومات النظام',
                Icons.settings_rounded,
                [
                  _detailRow(
                    context,
                    'تاريخ الإنشاء',
                    _shipment['createdAt'] != null
                        ? _fmtDate(_shipment['createdAt'].toString())
                        : '',
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              _buildStatusControl(context),
            ],
          ),
        ),
        // Vertical Divider
        Container(
          width: 1.w,
          color: Colors.black.withOpacity(0.05),
          margin: EdgeInsets.symmetric(vertical: 16.h),
        ),
        // Right Column: pricing, direct payments, captains, status controls
        Expanded(
          flex: 2,
          child: ListView(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
            children: [
              _buildPricingAndWeightCard(context),
              SizedBox(height: 16.h),
              _buildMerchantInfoCard(context),
              SizedBox(height: 16.h),
              _buildPaymentSection(context),
              _buildReceiptImageCard(context),
              if (_shipment['driverName'] != null) ...[
                SizedBox(height: 16.h),
                _buildCaptainInfoCard(context),
              ],
              _buildActionCard(context),
            ],
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF041930) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: isDark ? Colors.white : Colors.black,
          size: 18.sp,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'تفاصيل الشحنة',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      centerTitle: true,
      actions: [
        if (_isRefreshing)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              width: 18.w,
              height: 18.w,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          )
        else
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 22.sp,
            ),
            onPressed: _refreshData,
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final status = (_shipment['status'] ?? '').toString();
    final number = (_shipment['shipmentNumber'] ?? '').toString();
    final title = (_shipment['title'] ?? '').toString();
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? Color(0xFF041930) : Colors.white,
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Shipment number and title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? 'اسم الشحنة' : 'رقم الشحنة',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.white.withOpacity(0.4)
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title.isNotEmpty ? title : '#$number',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 14.sp,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: number));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'تم نسخ رقم الشحنة',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                width: 180,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              // Status Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black12 : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? statusColor.withOpacity(0.2)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16.sp, color: statusColor),
                    SizedBox(width: 6.w),
                    Text(
                      _getArabicStatus(status),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              'رقم الشحنة: #$number',
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? Colors.white.withOpacity(0.35) : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          SizedBox(height: 16.h),
          Divider(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[300],
            height: 1,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.userNinja,
                size: 16.sp,
                color: isDark ? Colors.white.withOpacity(0.4) : Colors.black,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  _shipment['assignedAdminName'] != null
                      ? 'الموظف المسؤول: ${_shipment['assignedAdminName']}'
                      : 'الموظف المسؤول: غير مستلم ⚠️',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: _shipment['assignedAdminName'] != null
                        ? isDark
                              ? Colors.white
                              : AppColors.primary
                        : isDark
                        ? Colors.white.withOpacity(0.4)
                        : AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildClaimButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline(BuildContext context) {
    final fromAddress = (_shipment['fromAddress'] ?? '').toString();
    final fromGov = (_shipment['fromGovernorate'] ?? '').toString();
    final fromArea = (_shipment['fromArea'] ?? '').toString();

    final toAddress = (_shipment['toAddress'] ?? '').toString();
    final toGov = (_shipment['toGovernorate'] ?? '').toString();
    final toArea = (_shipment['toArea'] ?? '').toString();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
        ),
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.route,
                size: 18.sp,
                color: AppColors.secondary,
              ),
              SizedBox(width: 8.w),
              Text(
                'مسار الشحنة',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white.withOpacity(0.7) : Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual timeline line
              Column(
                children: [
                  Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.secondary, width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 75.h,
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[300],
                  ),
                  Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 2.w),
              // Addresses text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pickup "From"
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نقطة الاستلام (من)',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.white.withOpacity(0.35)
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          fromAddress.isNotEmpty ? fromAddress : 'غير محدد',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: isDark
                                ? Colors.white.withOpacity(0.85)
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (fromGov.isNotEmpty || fromArea.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            [
                              fromGov,
                              fromArea,
                            ].where((s) => s.isNotEmpty).join(' - '),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 25.h),
                    // Delivery "To"
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نقطة التوصيل (إلى)',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? Colors.white.withOpacity(0.35)
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          toAddress.isNotEmpty ? toAddress : 'غير محدد',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: isDark
                                ? Colors.white.withOpacity(0.85)
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (toGov.isNotEmpty || toArea.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            [
                              toGov,
                              toArea,
                            ].where((s) => s.isNotEmpty).join(' - '),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.black,
                            ),
                          ),
                        ],
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

  Widget _buildPricingAndWeightCard(BuildContext context) {
    final shipmentPrice =
        double.tryParse((_shipment['price'] ?? '0').toString()) ?? 0.0;
    final weight = _shipment['weight'] != null && _shipment['weight'] != 0
        ? '${_shipment['weight']} كجم'
        : 'غير محدد';
    final estTime = _shipment['estimatedTime']?.toString() ?? 'غير محدد';

    // Captain's share = 80%, platform share = 20%
    final platformShare = shipmentPrice * 0.20;
    final captainShare = shipmentPrice * 0.80;
    final bool pricingComputed =
        (_shipment['platformShare'] != null ||
        _shipment['captainShare'] != null);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
        ),
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.moneyBill1Wave,
                size: 18.sp,
                color: AppColors.success,
              ),
              SizedBox(width: 8.w),
              Text(
                'التكلفة والمواصفات',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white.withOpacity(0.7) : Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _specItem(
                  icon: Icons.payments_rounded,
                  label: 'سعر التاجر',
                  value: '${shipmentPrice.toStringAsFixed(2)} ج.م',
                  color: AppColors.secondary,
                ),
              ),
              Expanded(
                child: _specItem(
                  icon: Icons.scale_rounded,
                  label: 'الوزن المقدر',
                  value: weight,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _specItem(
                  icon: Icons.schedule_rounded,
                  label: 'الوقت المقدر',
                  value: estTime,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Discount section
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.grey[300]!,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'خصم المنصة (20%)',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white.withOpacity(0.4)
                            : Colors.black,
                      ),
                    ),
                    Text(
                      '- ${platformShare.toStringAsFixed(2)} ج.م',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'السعر النهائي للكابتن',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      '${captainShare.toStringAsFixed(2)} ج.م',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!pricingComputed) ...[
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                  Icons.calculate_rounded,
                  size: 16.sp,
                  color: isDark ? Colors.white : Colors.black,
                ),
                label: Text(
                  'حساب التسعير وإرسال إشعار',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _computeShipmentPricing(context),
              ),
            ),
          ],
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'حالة الدفع',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white.withOpacity(0.4) : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: (_shipment['isPaid'] == true)
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_shipment['isPaid'] == true)
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    child: Text(
                      (_shipment['isPaid'] == true)
                          ? 'تم الدفع'
                          : 'لم يتم الدفع',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: (_shipment['isPaid'] == true)
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                  if (_shipment['isPaid'] != true &&
                      _shipment['status'] != 'Pending Review' &&
                      _shipment['status'] != 'Cancelled') ...[
                    SizedBox(width: 8.w),
                    TextButton.icon(
                      icon: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14.sp,
                        color: AppColors.success,
                      ),
                      label: Text(
                        'تأكيد الشحنة',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        backgroundColor: AppColors.success.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final currentStatus = _shipment['status']?.toString() ?? '';
                        final hasCaptain = _shipment['captainId'] != null;
                        final String nextStatus;
                        if (currentStatus == 'Pending Review') {
                          nextStatus = hasCaptain
                              ? 'Assigned To Captain'
                              : 'Ready For Assignment';
                        } else {
                          nextStatus = currentStatus;
                        }
                        _confirmStatusChange(context, nextStatus, isPaid: true);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, size: 16.sp, color: AppColors.success),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'السعر النهائي الذي يستلمه الكابتن بعد خصم 20% هو ${captainShare.toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
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

  Future<void> _computeShipmentPricing(BuildContext context) async {
    try {
      final dio = di.sl<DioConsumer>();
      final response = await dio.post(
        EndPoint.computeShipmentPricing(_shipment['id'].toString()),
      );
      if (response != null && response['status'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حساب التسعير وإرسال الإشعار بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        _refreshData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حساب التسعير: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _specItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18.sp, color: color),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isDark ? Colors.white.withOpacity(0.4) : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCaptainInfoCard(BuildContext context) {
    final name = _shipment['driverName']?.toString() ?? '';
    final phone = _shipment['driverPhone']?.toString() ?? '';
    final avgRating =
        double.tryParse(_shipment['driverAvgRating']?.toString() ?? '0') ?? 0.0;
    final reviewCount =
        int.tryParse(_shipment['driverReviewCount']?.toString() ?? '0') ?? 0;
    final approvalStatus = _shipment['captainApprovalStatus']?.toString();
    final avatarUrl = _shipment['driverAvatar']?.toString();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
        ),
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.user,
                size: 18.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Text(
                'بيانات الكابتن',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white.withOpacity(0.7) : Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (avatarUrl != null && avatarUrl.isNotEmpty)
            Center(
              child: Container(
                width: 64.w,
                height: 64.w,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  avatarUrl.startsWith('http')
                      ? avatarUrl
                      : '${EndPoint.imageBaseUrl}$avatarUrl',
                  fit: BoxFit.cover,
                  width: 64.w,
                  height: 64.w,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF004aad), Color(0xFFF78710)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24.sp,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (avatarUrl != null && avatarUrl.isNotEmpty) SizedBox(height: 16.h),
          _detailRow(context, 'الاسم', name),
          if (phone.isNotEmpty)
            _detailRow(context, 'رقم الهاتف', phone, copyable: true),
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              children: [
                SizedBox(
                  width: 100.w,
                  child: Text(
                    'التقييم',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isDark
                          ? Colors.white.withOpacity(0.35)
                          : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 16.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '($reviewCount تقييم)',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark
                              ? Colors.white.withOpacity(0.5)
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 100.w,
                child: Text(
                  'حالة التكليف',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark
                        ? Colors.white.withOpacity(0.35)
                        : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildApprovalStatusBadge(approvalStatus),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantInfoCard(BuildContext context) {
    final clientName = _shipment['clientName']?.toString() ?? '';
    final merchantPhone = _shipment['clientPhone']?.toString() ?? '';
    final merchantEmail = _shipment['merchantEmail']?.toString() ?? '';
    final merchantCity = _shipment['merchantCity']?.toString() ?? '';
    final merchantStatus = _shipment['merchantStatus']?.toString() ?? '';
    final merchantCreatedAt = _shipment['merchantCreatedAt']?.toString() ?? '';
    final merchantFirstName = _shipment['merchantFirstName']?.toString() ?? '';
    final merchantLastName = _shipment['merchantLastName']?.toString() ?? '';

    final fullName =
        (merchantFirstName.isNotEmpty || merchantLastName.isNotEmpty)
        ? '$merchantFirstName $merchantLastName'.trim()
        : '';

    String arabicStatus = '';
    Color statusColor = Colors.white;
    switch (merchantStatus.toLowerCase()) {
      case 'active':
        arabicStatus = 'نشط';
        statusColor = AppColors.success;
        break;
      case 'banned':
        arabicStatus = 'محظور';
        statusColor = AppColors.error;
        break;
      case 'pending_verification':
        arabicStatus = 'بانتظار التحقق';
        statusColor = AppColors.warning;
        break;
      case 'pending_otp':
        arabicStatus = 'بانتظار كود التحقق';
        statusColor = AppColors.warning;
        break;
      default:
        arabicStatus = merchantStatus;
        statusColor = Colors.white;
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
        ),
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.store,
                size: 18.sp,
                color: AppColors.secondary,
              ),
              SizedBox(width: 8.w),
              Text(
                'بيانات التاجر / العميل',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (clientName.isNotEmpty)
            _detailRow(context, 'اسم المتجر', clientName, copyable: true),
          if (fullName.isNotEmpty)
            _detailRow(context, 'اسم المالك', fullName, copyable: true),
          if (merchantPhone.isNotEmpty)
            _detailRow(context, 'رقم الهاتف', merchantPhone, copyable: true),
          if (merchantEmail.isNotEmpty)
            _detailRow(
              context,
              'البريد الإلكتروني',
              merchantEmail,
              copyable: true,
            ),
          if (merchantCity.isNotEmpty)
            _detailRow(context, 'المدينة', merchantCity),
          if (merchantStatus.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100.w,
                    child: Text(
                      'حالة الحساب',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.white.withOpacity(0.35)
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      arabicStatus,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (merchantCreatedAt.isNotEmpty)
            _detailRow(context, 'تاريخ التسجيل', _fmtDate(merchantCreatedAt)),
        ],
      ),
    );
  }

  Widget _buildPremiumSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    final activeChildren = children
        .where(
          (child) =>
              child is! SizedBox || (child.width != 0.0 && child.height != 0.0),
        )
        .toList();
    if (activeChildren.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
        ),
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18.sp, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...activeChildren,
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool copyable = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (value.toString().trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? Colors.white.withOpacity(0.35) : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? Colors.white.withOpacity(0.85) : Colors.black,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          if (copyable) ...[
            SizedBox(width: 8.w),
            IconButton(
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.copy_rounded,
                size: 14.sp,
                color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم نسخ $label',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    width: 200,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(String date) {
    if (date.length >= 19) {
      return '${date.substring(0, 10)} ${date.substring(11, 19)}';
    }
    return date;
  }

  Widget _buildActionCard(BuildContext context) {
    final status = (_shipment['status'] ?? '').toString();
    final id = _shipment['id'].toString();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (status == 'Pending Review') {
      return Container(
        margin: EdgeInsets.only(top: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF041930) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إجراءات المراجعة للشحنة الجديدة',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white.withOpacity(0.7) : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              icon: Icon(
                Icons.check_circle_outline_rounded,
                size: 16.sp,
                color: Colors.white,
              ),
              label: Text(
                'موافقة وتنشيط الشحنة',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _approveDirectly(context, id),
            ),
          ],
        ),
      );
    } else if (status == 'Ready For Assignment') {
      return Container(
        margin: EdgeInsets.only(top: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF041930) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: Icon(
                Icons.person_add_rounded,
                size: 16.sp,
                color: Colors.white,
              ),
              label: Text(
                'توجيه وتعيين كابتن للمهمة',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _openDispatcher(context),
            ),
          ],
        ),
      );
    } else if (status == 'Assigned To Captain' || status == 'Captain Arrived') {
      return Container(
        margin: EdgeInsets.only(top: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF041930) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.motorcycle,
                  size: 16.sp,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8.w),
                Text(
                  'الكابتن: ${_shipment['driverName'] ?? 'غير معروف'}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            if (status == 'Assigned To Captain')
              ElevatedButton.icon(
                icon: FaIcon(
                  FontAwesomeIcons.checkCircle,
                  size: 16.sp,
                  color: Colors.white,
                ),
                label: Text(
                  'تأكيد وصول الكابتن',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    _confirmStatusChange(context, 'Captain Arrived'),
              ),
            if (status == 'Captain Arrived')
              ElevatedButton.icon(
                icon: Icon(
                  Icons.inventory_2_rounded,
                  size: 16.sp,
                  color: Colors.white,
                ),
                label: Text(
                  'تأكيد استلام الشحنة',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _confirmStatusChange(context, 'Picked Up'),
              ),
          ],
        ),
      );
    } else if (status == 'Picked Up' || status == 'In Transit') {
      return Container(
        margin: EdgeInsets.only(top: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF041930) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status == 'Picked Up')
              ElevatedButton.icon(
                icon: FaIcon(
                  FontAwesomeIcons.truckFast,
                  size: 16.sp,
                  color: Colors.white,
                ),
                label: Text(
                  'تأكيد الشروع في التوصيل',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _confirmStatusChange(context, 'In Transit'),
              ),
            ElevatedButton.icon(
              icon: FaIcon(
                FontAwesomeIcons.truckFast,
                size: 16.sp,
                color: Colors.white,
              ),
              label: Text(
                'تأكيد التوصيل',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _confirmStatusChange(context, 'Delivered'),
            ),
          ],
        ),
      );
    } else if (status == 'Delivered') {
      return Container(
        margin: EdgeInsets.only(top: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF041930) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
          ),
        ),
        child: ElevatedButton.icon(
          icon: FaIcon(
            FontAwesomeIcons.checkCircle,
            size: 16.sp,
            color: Colors.white,
          ),
          label: Text(
            'تأكيد الإكمال',
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _confirmStatusChange(context, 'Completed'),
        ),
      );
    } else if (status == 'Completed') {
      return Container(
        margin: EdgeInsets.only(top: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 20.sp,
            ),
            SizedBox(width: 12.w),
            Text(
              'الشحنة مكتملة ✓',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (status == 'Cancelled') {
      return Container(
        margin: EdgeInsets.only(top: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.error, size: 20.sp),
            SizedBox(width: 12.w),
            Text(
              'الشحنة ملغاة',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusControl(BuildContext context) {
    final currentStatus = (_shipment['status'] ?? '').toString();
    final currentIdx = _getStatusIndex(currentStatus);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF041930) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.retweet,
                size: 18.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Text(
                'التحكم في الحالة',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white.withOpacity(0.7) : Colors.black,
                ),
              ),
              const Spacer(),
              Text(
                'الحالية: ${_getArabicStatus(currentStatus)}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...List.generate(_allStatuses.length, (i) {
                final status = _allStatuses[i];
                final isCurrent = status == currentStatus;
                final isPast = currentIdx >= 0 && i < currentIdx;
                final isAvailable = !isCurrent;

                return GestureDetector(
                  onTap: isAvailable
                      ? () => _confirmStatusChange(context, status)
                      : null,
                  child: MouseRegion(
                    cursor: isAvailable
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primary.withOpacity(0.2)
                            : isPast
                            ? AppColors.success.withOpacity(0.1)
                            : isDark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primary
                              : isPast
                              ? AppColors.success.withOpacity(0.3)
                              : isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.grey.shade300,
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCurrent
                                ? Icons.circle_rounded
                                : isPast
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 14,
                            color: isCurrent
                                ? AppColors.primary
                                : isPast
                                ? AppColors.success
                                : isDark
                                ? Colors.white.withOpacity(0.3)
                                : Colors.black,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getArabicStatus(status),
                            style: TextStyle(
                              fontSize: 11,
                              color: isCurrent
                                  ? Colors.black
                                  : isPast
                                  ? AppColors.success
                                  : isDark
                                  ? Colors.white.withOpacity(0.4)
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: currentStatus != 'Cancelled'
                    ? () => _confirmStatusChange(context, 'Cancelled')
                    : null,
                child: MouseRegion(
                  cursor: currentStatus != 'Cancelled'
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: currentStatus == 'Cancelled'
                          ? AppColors.error.withOpacity(0.2)
                          : AppColors.error.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentStatus == 'Cancelled'
                            ? AppColors.error
                            : AppColors.error.withOpacity(0.2),
                        width: currentStatus == 'Cancelled' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cancel_rounded,
                          size: 14,
                          color: currentStatus == 'Cancelled'
                              ? AppColors.error
                              : AppColors.error.withOpacity(0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ملغي',
                          style: TextStyle(
                            fontSize: 11,
                            color: currentStatus == 'Cancelled'
                                ? AppColors.error
                                : AppColors.error.withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  Future<void> _confirmStatusChange(
    BuildContext context,
    String newStatus, {
    bool? isPaid,
  }) async {
    final currentStatus = (_shipment['status'] ?? '').toString();
    if (currentStatus == newStatus && isPaid == null) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF041930) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.truckFast,
              color: AppColors.secondary,
              size: 20,
            ),
            SizedBox(width: 8.w),
            Text(
              newStatus == 'Cancelled' ? 'تأكيد الإلغاء' : 'تغيير الحالة',
              style: GoogleFonts.tajawal(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          isPaid == true
              ? 'هل أنت متأكد من تأكيد استلام الدفع وتحديث حالة الشحنة إلى "${_getArabicStatus(newStatus)}"؟'
              : 'هل أنت متأكد من تغيير حالة الشحنة من "${_getArabicStatus(currentStatus)}" إلى "${_getArabicStatus(newStatus)}"?',
          style: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.7) : Colors.black,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'Cancelled'
                  ? AppColors.error
                  : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _changeStatus(newStatus, isPaid: isPaid);
    }
  }

  Future<void> _changeStatus(String newStatus, {bool? isPaid}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.cyan)),
    );

    try {
      final dio = di.sl<DioConsumer>();
      final id = _shipment['id'].toString();
      final Map<String, dynamic> data = {'status': newStatus};
      if (isPaid != null) {
        data['isPaid'] = isPaid;
      }
      await dio.put(EndPoint.updateShipmentStatus(id), data: data);

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تغيير الحالة إلى "${_getArabicStatus(newStatus)}" بنجاح',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      di.sl<DashboardCubit>().loadDashboard();
      _refreshData();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تغيير الحالة: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _approveDirectly(BuildContext context, String id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.cyan)),
    );

    try {
      final settingsApi = di.sl<SettingsApi>();
      final settings = await settingsApi.getSettings();
      final nextStatus = 'Ready For Assignment';

      final dio = di.sl<DioConsumer>();
      await dio.put(
        '${EndPoint.createShipment}/$id/status',
        data: {'status': nextStatus},
      );

      Navigator.pop(context); // Pop Loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول الشحنة وتحديث الحالة بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );

      di.sl<DashboardCubit>().loadDashboard();
      _refreshData();
    } catch (e) {
      Navigator.pop(context); // Pop Loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إتمام العملية: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _cleanReceiptUrl(String? filename) {
    if (filename == null || filename.isEmpty) return '';
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    final baseUrl = EndPoint.imageBaseUrl.endsWith('/')
        ? EndPoint.imageBaseUrl.substring(0, EndPoint.imageBaseUrl.length - 1)
        : EndPoint.imageBaseUrl;
    if (filename.contains('uploads/')) {
      final cleanPath = filename.startsWith('/') ? filename : '/$filename';
      return '$baseUrl$cleanPath';
    }
    return '$baseUrl/uploads/receipts/$filename';
  }

  Future<void> _reviewPayment(
    String paymentId,
    String action, {
    String? note,
  }) async {
    try {
      final dio = di.sl<DioConsumer>();
      final response = await dio.put(
        EndPoint.directPaymentReview(paymentId),
        data: {'action': action, 'adminNote': note ?? ''},
      );
      if (response != null && response['status'] == 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                action == 'approve'
                    ? '✅ تم قبول الدفع بنجاح'
                    : '❌ تم رفض الدفع',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: action == 'approve'
                  ? AppColors.success
                  : AppColors.error,
            ),
          );
          di.sl<DashboardCubit>().loadDashboard();
          _refreshData();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response?['message']?.toString() ?? 'فشل العملية'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildPaymentSection(BuildContext context) {
    final hasDirectPayment = _shipment['directPayment'] != null;
    final isPaid = _shipment['isPaid'] == true;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (!hasDirectPayment && !isPaid) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF041930) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.payment_rounded, color: AppColors.error, size: 20.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رسوم التوصيل: تم التأكيد',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'تم تأكيد رسوم التوصيل وجاري تعيين المندوب.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark
                          ? Colors.white.withOpacity(0.4)
                          : Colors.grey[600]!,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!hasDirectPayment && isPaid) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF041930) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 22.sp,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تم الدفع عن طريق المحفظة',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'تم خصم رسوم التوصيل من محفظة التاجر تلقائياً وتفعيل الطلب.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark
                          ? Colors.white.withOpacity(0.4)
                          : Colors.grey[600]!,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final dp = _shipment['directPayment'] as Map<String, dynamic>;
    final dpStatus = dp['status']?.toString() ?? 'pending';
    final dpMethod = dp['paymentMethod']?.toString() ?? '—';
    final fromName = dp['fromName']?.toString() ?? '—';
    final fromPhone = dp['fromPhone']?.toString() ?? '—';
    final adminNote = dp['adminNote']?.toString();
    final paymentId = dp['id']?.toString() ?? '';

    Color statusColor = AppColors.warning;
    String statusText = 'قيد المراجعة';
    if (dpStatus == 'approved') {
      statusColor = AppColors.success;
      statusText = 'مقبول / تم السداد';
    } else if (dpStatus == 'rejected') {
      statusColor = AppColors.error;
      statusText = 'مرفوض';
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF041930) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[300]!,
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
                  FaIcon(
                    FontAwesomeIcons.receipt,
                    color: statusColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'تفاصيل السداد المباشر',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _detailRow(context, 'وسيلة الدفع', dpMethod),
          _detailRow(context, 'اسم المُرسل', fromName),
          _detailRow(context, 'رقم المحول منه', fromPhone, copyable: true),
          if (adminNote != null && adminNote.isNotEmpty)
            _detailRow(context, 'ملاحظة الإدارة', adminNote),
          if (dpStatus == 'pending') ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _reviewPayment(paymentId, 'approve'),
                    child: Text(
                      'قبول الدفع',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final noteController = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF151532),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            'رفض إيصال الدفع',
                            style: GoogleFonts.tajawal(
                              color: Colors.red,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: TextField(
                            controller: noteController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'سبب الرفض (مثال: الإيصال غير واضح)',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.black.withOpacity(0.5),
                              ),
                              fillColor: Colors.transparent,
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.black.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.black.withOpacity(0.5),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                final note = noteController.text.trim();
                                Navigator.pop(context);
                                _reviewPayment(paymentId, 'reject', note: note);
                              },
                              child: const Text(
                                'تأكيد الرفض',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      'رفض الدفع',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
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

  void _openNegotiationChat(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => OfferNegotiationScreen(
              shipmentId: _shipment['id'].toString(),
              number: _shipment['shipmentNumber'].toString(),
              title: _shipment['title'] ?? '',
              price:
                  double.tryParse(_shipment['price']?.toString() ?? '0') ?? 0,
            ),
          ),
        )
        .then((_) => _refreshData());
  }

  void _openDispatcher(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CaptainDispatcherScreen(
              shipmentId: _shipment['id'].toString(),
              fromCity:
                  _shipment['fromArea'] ?? _shipment['fromGovernorate'] ?? '',
              toCity: _shipment['toArea'] ?? _shipment['toGovernorate'] ?? '',
            ),
          ),
        )
        .then((_) => _refreshData());
  }

  Widget _buildReceiptImageCard(BuildContext context) {
    final hasDirectPayment = _shipment['directPayment'] != null;
    if (!hasDirectPayment) return const SizedBox.shrink();

    final dp = _shipment['directPayment'] as Map<String, dynamic>;
    final receiptImage = dp['receiptImage']?.toString() ?? '';
    if (receiptImage.isEmpty) return const SizedBox.shrink();

    final dpStatus = dp['status']?.toString() ?? 'pending';
    Color statusColor = AppColors.warning;
    if (dpStatus == 'approved') {
      statusColor = AppColors.success;
    } else if (dpStatus == 'rejected') {
      statusColor = AppColors.error;
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white : Colors.grey.shade300),
        color: isDark ? const Color(0xFF041930) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.fileInvoice,
                size: 18.sp,
                color: statusColor,
              ),
              SizedBox(width: 8.w),
              Text(
                'إيصال الدفع المرفق',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      InteractiveViewer(
                        child: Image.network(
                          _cleanReceiptUrl(receiptImage),
                          fit: BoxFit.contain,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 280.h,

                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.35) : Colors.white,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      _cleanReceiptUrl(receiptImage),
                      height: 280.h,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150.h,
                        color: Colors.white.withOpacity(0.05),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_rounded,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12.h,
                      right: 12.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 14.sp,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'تكبير الصورة',
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: Colors.white,
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
            ),
          ),
          SizedBox(height: 8.h),
          Center(
            child: Text(
              'انقر على صورة الإيصال لتكبيرها واستعراضها بالكامل',
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? Colors.white.withOpacity(0.4) : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimButton() {
    final user = context.read<AuthCubit>().state.user;
    final role = user?['role']?.toString();
    if (role != 'admin' && role != 'employee') {
      return const SizedBox.shrink();
    }

    final currentUserId = user?['id']?.toString();
    final assignedId = _shipment['assignedAdminId']?.toString();
    final isClaimedByMe = assignedId != null && assignedId == currentUserId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (isClaimedByMe) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF041930) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 12.sp, color: AppColors.primary),
            SizedBox(width: 4.w),
            Text(
              'مسؤوليتك',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final hasAssignee = _shipment['assignedAdminName'] != null;

    return ElevatedButton(
      onPressed: _isClaiming ? null : _claimShipment,
      style: ElevatedButton.styleFrom(
        backgroundColor: hasAssignee
            ? Colors.white.withOpacity(0.08)
            : AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: hasAssignee
              ? BorderSide(color: Colors.white.withOpacity(0.15))
              : BorderSide.none,
        ),
      ),
      child: _isClaiming
          ? SizedBox(
              width: 12.w,
              height: 12.w,
              child: const CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            )
          : Text(
              hasAssignee ? 'استلم بديل' : 'استلام الشحنة',
              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
            ),
    );
  }

  Future<void> _claimShipment() async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);
    try {
      final dio = di.sl<DioConsumer>();
      final response = await dio.post(
        EndPoint.claimShipment(_shipment['id'].toString()),
      );
      if (response != null && response['status'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'تم استلام الشحنة بنجاح لمتابعتها',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refreshData();
        context.read<DashboardCubit>().loadDashboard();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل استلام الشحنة: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isClaiming = false);
    }
  }
}
