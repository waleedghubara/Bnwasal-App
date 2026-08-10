// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/features/home/views/home_user.dart';
import 'package:we_deliver/features/home/views/intro_video_screen.dart';
import 'package:we_deliver/features/wallet/presentation/pages/wallet_screen.dart';

import '../../../core/theme/app_assets.dart';
import 'package:we_deliver/features/home/views/home_delivery.dart';
import 'package:we_deliver/features/trips/presentation/pages/trips_screen.dart';
import '../../order/presentation/pages/orders_screen.dart';
import '../../shipment/presentation/pages/shipments_screen.dart';

import 'package:we_deliver/core/services/location_service.dart';
import 'package:we_deliver/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:we_deliver/core/routes/routes.dart';
import 'package:we_deliver/features/profile/presentation/bloc/profile_state.dart';
import '../../profile/presentation/pages/profile_screen.dart';
import '../../profile/presentation/bloc/profile_cubit.dart';
import '../../../core/di/injection_container.dart';
import '../../trips/presentation/manager/trip_cubit.dart';

class MainLayoutScreen extends StatefulWidget {
  final bool isDelivery;
  const MainLayoutScreen({super.key, this.isDelivery = false});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  late final List<Widget> _screens;
  bool _showIntroVideo = false;
  String _videoUrl = '';

  @override
  void initState() {
    super.initState();
    _screens = [
      widget.isDelivery ? const HomeDelivery() : const HomeUserScreen(),
      widget.isDelivery ? const TripsScreen() : const OrdersScreen(),
      ShipmentsScreen(isDelivery: widget.isDelivery),
      const WalletScreen(),
      const ProfileScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateLocationSilently();
      _checkIntroVideo();
    });
  }

  Future<void> _checkIntroVideo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final watched = prefs.getBool('watched_intro_video') ?? false;
      if (!watched) {
        final videoKey = widget.isDelivery
            ? 'captain_video_url'
            : 'merchant_video_url';
        final url = prefs.getString(videoKey) ?? '';
        if (url.isNotEmpty) {
          setState(() {
            _videoUrl = url;
            _showIntroVideo = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking intro video: $e');
    }
  }

  Future<void> _updateLocationSilently() async {
    try {
      final locationService = sl<LocationService>();
      final hasPermission = await locationService.handleLocationPermission();
      if (hasPermission) {
        final position = await locationService.getCurrentLocation();
        if (position != null) {
          await sl<UpdateProfileUseCase>().call(
            latitude: position.latitude,
            longitude: position.longitude,
          );
          debugPrint(
            'Silent Location Update success: lat=${position.latitude}, lng=${position.longitude}',
          );
        }
      }
    } catch (e) {
      debugPrint('Silent Location Update failed: $e');
    }
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileCubit>(
          create: (context) => sl<ProfileCubit>()..loadProfile(),
        ),
        if (widget.isDelivery)
          BlocProvider<TripCubit>(
            create: (context) => sl<TripCubit>()..loadTrips(),
          ),
      ],
      child: BlocListener<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded) {
            final user = state.user;
            if (user.isProfileComplete == false) {
              final missingDetails = user.missingDetails ?? [];
              if (missingDetails.contains('documents')) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.identityVerification,
                  (route) => false,
                  arguments: {'step': 'upload'},
                );
              } else if (missingDetails.contains('vehicle')) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.identityVerification,
                  (route) => false,
                  arguments: {'step': 'selectVehicle'},
                );
              } else {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.identityVerification,
                  (route) => false,
                );
              }
            }
          }
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: Colors.white,
                body: IndexedStack(index: _currentIndex, children: _screens),
                bottomNavigationBar: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: Colors.white,
                    selectedItemColor: AppColors.primary,
                    unselectedItemColor: Colors.grey.shade400,
                    selectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    elevation: 0,
                    items: [
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: EdgeInsets.only(bottom: 6.0, top: 8.0),
                          child: FaIcon(FontAwesomeIcons.home, size: 26),
                        ),
                        label: 'الرئيسية',
                      ),
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: EdgeInsets.only(bottom: 6.0, top: 8.0),
                          child: FaIcon(
                            widget.isDelivery
                                ? FontAwesomeIcons.truckFast
                                : FontAwesomeIcons.shoppingBasket,
                            size: 26,
                          ),
                        ),
                        label: widget.isDelivery ? 'رحلاتي' : 'الطلبات',
                      ),
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: EdgeInsets.only(bottom: 6.0, top: 8.0),
                          child: widget.isDelivery
                              ? FaIcon(FontAwesomeIcons.tasks, size: 26)
                              : SvgPicture.asset(
                                  AppAssets.boxh,
                                  colorFilter: ColorFilter.mode(
                                    _currentIndex == 2
                                        ? AppColors.primary
                                        : Colors.grey,
                                    BlendMode.srcIn,
                                  ),
                                  width: 29,
                                  height: 29,
                                ),
                        ),
                        label: widget.isDelivery ? 'المهام' : 'الشحنات',
                      ),
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: EdgeInsets.only(bottom: 6.0, top: 8.0),
                          child: SvgPicture.asset(
                            AppAssets.walleth,
                            colorFilter: ColorFilter.mode(
                              _currentIndex == 3
                                  ? AppColors.primary
                                  : Colors.grey,
                              BlendMode.srcIn,
                            ),
                            width: 24,
                            height: 24,
                          ),
                        ),
                        label: 'المحفظة',
                      ),
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: EdgeInsets.only(bottom: 6.0, top: 8.0),
                          child: FaIcon(FontAwesomeIcons.user, size: 26),
                        ),
                        label: 'الملف الشخصي',
                      ),
                    ],
                  ),
                ),
              ),
              if (_showIntroVideo)
                IntroVideoScreen(
                  videoUrl: _videoUrl,
                  onDismiss: () {
                    setState(() {
                      _showIntroVideo = false;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
