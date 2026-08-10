// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/theme/typography.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';
import '../../../shipment/presentation/pages/map_picker_screen.dart';
import '../bloc/address_cubit.dart';
import '../bloc/address_state.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/appsflyer_service.dart';

class AddEditAddressScreen extends StatefulWidget {
  final bool isEdit;
  final SavedAddress? address;

  const AddEditAddressScreen({
    super.key,
    this.isEdit = false,
    this.address,
  });

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailController = TextEditingController();
  String? _selectedGovernorate;
  String? _selectedCity;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.address != null) {
      final addr = widget.address!;
      _selectedGovernorate = addr.governorate.isNotEmpty ? addr.governorate : null;
      _selectedCity = addr.city.isNotEmpty ? addr.city : null;
      _locationController.text = addr.address;
      _nameController.text = addr.title;
      _phoneController.text = addr.phone ?? '';
      _detailController.text = addr.address;
      _latitude = addr.latitude;
      _longitude = addr.longitude;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خدمات الموقع غير مفعلة')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض إذن الوصول للموقع')),
          );
        }
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      _latitude = position.latitude;
      _longitude = position.longitude;

      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذّر تحديد العنوان، تأكد من الاتصال بالإنترنت'),
            ),
          );
          print('فشل في تحديد الموقع: $e');
        }
        return;
      }

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _locationController.text =
              '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}';
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('فشل في تحديد الموقع: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في تحديد الموقع')),
        );
      }
    }
  }

  Future<void> _pickLocationFromMap() async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: 'اختر موقع العنوان',
          initialAddress: _locationController.text.isNotEmpty ? _locationController.text : null,
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _locationController.text = result.address;
        _latitude = result.latitude;
        _longitude = result.longitude;
        // Optionally update details if they are empty
        if (_detailController.text.isEmpty) {
          _detailController.text = result.address;
        }
      });
    }
  }

  void _onSavePressed() {
    if (_formKey.currentState!.validate()) {
      context.read<AddressCubit>().saveAddress(
            id: widget.isEdit ? widget.address?.id : null,
            title: _nameController.text.trim(),
            address: _detailController.text.trim().isNotEmpty 
                ? _detailController.text.trim()
                : _locationController.text.trim(),
            governorate: _selectedGovernorate ?? '',
            city: _selectedCity ?? '',
            latitude: _latitude,
            longitude: _longitude,
            phone: _phoneController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isEdit ? 'تعديل عنوان جديد' : 'اضافة عنوان جديد',
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
        actions: [
          if (widget.isEdit && widget.address != null)
            BlocBuilder<AddressCubit, AddressState>(
              builder: (context, state) {
                if (state is AddressLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                      ),
                    ),
                  );
                }
                return TextButton(
                  onPressed: () {
                    context.read<AddressCubit>().removeAddress(widget.address!.id);
                  },
                  child: Text(
                    'حذف',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: BlocListener<AddressCubit, AddressState>(
        listener: (context, state) {
          if (state is AddressActionSuccess) {
            if (!widget.isEdit) {
              sl<AppsFlyerService>().logEvent('af_add_address', {
                'address_title': _nameController.text.trim(),
                'governorate': _selectedGovernorate ?? '',
                'city': _selectedCity ?? '',
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          } else if (state is AddressError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),
                _buildFieldLabel('الموقع'),
                SizedBox(height: 8.h),
                CustomTextField(
                  controller: _locationController,
                  hintText: 'اختر الموقع',
                  readOnly: true,
                  onTap: _pickLocationFromMap,
                  rightWidget: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                  ),
                  leftWidget: IconButton(
                    icon: Icon(
                      Icons.my_location,
                      color: AppColors.primary2,
                      size: 20.sp,
                    ),
                    onPressed: _getCurrentLocation,
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'الموقع مطلوب' : null,
                ),
                SizedBox(height: 20.h),
                _buildFieldLabel('اسم المكان( البيت، المحل)'),
                SizedBox(height: 8.h),
                CustomTextField(
                  controller: _nameController,
                  rightWidget: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                  ),
                  hintText: 'اسم المكان',
                  validator: (v) => v == null || v.isEmpty ? 'اسم المكان مطلوب' : null,
                ),
                SizedBox(height: 20.h),
                _buildFieldLabel('رقم الهاتف'),
                SizedBox(height: 8.h),
                CustomTextField(
                  controller: _phoneController,
                  hintText: 'رقم الهاتف',
                  keyboardType: TextInputType.phone,
                  rightWidget: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.phone_outlined,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'رقم الهاتف مطلوب' : null,
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('المحافظة'),
                          SizedBox(height: 8.h),
                          _buildGovernorateDropdown(),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('المدينة'),
                          SizedBox(height: 8.h),
                          _buildCityDropdown(),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                _buildFieldLabel('العنوان بالتفصيل'),
                SizedBox(height: 8.h),
                CustomTextField(
                  controller: _detailController,
                  hintText: 'العنوان بالتفصيل',
                  rightWidget: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'العنوان بالتفصيل مطلوب' : null,
                ),
                SizedBox(height: 60.h),
                _buildSaveButton(),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF333333),
      ),
    );
  }

  Widget _buildGovernorateDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGovernorate,
      alignment: Alignment.centerRight,
      hint: Text(
        'المحافظة',
        style: AppTypography.h5.copyWith(
          color: const Color(0xFFBDBDBD),
          fontSize: 14.sp,
        ),
      ),
      items: EgyptLocations.governorates.map((gov) {
        return DropdownMenuItem(
          value: gov,
          alignment: Alignment.centerRight,
          child: Text(
            gov,
            style: AppTypography.h6.copyWith(
              color: Colors.black,
              fontSize: 14.sp,
            ),
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedGovernorate = val;
          _selectedCity = null;
        });
      },
      decoration: _dropdownDecoration(),
      validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
    );
  }

  Widget _buildCityDropdown() {
    final cities = _selectedGovernorate != null
        ? EgyptLocations.citiesFor(_selectedGovernorate!)
        : <String>[];
    return DropdownButtonFormField<String>(
      initialValue: _selectedCity,
      alignment: Alignment.centerRight,
      hint: Text(
        'المدينة',
        style: AppTypography.h6.copyWith(color: const Color(0xFFBDBDBD), fontSize: 14.sp),
      ),
      items: cities.map((city) {
        return DropdownMenuItem(
          value: city,
          alignment: Alignment.centerRight,
          child: Text(
            city,
            style: AppTypography.h6.copyWith(color: Colors.black),
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedCity = val;
        });
      },
      decoration: _dropdownDecoration(),
      validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: BlocBuilder<AddressCubit, AddressState>(
        builder: (context, state) {
          final isLoading = state is AddressLoading;
          return ElevatedButton(
            onPressed: isLoading ? null : _onSavePressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF204CB3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'حفظ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          );
        },
      ),
    );
  }
}
