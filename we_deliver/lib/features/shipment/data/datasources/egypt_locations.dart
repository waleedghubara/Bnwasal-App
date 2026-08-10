/// Mock data simulating backend response for Egyptian governorates & cities
class EgyptLocations {
  static const Map<String, List<String>> governoratesAndCities = {
    'الإسكندرية': [
      'الرمل',
      'المنتزه',
      'سيدي جابر',
      'العجمي',
      'برج العرب',
      'محرم بك',
      'لوران',
      'سموحة',

      // شرق الإسكندرية
      'سيدي بشر',
      'ميامي',
      'العصافرة',
      'المندرة',
      'المعمورة',
      'الفلكي',
      'السيوف',
      'فيكتوريا',
      'أبو قير',
      'الطابية',
      'خورشيد',
      'المعمورة البلد',
      'طوسون',
      'المعمورة الشاطئ',

      // وسط الإسكندرية
      'كليوباترا',
      'سبورتنج',
      'مصطفى كامل',
      'فلمنج',
      'سان ستيفانو',
      'بولكلي',
      'رشدي',
      'زيزينيا',
      'جليم',
      'شوتس',
      'عزبة سعد',
      'أبيس',

      // وسط البلد
      'الإبراهيمية',
      'الأزاريطة',
      'الشاطبي',
      'باب شرق',
      'وابور المياه',
      'الحضرة',
      'كرموز',
      'كوم الدكة',
      'العطارين',
      'محطة مصر',
      'المنشية',

      // غرب الإسكندرية
      'القباري',
      'الورديان',
      'المكس',
      'نجع العرب',
      'المتراس',
      'أم زغيو',
      'عامود السواري',
      'رأس التين',
      'بحري',
      'الأنفوشي',
      'السيالة',
      'اللبان',
      'ميناء الإسكندرية',

      // العجمي والدخيلة
      'الكيلو 21',
      'البيطاش',
      'الهانوفيل',
      'أبو يوسف',
      'الدخيلة',
      'أبو تلات',

      // العامرية وبرج العرب
      'النهضة',
      'مرغم',
      'عبد القادر',
      'الناصرية',
      'المنطقة الحرة',
      'الكينج مريوط',
      'برج العرب القديمة',
      'برج العرب الجديدة',
      'بهيج',
      'أبو صير',
      'الغربانيات',
      'بنجر السكر',
    ],
  };

  static List<String> get governorates => governoratesAndCities.keys.toList();

  static List<String> citiesFor(String governorate) =>
      governoratesAndCities[governorate] ?? [];
}

/// Mock saved addresses (would come from user profile API)
class SavedAddress {
  final String id;
  final String title;
  final String address;
  final String governorate;
  final String city;
  final double? latitude;
  final double? longitude;
  final String? phone;

  const SavedAddress({
    required this.id,
    required this.title,
    required this.address,
    required this.governorate,
    required this.city,
    this.latitude,
    this.longitude,
    this.phone,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id']?.toString() ?? '',
      title: json['label']?.toString() ?? '',
      address: json['detail']?.toString() ?? '',
      governorate: json['governorate']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty && id != 'custom_map') 'id': id,
      'label': title,
      'detail': address,
      'governorate': governorate,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      if (phone != null) 'phone': phone,
    };
  }
}
