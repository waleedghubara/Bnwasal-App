// ignore_for_file: strict_top_level_inference, use_build_context_synchronously

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/theme/app_assets.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_button.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import 'package:we_deliver/core/services/location_service.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:geocoding/geocoding.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_state.dart';
import '../../domain/entities/user_entity.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _cityController = TextEditingController();

  File? _pickedImage;
  bool _initialized = false;
  bool _isSaving = false;
  
  double? _latitude;
  double? _longitude;
  bool _fetchingLocation = false;
  String _locationStatus = 'لم يتم تحديد موقعك الجغرافي بعد';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retrieveLocation();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _storeNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _initFromUser(UserEntity user) {
    if (_initialized) return;
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _phoneController.text = user.phone;
    _storeNameController.text = user.storeName ?? '';
    _cityController.text = user.city ?? '';
    _latitude = user.latitude;
    _longitude = user.longitude;
    if (_latitude != null && _longitude != null) {
      _locationStatus = 'تم تحديد موقعك بنجاح ✅';
    }
    _initialized = true;
  }

  Future<void> _retrieveLocation() async {
    if (_fetchingLocation) return;
    if (!mounted) return;
    setState(() {
      _fetchingLocation = true;
      _locationStatus = 'جاري تحديد موقعك الجغرافي الحالي...';
    });

    try {
      final locationService = sl<LocationService>();
      final position = await locationService.getCurrentLocation();
      
      if (position != null) {
        String? resolvedCity;
        try {
          await setLocaleIdentifier("ar");
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            resolvedCity = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea;
          }
        } catch (e) {
          debugPrint('Native geocoding unavailable, switching to OSM Nominatim...');
          try {
            final dio = Dio();
            dio.options.headers['User-Agent'] = 'WeDeliverApp/1.0.0 (contact: support@wedeliver.com)';
            final response = await dio.get(
              'https://nominatim.openstreetmap.org/reverse',
              queryParameters: {
                'lat': position.latitude,
                'lon': position.longitude,
                'format': 'json',
                'accept-language': 'ar',
                'addressdetails': 1,
              },
            );
            if (response.statusCode == 200 && response.data != null) {
              final address = response.data['address'];
              if (address != null) {
                resolvedCity = address['city'] ?? 
                               address['town'] ?? 
                               address['village'] ?? 
                               address['suburb'] ?? 
                               address['state'];
              }
            }
          } catch (apiError) {
            debugPrint('OSM Nominatim Geocoding fallback error: $apiError');
          }
        }

        if (!mounted) return;
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          if (resolvedCity != null && resolvedCity.isNotEmpty) {
            _cityController.text = resolvedCity;
          }
          _locationStatus = 'تم تحديد موقعك بنجاح ✅';
        });
      } else {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'فشل تحديد الموقع. يرجى تفعيل الـ GPS وإعطاء الصلاحية.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'حدث خطأ أثناء الحصول على الموقع';
      });
    } finally {
      if (mounted) {
        setState(() {
          _fetchingLocation = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() => _pickedImage = File(picked.path));
    }
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    context.read<ProfileCubit>().updateProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      storeName: _storeNameController.text.trim().isEmpty
          ? null
          : _storeNameController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      profileImage: _pickedImage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تعديل بيانات الحساب',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileUpdateSuccess) {
            setState(() {
              _isSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تم تحديث البيانات بنجاح ✅',
                  textAlign: TextAlign.right,
                ),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context);
          } else if (state is ProfileError) {
            setState(() {
              _isSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, textAlign: TextAlign.right),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          // Pre-fill fields from loaded/updating state
          final user = state is ProfileLoaded
              ? state.user
              : state is ProfileUpdating
              ? state.user
              : null;
          if (user != null) _initFromUser(user);

          final isLoading = state is ProfileUpdating;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── Profile Image ──
                  _buildProfileImage(user),
                  const SizedBox(height: 36),

                  // ── First Name ──
                  _buildLabel('الاسم الأول'),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _firstNameController,
                    hintText: 'أدخل الاسم الأول',
                    rightWidget: _icon(FontAwesomeIcons.user),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Last Name ──
                  _buildLabel('الاسم الأخير'),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _lastNameController,
                    hintText: 'أدخل الاسم الأخير',
                    rightWidget: _icon(FontAwesomeIcons.user),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Phone ──
                  _buildLabel('رقم الهاتف'),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _phoneController,
                    hintText: 'أدخل رقم الهاتف',
                    keyboardType: TextInputType.phone,
                    rightWidget: _icon(FontAwesomeIcons.phone),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Store Name (Merchant only) ──
                  if (user?.role == 'merchant') ...[
                    _buildLabel('اسم المتجر'),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _storeNameController,
                      hintText: 'أدخل اسم المتجر',
                      rightWidget: _icon(FontAwesomeIcons.shop),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── City ──
                  _buildLabel('المدينة'),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _cityController,
                    hintText: 'أدخل المدينة',
                    rightWidget: _icon(FontAwesomeIcons.locationDot),
                  ),
                  const SizedBox(height: 24),

                  // ── Location Coordinates display ──
                  _buildLabel('الموقع الجغرافي الحالي للمتجر/الحساب'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _latitude != null ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.locationCrosshairs,
                          color: _latitude != null ? AppColors.primary : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _locationStatus,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _latitude != null ? Colors.black87 : Colors.grey.shade600,
                                ),
                              ),
                              if (_latitude != null && _longitude != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'خط العرض: ${_latitude!.toStringAsFixed(6)}  |  خط الطول: ${_longitude!.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_fetchingLocation)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                            onPressed: _retrieveLocation,
                            tooltip: 'تحديث الموقع',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Save Button ──
                  CustomButton(
                    text: 'حفظ التغييرات',
                    isLoading: isLoading || _isSaving,
                    onPressed: _save,
                    textColor: Colors.white,
                    borderRadius: 14,
                    height: 54,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImage(UserEntity? user) {
    final imageUrl = user?.profileImage != null
        ? '${EndPoint.imageBaseUrl}${user!.profileImage}'
        : null;

    return Center(
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFF0F0F0),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _pickedImage != null
                  ? Image.file(_pickedImage!, fit: BoxFit.cover)
                  : imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _defaultAvatar(),
                    )
                  : _defaultAvatar(),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Center(
      child: Image.asset(
        AppAssets.group,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.person, size: 50, color: Color(0xFFBDBDBD)),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    );
  }

  Widget _icon(data) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FaIcon(data, size: 18, color: AppColors.primary),
    );
  }
}
