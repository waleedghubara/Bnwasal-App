// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/features/shipment/presentation/manager/shipment_cubit.dart';
import 'package:we_deliver/features/shipment/presentation/pages/add_shipment_screen.dart';
import 'package:we_deliver/features/shipment/presentation/widgets/shipment_card.dart';
import '../../domain/entities/shipment.dart';
import 'driver_shipments_screen.dart';

class ShipmentsScreen extends StatefulWidget {
  final bool isDelivery;
  const ShipmentsScreen({super.key, this.isDelivery = false});

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen>
    with TickerProviderStateMixin {
  final ShipmentCubit _cubit = sl<ShipmentCubit>();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimController;
  late Animation<double> _fabScaleAnim;
  late Animation<double> _optionsFadeAnim;

  final List<String> _filters = ShipmentStatus.userFilters;

  String _filterLabel(String filter) {
    if (filter == ShipmentStatus.all) return 'الكل';
    return ShipmentStatus.getArabicStatus(filter);
  }

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabScaleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeOut),
    );
    _optionsFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeOut),
    );
    _cubit.addListener(_onCubitChange);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _cubit.updateSearch(_searchController.text.trim());
  }

  void _onCubitChange() {
    if (mounted) setState(() {});
    if (_cubit.showAddOptions) {
      _fabAnimController.forward();
    } else {
      _fabAnimController.reverse();
    }
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _cubit.removeListener(_onCubitChange);
    _cubit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDelivery) {
      return const DriverShipmentsScreen();
    }
    final shipments = _cubit.filteredShipments.where((s) => s.status != 'Negotiation' && s.status != 'negotiation').toList();

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_cubit.showAddOptions) _cubit.closeAddOptions();
        },
        child: Column(
          children: [
            // ── Header section (white card) ──
            Container(
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Title row
                    const SizedBox(height: 12),
                    const Text(
                      'الشحنات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Search bar row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Search field
                          Expanded(
                            child: CustomTextField(
                              hintText: 'بحث...',
                              height: 48,
                              rightWidget: Padding(
                                padding: EdgeInsetsDirectional.all(4),
                                child: Icon(
                                  Icons.search,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                              ),
                              controller: _searchController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Filter button
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Filter chips
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filters.length,
                        separatorBuilder: (_, i) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final isSelected = _cubit.selectedFilter == filter;
                          return GestureDetector(
                            onTap: () => _cubit.selectFilter(filter),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                _filterLabel(filter),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Body: list or empty state ──
            Expanded(
              child: _cubit.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _cubit.errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _cubit.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () => _cubit.loadShipments(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                  child: const Text(
                                    'إعادة المحاولة',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _cubit.loadShipments(),
                          color: AppColors.primary,
                          child: shipments.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 100),
                                    _buildEmptyState(),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: shipments.length,
                                  itemBuilder: (context, index) {
                                    return ShipmentCard(shipment: shipments[index]);
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),

      // ── FAB with options ──
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(AppAssets.boxn, width: 90, height: 90),
          const SizedBox(height: 20),
          const Text(
            'لم يتم العثور علي شحنات',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر طلباتك هنا! اذا كنت تستخدم فلتر\n حاول اعادة ظبطه',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Option cards (animated)
        FadeTransition(
          opacity: _optionsFadeAnim,
          child: ScaleTransition(
            scale: _fabScaleAnim,
            alignment: Alignment.bottomRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildOptionCard(
                  label: 'شحنة واحدة',
                  onTap: () {
                    _cubit.closeAddOptions();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddShipmentScreen(cubit: _cubit),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildOptionCard(
                  label: 'اكثر من شحنة',
                  onTap: () {
                    _cubit.closeAddOptions();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddShipmentScreen(
                          cubit: _cubit,
                          isMultiShipment: true,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Main FAB
        GestureDetector(
          onTap: _cubit.toggleAddOptions,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: _cubit.showAddOptions ? 0.125 : 0,
              duration: const Duration(milliseconds: 250),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
