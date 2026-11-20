import 'dart:convert';
import '../../../../core/utils/image_helper.dart';
import '../../../merchant/data/models/merchant_models.dart';

export '../../../../core/utils/image_helper.dart' show formatImageUrl;

class StoreModel {
  final int id;
  final String storeName;
  final String storeDescription;
  final String storeAddress;
  final String phone;
  final String? profileImage;
  final String? coverImage;
  final String? city;
  final String category;
  final String activityType;
  final String openingHours;
  final double minOrderAmount;
  final double deliveryFee;
  final bool isOpen;
  final int productsCount;
  final int categoriesCount;
  final String? preparationTime;
  final String? deliveryTime;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final int ratingCount;

  /// Dynamic check: considers both the database manual isOpen toggle
  /// and the configured weekly opening hours / time schedule
  bool get isCurrentlyOpen {
    if (!isOpen) return false;
    return isStoreOpenNow(openingHours);
  }

  String? get fullProfileImage => formatImageUrl(profileImage);
  String? get fullCoverImage => formatImageUrl(coverImage) ?? formatImageUrl(profileImage);

  String get displayActivityName {
    switch (activityType) {
      case 'restaurant': return 'مطاعم';
      case 'supermarket': return 'ماركت';
      case 'bakery': return 'مخبوزات';
      case 'roastery': return 'محمصة و عطارة';
      case 'sweets': return 'حلويات';
      case 'vegetables': return 'فواكه وخضروات';
      case 'dairy': return 'ألبان وجبن';
      case 'juices': return 'عصائر وكوكتيلات';
      case 'coffee': return 'قهوة وبُن';
      case 'online': return 'أونلاين';
      case 'pharmacy': return 'صيدلية';
      case 'clothes': return 'ملابس';
      case 'store': return 'محل ومتاجر';
      default: return 'أخرى';
    }
  }

  bool matchesCategory(String filter) {
    final f = filter.toLowerCase().trim();
    if (f.isEmpty || f == 'الكل' || f == 'all') return true;

    final act = activityType.toLowerCase().trim();
    final displayAct = displayActivityName.toLowerCase().trim();

    if (act == f || displayAct == f) return true;

    const activityAliases = <String, List<String>>{
      'restaurant': ['restaurant', 'مطاعم', 'مطعم'],
      'supermarket': ['supermarket', 'ماركت', 'سوبر ماركت', 'ماركت / سوبر ماركت', 'ماركت ومتاجر', 'بقالة'],
      'bakery': ['bakery', 'مخبوزات', 'مخبز', 'افران', 'أفران'],
      'roastery': ['roastery', 'محمصة و عطارة', 'محمصة', 'عطارة', 'محامص'],
      'sweets': ['sweets', 'حلويات', 'حلواني', 'حلو'],
      'vegetables': ['vegetables', 'فواكه وخضروات', 'خضار', 'فواكه', 'خضار وفواكه'],
      'dairy': ['dairy', 'ألبان وجبن', 'البان وجبن', 'ألبان', 'البان', 'جبن'],
      'juices': ['juices', 'عصائر وكوكتيلات', 'عصائر', 'عصير', 'كوكتيل'],
      'coffee': ['coffee', 'قهوة وبُن', 'قهوة وبن', 'قهوة', 'بن', 'كافيه'],
      'online': ['online', 'أونلاين', 'اونلاين', 'متجر أونلاين', 'متجر اونلاين'],
      'pharmacy': ['pharmacy', 'صيدلية', 'صيدليات', 'علاج', 'أدوية', 'ادوية'],
      'clothes': ['clothes', 'ملابس وأزياء', 'ملابس وازياء', 'ملابس', 'أزياء', 'ازياء'],
      'store': ['store', 'محل / متجر عام', 'متجر عام', 'محل ومتاجر', 'محل', 'متجر'],
    };

    String? matchedGroup;
    for (final entry in activityAliases.entries) {
      if (entry.key == f || entry.value.any((alias) => alias == f || f.contains(alias))) {
        matchedGroup = entry.key;
        break;
      }
    }

    if (matchedGroup != null) {
      final validActs = activityAliases[matchedGroup]!;
      return act == matchedGroup || validActs.contains(act);
    }

    return act == f;
  }

