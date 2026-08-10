// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:we_deliver/core/theme/colors.dart';
import '../bloc/address_cubit.dart';
import '../bloc/address_state.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  static const String _mapStyle = '''
[
  { "elementType": "geometry", "stylers": [{ "color": "#f5f5f5" }] },
  { "featureType": "poi", "stylers": [{ "visibility": "off" }] },
  { "featureType": "road", "elementType": "geometry", "stylers": [{ "color": "#ffffff" }] },
  { "featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{ "color": "#757575" }] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [{ "color": "#dadada" }] },
  { "featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{ "color": "#616161" }] },
  { "featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{ "color": "#9e9e9e" }] },
  { "featureType": "transit", "stylers": [{ "visibility": "off" }] },
  { "featureType": "water", "elementType": "geometry", "stylers": [{ "color": "#c9d2d4" }] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [{ "color": "#9e9e9e" }] }
]
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'عناوين الاستلام',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<AddressCubit, AddressState>(
        builder: (context, state) {
          if (state is AddressLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          } else if (state is AddressError) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.message,
                      style: TextStyle(fontSize: 14.sp, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    ElevatedButton(
                      onPressed: () => context.read<AddressCubit>().loadAddresses(),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                    )
                  ],
                ),
              ),
            );
          } else if (state is AddressLoaded) {
            final addresses = state.addresses;
            if (addresses.isEmpty) {
              return Center(
                child: Text(
                  'لا يوجد عناوين محفوظة حالياً',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                return _buildAddressCard(context, addresses[index]);
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final cubit = context.read<AddressCubit>();
          Navigator.pushNamed(context, '/add-address').then((value) {
            if (value == true) {
              cubit.loadAddresses();
            }
          });
        },
        backgroundColor: AppColors.primary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(Icons.add, color: AppColors.background, size: 28.sp),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget _buildAddressCard(BuildContext context, SavedAddress address) {
    final latLng = LatLng(
      address.latitude ?? 30.0444,
      address.longitude ?? 31.2357,
    );

    return GestureDetector(
      onTap: () {
        final cubit = context.read<AddressCubit>();
        Navigator.pushNamed(
          context,
          '/edit-address',
          arguments: address,
        ).then((value) {
          if (value == true) {
            cubit.loadAddresses();
          }
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100.w,
              height: 100.h,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(12.r),
                  bottomRight: Radius.circular(12.r),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: latLng,
                    zoom: 14,
                  ),
                  liteModeEnabled: true,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  markers: {
                    Marker(
                      markerId: MarkerId(address.id),
                      position: latLng,
                    ),
                  },
                  onMapCreated: (controller) {
                    controller.setMapStyle(_mapStyle);
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${address.governorate} - ${address.city}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '${address.title}: ${address.address}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF888888),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (address.phone != null && address.phone!.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(
                        'الهاتف: ${address.phone}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFFBDBDBD),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
