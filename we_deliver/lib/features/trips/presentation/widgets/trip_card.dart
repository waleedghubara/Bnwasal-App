import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/entities/trip.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  const TripCard({super.key, required this.trip});

  // LatLng _getLatLngForText(String text) {
  //   final cleanText = text.trim().toLowerCase();

  //   final Map<String, LatLng> coords = {
  //     // Alexandria Neighborhoods
  //     'سيدي بشر': const LatLng(31.2638, 30.0172),
  //     'ميامي': const LatLng(31.2680, 30.0240),
  //     'العصافرة': const LatLng(31.2721, 30.0335),
  //     'المندرة': const LatLng(31.2750, 30.0440),
  //     'المعمورة': const LatLng(31.2778, 30.0558),
  //     'أبو قير': const LatLng(31.3128, 30.0631),
  //     'ابو قير': const LatLng(31.3128, 30.0631),
  //     'سموحة': const LatLng(31.2089, 29.9489),
  //     'سيدي جابر': const LatLng(31.2210, 29.9390),
  //     'الرمل': const LatLng(31.2003, 29.9187),
  //     'لوران': const LatLng(31.2464, 29.9734),
  //     'العجمي': const LatLng(31.1328, 29.7928),
  //     'برج العرب': const LatLng(30.9167, 29.5833),
  //     'المنتزه': const LatLng(31.2764, 30.0150),
  //     'محرم بك': const LatLng(31.1965, 29.9180),
  //     'كليوباترا': const LatLng(31.2230, 29.9310),
  //     'سبورتنج': const LatLng(31.2180, 29.9270),
  //     'مصطفى كامل': const LatLng(31.2260, 29.9400),
  //     'سان ستيفانو': const LatLng(31.2440, 29.9650),
  //     'جليم': const LatLng(31.2410, 29.9600),
  //     'زيزينيا': const LatLng(31.2425, 29.9620),
  //     'الإبراهيمية': const LatLng(31.2110, 29.9200),
  //     'المنشية': const LatLng(31.2005, 29.8970),
  //     'البيطاش': const LatLng(31.1350, 29.8050),
  //     'الهانوفيل': const LatLng(31.1250, 29.7750),
  //     'الدخيلة': const LatLng(31.1390, 29.8210),
  //     'سوتير': const LatLng(31.2120, 29.9120),
  //     'أبيس': const LatLng(31.1850, 29.9790),

  //     // Cairo Neighborhoods
  //     'المعادي': const LatLng(29.9602, 31.2569),
  //     'مدينة نصر': const LatLng(30.0609, 31.3472),
  //     'مصر الجديدة': const LatLng(30.0917, 31.3250),
  //     'التجمع': const LatLng(30.0200, 31.4900),
  //     'الدقي': const LatLng(30.0382, 31.2115),
  //     'المهندسين': const LatLng(30.0614, 31.1982),
  //     'وسط البلد': const LatLng(30.0444, 31.2357),
  //     'شبرا': const LatLng(30.0833, 31.2500),
  //     'حلوان': const LatLng(29.8403, 31.2987),
  //     'الزمالك': const LatLng(30.0632, 31.2198),

  //     // Main Governorates (Fallbacks)
  //     'الإسكندرية': const LatLng(31.2001, 29.9187),
  //     'اسكندرية': const LatLng(31.2001, 29.9187),
  //     'القاهرة': const LatLng(30.0444, 31.2357),
  //     'قاهره': const LatLng(30.0444, 31.2357),
  //     'الجيزة': const LatLng(30.0130, 31.2089),
  //     'جيزة': const LatLng(30.0130, 31.2089),
  //     'القليوبية': const LatLng(30.4591, 31.1858),
  //     'الغربية': const LatLng(30.8754, 31.0335),
  //     'الدقهلية': const LatLng(31.0409, 31.3785),
  //     'الشرقية': const LatLng(30.5877, 31.5020),
  //     'المنوفية': const LatLng(30.5510, 31.0104),
  //     'البحيرة': const LatLng(31.0364, 30.4688),
  //     'كفر الشيخ': const LatLng(31.1107, 30.9388),
  //     'دمياط': const LatLng(31.4175, 31.8144),
  //     'بورسعيد': const LatLng(31.2653, 32.3019),
  //     'الإسماعيلية': const LatLng(30.6043, 32.2723),
  //     'السويس': const LatLng(29.9668, 32.5498),
  //     'الفيوم': const LatLng(29.3084, 30.8428),
  //     'بني سويف': const LatLng(29.0744, 31.0978),
  //     'المنيا': const LatLng(28.0871, 30.7618),
  //     'أسيوط': const LatLng(27.1783, 31.1859),
  //     'سوهاج': const LatLng(26.5591, 31.6957),
  //     'قنا': const LatLng(26.1551, 32.7160),
  //     'الأقصر': const LatLng(25.6872, 32.6396),
  //     'أسوان': const LatLng(24.0889, 32.8998),
  //     'مطروح': const LatLng(31.3547, 27.2373),
  //     'البحر الأحمر': const LatLng(27.2579, 33.8116),
  //     'الوادى الجديد': const LatLng(25.4390, 30.5586),
  //   };

  //   for (final entry in coords.entries) {
  //     if (cleanText.contains(entry.key.toLowerCase())) {
  //       return entry.value;
  //     }
  //   }

  //   return const LatLng(30.0444, 31.2357); // Cairo fallback
  // }

  @override
  Widget build(BuildContext context) {
    // final fromLatLng = _getLatLngForText(trip.fromCity ?? trip.from);
    // final toLatLng = _getLatLngForText(trip.toCity ?? trip.to);

    // // final centerLatLng = LatLng(
    // //   (fromLatLng.latitude + toLatLng.latitude) / 2,
    // //   (fromLatLng.longitude + toLatLng.longitude) / 2,
    // // );

    // // double zoom = 12.0;
    // // final double latDiff = (fromLatLng.latitude - toLatLng.latitude).abs();
    // // final double lngDiff = (fromLatLng.longitude - toLatLng.longitude).abs();
    // // final double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    // // if (maxDiff > 1.5) {
    // //   zoom = 6.0;
    // // } else if (maxDiff > 0.5) {
    // //   zoom = 8.0;
    // // } else if (maxDiff > 0.1) {
    // //   zoom = 10.0;
    // // }

    return Opacity(
      opacity: trip.isExpired ? 0.6 : 1.0,
      child: Container(
        margin: EdgeInsets.only(bottom: 18.h),
        height: trip.isExpired ? 142.h : 120.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8.r),
                bottomRight: Radius.circular(8.r),
              ),
              // GoogleMap(
              //     initialCameraPosition: CameraPosition(
              //       target: centerLatLng,
              //       zoom: zoom,
              //     ),
              //     markers: {
              //       Marker(
              //         markerId: const MarkerId('start'),
              //         position: fromLatLng,
              //         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              //       ),
              //       if (fromLatLng != toLatLng)
              //         Marker(
              //           markerId: const MarkerId('dest'),
              //           position: toLatLng,
              //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              //         ),
              //     },
              //     zoomControlsEnabled: false,
              //     myLocationButtonEnabled: false,
              //     myLocationEnabled: false,
              //     compassEnabled: false,
              //     scrollGesturesEnabled: false,
              //     zoomGesturesEnabled: false,
              //     tiltGesturesEnabled: false,
              //     rotateGesturesEnabled: false,
              //     mapToolbarEnabled: false,
              //   ),
              child: SizedBox(
                width: 110.w,
                height: trip.isExpired ? 142.h : 120.h,
                child: Image.asset('assets/images/map.png'),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trip.isExpired) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              color: Colors.red.shade700,
                              size: 12.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'منتهية',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 6.h),
                    ],
                    _buildLocationRow('من', trip.from),
                    SizedBox(height: 12.h),
                    _buildLocationRow('إلى', trip.to),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(String label, String location) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 8.w,
              height: 8.h,
              decoration: BoxDecoration(
                color: label == 'من'
                    ? const Color(0xFFE99863)
                    : const Color(0xFF204CB3),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13.sp),
              ),
              Text(
                location,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
