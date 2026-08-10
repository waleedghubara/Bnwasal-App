// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import 'package:we_deliver/features/shipment/data/datasources/egypt_locations.dart';
import 'package:we_deliver/features/shipment/data/models/shipment_model.dart';
import 'package:we_deliver/features/shipment/presentation/manager/shipment_cubit.dart';
import 'package:we_deliver/features/shipment/presentation/pages/map_picker_screen.dart';
import 'package:we_deliver/features/shipment/presentation/widgets/shipment_pickers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/location_service.dart';
import '../../../profile/presentation/bloc/address_cubit.dart';
import '../../data/datasources/delivery_pricing.dart';
import '../../domain/entities/shipment.dart';
import '../widgets/price_suggestion_widget.dart';
import '../../../../core/api/end_point.dart';
import '../../../../core/cache/cache_helper.dart';

class AddShipmentScreen extends StatefulWidget {
  final ShipmentCubit cubit;
  final bool isMultiShipment;
  final Shipment? editingShipment;

  const AddShipmentScreen({
    super.key,
    required this.cubit,
    this.isMultiShipment = false,
    this.editingShipment,
  });

  @override
  State<AddShipmentScreen> createState() => _AddShipmentScreenState();
}

class _AddShipmentScreenState extends State<AddShipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  final _toGovernorateController = TextEditingController();
  final _toAreaController = TextEditingController();
  final _fromGovernorateController = TextEditingController();
  final _fromAreaController = TextEditingController();
  final _deliveryDateController = TextEditingController();
  bool isWithoutAdvance = false;
  TextEditingController priceController = TextEditingController();
  TextEditingController weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _couponController = TextEditingController();

  bool _isCouponValid = false;
  double _discountApplied = 0.0;
  String? _couponError;
  bool _isValidatingCoupon = false;

  Future<void> _validateCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    try {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);
      final price = double.tryParse(_priceController.text) ?? 0.0;

      final response = await sl<Dio>().get(
        '${EndPoint.baseUrl}coupons/validate',
        queryParameters: {'code': code, 'price': price},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] == 1 && responseData['valid'] == true) {
        final data = responseData['data'] as Map<String, dynamic>;
        setState(() {
          _isCouponValid = true;
          _discountApplied = (data['discountApplied'] as num).toDouble();
          _couponError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تطبيق الكوبون بنجاح! خصم ${_discountApplied.toInt()} ج.م',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isCouponValid = false;
          _discountApplied = 0.0;
          _couponError = responseData['message'] ?? 'كوبون غير صالح';
        });
      }
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      setState(() {
        _isCouponValid = false;
        _discountApplied = 0.0;
        _couponError = errorData['message'] ?? 'خطأ في التحقق من الكوبون';
      });
    } catch (e) {
      setState(() {
        _isCouponValid = false;
        _discountApplied = 0.0;
        _couponError = 'خطأ غير متوقع';
      });
    } finally {
      setState(() {
        _isValidatingCoupon = false;
      });
    }
  }

  // From address
  String? _fromGovernorate;
  String? _fromCity;
  double? _fromLatitude;
  double? _fromLongitude;

  // To address
  String? _toGovernorate;
  String? _toCity;
  double? _toLatitude;
  double? _toLongitude;

  bool isFragile = false;

  // Product image (single mode)
  File? _productImage;
  // Product images (multi mode)
  final List<File> _productImages = [];
  final _picker = ImagePicker();
  final List<Shipment> _shipments = [];

  @override
  void initState() {
    super.initState();
    if (widget.editingShipment != null) {
      final s = widget.editingShipment!;
      _titleController.text = s.title ?? '';
      _fromController.text = s.fromAddress;
      _toController.text = s.toAddress;
      _fromGovernorate = s.fromGovernorate;
      _fromGovernorateController.text = s.fromGovernorate ?? '';
      _fromCity = s.fromArea;
      _fromAreaController.text = s.fromArea ?? '';
      _toGovernorate = s.toGovernorate;
      _toGovernorateController.text = s.toGovernorate ?? '';
      _toCity = s.toArea;
      _toAreaController.text = s.toArea ?? '';
      _priceController.text = s.price.toInt().toString();
      _notesController.text = s.notes ?? '';
      priceController.text = s.price.toInt().toString();
      weightController.text = s.weight?.toInt().toString() ?? '';
      isFragile = s.isFragile;
      isWithoutAdvance = s.isWithoutAdvance;
      _fromLatitude = s.merchantLatitude;
      _fromLongitude = s.merchantLongitude;
      _toLatitude = s.toLatitude;
      _toLongitude = s.toLongitude;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefillPickupAddress();
      });
    }
  }

  Future<void> _prefillPickupAddress() async {
    if (_fromController.text.isNotEmpty) return;
    debugPrint('[AddShipmentScreen] Prefilling pickup location on launch...');
    try {
      final locService = sl<LocationService>();
      final position = await locService.getCurrentLocation();
      if (position != null) {
        final result = await locService.reverseGeocodeGoogle(
          position.latitude,
          position.longitude,
        );
        if (result != null && mounted && _fromController.text.isEmpty) {
          setState(() {
            _fromController.text = result.address;
            _fromLatitude = result.latitude;
            _fromLongitude = result.longitude;
            if (result.governorate != null && result.governorate!.isNotEmpty) {
              _fromGovernorate = result.governorate;
              _fromGovernorateController.text = result.governorate!;
            }
            if (result.city != null && result.city!.isNotEmpty) {
              _fromCity = result.city;
              _fromAreaController.text = result.city!;
            }
          });
          debugPrint(
            '[AddShipmentScreen] Successfully prefilled pickup address: ${result.address}',
          );
        }
      }
    } catch (e) {
      debugPrint('[AddShipmentScreen] Error prefilling pickup location: $e');
    }
  }

  void _resetForm() {
    _titleController.clear();
    _fromController.clear();
    _toController.clear();
    _fromGovernorateController.clear();
    _fromAreaController.clear();
    _toGovernorateController.clear();
    _toAreaController.clear();
    _deliveryDateController.clear();
    _priceController.clear();
    _notesController.clear();
    priceController.clear();
    weightController.clear();
    setState(() {
      _fromGovernorate = null;
      _fromCity = null;
      _fromLatitude = null;
      _fromLongitude = null;
      _toGovernorate = null;
      _toCity = null;
      _toLatitude = null;
      _toLongitude = null;

      _productImage = null;
      _productImages.clear();
      isFragile = false;
      isWithoutAdvance = false;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _showImageSourceBottomSheet(
    BuildContext context,
    Function(File) onImagePicked,
  ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'اختر مصدر الصورة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        final picked = await _picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                        );
                        if (picked != null) {
                          onImagePicked(File(picked.path));
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              size: 32,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'الكاميرا',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        final picked = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (picked != null) {
                          onImagePicked(File(picked.path));
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.photo_library_rounded,
                              size: 32,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'المعرض',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    _showImageSourceBottomSheet(context, (file) {
      setState(() => _productImage = file);
    });
  }

  Future<void> _pickMultiImage() async {
    _showImageSourceBottomSheet(context, (file) {
      setState(() => _productImages.add(file));
    });
  }

  void _removeImage(int index) {
    setState(() => _productImages.removeAt(index));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _fromGovernorateController.dispose();
    _fromAreaController.dispose();
    _toGovernorateController.dispose();
    _toAreaController.dispose();
    _deliveryDateController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    priceController.dispose();
    weightController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.editingShipment == null) {
      if (widget.isMultiShipment && _productImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يرجى إضافة صورة واحدة على الأقل للشحنة',
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!widget.isMultiShipment && _productImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إضافة صورة للشحنة', textAlign: TextAlign.right),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (_formKey.currentState!.validate()) {
      if (widget.editingShipment != null) {
        final updatedShipment = ShipmentModel(
          id: widget.editingShipment!.id,
          shipmentNumber: widget.editingShipment!.shipmentNumber,
          title: _titleController.text.trim(),
          fromAddress: _fromController.text.trim(),
          toAddress: _toController.text.trim(),
          fromGovernorate: _fromGovernorate,
          fromArea: _fromCity,
          toGovernorate: _toGovernorate,
          toArea: _toCity,
          toLatitude: _toLatitude,
          toLongitude: _toLongitude,
          merchantLatitude: _fromLatitude,
          merchantLongitude: _fromLongitude,
          status: widget.editingShipment!.status,
          price: double.tryParse(_priceController.text) ?? 0,
          weight: double.tryParse(weightController.text) ?? 0,
          notes: _notesController.text.trim(),
          isFragile: isFragile,
          isWithoutAdvance: isWithoutAdvance,
          images: _productImages.isNotEmpty
              ? List.from(_productImages)
              : (_productImage != null ? [_productImage!] : null),
          createdAt: widget.editingShipment!.createdAt,
        );

        widget.cubit.updateShipment(updatedShipment).then((_) {
          if (mounted) {
            if (widget.cubit.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.cubit.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تعديل الشحنة بنجاح!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            }
          }
        });
      } else {
        final newShipment = ShipmentModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          shipmentNumber:
              'H${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
          title: _titleController.text.trim(),
          fromAddress: _fromController.text.trim(),
          toAddress: _toController.text.trim(),
          fromGovernorate: _fromGovernorate,
          fromArea: _fromCity,
          toGovernorate: _toGovernorate,
          toArea: _toCity,
          toLatitude: _toLatitude,
          toLongitude: _toLongitude,
          merchantLatitude: _fromLatitude,
          merchantLongitude: _fromLongitude,
          status: ShipmentStatus.newShipment,
          price: double.tryParse(_priceController.text) ?? 0,
          weight: double.tryParse(weightController.text) ?? 0,
          notes: _notesController.text.trim(),
          isFragile: isFragile,
          isWithoutAdvance: isWithoutAdvance,
          images: _productImages.isNotEmpty
              ? List.from(_productImages)
              : (_productImage != null ? [_productImage!] : null),
          createdAt: DateTime.now(),
          couponCode: _isCouponValid
              ? _couponController.text.trim().toUpperCase()
              : null,
        );

        widget.cubit.addShipment(newShipment).then((_) {
          if (mounted) {
            if (widget.cubit.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.cubit.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
            } else {
              setState(() {
                _shipments.add(newShipment);
              });

              _resetForm();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تمت إضافة الشحنة بنجاح! ابدأ إدخال بيانات الشحنة التالية',
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        });
      }
    }
  }

  void _showSavedAddresses(bool isFrom) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (context) => sl<AddressCubit>(),
        child: SavedAddressesSheet(
          isPickup: isFrom,
          onSelect: (addr) {
            if (addr.id == 'custom_map') {
              _openMapPicker(isFrom, focusSearch: false);
              return;
            }
            if (addr.id == 'search_address') {
              _openMapPicker(isFrom, focusSearch: true);
              return;
            }
            setState(() {
              if (isFrom) {
                _fromController.text = addr.address;
                _fromGovernorateController.text = addr.governorate;
                _fromAreaController.text = addr.city;
                _fromGovernorate = addr.governorate;
                _fromCity = addr.city;
                _fromLatitude = addr.latitude;
                _fromLongitude = addr.longitude;
              } else {
                _toController.text = addr.address;
                _toGovernorateController.text = addr.governorate;
                _toAreaController.text = addr.city;
                _toGovernorate = addr.governorate;
                _toCity = addr.city;
                _toLatitude = addr.latitude;
                _toLongitude = addr.longitude;
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _openMapPicker(bool isFrom, {bool focusSearch = false}) async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: isFrom ? 'اختيار موقع الاستلام' : 'اختيار موقع التسليم',
          isPickup: isFrom,
          focusSearch: focusSearch,
          initialAddress: isFrom
              ? (_fromController.text.isNotEmpty ? _fromController.text : null)
              : (_toController.text.isNotEmpty ? _toController.text : null),
          initialLatitude: isFrom ? _fromLatitude : _toLatitude,
          initialLongitude: isFrom ? _fromLongitude : _toLongitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isFrom) {
          _fromController.text = result.address;
          _fromLatitude = result.latitude;
          _fromLongitude = result.longitude;
          if (result.governorate != null && result.governorate!.isNotEmpty) {
            _fromGovernorate = result.governorate;
            _fromGovernorateController.text = result.governorate!;
          }
          if (result.city != null && result.city!.isNotEmpty) {
            _fromCity = result.city;
            _fromAreaController.text = result.city!;
          }
        } else {
          _toController.text = result.address;
          _toLatitude = result.latitude;
          _toLongitude = result.longitude;
          if (result.governorate != null && result.governorate!.isNotEmpty) {
            _toGovernorate = result.governorate;
            _toGovernorateController.text = result.governorate!;
          }
          if (result.city != null && result.city!.isNotEmpty) {
            _toCity = result.city;
            _toAreaController.text = result.city!;
          }
        }
      });
    }
  }

  // Show governorate picker
  void _showGovernoratePicker(bool isFrom) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickerSheet(
        title: 'اختر المحافظة',
        items: EgyptLocations.governorates,
        selected: isFrom ? _fromGovernorate : _toGovernorate,
        onSelect: (gov) {
          setState(() {
            if (isFrom) {
              _fromGovernorate = gov;
              _fromGovernorateController.text = gov;
              _fromCity = null;
              _fromAreaController.clear();
            } else {
              _toGovernorate = gov;
              _toGovernorateController.text = gov;
              _toCity = null;
              _toAreaController.clear();
            }
          });
        },
      ),
    );
  }

  // Show city picker
  void _showCityPicker(bool isFrom) {
    final gov = isFrom ? _fromGovernorate : _toGovernorate;
    if (gov == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر المحافظة أولاً'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickerSheet(
        title: 'اختر المنطقة',
        items: EgyptLocations.citiesFor(gov),
        selected: isFrom ? _fromCity : _toCity,
        onSelect: (city) => setState(() {
          if (isFrom) {
            _fromCity = city;
            _fromAreaController.text = city;
          } else {
            _toCity = city;
            _toAreaController.text = city;
          }
        }),
      ),
    );
  }

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
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios,
                size: 16,
                color: Colors.black87,
              ),
            ),
          ),
          title: Text(
            widget.editingShipment != null ? 'تعديل الشحنة' : 'إضافة شحنة',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField(
                  label: 'محتوى الشحنة *',
                  hint: 'مثال: ملابس، إلكترونيات، إلخ...',
                  controller: _titleController,
                  prefixIcon: FontAwesomeIcons.box,
                  prefixColor: AppColors.primary,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'عنوان الاستلام ',
                  hint: 'اختار من العناوين المحفوظة او ادخل عنوان جديد',
                  controller: _fromController,
                  prefixIcon: FontAwesomeIcons.locationDot,
                  suffixIcon: FontAwesomeIcons.chevronDown,
                  prefixColor: const Color(0xFFE05B3A),
                  onTap: () => _showSavedAddresses(true),
                  readOnly: true,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        label: 'المحافظة',
                        hint: 'مثال: الاسكندرية',
                        prefixIcon: FontAwesomeIcons.mapPin,
                        prefixColor: const Color(0xFFE05B3A),
                        suffixIcon: FontAwesomeIcons.chevronDown,
                        suffixColor: AppColors.primary,
                        controller: _fromGovernorateController,
                        onTap: () => _showGovernoratePicker(true),
                        readOnly: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _buildField(
                        label: 'المنطقة',
                        hint: 'مثال: الرمل',
                        prefixIcon: FontAwesomeIcons.flag,
                        suffixIcon: FontAwesomeIcons.chevronDown,
                        suffixColor: AppColors.primary,
                        controller: _fromAreaController,
                        onTap: () => _showCityPicker(true),
                        readOnly: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'عنوان التسليم',
                  hint: 'مثال: العجمي الهانوفيل',
                  controller: _toController,
                  prefixIcon: FontAwesomeIcons.locationDot,
                  prefixColor: const Color(0xFFE05B3A),
                  suffixIcon: FontAwesomeIcons.chevronDown,
                  onTap: () => _showSavedAddresses(false),
                  readOnly: true,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        label: 'المحافظة',
                        hint: 'مثال: الاسكندرية',
                        prefixIcon: FontAwesomeIcons.mapPin,
                        suffixIcon: FontAwesomeIcons.chevronDown,
                        controller: _toGovernorateController,
                        onTap: () => _showGovernoratePicker(false),
                        readOnly: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _buildField(
                        label: 'المنطقة',
                        hint: 'مثال: العجمي ',
                        prefixIcon: FontAwesomeIcons.flag,
                        suffixIcon: FontAwesomeIcons.chevronDown,
                        controller: _toAreaController,
                        onTap: () => _showCityPicker(false),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                PriceSuggestionWidget(
                  fromArea: _fromCity,
                  toArea: _toCity,
                  priceController: _priceController,
                ),

                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _buildField(
                        label: 'كوبون الخصم (اختياري)',
                        hint: 'أدخل رمز الكوبون هنا',
                        prefixIcon: FontAwesomeIcons.ticket,
                        controller: _couponController,
                        readOnly: _isCouponValid,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isValidatingCoupon
                            ? null
                            : (_isCouponValid
                                  ? () {
                                      setState(() {
                                        _isCouponValid = false;
                                        _discountApplied = 0.0;
                                        _couponController.clear();
                                      });
                                    }
                                  : _validateCoupon),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCouponValid
                              ? Colors.red
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isValidatingCoupon
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isCouponValid ? 'إلغاء' : 'تطبيق'),
                      ),
                    ),
                  ],
                ),
                if (_couponError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _couponError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                if (_isCouponValid) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'قيمة الخصم المطبقة:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '- ${_discountApplied.toInt()} ج.م',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'السعر النهائي للتوصيل:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${((double.tryParse(_priceController.text) ?? 0.0) - _discountApplied).clamp(0.0, double.infinity).toInt()} ج.م',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (!isWithoutAdvance) ...[
                          Expanded(
                            child: _buildField(
                              label: "سعر الشحنة",
                              hint: "سعر الشحنة ادخل المبلغ",
                              prefixIcon: FontAwesomeIcons.coins,
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.isEmpty
                                  ? 'هذا الحقل مطلوب'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: isWithoutAdvance,
                              onChanged: (value) {
                                setState(() {
                                  isWithoutAdvance = value!;
                                  if (isWithoutAdvance) {
                                    priceController.clear();
                                  }
                                });
                              },
                            ),
                            const Text("بدون مقدم"),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: "وزن الشحنة",
                            hint: "ادخل وزن الشحنة",
                            prefixIcon: FontAwesomeIcons.weight,

                            controller: weightController,
                            validator: (v) => v == null || v.isEmpty
                                ? 'هذا الحقل مطلوب'
                                : null,
                          ),
                        ),
                        SizedBox(width: 10),
                        Row(
                          children: [
                            Checkbox(
                              value: isFragile,
                              onChanged: (value) {
                                setState(() {
                                  isFragile = value!;
                                });
                              },
                            ),
                            Text("قابل للكسر"),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _buildField(
                  label: 'ملاحظات (اختياري)',
                  hint: 'أي تعليمات خاصة للمندوب...',

                  controller: _notesController,
                ),
                const SizedBox(height: 14),
                // Product image picker
                if (widget.isMultiShipment)
                  _buildMultiImagePicker()
                else
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: _productImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(_productImage!),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.upload,
                                  size: 32,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'اضغط لإضافة صورة المنتج * (إجباري)',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'JPG, PNG',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                const SizedBox(height: 32),

                // Submit button
                AnimatedBuilder(
                  animation: widget.cubit,
                  builder: (context, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: widget.cubit.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: widget.cubit.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.editingShipment != null
                                    ? 'حفظ التعديلات'
                                    : 'إضافة الشحنة',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                if (_shipments.isNotEmpty) ...[
                  const Divider(height: 40),
                  const Text(
                    'الشحنات التي تم إضافتها',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _shipments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final s = _shipments[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.box,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'شحنة رقم: ${s.shipmentNumber}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'من: ${s.fromAddress} إلى: ${s.toAddress}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${s.price.toInt()} ج',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'إتمام وإغلاق',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    FaIconData? prefixIcon,
    Color? prefixColor,
    FaIconData? suffixIcon,
    Color? suffixColor,
    int maxLines = 1,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        CustomTextField(
          hintText: hint,
          height: 48,
          hintColor: const Color.fromARGB(255, 78, 78, 78),
          hintSize: 13,
          rightWidget: Padding(
            padding: EdgeInsetsDirectional.only(start: 10),
            child: FaIcon(prefixIcon, size: 20, color: AppColors.primary),
          ),
          maxLines: maxLines,
          leftWidget: Padding(
            padding: EdgeInsetsDirectional.only(end: 14),
            child: FaIcon(suffixIcon, size: 14, color: Colors.grey),
          ),
          controller: controller,
          onTap: onTap,
          readOnly: readOnly,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildMultiImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const FaIcon(
              FontAwesomeIcons.images,
              size: 15,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            const Text(
              'صور المنتجات',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            if (_productImages.isNotEmpty)
              Text(
                'عدد الصور:  ${_productImages.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _productImages.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            // Last cell = Add button
            if (index == _productImages.length) {
              return GestureDetector(
                onTap: _pickMultiImage,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.35),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.plus,
                        size: 22,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'إضافة صورة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            // Image cell with remove button
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_productImages[index], fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
