import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:we_deliver/core/theme/colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../merchant/data/models/merchant_models.dart';
import '../manager/stores_cubit.dart';
import '../manager/stores_state.dart';
import '../../data/models/store_models.dart';
import 'store_checkout_screen.dart';
import 'store_details_screen.dart';
import 'product_details_screen.dart';
import 'client_store_orders_screen.dart';
import 'main_categories_screen.dart';
import '../../../../core/services/auth_guard.dart';

class StoresScreen extends StatefulWidget {
  final int? initialStoreId;

  const StoresScreen({super.key, this.initialStoreId});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  late StoresCubit _storesCubit;
  static bool _hasShownStorePromoPopup = false;
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _storesCubit = sl<StoresCubit>();
    _storesCubit.initStoresFeed().then((_) {
      if (widget.initialStoreId != null) {
        _storesCubit.selectStore(widget.initialStoreId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  void _openCartPage(BuildContext context, StoresCubit cubit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BlocProvider.value(value: cubit, child: const StoreCartScreen()),
      ),
    );
  }

  void _openFavoritesPage(BuildContext context, StoresCubit cubit) {
    AuthGuard.requireAuth(
      context,
      reason: 'يرجى تسجيل الدخول لعرض قائمة المنتجات المفضلة لديك',
      onAuthenticated: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: StoreFavoritesScreen(
                onProductTap: (prod) => _openProductDialog(prod),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAllStoresPage(
    BuildContext context,
    StoresCubit cubit, {
    String? initialCategory,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: AllStoresScreen(initialFilter: initialCategory),
        ),
      ),
    );
  }

  void _openMainCategoriesPage(BuildContext context, StoresCubit cubit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const MainCategoriesScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocProvider.value(
        value: _storesCubit,
        child: BlocConsumer<StoresCubit, StoresState>(
          listener: (context, state) {
            if (state is StoresMainLoaded && !_hasShownStorePromoPopup) {
              StoreBannerModel? popupBanner;
              for (final b in state.banners) {
                if (b.showPopup) {
                  popupBanner = b;
                  break;
                }
              }
              if (popupBanner != null) {
                final banner = popupBanner;
                _hasShownStorePromoPopup = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    showStorePromotionalDialog(
                      context,
                      banner,
                      onExplore: () {
                        if (banner.merchantId != null) {
                          _storesCubit.selectStore(banner.merchantId);
                        }
                      },
                    );
                  }
                });
              }
            }
          },
          builder: (context, state) {
            final cubit = context.read<StoresCubit>();

            return Scaffold(
              backgroundColor: const Color(0xFFF8F9FA),
              bottomNavigationBar: cubit.cart.isNotEmpty
                  ? _buildFloatingCartBar(context, cubit)
                  : null,
              body: state is StoresMainLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF5B00),
                      ),
                    )
                  : state is StoresError
                  ? _buildErrorView(state.message)
                  : _buildBody(
                      context,
                      cubit,
                      state is StoresMainLoaded ? state : null,
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 54, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5B00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _storesCubit.initStoresFeed(),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(
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
    );
  }

  Widget _buildBody(
    BuildContext context,
    StoresCubit cubit,
    StoresMainLoaded? state,
  ) {
    final stores = cubit.stores;
    final banners = cubit.banners;
    final popularProducts = cubit.popularProducts.isNotEmpty
        ? cubit.popularProducts
        : cubit.allProducts.take(8).toList();
    final isSearching = _searchController.text.trim().isNotEmpty;
    final searchResults = cubit.displayedProducts;

    return RefreshIndicator(
      color: const Color(0xFFFF5B00),
      onRefresh: () async => cubit.initStoresFeed(),
      child: CustomScrollView(
        slivers: [
          // 1. Curved Orange Header
          SliverToBoxAdapter(
            child: _buildCurvedOrangeHeader(context, cubit),
          ),

          // Search Results Mode
          if (isSearching) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'نتائج البحث عن "${_searchController.text.trim()}"',
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        cubit.searchProducts('');
                        setState(() {});
                      },
                      child: Text(
                        'إلغاء البحث',
                        style: GoogleFonts.cairo(
                          color: const Color(0xFFFF5B00),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (searchResults.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'لا توجد وجبات أو منتجات مطابقة لبحثك',
                      style: GoogleFonts.cairo(
                        color: Colors.black45,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.74,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = searchResults[index];
                    return _PopularProductCard(
                      product: product,
                      isFavorite: cubit.isProductFavorite(product.id),
                      onFavoriteTap: () {
                        AuthGuard.requireAuth(
                          context,
                          reason: 'يرجى تسجيل الدخول لإضافة هذا المنتج إلى المفضلة',
                          onAuthenticated: () => cubit.toggleFavorite(product),
                        );
                      },
                      onTap: product.isAvailable
                          ? () => _openProductDialog(product)
                          : null,
                      onAddTap: product.isAvailable
                          ? () {
                              if (product.sizes.isNotEmpty ||
                                  product.addons.isNotEmpty) {
                                _openProductDialog(product);
                              } else {
                                cubit.addToCart(
                                  StoreCartItem(product: product),
                                );
                                _showItemAddedSnackBar(context, product.name);
                              }
                            }
                          : null,
                    );
                  }, childCount: searchResults.length),
                ),
              ),
          ] else ...[
            // 2. Food Categories Bar (شريط الأقسام تحت السيرش وفوق البنرات)
            SliverToBoxAdapter(
              child: _buildFoodCategoriesSection(context, cubit),
            ),

            // 3. Advertising Banners Carousel
            if (banners.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: _StoreAdBannersSlider(
                    banners: banners,
                    onBannerTap: (banner) {
                      if (banner.merchantId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoreDetailsScreen(
                              storeId: banner.merchantId!,
                              storeName: banner.storeName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),

            // 3. "الأقسام والمتاجر" (Registered Backend Stores Grid)
            SliverToBoxAdapter(
              child: _buildRegisteredStoresGridSection(context, cubit, stores),
            ),

            // 4. "الأكثر طلباً" Section (Horizontal Scroll matching Screenshot 2)
            if (popularProducts.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildMostPopularSection(
                  context,
                  cubit,
                  popularProducts,
                ),
              ),
          ],

          // Bottom Spacing
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showItemAddedSnackBar(BuildContext context, String productName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تمت إضافة $productName إلى السلة',
          style: GoogleFonts.cairo(),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.black87,
      ),
    );
  }

  Widget _buildCurvedOrangeHeader(BuildContext context, StoresCubit cubit) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF5200), Color(0xFFFF6F00)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            children: [
              // Top Action Row (RTL: Favorites on Right, Cart on Left)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Favorites Button (Heart)
                  GestureDetector(
                    onTap: () => _openFavoritesPage(context, cubit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cubit.favoriteProducts.isNotEmpty
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            cubit.favoriteProducts.isNotEmpty
                                ? 'المفضلة (${cubit.favoriteProducts.length})'
                                : 'المفضلة',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Stores Activity Orders (طلبات المتاجر)
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'طلباتي',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Cart Bag Icon with Badge
                  GestureDetector(
                    onTap: () => _openCartPage(context, cubit),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'السلة',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (cubit.cartTotalItems > 0)
                          Positioned(
                            top: -4,
                            left: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                '${cubit.cartTotalItems}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  color: const Color(0xFFFF5200),
                                  fontSize: 10.5,
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

              const SizedBox(height: 16),

              // Circular White Search Bar (Full Width)
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (val) {
                      cubit.searchProducts(val.trim());
                      setState(() {});
                    },
                    onChanged: (val) {
                      cubit.searchProducts(val.trim());
                      setState(() {});
                    },
                    style: GoogleFonts.cairo(fontSize: 13.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'ابحث عن وجبات خفيفة أو مطعمك المفضل',
                      hintStyle: GoogleFonts.cairo(
                        color: const Color(0xFF9E9E9E),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFFFF5B00),
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: Colors.black54,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                cubit.searchProducts('');
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
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

  // 2. Main Activity Categories Bar (شريط الأقسام الرئيسية تحت السيرش)
  Widget _buildFoodCategoriesSection(BuildContext context, StoresCubit cubit) {
    final categories = cubit.mainCategories;
    if (categories.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & "عرض الكل"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الأقسام الرئيسية',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                InkWell(
                  onTap: () => _openMainCategoriesPage(context, cubit),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'عرض الكل ',
                          style: GoogleFonts.cairo(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF5B00),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Color(0xFFFF5B00),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Categories List (Dark Navy Cards matching screenshot)
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected =
                    (_selectedCategoryFilter == null &&
                        (cat.key == 'all' || cat.name == 'الكل')) ||
                    _selectedCategoryFilter == cat.name ||
                    _selectedCategoryFilter == cat.key;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedCategoryFilter == cat.name ||
                          _selectedCategoryFilter == cat.key ||
                          cat.key == 'all' ||
                          cat.name == 'الكل') {
                        _selectedCategoryFilter = null;
                      } else {
                        _selectedCategoryFilter = cat.name;
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: isSelected
                          ? BorderRadius.circular(12)
                          : BorderRadius.circular(0),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Visual/Image
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                            child: Center(child: _buildCategoryCardVisual(cat)),
                          ),
                        ),

                        // Title
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            cat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black,
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
    );
  }

  Widget _buildCategoryCardVisual(MainStoreCategoryModel cat) {
    if (cat.image.isNotEmpty) {
      final imgUrl = formatImageUrl(cat.image);
      if (imgUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(
            imgUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallbackCategoryIcon(cat.name, key: cat.key),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF5B00),
                  ),
                ),
              );
            },
          ),
        );
      }
    }
    return _buildFallbackCategoryIcon(cat.name, key: cat.key);
  }

  Widget _buildFallbackCategoryIcon(String name, {String key = ''}) {
    final k = key.toLowerCase();
    final n = name.toLowerCase();

    String emoji = '🍽️';
    if (k == 'all' || n.contains('كل')) {
      emoji = '✨';
    } else if (k == 'restaurant' || n.contains('مطاعم') || n.contains('مطعم')) {
      emoji = '🍔';
    } else if (k == 'supermarket' || n.contains('ماركت')) {
      emoji = '🛒';
    } else if (k == 'bakery' || n.contains('مخبوز')) {
      emoji = '🥐';
    } else if (k == 'roastery' || n.contains('محمص') || n.contains('عطار')) {
      emoji = '🥜';
    } else if (k == 'sweets' || n.contains('حلوي')) {
      emoji = '🍰';
    } else if (k == 'vegetables' || n.contains('فواكه') || n.contains('خضار')) {
      emoji = '🍎';
    } else if (k == 'dairy' ||
        n.contains('لبن') ||
        n.contains('جبن') ||
        n.contains('ألبان')) {
      emoji = '🧀';
    } else if (k == 'juices' ||
        n.contains('عصائر') ||
        n.contains('عصير') ||
        n.contains('كوكتيل')) {
      emoji = '🍹';
    } else if (k == 'coffee' || n.contains('قهوة') || n.contains('بن')) {
      emoji = '☕';
    } else if (k == 'online' ||
        n.contains('أونلاين') ||
        n.contains('اونلاين')) {
      emoji = '🛍️';
    } else if (k == 'pharmacy' || n.contains('صيدلي')) {
      emoji = '💊';
    } else if (k == 'clothes' || n.contains('ملابس')) {
      emoji = '👕';
    } else {
      emoji = '🏪';
    }

    return Text(emoji, style: const TextStyle(fontSize: 32));
  }

  // 3. Registered Backend Stores Grid Section (All Stores)
  Widget _buildRegisteredStoresGridSection(
    BuildContext context,
    StoresCubit cubit,
    List<StoreModel> stores,
  ) {
    if (stores.isEmpty) return const SizedBox.shrink();

    final filteredStores =
        (_selectedCategoryFilter == null ||
            _selectedCategoryFilter == 'الكل' ||
            _selectedCategoryFilter == 'all')
        ? stores
        : stores
              .where((s) => s.matchesCategory(_selectedCategoryFilter!))
              .toList();

    final displayStores = filteredStores;
    final displayItemsCount = displayStores.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & "عرض الكل"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المتاجر والمطاعم',
                style: GoogleFonts.cairo(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () => _openAllStoresPage(
                  context,
                  cubit,
                  initialCategory: _selectedCategoryFilter,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'عرض الكل ',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF5B00),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: Color(0xFFFF5B00),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_selectedCategoryFilter != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5B00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF5B00),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تصفية حسب: $_selectedCategoryFilter',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF5B00),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategoryFilter = null),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFFFF5B00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          if (displayStores.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'لا توجد متاجر في قسم "$_selectedCategoryFilter" حالياً',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تصفح باقي الأقسام أو اعرض جميع المتاجر المتوفرة',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        setState(() => _selectedCategoryFilter = null),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'عرض جميع المتاجر',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5B00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayItemsCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
              itemBuilder: (context, index) {
                final store = displayStores[index];
                return _buildStoreGridCard(
                  title: store.storeName,
                  subtitle: store.storeDescription.isNotEmpty
                      ? store.storeDescription
                      : (store.displayActivityName.isNotEmpty
                            ? store.displayActivityName
                            : 'متجر ومطعم'),
                  imageUrl: store.fullProfileImage ?? store.fullCoverImage,
                  isOpen: store.isCurrentlyOpen,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoreDetailsScreen(
                          storeId: store.id,
                          storeName: store.storeName,
                          initialStore: store,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStoreGridCard({
    required String title,
    required String subtitle,
    String? imageUrl,
    bool isOpen = true,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1E293B),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white30,
                      size: 36,
                    ),
                  ),
                )
              else
                Container(
                  color: const Color(0xFF1E293B),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white30,
                    size: 36,
                  ),
                ),

              // Gradient Overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),

              // Status Tag
              if (!isOpen)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'مغلق',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ),

              // Title & Subtitle
              Positioned(
                bottom: 8,
                right: 10,
                left: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 10.5,
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

  // 3. Most Popular Section (الأكثر طلباً - Horizontal Cards)
  Widget _buildMostPopularSection(
    BuildContext context,
    StoresCubit cubit,
    List<MerchantProductModel> popularProducts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الأكثر طلباً',
                style: GoogleFonts.cairo(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (popularProducts.length > 3)
                InkWell(
                  onTap: () => _openAllStoresPage(context, cubit),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      'المزيد',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF5B00),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Vertical List of Cards (تحت بعضها)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: popularProducts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = popularProducts[index];
              return _buildPopularProductVerticalTile(context, cubit, product);
            },
          ),
        ),
      ],
    );
  }

