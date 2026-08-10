import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/routes/routes.dart';

import '../widgets/trip_card.dart';
import '../manager/trip_cubit.dart';
import '../manager/trip_state.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'رحلاتي',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: BlocBuilder<TripCubit, TripState>(
          builder: (context, state) {
            if (state is TripLoading && context.read<TripCubit>().allTrips.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            } else if (state is TripError && context.read<TripCubit>().allTrips.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 64.sp),
                      SizedBox(height: 16.h),
                      Text(
                        state.message,
                        style: TextStyle(color: Colors.red, fontSize: 16.sp, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => context.read<TripCubit>().loadTrips(),
                        child: const Text('إعادة المحاولة'),
                      )
                    ],
                  ),
                ),
              );
            }

            final currentTrips = context.read<TripCubit>().allTrips;

            if (currentTrips.isEmpty) {
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => context.read<TripCubit>().loadTrips(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: _buildEmptyState(),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => context.read<TripCubit>().loadTrips(),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                itemCount: currentTrips.length,
                itemBuilder: (context, index) {
                  final trip = currentTrips[index];
                  return GestureDetector(
                    onTap: trip.isExpired
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'هذه الرحلة منتهية ولا يمكن تعديلها',
                                  textAlign: TextAlign.right,
                                ),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : () async {
                            await Navigator.pushNamed(
                              context,
                              Routes.editTrip,
                              arguments: trip,
                            );
                            if (context.mounted) {
                              context.read<TripCubit>().loadTrips();
                            }
                          },
                    child: TripCard(trip: trip),
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          splashColor: AppColors.primary,
          onPressed: () async {
            await Navigator.pushNamed(context, Routes.addTrip);
            if (context.mounted) {
              context.read<TripCubit>().loadTrips();
            }
          },
          backgroundColor: AppColors.primary,
          elevation: 2,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 100.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 24.h),
          Text(
            'لم يتم العثور علي رحلات',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              'ستظهر رحلاتك هنا بمجرد اضافة المسار الخاص بك اضغط علي اضافة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}
