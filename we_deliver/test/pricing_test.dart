import 'package:flutter_test/flutter_test.dart';
import 'package:we_deliver/features/shipment/data/datasources/delivery_pricing.dart';

void main() {
  group('DeliveryPricing Tests', () {
    test('Exact matches (Symmetric & Asymmetric)', () {
      // Asymmetric pair: العصافرة -> المكس (78) vs المكس -> العصافرة (86)
      expect(DeliveryPricing.getSuggestedPrice('العصافرة', 'المكس'), 78.0);
      expect(DeliveryPricing.getSuggestedPrice('المكس', 'العصافرة'), 86.0);

      // Asymmetric pair: سيدي بشر -> زيزينيا (44) vs زيزينيا -> سيدي بشر (34)
      expect(DeliveryPricing.getSuggestedPrice('سيدي بشر', 'زيزينيا'), 44.0);
      expect(DeliveryPricing.getSuggestedPrice('زيزينيا', 'سيدي بشر'), 34.0);

      // Symmetric pair: أبو يوسف -> أبو يوسف (30)
      expect(DeliveryPricing.getSuggestedPrice('أبو يوسف', 'أبو يوسف'), 30.0);

      // Test with trailing/leading spaces
      expect(DeliveryPricing.getSuggestedPrice('  العصافرة  ', 'المكس '), 78.0);
    });

    test('Contains matches (Partial matches)', () {
      // "منطقة العصافرة" should match "العصافرة"
      expect(DeliveryPricing.getSuggestedPrice('منطقة العصافرة', 'المكس'), 78.0);
    });

    test('Fallback to legacy zone pricing for unmatched areas', () {
      // E.g. 'بحري' is in Zone A (is in areaToZone but not one of the 27 Excel areas),
      // 'أبو تلات' is in Zone E (not in Excel areas but in areaToZone).
      // Zone A -> Zone E = 90
      expect(DeliveryPricing.getSuggestedPrice('بحري', 'أبو تلات'), 90.0);
    });
  });
}
