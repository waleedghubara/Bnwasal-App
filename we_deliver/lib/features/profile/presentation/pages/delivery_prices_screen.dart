import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/features/shipment/data/datasources/delivery_pricing.dart';

class DeliveryPricesScreen extends StatefulWidget {
  const DeliveryPricesScreen({super.key});

  @override
  State<DeliveryPricesScreen> createState() => _DeliveryPricesScreenState();
}

class _DeliveryPricesScreenState extends State<DeliveryPricesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Interactive pricing selectors
  String _selectedFromArea = 'الكيلو 21';
  String _selectedToArea = 'الكيلو 21';

  final List<String> _areas = const [
    'أبو يوسف',
    'الإبراهيمية',
    'البيطاش',
    'الدخيلة',
    'الشاطبي',
    'العجمي',
    'العصافرة',
    'الكيلو 21',
    'المعمورة',
    'المكس',
    'المنتزه',
    'المندرة',
    'المنشية',
    'الهانوفيل',
    'الورديان',
    'جليم',
    'رشدي',
    'زيزينيا',
    'سان ستيفانو',
    'سبورتنج',
    'سموحة',
    'سيدي بشر',
    'كرموز',
    'لوران',
    'محرم بك',
    'محطة مصر',
    'ميامي',
  ];

  final List<String> _zones = [
    'Zone A',
    'Zone B',
    'Zone C',
    'Zone D',
    'Zone E',
    'Zone F',
  ];

  // Zone metadata for descriptions
  final Map<String, String> _zoneDescriptions = {
    'Zone A': 'وسط وشرق الإسكندرية (المناطق القريبة والمركزية)',
    'Zone B': 'شرق الإسكندرية (المناطق السكنية الحيوية)',
    'Zone C': 'شرق الإسكندرية الأبعد والأحياء المتوسطة',
    'Zone D': 'أطراف شرق الإسكندرية والمناطق السياحية',
    'Zone E': 'غرب الإسكندرية والعجمي',
    'Zone F': 'العامرية وبرج العرب والمناطق الصناعية الحرة',
  };

  // Regions belonging to each zone
  final Map<String, List<String>> _zoneRegions = {
    'Zone A': [
      'بحري',
      'المنشية',
      'محطة الرمل',
      'الشاطبي',
      'الأزاريطة',
      'كامب شيزار',
      'الإبراهيمية',
      'سموحة',
      'كليوباترا',
      'سيدي جابر',
      'الحضرة',
      'مبرة بك',
      'محرم بك',
    ],
    'Zone B': [
      'رشدي',
      'مصطفى كامل',
      'جليم',
      'سان ستيفانو',
      'لوران',
      'جاناكليس',
      'باكوس',
      'فلمنج',
      'زيزينيا',
      'بولكلي',
      'سبا باشا',
      'الرمل',
    ],
    'Zone C': [
      'ميامي',
      'العصافرة قبلي',
      'العصافرة بحري',
      'العصافرة',
      'سيدي بشر قبلي',
      'سيدي بشر بحري',
      'سيدي بشر',
      'السيوف',
      'السيوف شماعة',
      'فيكتوريا',
      'الرأس السوداء',
      'الساعة',
      'الفلكي',
      'خورشيد',
    ],
    'Zone D': [
      'المندرة قبلي',
      'المندرة بحري',
      'المندرة',
      'المعمورة',
      'المعمورة البلد',
      'أبو قير',
      'الطابية',
      'المعمورة الشاطئ',
      'طوسون',
      'المنتزه',
    ],
    'Zone E': [
      'كرموز',
      'مينا البصل',
      'القباري',
      'الورديان',
      'المكس',
      'الدخيلة',
      'البيطاش',
      'الهانوفيل',
      'بيانكي',
      'العجمي',
      'الكيلو 21',
      'الكيلو 26',
      'نجع العرب',
      'أبو تلات',
      'أبو يوسف',
    ],
    'Zone F': [
      'برج العرب',
      'برج العرب الجديدة',
      'كينج مريوط',
      'العامرية',
      'النهضة',
      'أم زغيو',
      'عبد القادر',
      'مرغم',
      'الناصرية',
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 18,
              color: Colors.black87,
            ),
          ),
          title: const Text(
            'جدول أسعار التوصيل',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: GoogleFonts.almarai(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'حاسبة الأسعار'),
                    Tab(text: 'دليل المناطق والـ Zones'),
                  ],
                ),
                Divider(height: 1, color: Colors.grey.shade100),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildPriceCalculatorTab(), _buildZonesDirectoryTab()],
        ),
      ),
    );
  }

  Widget _buildPriceCalculatorTab() {
    final double? price =
        DeliveryPricing.getSuggestedPrice(_selectedFromArea, _selectedToArea);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.08),
                  AppColors.primary.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'تعتمد أسعار التوصيل لدينا على منطقة الاستلام ومنطقة التسليم المحددة. اختر المناطق بالأسفل لمعرفة السعر الفوري.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'احسب سعر التوصيل فوريًا',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Selectors Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // From Area dropdown
                _buildDropdownField(
                  label: 'من منطقة الاستلام (Pickup)',
                  value: _selectedFromArea,
                  items: _areas,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFromArea = val);
                  },
                ),
                const SizedBox(height: 16),

                // Swap button decoration
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.swap_vert,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                  ],
                ),
                const SizedBox(height: 16),

                // To Area dropdown
                _buildDropdownField(
                  label: 'إلى منطقة التسليم (Delivery)',
                  value: _selectedToArea,
                  items: _areas,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedToArea = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Price result Card
          if (price != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'تكلفة التوصيل المقدرة',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        price.toInt().toString(),
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'جنيه مصري',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade100),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flash_on,
                        color: Colors.amber.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'توصيل فوري سريع وآمن',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZonesDirectoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _zones.length,
      itemBuilder: (context, index) {
        final zone = _zones[index];
        final description = _zoneDescriptions[zone] ?? '';
        final regions = _zoneRegions[zone] ?? [];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  zone,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              title: Text(
                description,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                'يحتوي على ${regions.length} مناطق',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'المناطق المشمولة بالـ Zone:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: regions.map((region) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              region,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
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
    );
  }
}
