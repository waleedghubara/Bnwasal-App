import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OfferSuccessScreen extends StatelessWidget {
  final int negotiatedPrice;

  const OfferSuccessScreen({super.key, required this.negotiatedPrice});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          centerTitle: true,
          title: Text(
            'ارسال العرض',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Blue Checkmark Icon
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF0F5FF),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1F4C9B).withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF4A80F0), Color(0xFF1F4C9B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Success Title
                Text(
                  'تم ارسال عرضك بنجاح',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Success Description
                Text(
                  'تم ارسال عرضك و سياتيك الرد بالموافقة او الرفض من قبل التاجر تابع الاشعارات',
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