  StoreModel({
    required this.id,
    required this.storeName,
    required this.storeDescription,
    required this.storeAddress,
    required this.phone,
    this.profileImage,
    this.coverImage,
    this.city,
    this.category = 'مطاعم',
    this.activityType = 'restaurant',
    required this.openingHours,
    required this.minOrderAmount,
    required this.deliveryFee,
    required this.isOpen,
    this.productsCount = 0,
    this.categoriesCount = 0,
    this.preparationTime,
    this.deliveryTime,
    this.latitude,
    this.longitude,
    this.rating,
    this.ratingCount = 0,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    final double? parsedRating = json['rating'] != null && json['rating'].toString().isNotEmpty
        ? double.tryParse(json['rating'].toString())
        : null;
    final int parsedRatingCount = json['ratingCount'] != null
        ? (int.tryParse(json['ratingCount'].toString()) ?? 0)
        : 0;
    final double? parsedLat = json['latitude'] != null && json['latitude'].toString().isNotEmpty
        ? double.tryParse(json['latitude'].toString())
        : null;
    final double? parsedLng = json['longitude'] != null && json['longitude'].toString().isNotEmpty
        ? double.tryParse(json['longitude'].toString())
        : null;
    final String? prepTime = json['preparationTime'] != null && json['preparationTime'].toString().trim().isNotEmpty
        ? json['preparationTime'].toString().trim()
        : null;
    final String? delTime = json['deliveryTime'] != null && json['deliveryTime'].toString().trim().isNotEmpty
        ? json['deliveryTime'].toString().trim()
        : null;

    return StoreModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      storeName: json['storeName']?.toString() ?? 'متجر',
      storeDescription: json['storeDescription']?.toString() ?? '',
      storeAddress: json['storeAddress']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      profileImage: json['profileImage']?.toString(),
      coverImage: json['coverImage']?.toString() ?? json['bannerImage']?.toString(),
      city: json['city']?.toString() ?? json['storeAddress']?.toString(),
      category: json['category']?.toString() ?? 'مطاعم',
      activityType: (json['activityType'] != null && json['activityType'].toString().trim().isNotEmpty)
          ? json['activityType'].toString().trim()
          : 'restaurant',
      openingHours: json['openingHours']?.toString() ?? '10:00 ص - 02:00 ص',
      minOrderAmount:
          double.tryParse(json['minOrderAmount']?.toString() ?? '0') ?? 0.0,
      deliveryFee:
          double.tryParse(json['deliveryFee']?.toString() ?? '0') ?? 0.0,
      isOpen: json['isOpen'] == 1 || json['isOpen'] == true,
      productsCount: json['productsCount'] is int
          ? json['productsCount']
          : int.tryParse(json['productsCount']?.toString() ?? '0') ?? 0,
      categoriesCount: json['categoriesCount'] is int
          ? json['categoriesCount']
          : int.tryParse(json['categoriesCount']?.toString() ?? '0') ?? 0,
      preparationTime: prepTime,
      deliveryTime: delTime,
      latitude: parsedLat,
      longitude: parsedLng,
      rating: parsedRating,
      ratingCount: parsedRatingCount,
    );
  }
}



