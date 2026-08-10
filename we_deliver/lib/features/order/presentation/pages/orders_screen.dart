// ignore_for_file: deprecated_member_use

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import '../../../../core/theme/typography.dart';
import '../manager/order_cubit.dart';
import '../../domain/entities/order.dart';
import 'add_order_screen.dart';
import 'order_details_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/api/end_point.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderCubit _cubit = sl<OrderCubit>();
  final _searchController = TextEditingController();
  io.Socket? _socket;
  final List<String> _filters = [
    'الكل',
    OrderStatus.pending,
    OrderStatus.awaitingPayment,
    OrderStatus.readyForAssignment,
    OrderStatus.assignedToCaptain,
    // Captain Arrived مخفي من الـ UI - يُعامل كـ Assigned To Captain
    OrderStatus.pickedUp,
    OrderStatus.inTransit,
    OrderStatus.delivered,
    OrderStatus.completed,
    OrderStatus.cancelled,
  ];

  String _filterLabel(String filter) {
    if (filter == 'الكل') return 'الكل';
    return OrderStatus.getArabicStatus(filter);
  }

  @override
  void initState() {
    super.initState();
    _cubit.addListener(_onCubitChange);
    _initSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cubit.loadOrders();
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
      debugPrint('🔌 Orders Screen Socket Connected');
    });

    _socket!.on('notification', (data) {
      debugPrint('🔔 Notification received on Orders Screen: $data');
      if (mounted) {
        _cubit.loadOrders();
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 Orders Screen Socket Disconnected');
    });
  }

  void _onCubitChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _searchController.dispose();
    _cubit.removeListener(_onCubitChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _cubit.filteredOrders.where((o) => o.status != 'Negotiation' && o.status != 'negotiation').toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'طلباتي',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(130),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: CustomTextField(
                    controller: _searchController,
                    hintText: 'ابحث برقم الطلب، العنوان، أو الهاتف...',
                    height: 50,
                    onChanged: (v) => _cubit.setSearchQuery(v),
                    rightWidget: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.search, color: Colors.grey, size: 20),
                    ),
                  ),
                ),
                _buildFilterChips(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        body: _cubit.isLoading && orders.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _cubit.errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'حدث خطأ: ${_cubit.errorMessage}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _cubit.loadOrders(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => _cubit.loadOrders(),
                color: AppColors.primary,
                child: orders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          return FadeInUp(
                            duration: Duration(
                              milliseconds: 300 + (index * 100),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildOrderCard(orders[index]),
                            ),
                          );
                        },
                      ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddOrderScreen(cubit: _cubit),
              ),
            );
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final isSelected = _cubit.selectedFilter == _filters[index];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(
                _filterLabel(_filters[index]),
                style: AppTypography.h6,
              ),
              selected: isSelected,
              onSelected: (_) => _cubit.selectFilter(_filters[index]),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              pressElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey.shade200,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderEntity order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          order.status,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        OrderStatus.getArabicStatus(order.status),
                        style: TextStyle(
                          color: _getStatusColor(order.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '#${order.orderNumber}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  order.details,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.store_rounded, order.storeDescription),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on_rounded, order.deliveryAddress),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone_rounded, order.phone),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFBFB),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إجمالي الطلب',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    Text(
                      '${(order.orderPrice + order.deliveryFee).toInt()} ج.م',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailsScreen(order: order),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'عرض التفاصيل',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        return Colors.deepPurple;
      case OrderStatus.awaitingPayment:
        return Colors.amber.shade700;
      case OrderStatus.readyForAssignment:
      case OrderStatus.assignedToCaptain:
        return Colors.blue;
      case OrderStatus.captainArrived:
      case OrderStatus.pickedUp:
        return Colors.teal;
      case OrderStatus.inTransit:
        return Colors.purple;
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

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: SvgPicture.asset(
                  AppAssets.orders,
                  width: 120,
                  height: 120,
                ),
              ),
              const SizedBox(height: 24),
              FadeInUp(
                child: Column(
                  children: [
                    const Text(
                      'لا توجد نتائج مطابقة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'جرب البحث بكلمات أخرى أو تغيير الفلتر',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