  // Vertical Tile for Popular Products (Stacked under each other)
  Widget _buildPopularProductVerticalTile(
    BuildContext context,
    StoresCubit cubit,
    MerchantProductModel product,
  ) {
    final finalPrice =
        (product.discountPrice != null && product.discountPrice! > 0)
        ? product.discountPrice!
        : product.price;
    final isFavorite = cubit.isProductFavorite(product.id);

    return GestureDetector(
      onTap: product.isAvailable ? () => _openProductDialog(product) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Thumbnail Image on Right (in RTL)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    formatImageUrl(product.image) != null
                        ? Image.network(
                            formatImageUrl(product.image)!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildProductThumbnailPlaceholder(),
                          )
                        : _buildProductThumbnailPlaceholder(),
                    if (!product.isAvailable)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Text(
                          'غير متوفر',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 14),

            // 2. Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Store Name & Rating
                  Row(
                    children: [
                      if (product.storeName != null &&
                          product.storeName!.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            product.storeName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFF5B00),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (product.rating > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Product Title
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),

                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: Colors.black45,
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Price Row
                  Row(
                    children: [
                      Text(
                        '${finalPrice.toStringAsFixed(0)} ج.م',
                        style: GoogleFonts.cairo(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF5B00),
                        ),
                      ),
                      if (product.discountPrice != null &&
                          product.discountPrice! > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${product.price.toStringAsFixed(0)} ج.م',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 3. Action Buttons (Favorite + Add to Cart)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Favorite Button
                GestureDetector(
                  onTap: () {
                    AuthGuard.requireAuth(
                      context,
                      reason: 'يرجى تسجيل الدخول لإضافة هذا المنتج إلى المفضلة',
                      onAuthenticated: () => cubit.toggleFavorite(product),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? Colors.redAccent : Colors.black26,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Add to Cart Button
                if (product.isAvailable)
                  GestureDetector(
                    onTap: () {
                      if (product.sizes.isNotEmpty ||
                          product.addons.isNotEmpty) {
                        _openProductDialog(product);
                      } else {
                        cubit.addToCart(StoreCartItem(product: product));
                        _showItemAddedSnackBar(context, product.name);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5B00),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_shopping_cart_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'أضف',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  Widget _buildProductThumbnailPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.fastfood_rounded, size: 28, color: Colors.black26),
      ),
    );
  }

  // Floating Cart Bar (Bottom of screen when cart has items)
  Widget _buildFloatingCartBar(BuildContext context, StoresCubit cubit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
        child: InkWell(
          onTap: () => _openCartPage(context, cubit),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5200), Color(0xFFFF6F00)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4DFF5200),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Cart Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${cubit.cartTotalItems}',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'عرض سلة المشتريات',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '${cubit.cartTotal.toStringAsFixed(0)} ج.م',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Popular Product Card
// ---------------------------------------------------------
class _PopularProductCard extends StatelessWidget {
  final MerchantProductModel product;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const _PopularProductCard({
    required this.product,
    required this.isFavorite,
    required this.onFavoriteTap,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final finalPrice =
        (product.discountPrice != null && product.discountPrice! > 0)
        ? product.discountPrice!
        : product.price;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Image + Store Badge & Favorite Icon
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: formatImageUrl(product.image) != null
                        ? Image.network(
                            formatImageUrl(product.image)!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),

                  // Rating Badge (e.g. ★ 3.0 or جديد)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            product.rating > 0
                                ? Icons.star_rounded
                                : Icons.fiber_new_rounded,
                            color: product.rating > 0
                                ? Colors.amber
                                : const Color(0xFF10B981),
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            product.rating > 0
                                ? product.rating.toStringAsFixed(1)
                                : 'جديد',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (product.ratingCount > 0) ...[
                            const SizedBox(width: 2),
                            Text(
                              '(${product.ratingCount})',
                              style: GoogleFonts.cairo(
                                color: Colors.white70,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Heart Favorite Button
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: onFavoriteTap,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFavorite ? Colors.redAccent : Colors.black45,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                  // Unavailable Overlay
                  if (!product.isAvailable)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'غير متاح',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. Product Name & Price with Orange Plus Button
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Price Bar with Orange '+' Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Text(
                          '${finalPrice.toStringAsFixed(0)} جنية',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),

                        // Orange '+' Button
                        GestureDetector(
                          onTap: onAddTap,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5B00),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x40FF5B00),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.fastfood_rounded, size: 30, color: Colors.black26),
      ),
    );
  }
}

// ---------------------------------------------------------
// Advertising Banners Slider
// ---------------------------------------------------------
class _StoreAdBannersSlider extends StatefulWidget {
  final List<StoreBannerModel> banners;
  final ValueChanged<StoreBannerModel> onBannerTap;

  const _StoreAdBannersSlider({
    required this.banners,
    required this.onBannerTap,
  });

  @override
  State<_StoreAdBannersSlider> createState() => _StoreAdBannersSliderState();
}

class _StoreAdBannersSliderState extends State<_StoreAdBannersSlider> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 175,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: GestureDetector(
                  onTap: () => widget.onBannerTap(banner),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (banner.fullImage != null &&
                              banner.fullImage!.isNotEmpty)
                            Image.network(
                              banner.fullImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(
                                  0xFFFF5B00,
                                ).withValues(alpha: 0.08),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  size: 48,
                                  color: Color(0xFFFF5B00),
                                ),
                              ),
                            )
                          else
                            Container(
                              color: const Color(
                                0xFFFF5B00,
                              ).withValues(alpha: 0.08),
                              child: const Icon(
                                Icons.storefront_rounded,
                                size: 48,
                                color: Color(0xFFFF5B00),
                              ),
                            ),

                          if (banner.storeName.isNotEmpty)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  banner.storeName,
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final isCurrent = i == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: isCurrent ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFFFF5B00)
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------
// Full Screen: StoreFavoritesScreen (صفحة المفضلات كاملة)
// ---------------------------------------------------------
class StoreFavoritesScreen extends StatelessWidget {
  final ValueChanged<MerchantProductModel> onProductTap;

  const StoreFavoritesScreen({super.key, required this.onProductTap});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'الوجبات والأطعمة المفضلة',
            style: GoogleFonts.cairo(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<StoresCubit, StoresState>(
          builder: (context, state) {
            final cubit = context.read<StoresCubit>();
            final favorites = cubit.favoriteProducts;

            if (favorites.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          size: 64,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'لا توجد أطعمة مفضلة بعد',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط على علامة القلب في أي وجبة أو طعام لإضافته إلى قائمتك المفضلة وتسهيل الوصول إليه لاحقاً.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                final product = favorites[index];
                return _PopularProductCard(
                  product: product,
                  isFavorite: true,
                  onFavoriteTap: () => cubit.toggleFavorite(product),
                  onTap: () => onProductTap(product),
                  onAddTap: () {
                    cubit.addToCart(StoreCartItem(product: product));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تمت إضافة ${product.name} إلى السلة',
                          style: GoogleFonts.cairo(),
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.black87,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Full Screen: StoreCartScreen (صفحة السلة كاملة)
// ---------------------------------------------------------
class StoreCartScreen extends StatelessWidget {
  const StoreCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'سلة المشتريات',
            style: GoogleFonts.cairo(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            BlocBuilder<StoresCubit, StoresState>(
              builder: (context, state) {
                final cubit = context.read<StoresCubit>();
                if (cubit.cart.isEmpty) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () => cubit.clearCart(),
                  child: Text(
                    'تفريغ السلة',
                    style: GoogleFonts.cairo(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<StoresCubit, StoresState>(
          builder: (context, state) {
            final cubit = context.read<StoresCubit>();
            final cart = cubit.cart;

            if (cart.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF5B00,
                          ).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Color(0xFFFF5B00),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'سلة المشتريات فارغة',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تصفح المتاجر والوجبات اللذيذة وأضف ما يعجبك إلى السلة للطلب الفوري.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5B00),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'تصفح المتاجر',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: item.fullProductImage != null
                                  ? Image.network(
                                      item.fullProductImage!,
                                      width: 65,
                                      height: 65,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.fastfood, size: 36),
                                    )
                                  : const Icon(Icons.fastfood, size: 36),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (item.selectedSize != null)
                                    Text(
                                      'الحجم: ${item.selectedSize!.name}',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  if (item.selectedAddons.isNotEmpty)
                                    Text(
                                      'الإضافات: ${item.selectedAddons.map((a) => a.name).join("، ")}',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11.5,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.totalPrice.toStringAsFixed(0)} ج.م',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFF5B00),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 22,
                                    color: Colors.black54,
                                  ),
                                  onPressed: () => cubit.updateCartItemQuantity(
                                    index,
                                    item.quantity - 1,
                                  ),
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 22,
                                    color: Color(0xFFFF5B00),
                                  ),
                                  onPressed: () => cubit.updateCartItemQuantity(
                                    index,
                                    item.quantity + 1,
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

                // Bottom Checkout Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 10,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'إجمالي الطلب:',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              '${cubit.cartTotal.toStringAsFixed(0)} ج.م',
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF5B00),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5B00),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            AuthGuard.requireAuth(
                              context,
                              reason: 'يرجى تسجيل الدخول لإتمام عملية الشراء ومتابعة الطلب',
                              onAuthenticated: () {
                                final store =
                                    cubit.selectedStore ??
                                    (cubit.stores.isNotEmpty
                                        ? cubit.stores.first
                                        : null);
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
                            );
                          },
                          child: Text(
                            'متابعة الشراء وإنهاء الطلب',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Full Screen: AllStoresScreen (صفحة جميع المتاجر والبحث كاملة)
// ---------------------------------------------------------
class AllStoresScreen extends StatefulWidget {
  final String? initialFilter;

  const AllStoresScreen({super.key, this.initialFilter});

  @override
  State<AllStoresScreen> createState() => _AllStoresScreenState();
}

class _AllStoresScreenState extends State<AllStoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'الكل';

  final List<String> _categories = [
    'الكل',
    'مطاعم',
    'ماركت / سوبر ماركت',
    'مخبوزات',
    'محمصة و عطارة',
    'حلويات',
    'فواكه وخضروات',
    'ألبان وجبن',
    'عصائر وكوكتيلات',
    'قهوة وبُن',
    'أونلاين',
    'صيدلية',
    'ملابس وأزياء',
    'محل / متجر عام',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedCategory = widget.initialFilter!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'جميع المتاجر والمطاعم',
            style: GoogleFonts.cairo(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<StoresCubit, StoresState>(
          builder: (context, state) {
            final cubit = context.read<StoresCubit>();
            var filteredStores = cubit.stores;

            // Category filter
            if (_selectedCategory != 'الكل') {
              filteredStores = filteredStores
                  .where((s) => s.matchesCategory(_selectedCategory))
                  .toList();
            }

            // Search text filter
            if (_searchQuery.isNotEmpty) {
              filteredStores = filteredStores.where((s) {
                return s.storeName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    s.storeDescription.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    s.category.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    );
              }).toList();
            }

            return Column(
              children: [
                // Top Search Bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن أي متجر أو مطعم...',
                        hintStyle: GoogleFonts.cairo(
                          color: Colors.black45,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFFFF5B00),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                ),

                // Category Filter Chips
                Container(
                  color: Colors.white,
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(
                          cat,
                          style: GoogleFonts.cairo(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFFF5B00),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      );
                    },
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Stores List
                Expanded(
                  child: filteredStores.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_off_rounded,
                                  size: 54,
                                  color: Colors.black26,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد متاجر مطابقة لبحثك',
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredStores.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final store = filteredStores[index];
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StoreDetailsScreen(
                                      storeId: store.id,
                                      storeName: store.storeName,
                                      initialStore: store,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Store Cover / Banner
                                    if (store.fullCoverImage != null &&
                                        store.fullCoverImage!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(18),
                                            ),
                                        child: Image.network(
                                          store.fullCoverImage!,
                                          height: 110,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),

                                    // Store Details Row
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 26,
                                            backgroundColor: const Color(
                                              0xFFFF5B00,
                                            ).withValues(alpha: 0.1),
                                            backgroundImage:
                                                store.fullProfileImage !=
                                                        null &&
                                                    store
                                                        .fullProfileImage!
                                                        .isNotEmpty
                                                ? NetworkImage(
                                                    store.fullProfileImage!,
                                                  )
                                                : null,
                                            child:
                                                store.fullProfileImage ==
                                                        null ||
                                                    store
                                                        .fullProfileImage!
                                                        .isEmpty
                                                ? const Icon(
                                                    Icons.store_rounded,
                                                    color: Color(0xFFFF5B00),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  store.storeName,
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(
                                                      0xFF0F172A,
                                                    ),
                                                  ),
                                                ),
                                                if (store
                                                    .storeDescription
                                                    .isNotEmpty)
                                                  Text(
                                                    store.storeDescription,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: GoogleFonts.cairo(
                                                      fontSize: 12.5,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'التوصيل: ${store.deliveryFee > 0 ? "${store.deliveryFee.toStringAsFixed(0)} ج.م" : "مجاني"}',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 12.5,
                                                    color: const Color(
                                                      0xFFFF5B00,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: store.isCurrentlyOpen
                                                  ? const Color(
                                                      0xFF10B981,
                                                    ).withValues(alpha: 0.1)
                                                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              store.isCurrentlyOpen ? 'مفتوح' : 'مغلق',
                                              style: GoogleFonts.cairo(
                                                color: store.isCurrentlyOpen
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFEF4444),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
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
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Promotional Ad Popup Dialog
// ---------------------------------------------------------
void showStorePromotionalDialog(
  BuildContext context,
  StoreBannerModel banner, {
  VoidCallback? onExplore,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Container(
                  height: 185,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    image:
                        banner.fullImage != null && banner.fullImage!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(banner.fullImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: banner.fullImage == null || banner.fullImage!.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 54,
                            color: Color(0xFFFF5B00),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (banner.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      banner.description,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5B00),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      if (onExplore != null) onExplore();
                    },
                    child: Text(
                      'اطلب الآن',
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
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------
// Product Customization Modal Sheet
// ---------------------------------------------------------
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
    if (_selectedSize != null) price += _selectedSize!.extraPrice;
    for (final addon in _selectedAddons) {
      price += addon.price;
    }
    return price * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final hasSizes = widget.product.sizes.isNotEmpty;
    final hasAddons = widget.product.addons.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
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
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
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
                                color: const Color(0xFFFF5B00),
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
                    final isSelected = _selectedSize?.name == size.name;
                    return InkWell(
                      onTap: () => setState(() => _selectedSize = size),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? const Color(0xFFFF5B00)
                                  : Colors.black38,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              size.name,
                              style: GoogleFonts.cairo(fontSize: 14.5),
                            ),
                            const Spacer(),
                            if (size.extraPrice > 0)
                              Text(
                                '+${size.extraPrice.toStringAsFixed(0)} ج.م',
                                style: GoogleFonts.cairo(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
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
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _selectedAddons.removeWhere(
                              (a) => a.name == addon.name,
                            );
                          } else {
                            _selectedAddons.add(addon);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isChecked
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              color: isChecked
                                  ? const Color(0xFFFF5B00)
                                  : Colors.black38,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              addon.name,
                              style: GoogleFonts.cairo(fontSize: 14.5),
                            ),
                            const Spacer(),
                            Text(
                              '+${addon.price.toStringAsFixed(0)} ج.م',
                              style: GoogleFonts.cairo(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const Divider(height: 1, color: Color(0xFFF1F3F5)),
                ],

                // Quantity & Notes
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الكمية',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
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
                                  icon: const Icon(
                                    Icons.add,
                                    size: 18,
                                    color: Color(0xFFFF5B00),
                                  ),
                                  onPressed: () => setState(() => _quantity++),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'ملاحظات خاصة على الوجبة...',
                          hintStyle: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Add to Cart Action Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5B00),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      final item = StoreCartItem(
                        product: widget.product,
                        quantity: _quantity,
                        selectedSize: _selectedSize,
                        selectedAddons: _selectedAddons,
                        notes: _notesController.text.trim(),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إضافة إلى السلة',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_totalPrice.toStringAsFixed(0)} ج.م',
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
        ),
      ),
    );
  }
}