/// Helper function to check if a store is open right now based on its openingHours
bool isStoreOpenNow(String? openingHours, {DateTime? now}) {
  if (openingHours == null || openingHours.trim().isEmpty) return true;
  final raw = openingHours.trim();

  if (raw.contains('24 ساعة')) return true;
  if (raw.contains('مغلق مؤقتاً') || raw == 'مغلق') return false;

  final current = now ?? DateTime.now();
  final curMin = current.hour * 60 + current.minute;

  // 1. Check structured JSON if openingHours contains daily configuration
  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekday = days[current.weekday - 1]; // 1 = Monday ... 7 = Sunday
      final prevWeekday = days[(current.weekday - 2 + 7) % 7];

      // Check yesterday overnight shift
      final prevConfig = parsed[prevWeekday];
      if (prevConfig is Map && prevConfig['closed'] != true) {
        final pOpen = _parseTimeStrToMin(prevConfig['open']?.toString());
        final pClose = _parseTimeStrToMin(prevConfig['close']?.toString());
        if (pOpen != null && pClose != null && pOpen > pClose) {
          if (curMin <= pClose) return true;
        }
      }

      final todayConfig = parsed[weekday];
      if (todayConfig is Map) {
        if (todayConfig['closed'] == true) return false;
        final tOpen = _parseTimeStrToMin(todayConfig['open']?.toString());
        final tClose = _parseTimeStrToMin(todayConfig['close']?.toString());
        if (tOpen != null && tClose != null) {
          if (tOpen == 0 && (tClose >= 1439 || tClose == 0)) return true;
          if (tOpen <= tClose) {
            return curMin >= tOpen && curMin <= tClose;
          } else {
            return curMin >= tOpen || curMin <= tClose;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Check range string: e.g. "10:00 ص - 02:00 ص" or "09:00 - 23:00"
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) {
      final tOpen = _parseTimeStrToMin(parts[0]);
      final tClose = _parseTimeStrToMin(parts[1]);
      if (tOpen != null && tClose != null) {
        if (tOpen <= tClose) {
          return curMin >= tOpen && curMin <= tClose;
        } else {
          return curMin >= tOpen || curMin <= tClose;
        }
      }
    }
  }

  return true;
}

int? _parseTimeStrToMin(String? tStr) {
  if (tStr == null || tStr.trim().isEmpty) return null;
  final raw = tStr.trim().toLowerCase();
  final isPM = raw.contains('م') || raw.contains('pm');
  final isAM = raw.contains('ص') || raw.contains('am');

  final clean = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  int? h = int.tryParse(parts[0]);
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (h == null) return null;

  if (isPM && h < 12) h += 12;
  if (isAM && h == 12) h = 0;

  return h * 60 + m;
}

class StoreDetailsModel {
  final StoreModel store;
  final List<MerchantCategoryModel> categories;
  final List<MerchantProductModel> products;

  StoreDetailsModel({
    required this.store,
    required this.categories,
    required this.products,
  });

  factory StoreDetailsModel.fromJson(Map<String, dynamic> json) {
    final storeJson = json['store'] as Map<String, dynamic>? ?? {};
    final categoriesList = (json['categories'] as List? ?? [])
        .map(
          (c) => MerchantCategoryModel.fromJson(Map<String, dynamic>.from(c)),
        )
        .toList();
    final productsList = (json['products'] as List? ?? [])
        .map((p) => MerchantProductModel.fromJson(Map<String, dynamic>.from(p)))
        .toList();

    return StoreDetailsModel(
      store: StoreModel.fromJson(storeJson),
      categories: categoriesList,
      products: productsList,
    );
  }
}



/// Helper function to check if a store is open right now based on its openingHours
bool isStoreOpenNow(String? openingHours, {DateTime? now}) {
  if (openingHours == null || openingHours.trim().isEmpty) return true;
  final raw = openingHours.trim();

  if (raw.contains('24 ساعة')) return true;
  if (raw.contains('مغلق مؤقتاً') || raw == 'مغلق') return false;

  final current = now ?? DateTime.now();
  final curMin = current.hour * 60 + current.minute;

  // 1. Check structured JSON if openingHours contains daily configuration
  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekday = days[current.weekday - 1]; // 1 = Monday ... 7 = Sunday
      final prevWeekday = days[(current.weekday - 2 + 7) % 7];

      // Check yesterday overnight shift
      final prevConfig = parsed[prevWeekday];
      if (prevConfig is Map && prevConfig['closed'] != true) {
        final pOpen = _parseTimeStrToMin(prevConfig['open']?.toString());
        final pClose = _parseTimeStrToMin(prevConfig['close']?.toString());
        if (pOpen != null && pClose != null && pOpen > pClose) {
          if (curMin <= pClose) return true;
        }
      }

      final todayConfig = parsed[weekday];
      if (todayConfig is Map) {
        if (todayConfig['closed'] == true) return false;
        final tOpen = _parseTimeStrToMin(todayConfig['open']?.toString());
        final tClose = _parseTimeStrToMin(todayConfig['close']?.toString());
        if (tOpen != null && tClose != null) {
          if (tOpen == 0 && (tClose >= 1439 || tClose == 0)) return true;
          if (tOpen <= tClose) {
            return curMin >= tOpen && curMin <= tClose;
          } else {
            return curMin >= tOpen || curMin <= tClose;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Check range string: e.g. "10:00 ص - 02:00 ص" or "09:00 - 23:00"
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) {
      final tOpen = _parseTimeStrToMin(parts[0]);
      final tClose = _parseTimeStrToMin(parts[1]);
      if (tOpen != null && tClose != null) {
        if (tOpen <= tClose) {
          return curMin >= tOpen && curMin <= tClose;
        } else {
          return curMin >= tOpen || curMin <= tClose;
        }
      }
    }
  }

  return true;
}

int? _parseTimeStrToMin(String? tStr) {
  if (tStr == null || tStr.trim().isEmpty) return null;
  final raw = tStr.trim().toLowerCase();
  final isPM = raw.contains('م') || raw.contains('pm');
  final isAM = raw.contains('ص') || raw.contains('am');

  final clean = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  int? h = int.tryParse(parts[0]);
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (h == null) return null;

  if (isPM && h < 12) h += 12;
  if (isAM && h == 12) h = 0;

  return h * 60 + m;
}

class StoreCartItem {
  final MerchantProductModel product;
  final ProductSizeOption? selectedSize;
  final List<ProductAddonOption> selectedAddons;
  int quantity;
  final String? notes;

  String? get fullProductImage => formatImageUrl(product.image);

  StoreCartItem({
    required this.product,
    this.selectedSize,
    this.selectedAddons = const [],
    this.quantity = 1,
    this.notes,
  });

  double get basePrice =>
      (product.discountPrice != null && product.discountPrice! > 0)
      ? product.discountPrice!
      : product.price;

  double get sizeExtraPrice => selectedSize?.extraPrice ?? 0.0;

  double get addonsExtraPrice {
    double total = 0.0;
    for (final addon in selectedAddons) {
      total += addon.price;
    }
    return total;
  }

  double get unitPrice => basePrice + sizeExtraPrice + addonsExtraPrice;

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'productName': product.name,
      'productImage': product.image,
      'size': selectedSize?.name,
      'addons': selectedAddons
          .map((a) => {'name': a.name, 'price': a.price})
          .toList(),
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'notes': notes,
    };
  }
}

class StoreBannerModel {
  final int id;
  final int? merchantId;
  final String storeName;
  final String? storeImage;
  final String storeOpeningHours;
  final bool storeIsOpen;
  final String title;
  final String description;
  final String image;
  final String badge;
  final String actionType;
  final String actionValue;
  final bool showPopup;

  StoreBannerModel({
    required this.id,
    this.merchantId,
    required this.storeName,
    this.storeImage,
    required this.storeOpeningHours,
    required this.storeIsOpen,
    required this.title,
    required this.description,
    required this.image,
    required this.badge,
    required this.actionType,
    required this.actionValue,
    required this.showPopup,
  });

  String? get fullImage => formatImageUrl(image);
  String? get fullStoreImage => formatImageUrl(storeImage);

  factory StoreBannerModel.fromJson(Map<String, dynamic> json) {
    return StoreBannerModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      merchantId: json['merchantId'] != null
          ? (json['merchantId'] is int
              ? json['merchantId']
              : int.tryParse(json['merchantId'].toString()))
          : null,
      storeName: json['storeName']?.toString() ?? '',
      storeImage: json['storeImage']?.toString(),
      storeOpeningHours:
          json['storeOpeningHours']?.toString() ?? '10:00 ص - 02:00 ص',
      storeIsOpen: json['storeIsOpen'] == true || json['storeIsOpen'] == 1,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      badge: json['badge']?.toString() ?? 'إعلان مميز',
      actionType: json['actionType']?.toString() ?? 'store',
      actionValue: json['actionValue']?.toString() ?? '',
      showPopup: json['showPopup'] == true || json['showPopup'] == 1,
    );
  }
}



