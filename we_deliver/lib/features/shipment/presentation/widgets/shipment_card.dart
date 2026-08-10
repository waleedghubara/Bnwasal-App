// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/features/shipment/presentation/pages/shipment_details_screen.dart';

import 'package:we_deliver/features/shipment/domain/entities/shipment.dart';

class ShipmentCard extends StatelessWidget {
  final Shipment shipment;

  const ShipmentCard({super.key, required this.shipment});

  Color _getStatusColor(String status) {
    switch (status) {
      case ShipmentStatus.newShipment:
        return const Color(0xFF2E9E5B);
      case ShipmentStatus.offerAccepted:
        return const Color(0xFF00B4D8);
      case ShipmentStatus.inExecution:
        return const Color(0xFFF78710);
      case ShipmentStatus.finished:
        return Colors.grey;
      case ShipmentStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(shipment.status);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShipmentDetailsScreen(shipment: shipment),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SvgPicture.asset(AppAssets.box),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ShipmentStatus.getArabicStatus(shipment.status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 3),
                      Text(
                        'رقم الشحنة: ${shipment.shipmentNumber}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // From / To with dotted line
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDottedTimeline(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'من',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shipment.fromAddress,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'الي',
                        style: TextStyle(
                          color: AppColors.primary2,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shipment.toAddress,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 10),

            // Footer: time + driver/status + price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Driver name if available
                if (shipment.driverName != null)
                  Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.truckFast,
                        size: 13,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        shipment.driverName!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                // Price
                Text(
                  '${shipment.price.toInt()} ج',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'تفاصيل الشحنة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedTimeline() {
    return Column(
      children: [
        const SizedBox(height: 4),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF1F4C9B),
            shape: BoxShape.circle,
          ),
        ),
        ...List.generate(
          4,
          (i) => Container(
            width: 1.2,
            height: 9,
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            color: const Color(0xFF1F4C9B).withValues(alpha: 0.4),
          ),
        ),
        Container(
          width: 7,
          height: 9,
          decoration: const BoxDecoration(
            color: Color(0xFFFFB000),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
