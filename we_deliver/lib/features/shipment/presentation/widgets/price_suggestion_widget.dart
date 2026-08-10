import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/features/shipment/data/datasources/delivery_pricing.dart';

class PriceSuggestionWidget extends StatelessWidget {
  final String? fromArea;
  final String? toArea;
  final TextEditingController priceController;

  const PriceSuggestionWidget({
    super.key,
    required this.fromArea,
    required this.toArea,
    required this.priceController,
  });

  @override
  Widget build(BuildContext context) {
    if (fromArea == null ||
        toArea == null ||
        fromArea!.isEmpty ||
        toArea!.isEmpty) {
      return const SizedBox.shrink();
    }

    final price = DeliveryPricing.getSuggestedPrice(fromArea, toArea);
    if (price == null) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'لم نجد سعرًا مقترحًا لهذه المناطق، يرجى إدخال السعر يدويًا.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Auto-fill price controller and keep it updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final priceStr = price.toInt().toString();
      if (priceController.text != priceStr) {
        priceController.text = priceStr;
      }
    });

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
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
                    FontAwesomeIcons.handHoldingDollar,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'سعر التوصيل',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'تم التحديد',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'من: $fromArea ➔ إلى: $toArea',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${DeliveryPricing.getZone(fromArea)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Text(
                        ' ➔ ',
                        style: TextStyle(fontSize: 10, color: Colors.black38),
                      ),
                      Text(
                        '${DeliveryPricing.getZone(toArea)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price.toInt().toString(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'ج.م',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Price is auto-filled and cannot be negotiated, so we do not show the approval button here.
        ],
      ),
    );
  }
}