/// Helper function to check if a store is open right now based on its openingHours
bool isStoreOpenNow(String? openingHours, {DateTime? now}) {
  if (openingHours == null || openingHours.trim().isEmpty) return true;
  final raw = openingHours.trim();

  if (raw.contains('24 ساعة')) return true;
  if (raw.contains('مغلق مؤقتاً') || raw == 'مغلق') return false;

  final current = now ?? DateTime.now();
  final curMin = current.hour * 60 + current.minute;

  // 1. Check structured JSON if openingHours contains daily configuration
  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekday = days[current.weekday - 1]; // 1 = Monday ... 7 = Sunday
      final prevWeekday = days[(current.weekday - 2 + 7) % 7];

      // Check yesterday overnight shift
      final prevConfig = parsed[prevWeekday];
      if (prevConfig is Map && prevConfig['closed'] != true) {
        final pOpen = _parseTimeStrToMin(prevConfig['open']?.toString());
        final pClose = _parseTimeStrToMin(prevConfig['close']?.toString());
        if (pOpen != null && pClose != null && pOpen > pClose) {
          if (curMin <= pClose) return true;
        }
      }

      final todayConfig = parsed[weekday];
      if (todayConfig is Map) {
        if (todayConfig['closed'] == true) return false;
        final tOpen = _parseTimeStrToMin(todayConfig['open']?.toString());
        final tClose = _parseTimeStrToMin(todayConfig['close']?.toString());
        if (tOpen != null && tClose != null) {
          if (tOpen == 0 && (tClose >= 1439 || tClose == 0)) return true;
          if (tOpen <= tClose) {
            return curMin >= tOpen && curMin <= tClose;
          } else {
            return curMin >= tOpen || curMin <= tClose;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Check range string: e.g. "10:00 ص - 02:00 ص" or "09:00 - 23:00"
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) {
      final tOpen = _parseTimeStrToMin(parts[0]);
      final tClose = _parseTimeStrToMin(parts[1]);
      if (tOpen != null && tClose != null) {
        if (tOpen <= tClose) {
          return curMin >= tOpen && curMin <= tClose;
        } else {
          return curMin >= tOpen || curMin <= tClose;
        }
      }
    }
  }

  return true;
}

int? _parseTimeStrToMin(String? tStr) {
  if (tStr == null || tStr.trim().isEmpty) return null;
  final raw = tStr.trim().toLowerCase();
  final isPM = raw.contains('م') || raw.contains('pm');
  final isAM = raw.contains('ص') || raw.contains('am');

  final clean = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  int? h = int.tryParse(parts[0]);
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (h == null) return null;

  if (isPM && h < 12) h += 12;
  if (isAM && h == 12) h = 0;

  return h * 60 + m;
}

class MainStoreCategoryModel {
  final int id;
  final String key;
  final String name;
  final String tag;
  final String icon;
  final String image;
  final int storeCount;

  MainStoreCategoryModel({
    required this.id,
    this.key = '',
    required this.name,
    required this.tag,
    required this.icon,
    required this.image,
    this.storeCount = 0,
  });

  factory MainStoreCategoryModel.fromJson(Map<String, dynamic> json) {
    return MainStoreCategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      tag: json['tag']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      storeCount: json['storeCount'] is int
          ? json['storeCount']
          : int.tryParse(json['storeCount']?.toString() ?? '0') ?? 0,
    );
  }
}



