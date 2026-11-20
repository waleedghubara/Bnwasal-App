import 'package:geolocator/geolocator.dart';
import '../../../../core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../merchant/data/models/merchant_models.dart';
import '../manager/stores_cubit.dart';
import '../manager/stores_state.dart';
import '../../data/models/store_models.dart';
import 'store_checkout_screen.dart';
import 'product_details_screen.dart';
import 'client_store_orders_screen.dart';
import 'stores_screen.dart';

class StoreDetailsScreen extends StatefulWidget {
  final int storeId;
  final String storeName;
  final StoreModel? initialStore;

  const StoreDetailsScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    this.initialStore,
  });

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  late StoresCubit _storesCubit;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _storesCubit = sl<StoresCubit>()..selectStore(widget.storeId);
    _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    try {
      final locService = sl<LocationService>();
      if (locService.lastKnownAccuratePosition != null) {
        if (mounted) setState(() => _userPosition = locService.lastKnownAccuratePosition);
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          setState(() => _userPosition = last);
        }
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 4),
          ),
        );
        if (mounted) {
          setState(() => _userPosition = current);
        }
      }
    } catch (_) {}
  }

  String? _getDistanceString(StoreModel store) {
    if (_userPosition == null || store.latitude == null || store.longitude == null) {
      return null;
    }
    final meters = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      store.latitude!,
      store.longitude!,
    );
    final km = meters / 1000.0;
    if (km < 1.0) {
      return '${meters.round()} م';
    }
    return '${km.toStringAsFixed(1)} كم';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openProductDialog(MerchantProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _storesCubit,
          child: ProductDetailsScreen(product: product),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _storesCubit,
      child: BlocBuilder<StoresCubit, StoresState>(
        builder: (context, state) {
          final cubit = context.read<StoresCubit>();
          final store = cubit.selectedStore ?? widget.initialStore;
          final categories = cubit.categories;
          final products = cubit.displayedProducts;
          final isLoading =
              state is StoresMainLoading ||
              (state is StoresMainLoaded && state.isProductsLoading);

          return Scaffold(
            backgroundColor: const Color(0xFFF7F8FA),
            appBar: store == null
                ? AppBar(
                    title: Text(
                      widget.storeName,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    centerTitle: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black87,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  )
                : null,
            bottomNavigationBar: cubit.cart.isNotEmpty
                ? _buildFloatingCartBar(context, cubit, store)
                : null,
            body: isLoading && store == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : state is StoresError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 54,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () =>
                                _storesCubit.selectStore(widget.storeId),
                            child: Text(
                              'إعادة المحاولة',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildStoreContent(
                    context,
                    cubit,
                    store,
                    categories,
                    products,
                    isLoading,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCoverHeader(
    BuildContext context,
    StoresCubit cubit,
    StoreModel store,
    List<MerchantCategoryModel> categories,
    List<MerchantProductModel> products,
  ) {
    final coverUrl = store.fullCoverImage;
    final profileUrl = store.fullProfileImage;

    return SliverToBoxAdapter(
      child: Column(
        children: [
          // 1. Cover Image with Overlay Actions
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover Image Container
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  image: coverUrl != null && coverUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(coverUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: coverUrl == null || coverUrl.isEmpty
                    ? Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF5200), Color(0xFFFF7A00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : null,
              ),

              // Gradient Overlay for button contrast
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Top Action Buttons (Circular white buttons matching screenshot)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Circular Back Button (Right in RTL)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      // Left Action Buttons (Search, Share, Orders, Cart)
                      Row(
                        children: [
                          // Search Button
                          GestureDetector(
                            onTap: () {
                              _searchFocusNode.requestFocus();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.search_rounded,
                                size: 21,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          // Orders History Button
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ClientStoreOrdersScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 20,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          // Cart Button
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: cubit,
                                    child: const StoreCartScreen(),
                                  ),
                                ),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 21,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (cubit.cartTotalItems > 0)
                                  Positioned(
                                    top: -2,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3.5),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF5200),
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Text(
                                        '${cubit.cartTotalItems}',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.cairo(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Overlapping Store Information Card (Matching Screenshot)
          Transform.translate(
            offset: const Offset(0, -32),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Store Logo on right + Store Name & Delivery Subtitle on left
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store Logo in rounded container (appears on the right in RTL)
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: profileUrl != null && profileUrl.isNotEmpty
                              ? Image.network(
                                  profileUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.storefront_rounded,
                                    color: AppColors.primary,
                                    size: 36,
                                  ),
                                )
                              : const Icon(
                                  Icons.storefront_rounded,
                                  color: AppColors.primary,
                                  size: 36,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Name & Subtitle (appears on the left in RTL)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.storeName,
                              style: GoogleFonts.cairo(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1E293B),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              store.category.isNotEmpty
                                  ? store.category
                                  : (store.city != null && store.city!.isNotEmpty ? store.city! : 'متجر'),
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Row 2: Real Badges (Rating • Delivery Time • Prep Time)
                  Builder(
                    builder: (context) {
                      final List<Widget> badgeItems = [];

                      // Real Rating from DB
                      if (store.rating != null && store.rating! > 0) {
                        badgeItems.add(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFB800),
                                size: 19,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                store.ratingCount > 0
                                    ? '${store.rating!.toStringAsFixed(1)} (${store.ratingCount})'
                                    : store.rating!.toStringAsFixed(1),
                                style: GoogleFonts.cairo(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Real Delivery Time from DB
                      if (store.deliveryTime != null && store.deliveryTime!.trim().isNotEmpty) {
                        badgeItems.add(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.two_wheeler_rounded,
                                color: Color(0xFFFF5722),
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                store.deliveryTime!,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Real Prep Time from DB
                      if (store.preparationTime != null && store.preparationTime!.trim().isNotEmpty) {
                        badgeItems.add(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Color(0xFFE67E22),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'تحضير ${store.preparationTime!}',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (badgeItems.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (int i = 0; i < badgeItems.length; i++) ...[
                                if (i > 0)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    child: Text('•', style: TextStyle(color: Colors.black26, fontSize: 14)),
                                  ),
                                badgeItems[i],
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // Row 3: Real Distance (or Address) & Open status
                  Builder(
                    builder: (context) {
                      final distStr = _getDistanceString(store);
                      return Row(
                        children: [
                          if (distStr != null) ...[
                            const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFD32F2F),
                              size: 16,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'المسافة: $distStr',
                              style: GoogleFonts.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ] else if (store.city != null && store.city!.trim().isNotEmpty) ...[
                            const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFD32F2F),
                              size: 16,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              store.city!,
                              style: GoogleFonts.cairo(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: store.isCurrentlyOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              store.isCurrentlyOpen ? 'مفتوح الآن' : 'مغلق',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  if (!store.isCurrentlyOpen) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'المتجر مغلق حالياً • مواعيد العمل: ${store.openingHours}',
                              style: GoogleFonts.cairo(
                                color: const Color(0xFFDC2626),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (store.storeDescription.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F3F5)),
                    const SizedBox(height: 8),
                    Text(
                      store.storeDescription,
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],

                  if (store.storeAddress.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            store.storeAddress,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreContent(
    BuildContext context,
    StoresCubit cubit,
    StoreModel? store,
    List<MerchantCategoryModel> categories,
    List<MerchantProductModel> products,
    bool isProductsLoading,
  ) {
    final selectedCatId = cubit.selectedCategoryId;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => cubit.selectStore(widget.storeId),
      child: CustomScrollView(
        slivers: [
          // 1. Cover Banner & Overlapping Store Information Card (مطابق تماماً للتصميم)
          if (store != null)
            _buildCoverHeader(context, cubit, store, categories, products),

          // 2. Search inside Store Products
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECEF)),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (val) => cubit.searchProducts(val.trim()),
                  onChanged: (val) {
                    if (val.isEmpty) cubit.searchProducts('');
                  },
                  style: GoogleFonts.cairo(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'ابحث في قائمة طعام ومنتجات المتجر...',
                    hintStyle: GoogleFonts.cairo(
                      color: Colors.black38,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 16,
                              color: Colors.black54,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              cubit.searchProducts('');
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Categories Horizontal Filter Pills (أقسام المتجر بفونت Cairo)
          if (categories.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                height: 44,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = selectedCatId == null;
                      return ChoiceChip(
                        label: Text(
                          'الكل',
                          style: GoogleFonts.cairo(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFDFE3E8),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) => cubit.selectCategory(null),
                      );
                    }

                    final cat = categories[index - 1];
                    final isSelected = selectedCatId == cat.id;

                    return ChoiceChip(
                      label: Text(
                        cat.name,
                        style: GoogleFonts.cairo(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFDFE3E8),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onSelected: (_) => cubit.selectCategory(cat.id),
                    );
                  },
                ),
              ),
            ),

          // 4. Products Section Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    'قائمة الأصناف (${products.length})',
                    style: GoogleFonts.cairo(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Products 2-Column Grid
          isProductsLoading
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
              : products.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'لا توجد منتجات متاحة حالياً',
                        style: GoogleFonts.cairo(
                          color: Colors.black45,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = products[index];
                      return _ProductListCard(
                        product: product,
                        onTap: product.isAvailable
                            ? () => _openProductDialog(product)
                            : null,
                      );
                    }, childCount: products.length),
                  ),
                ),

          // Extra spacing at bottom for floating cart
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildFloatingCartBar(
    BuildContext context,
    StoresCubit cubit,
    StoreModel? store,
  ) {
    final total = cubit.cartTotal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cubit.cartTotalItems} عنصر في السلة',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(0)} ج.م',
                  style: GoogleFonts.cairo(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                if (store != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: cubit,
                        child: StoreCheckoutScreen(store: store),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.shopping_cart_checkout_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                'إتمام الطلب',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Product List Card (مطابق للتصميم الأفقي المعروض)
class _ProductListCard extends StatelessWidget {
  final MerchantProductModel product;
  final VoidCallback? onTap;

  const _ProductListCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        product.discountPrice != null && product.discountPrice! > 0;
    final finalPrice = hasDiscount ? product.discountPrice! : product.price;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F1F4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Product Image with Heart Icon on right
            _buildProductImage(context),

            const SizedBox(width: 12),

            // 2. Product Information on left
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name (up to 2 lines)
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),

                  // Product Description if present
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],

                  // Preparation Time (وقت التحضير) - only if actually provided in database
                  if (product.preparationTime != null && product.preparationTime!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'وقت التحضير ${product.preparationTime!}',
                          style: GoogleFonts.cairo(
                            fontSize: 11.5,
                            color: Colors.black45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Price and Add Button Row
                  Row(
                    children: [
                      // Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            finalPrice.toStringAsFixed(2),
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'جنية',
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 8),
                            Text(
                              product.price.toStringAsFixed(2),
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const Spacer(),

                      // Circular Orange Add Button (+)
                      GestureDetector(
                        onTap: onTap,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: product.isAvailable
                                ? const Color(0xFFFF5200)
                                : Colors.black26,
                            shape: BoxShape.circle,
                            boxShadow: product.isAvailable
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF5200)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 22,
                          ),
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
    );
  }

  Widget _buildProductImage(BuildContext context) {
    final imgUrl = formatImageUrl(product.image);

    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imgUrl != null && imgUrl.isNotEmpty
                  ? Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),

          // Favorite / Heart Icon Button at top-right
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 16,
                color: Colors.black45,
              ),
            ),
          ),

          // Discount Badge
          if (product.discountPrice != null && product.discountPrice! > 0)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'خصم',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Unavailable Overlay
          if (!product.isAvailable)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'غير متاح',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF1F3F5),
      child: const Center(
        child: Icon(Icons.fastfood_rounded, size: 32, color: Colors.black26),
      ),
    );
  }
}

// Product Customization Modal Sheet
class _ProductCustomizationSheet extends StatefulWidget {
  final MerchantProductModel product;

  const _ProductCustomizationSheet({required this.product});

  @override
  State<_ProductCustomizationSheet> createState() =>
      _ProductCustomizationSheetState();
}

class _ProductCustomizationSheetState
    extends State<_ProductCustomizationSheet> {
  ProductSizeOption? _selectedSize;
  final List<ProductAddonOption> _selectedAddons = [];
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.product.sizes.isNotEmpty) {
      _selectedSize = widget.product.sizes.first;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _basePrice =>
      (widget.product.discountPrice != null &&
          widget.product.discountPrice! > 0)
      ? widget.product.discountPrice!
      : widget.product.price;

  double get _totalPrice {
    double price = _basePrice;
    if (_selectedSize != null) {
      price += _selectedSize!.extraPrice;
    }
    for (final addon in _selectedAddons) {
      price += addon.price;
    }
    return price * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final hasSizes = widget.product.sizes.isNotEmpty;
    final hasAddons = widget.product.addons.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    if (formatImageUrl(widget.product.image) != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          formatImageUrl(widget.product.image)!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name,
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.product.description.isNotEmpty)
                            Text(
                              widget.product.description,
                              style: GoogleFonts.cairo(
                                fontSize: 12.5,
                                color: Colors.black54,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '${_basePrice.toStringAsFixed(0)} ج.م',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F3F5)),

              // Sizes
              if (hasSizes) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Text(
                    'اختر الحجم',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...widget.product.sizes.map((size) {
                  return RadioListTile<String>(
                    value: size.name,
                    groupValue: _selectedSize?.name,
                    activeColor: AppColors.primary,
                    onChanged: (_) => setState(() => _selectedSize = size),
                    title: Text(
                      size.name,
                      style: GoogleFonts.cairo(fontSize: 14),
                    ),
                    secondary: size.extraPrice > 0
                        ? Text(
                            '+${size.extraPrice.toStringAsFixed(0)} ج.م',
                            style: GoogleFonts.cairo(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          )
                        : null,
                  );
                }),
                const Divider(height: 1, color: Color(0xFFF1F3F5)),
              ],

              // Addons
              if (hasAddons) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Text(
                    'إضافات اختيارية',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...widget.product.addons.map((addon) {
                  final isChecked = _selectedAddons.any(
                    (a) => a.name == addon.name,
                  );
                  return CheckboxListTile(
                    value: isChecked,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedAddons.add(addon);
                        } else {
                          _selectedAddons.removeWhere(
                            (a) => a.name == addon.name,
                          );
                        }
                      });
                    },
                    title: Text(
                      addon.name,
                      style: GoogleFonts.cairo(fontSize: 14),
                    ),
                    secondary: Text(
                      '+${addon.price.toStringAsFixed(0)} ج.م',
                      style: GoogleFonts.cairo(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
                const Divider(height: 1, color: Color(0xFFF1F3F5)),
              ],

              // Notes
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Text(
                  'ملاحظات خاصة (اختياري)',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _notesController,
                  style: GoogleFonts.cairo(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'مثال: بدون بصل، صوص زيادة...',
                    hintStyle: GoogleFonts.cairo(
                      color: Colors.black38,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8ECEF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8ECEF)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quantity & Add to Cart
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                          ),
                          Text(
                            '$_quantity',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final item = StoreCartItem(
                            product: widget.product,
                            selectedSize: _selectedSize,
                            selectedAddons: List.from(_selectedAddons),
                            quantity: _quantity,
                            notes: _notesController.text.trim().isNotEmpty
                                ? _notesController.text.trim()
                                : null,
                          );

                          context.read<StoresCubit>().addToCart(item);
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تمت إضافة ${widget.product.name} إلى السلة',
                                style: GoogleFonts.cairo(),
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.black87,
                            ),
                          );
                        },
                        child: Text(
                          'إضافة للسلة • ${_totalPrice.toStringAsFixed(0)} ج.م',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
  }
}