/// Helper function to check if a store is open right now based on its openingHours
bool isStoreOpenNow(String? openingHours, {DateTime? now}) {
  if (openingHours == null || openingHours.trim().isEmpty) return true;
  final raw = openingHours.trim();

  if (raw.contains('24 ساعة')) return true;
  if (raw.contains('مغلق مؤقتاً') || raw == 'مغلق') return false;

  final current = now ?? DateTime.now();
  final curMin = current.hour * 60 + current.minute;

  // 1. Check structured JSON if openingHours contains daily configuration
  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekday = days[current.weekday - 1]; // 1 = Monday ... 7 = Sunday
      final prevWeekday = days[(current.weekday - 2 + 7) % 7];

      // Check yesterday overnight shift
      final prevConfig = parsed[prevWeekday];
      if (prevConfig is Map && prevConfig['closed'] != true) {
        final pOpen = _parseTimeStrToMin(prevConfig['open']?.toString());
        final pClose = _parseTimeStrToMin(prevConfig['close']?.toString());
        if (pOpen != null && pClose != null && pOpen > pClose) {
          if (curMin <= pClose) return true;
        }
      }

      final todayConfig = parsed[weekday];
      if (todayConfig is Map) {
        if (todayConfig['closed'] == true) return false;
        final tOpen = _parseTimeStrToMin(todayConfig['open']?.toString());
        final tClose = _parseTimeStrToMin(todayConfig['close']?.toString());
        if (tOpen != null && tClose != null) {
          if (tOpen == 0 && (tClose >= 1439 || tClose == 0)) return true;
          if (tOpen <= tClose) {
            return curMin >= tOpen && curMin <= tClose;
          } else {
            return curMin >= tOpen || curMin <= tClose;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Check range string: e.g. "10:00 ص - 02:00 ص" or "09:00 - 23:00"
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) {
      final tOpen = _parseTimeStrToMin(parts[0]);
      final tClose = _parseTimeStrToMin(parts[1]);
      if (tOpen != null && tClose != null) {
        if (tOpen <= tClose) {
          return curMin >= tOpen && curMin <= tClose;
        } else {
          return curMin >= tOpen || curMin <= tClose;
        }
      }
    }
  }

  return true;
}

int? _parseTimeStrToMin(String? tStr) {
  if (tStr == null || tStr.trim().isEmpty) return null;
  final raw = tStr.trim().toLowerCase();
  final isPM = raw.contains('م') || raw.contains('pm');
  final isAM = raw.contains('ص') || raw.contains('am');

  final clean = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  int? h = int.tryParse(parts[0]);
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (h == null) return null;

  if (isPM && h < 12) h += 12;
  if (isAM && h == 12) h = 0;

  return h * 60 + m;
}

class ClientStoreOrderItemModel {
  final int id;
  final int? productId;
  final String productName;
  final String? productImage;
  final String? size;
  final List<dynamic> addons;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? notes;

  String? get fullProductImage => formatImageUrl(productImage);

  ClientStoreOrderItemModel({
    required this.id,
    this.productId,
    required this.productName,
    this.productImage,
    this.size,
    this.addons = const [],
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.notes,
  });

  factory ClientStoreOrderItemModel.fromJson(Map<String, dynamic> json) {
    return ClientStoreOrderItemModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productId: json['productId'] is int ? json['productId'] : int.tryParse(json['productId']?.toString() ?? ''),
      productName: json['productName']?.toString() ?? 'منتج',
      productImage: json['productImage']?.toString(),
      size: json['size']?.toString(),
      addons: json['addons'] is List ? json['addons'] as List : [],
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      unitPrice: double.tryParse(json['unitPrice']?.toString() ?? '0') ?? 0.0,
      totalPrice: double.tryParse(json['totalPrice']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString(),
    );
  }
}



/// Helper function to check if a store is open right now based on its openingHours
bool isStoreOpenNow(String? openingHours, {DateTime? now}) {
  if (openingHours == null || openingHours.trim().isEmpty) return true;
  final raw = openingHours.trim();

  if (raw.contains('24 ساعة')) return true;
  if (raw.contains('مغلق مؤقتاً') || raw == 'مغلق') return false;

  final current = now ?? DateTime.now();
  final curMin = current.hour * 60 + current.minute;

  // 1. Check structured JSON if openingHours contains daily configuration
  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekday = days[current.weekday - 1]; // 1 = Monday ... 7 = Sunday
      final prevWeekday = days[(current.weekday - 2 + 7) % 7];

      // Check yesterday overnight shift
      final prevConfig = parsed[prevWeekday];
      if (prevConfig is Map && prevConfig['closed'] != true) {
        final pOpen = _parseTimeStrToMin(prevConfig['open']?.toString());
        final pClose = _parseTimeStrToMin(prevConfig['close']?.toString());
        if (pOpen != null && pClose != null && pOpen > pClose) {
          if (curMin <= pClose) return true;
        }
      }

      final todayConfig = parsed[weekday];
      if (todayConfig is Map) {
        if (todayConfig['closed'] == true) return false;
        final tOpen = _parseTimeStrToMin(todayConfig['open']?.toString());
        final tClose = _parseTimeStrToMin(todayConfig['close']?.toString());
        if (tOpen != null && tClose != null) {
          if (tOpen == 0 && (tClose >= 1439 || tClose == 0)) return true;
          if (tOpen <= tClose) {
            return curMin >= tOpen && curMin <= tClose;
          } else {
            return curMin >= tOpen || curMin <= tClose;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Check range string: e.g. "10:00 ص - 02:00 ص" or "09:00 - 23:00"
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) {
      final tOpen = _parseTimeStrToMin(parts[0]);
      final tClose = _parseTimeStrToMin(parts[1]);
      if (tOpen != null && tClose != null) {
        if (tOpen <= tClose) {
          return curMin >= tOpen && curMin <= tClose;
        } else {
          return curMin >= tOpen || curMin <= tClose;
        }
      }
    }
  }

  return true;
}

int? _parseTimeStrToMin(String? tStr) {
  if (tStr == null || tStr.trim().isEmpty) return null;
  final raw = tStr.trim().toLowerCase();
  final isPM = raw.contains('م') || raw.contains('pm');
  final isAM = raw.contains('ص') || raw.contains('am');

  final clean = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  int? h = int.tryParse(parts[0]);
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (h == null) return null;

  if (isPM && h < 12) h += 12;
  if (isAM && h == 12) h = 0;

  return h * 60 + m;
}

class ClientStoreCaptainModel {
  final int id;
  final String name;
  final String phone;
  final String? profileImage;

  String? get fullProfileImage => formatImageUrl(profileImage);

  ClientStoreCaptainModel({
    required this.id,
    required this.name,
    required this.phone,
    this.profileImage,
  });

  factory ClientStoreCaptainModel.fromJson(Map<String, dynamic> json) {
    return ClientStoreCaptainModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'المندوب',
      phone: json['phone']?.toString() ?? '',
      profileImage: json['profileImage']?.toString(),
    );
  }
}



/// Helper function to check if a store is open right now based on its openingHours
bool isStoreOpenNow(String? openingHours, {DateTime? now}) {
  if (openingHours == null || openingHours.trim().isEmpty) return true;
  final raw = openingHours.trim();

  if (raw.contains('24 ساعة')) return true;
  if (raw.contains('مغلق مؤقتاً') || raw == 'مغلق') return false;

  final current = now ?? DateTime.now();
  final curMin = current.hour * 60 + current.minute;

  // 1. Check structured JSON if openingHours contains daily configuration
  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekday = days[current.weekday - 1]; // 1 = Monday ... 7 = Sunday
      final prevWeekday = days[(current.weekday - 2 + 7) % 7];

      // Check yesterday overnight shift
      final prevConfig = parsed[prevWeekday];
      if (prevConfig is Map && prevConfig['closed'] != true) {
        final pOpen = _parseTimeStrToMin(prevConfig['open']?.toString());
        final pClose = _parseTimeStrToMin(prevConfig['close']?.toString());
        if (pOpen != null && pClose != null && pOpen > pClose) {
          if (curMin <= pClose) return true;
        }
      }

      final todayConfig = parsed[weekday];
      if (todayConfig is Map) {
        if (todayConfig['closed'] == true) return false;
        final tOpen = _parseTimeStrToMin(todayConfig['open']?.toString());
        final tClose = _parseTimeStrToMin(todayConfig['close']?.toString());
        if (tOpen != null && tClose != null) {
          if (tOpen == 0 && (tClose >= 1439 || tClose == 0)) return true;
          if (tOpen <= tClose) {
            return curMin >= tOpen && curMin <= tClose;
          } else {
            return curMin >= tOpen || curMin <= tClose;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Check range string: e.g. "10:00 ص - 02:00 ص" or "09:00 - 23:00"
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) {
      final tOpen = _parseTimeStrToMin(parts[0]);
      final tClose = _parseTimeStrToMin(parts[1]);
      if (tOpen != null && tClose != null) {
        if (tOpen <= tClose) {
          return curMin >= tOpen && curMin <= tClose;
        } else {
          return curMin >= tOpen || curMin <= tClose;
        }
      }
    }
  }

  return true;
}

int? _parseTimeStrToMin(String? tStr) {
  if (tStr == null || tStr.trim().isEmpty) return null;
  final raw = tStr.trim().toLowerCase();
  final isPM = raw.contains('م') || raw.contains('pm');
  final isAM = raw.contains('ص') || raw.contains('am');

  final clean = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  int? h = int.tryParse(parts[0]);
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (h == null) return null;

  if (isPM && h < 12) h += 12;
  if (isAM && h == 12) h = 0;

  return h * 60 + m;
}

class ClientStoreOrderModel {
  final int id;
  final String orderNumber;
  final int? merchantId;
  final int? storeId;
  final String? details;
  final String? notes;
  final String deliveryAddress;
  final String clientName;
  final String phone;
  final double orderPrice;
  final double deliveryFee;
  final double serviceFee;
  final double totalAmount;
  final String status;
  final String storeOrderStatus;
  final String captainTripStatus;
  final String paymentMethod;
  final bool isPaid;
  final DateTime? createdAt;
  final String storeName;
  final String? storeLogo;
  final String? storeCover;
  final String? storePhone;
  final String? storeAddress;
  final ClientStoreCaptainModel? captain;
  final List<ClientStoreOrderItemModel> items;

  String? get fullStoreLogo => formatImageUrl(storeLogo);
  String? get fullStoreCover => formatImageUrl(storeCover) ?? fullStoreLogo;

  bool get isActive {
    final s = (storeOrderStatus.isNotEmpty ? storeOrderStatus : status).toLowerCase();
    return s != 'ملغي' &&
        s != 'ملغية' &&
        s != 'cancelled' &&
        s != 'منتهي' &&
        s != 'منتهية' &&
        s != 'مكتمل' &&
        s != 'مكتملة' &&
        s != 'completed' &&
        s != 'delivered' &&
        s != 'تم التسليم' &&
        s != 'تم التوصيل';
  }

  String get displayStatus {
    final s = (storeOrderStatus.isNotEmpty ? storeOrderStatus : status).toLowerCase();
    if (s == 'cancelled' || s == 'ملغي' || s == 'ملغية') return 'ملغي';
    if (s == 'pending' || s == 'new' || s == 'جديد' || s == 'بانتظار القبول' || s == 'في انتظار قبول المتجر') return 'في انتظار قبول المتجر';
    if (s == 'preparing' || s == 'قيد التجهيز' || s == 'جاري التجهيز') return 'جاري تجهيز الطلب';
    if (s == 'ready' || s == 'جاهز') return 'جاهز • بانتظار الكابتن';
    if (s == 'captain_assigned' || s == 'تم تعيين مندوب' || captainTripStatus == 'ASSIGNED') return 'تم تعيين مندوب للتوصيل';
    if (s == 'picked_up' || s == 'تم الاستلام' || captainTripStatus == 'ORDER_PICKED_UP' || captainTripStatus == 'HEADING_TO_CLIENT') return 'المندوب استلم الطلب وفي الطريق إليك';
    if (s == 'delivered' || s == 'completed' || s == 'مكتمل' || s == 'مكتملة' || captainTripStatus == 'DELIVERED_SUCCESSFULLY' || status == 'تم التوصيل' || status == 'تم التسليم') return 'تم التوصيل بنجاح';
    return status;
  }

  ClientStoreOrderModel({
    required this.id,
    required this.orderNumber,
    this.merchantId,
    this.storeId,
    this.details,
    this.notes,
    required this.deliveryAddress,
    required this.clientName,
    required this.phone,
    required this.orderPrice,
    required this.deliveryFee,
    this.serviceFee = 0.0,
    required this.totalAmount,
    required this.status,
    required this.storeOrderStatus,
    required this.captainTripStatus,
    required this.paymentMethod,
    required this.isPaid,
    this.createdAt,
    required this.storeName,
    this.storeLogo,
    this.storeCover,
    this.storePhone,
    this.storeAddress,
    this.captain,
    this.items = const [],
  });

  factory ClientStoreOrderModel.fromJson(Map<String, dynamic> json) {
    return ClientStoreOrderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderNumber: json['orderNumber']?.toString() ?? '',
      merchantId: json['merchantId'] is int ? json['merchantId'] : int.tryParse(json['merchantId']?.toString() ?? ''),
      storeId: json['storeId'] is int ? json['storeId'] : int.tryParse(json['storeId']?.toString() ?? ''),
      details: json['details']?.toString(),
      notes: json['notes']?.toString(),
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      orderPrice: double.tryParse(json['orderPrice']?.toString() ?? '0') ?? 0.0,
      deliveryFee: double.tryParse(json['deliveryFee']?.toString() ?? '0') ?? 0.0,
      serviceFee: double.tryParse(json['serviceFee']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'جديد',
      storeOrderStatus: json['storeOrderStatus']?.toString() ?? 'NEW',
      captainTripStatus: json['captainTripStatus']?.toString() ?? 'PENDING_ASSIGNMENT',
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      isPaid: json['isPaid'] == 1 || json['isPaid'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      storeName: json['storeName']?.toString() ?? 'متجر',
      storeLogo: json['storeLogo']?.toString(),
      storeCover: json['storeCover']?.toString(),
      storePhone: json['storePhone']?.toString(),
      storeAddress: json['storeAddress']?.toString(),
      captain: json['captain'] != null && json['captain'] is Map<String, dynamic>
          ? ClientStoreCaptainModel.fromJson(Map<String, dynamic>.from(json['captain']))
          : null,
      items: (json['items'] as List? ?? [])
          .map((i) => ClientStoreOrderItemModel.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
    );
  }
}



/// Helper function to check if a store is open right now based on its openingHours
bool isStoreOpenNow(String? openingHours, {DateTime? now}) {
  if (openingHours == null || openingHours.trim().isEmpty) return true;
  final raw = openingHours.trim();

  if (raw.contains('24 ساعة')) return true;
  if (raw.contains('مغلق مؤقتاً') || raw == 'مغلق') return false;

  final current = now ?? DateTime.now();
  final curMin = current.hour * 60 + current.minute;

  // 1. Check structured JSON if openingHours contains daily configuration
  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekday = days[current.weekday - 1]; // 1 = Monday ... 7 = Sunday
      final prevWeekday = days[(current.weekday - 2 + 7) % 7];

      // Check yesterday overnight shift
      final prevConfig = parsed[prevWeekday];
      if (prevConfig is Map && prevConfig['closed'] != true) {
        final pOpen = _parseTimeStrToMin(prevConfig['open']?.toString());
        final pClose = _parseTimeStrToMin(prevConfig['close']?.toString());
        if (pOpen != null && pClose != null && pOpen > pClose) {
          if (curMin <= pClose) return true;
        }
      }

      final todayConfig = parsed[weekday];
      if (todayConfig is Map) {
        if (todayConfig['closed'] == true) return false;
        final tOpen = _parseTimeStrToMin(todayConfig['open']?.toString());
        final tClose = _parseTimeStrToMin(todayConfig['close']?.toString());
        if (tOpen != null && tClose != null) {
          if (tOpen == 0 && (tClose >= 1439 || tClose == 0)) return true;
          if (tOpen <= tClose) {
            return curMin >= tOpen && curMin <= tClose;
          } else {
            return curMin >= tOpen || curMin <= tClose;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Check range string: e.g. "10:00 ص - 02:00 ص" or "09:00 - 23:00"
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) {
      final tOpen = _parseTimeStrToMin(parts[0]);
      final tClose = _parseTimeStrToMin(parts[1]);
      if (tOpen != null && tClose != null) {
        if (tOpen <= tClose) {
          return curMin >= tOpen && curMin <= tClose;
        } else {
          return curMin >= tOpen || curMin <= tClose;
        }
      }
    }
  }

  return true;
}

int? _parseTimeStrToMin(String? tStr) {
  if (tStr == null || tStr.trim().isEmpty) return null;
  final raw = tStr.trim().toLowerCase();
  final isPM = raw.contains('م') || raw.contains('pm');
  final isAM = raw.contains('ص') || raw.contains('am');

  final clean = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  int? h = int.tryParse(parts[0]);
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (h == null) return null;

  if (isPM && h < 12) h += 12;
  if (isAM && h == 12) h = 0;

  return h * 60 + m;
}

class ProductReviewModel {
  final int id;
  final double rating;
  final String comment;
  final DateTime? createdAt;
  final String userName;
  final String? userImage;

  String? get fullUserImage => formatImageUrl(userImage);

  ProductReviewModel({
    required this.id,
    required this.rating,
    required this.comment,
    this.createdAt,
    required this.userName,
    this.userImage,
  });

  factory ProductReviewModel.fromJson(Map<String, dynamic> json) {
    return ProductReviewModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      rating: double.tryParse(json['rating']?.toString() ?? '5') ?? 5.0,
      comment: json['comment']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      userName: json['userName']?.toString() ?? 'عميل',
      userImage: json['userImage']?.toString(),
    );
  }
}

/// Helper function to check if a store is open right now based on its openingHours
bool isStoreOpenNow(String? openingHours, {DateTime? now}) {
  if (openingHours == null || openingHours.trim().isEmpty) return true;
  final raw = openingHours.trim();

  if (raw.contains('24 ساعة')) return true;
  if (raw.contains('مغلق مؤقتاً') || raw == 'مغلق') return false;

  final current = now ?? DateTime.now();
  final curMin = current.hour * 60 + current.minute;

  // 1. Check structured JSON if openingHours contains daily configuration
  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekday = days[current.weekday - 1]; // 1 = Monday ... 7 = Sunday
      final prevWeekday = days[(current.weekday - 2 + 7) % 7];

      // Check yesterday overnight shift
      final prevConfig = parsed[prevWeekday];
      if (prevConfig is Map && prevConfig['closed'] != true) {
        final pOpen = _parseTimeStrToMin(prevConfig['open']?.toString());
        final pClose = _parseTimeStrToMin(prevConfig['close']?.toString());
        if (pOpen != null && pClose != null && pOpen > pClose) {
          if (curMin <= pClose) return true;
        }
      }

      final todayConfig = parsed[weekday];
      if (todayConfig is Map) {
        if (todayConfig['closed'] == true) return false;
        final tOpen = _parseTimeStrToMin(todayConfig['open']?.toString());
        final tClose = _parseTimeStrToMin(todayConfig['close']?.toString());
        if (tOpen != null && tClose != null) {
          if (tOpen == 0 && (tClose >= 1439 || tClose == 0)) return true;
          if (tOpen <= tClose) {
            return curMin >= tOpen && curMin <= tClose;
          } else {
            return curMin >= tOpen || curMin <= tClose;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Check range string: e.g. "10:00 ص - 02:00 ص" or "09:00 - 23:00"
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) {
      final tOpen = _parseTimeStrToMin(parts[0]);
      final tClose = _parseTimeStrToMin(parts[1]);
      if (tOpen != null && tClose != null) {
        if (tOpen <= tClose) {
          return curMin >= tOpen && curMin <= tClose;
        } else {
          return curMin >= tOpen || curMin <= tClose;
        }
      }
    }
  }

  return true;
}

int? _parseTimeStrToMin(String? tStr) {
  if (tStr == null || tStr.trim().isEmpty) return null;
  final raw = tStr.trim().toLowerCase();
  final isPM = raw.contains('م') || raw.contains('pm');
  final isAM = raw.contains('ص') || raw.contains('am');

  final clean = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  int? h = int.tryParse(parts[0]);
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (h == null) return null;

  if (isPM && h < 12) h += 12;
  if (isAM && h == 12) h = 0;

  return h * 60 + m;
}


  final current = now ?? DateTime.now();
  final curMin = current.hour * 60 + current.minute;

  // 1. Check structured JSON if openingHours contains daily configuration
  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(raw);
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekday = days[current.weekday - 1]; // 1 = Monday ... 7 = Sunday
      final prevWeekday = days[(current.weekday - 2 + 7) % 7];

      // Check yesterday overnight shift
      final prevConfig = parsed[prevWeekday];
      if (prevConfig is Map && prevConfig['closed'] != true) {
        final pOpen = _parseTimeStrToMin(prevConfig['open']?.toString());
        final pClose = _parseTimeStrToMin(prevConfig['close']?.toString());
        if (pOpen != null && pClose != null && pOpen > pClose) {
          if (curMin <= pClose) return true;
        }
      }

      final todayConfig = parsed[weekday];
      if (todayConfig is Map) {
        if (todayConfig['closed'] == true) return false;
        final tOpen = _parseTimeStrToMin(todayConfig['open']?.toString());
        final tClose = _parseTimeStrToMin(todayConfig['close']?.toString());
        if (tOpen != null && tClose != null) {
          if (tOpen == 0 && (tClose >= 1439 || tClose == 0)) return true;
          if (tOpen <= tClose) {
            return curMin >= tOpen && curMin <= tClose;
          } else {
            return curMin >= tOpen || curMin <= tClose;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Check range string: e.g. "10:00 ص - 02:00 ص" or "09:00 - 23:00"
  if (raw.contains('-')) {
    final parts = raw.split('-');
    if (parts.length >= 2) {
      final tOpen = _parseTimeStrToMin(parts[0]);
      final tClose = _parseTimeStrToMin(parts[1]);
      if (tOpen != null && tClose != null) {
        if (tOpen <= tClose) {
          return curMin >= tOpen && curMin <= tClose;
        } else {
          return curMin >= tOpen || curMin <= tClose;
        }
      }
    }
  }

  return true;
}

int? _parseTimeStrToMin(String? tStr) {
  if (tStr == null || tStr.trim().isEmpty) return null;
  final raw = tStr.trim().toLowerCase();
  final isPM = raw.contains('م') || raw.contains('pm');
  final isAM = raw.contains('ص') || raw.contains('am');

  final clean = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = clean.split(':');
  if (parts.isEmpty || parts[0].isEmpty) return null;

  int? h = int.tryParse(parts[0]);
  int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  if (h == null) return null;

  if (isPM && h < 12) h += 12;
  if (isAM && h == 12) h = 0;

  return h * 60 + m;
}


