// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:we_deliver/core/widgets/custom_text_field.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/api/end_point.dart';
import '../../../../core/cache/cache_helper.dart';
import '../../../profile/presentation/bloc/address_cubit.dart';
import '../../../shipment/data/datasources/delivery_pricing.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';
import '../../../shipment/presentation/pages/map_picker_screen.dart';
import '../../../shipment/presentation/widgets/shipment_pickers.dart';
import '../../../shipment/presentation/widgets/price_suggestion_widget.dart';
import '../../../../core/services/appsflyer_service.dart';
import '../../domain/entities/order.dart';
import '../manager/order_cubit.dart';

class AddOrderScreen extends StatefulWidget {
  final OrderCubit cubit;
  final OrderEntity? editingOrder;

  const AddOrderScreen({super.key, required this.cubit, this.editingOrder});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _storeLocationController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _storeGovernorateController = TextEditingController();
  final _storeAreaController = TextEditingController();
  final _notesController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _locationController = TextEditingController();
  final _deliveryGovernorateController = TextEditingController();
  final _deliveryAreaController = TextEditingController();
  final _priceController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _couponController = TextEditingController();

  // Store address
  String? _storeGovernorate;
  String? _storeCity;
  double? _merchantLatitude;
  double? _merchantLongitude;

  // Delivery address
  String? _deliveryGovernorate;
  String? _deliveryCity;
  double? _latitude;
  double? _longitude;

  bool _isSubmitting = false;
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
      final price = double.tryParse(_deliveryFeeController.text) ?? 0.0;

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم تطبيق الكوبون بنجاح! خصم ${_discountApplied.toInt()} ج.م',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  @override
  void dispose() {
    _couponController.dispose();
    _detailsController.dispose();
    _storeLocationController.dispose();
    _pickupLocationController.dispose();
    _storeGovernorateController.dispose();
    _storeAreaController.dispose();
    _notesController.dispose();
    _deliveryAddressController.dispose();
    _locationController.dispose();
    _deliveryGovernorateController.dispose();
    _deliveryAreaController.dispose();
    _priceController.dispose();
    _deliveryFeeController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.editingOrder != null) {
      final o = widget.editingOrder!;
      _detailsController.text = o.details;
      _storeLocationController.text = o.storeDescription;
      _pickupLocationController.text = o.storeDescription;
      _notesController.text = o.notes ?? '';
      _deliveryAddressController.text = o.deliveryAddress;
      _locationController.text = o.deliveryAddress;
      _priceController.text = o.orderPrice.toInt().toString();
      _deliveryFeeController.text = o.deliveryFee.toInt().toString();
      _phoneController.text = o.phone;
      _nameController.text = o.clientName;
      _latitude = o.latitude;
      _longitude = o.longitude;
      _merchantLatitude = o.merchantLatitude;
      _merchantLongitude = o.merchantLongitude;
    } else {
      _loadMerchantCity();
    }
  }

  Future<void> _loadMerchantCity() async {
    try {
      final token = await SecureCacheHelper().getData(key: ApiKey.token);
      if (token != null) {
        final response = await sl<Dio>().get(
          '${EndPoint.baseUrl}${EndPoint.getProfile}',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final data = response.data as Map<String, dynamic>;
        final city = data['data']['user']['city'] as String?;
        final gov =
            data['data']['user']['governorate'] as String? ?? 'الإسكندرية';
        if (mounted && city != null) {
          setState(() {
            _storeGovernorate = gov;
            _storeGovernorateController.text = gov;
            _storeCity = city;
            _storeAreaController.text = city;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading merchant city: $e');
    }
  }

  void _showSavedAddresses(bool isStore) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (context) => sl<AddressCubit>(),
        child: SavedAddressesSheet(
          isPickup: isStore,
          onSelect: (addr) {
            if (addr.id == 'custom_map') {
              _openMapPicker(isStore, focusSearch: false);
              return;
            }
            if (addr.id == 'search_address') {
              _openMapPicker(isStore, focusSearch: true);
              return;
            }
            setState(() {
              if (isStore) {
                _pickupLocationController.text = addr.address;
                if (_storeLocationController.text.isEmpty) {
                  _storeLocationController.text = addr.address;
                }
                _storeGovernorateController.text = addr.governorate;
                _storeAreaController.text = addr.city;
                _storeGovernorate = addr.governorate;
                _storeCity = addr.city;
                _merchantLatitude = addr.latitude;
                _merchantLongitude = addr.longitude;
              } else {
                _locationController.text = addr.address;
                if (_deliveryAddressController.text.isEmpty) {
                  _deliveryAddressController.text = addr.address;
                }
                _deliveryGovernorateController.text = addr.governorate;
                _deliveryAreaController.text = addr.city;
                _deliveryGovernorate = addr.governorate;
                _deliveryCity = addr.city;
                _latitude = addr.latitude;
                _longitude = addr.longitude;
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _openMapPicker(bool isStore, {bool focusSearch = false}) async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: isStore ? 'اختيار موقع الاستلام' : 'اختيار موقع التوصيل',
          isPickup: isStore,
          focusSearch: focusSearch,
          initialAddress: isStore
              ? (_pickupLocationController.text.isNotEmpty
                    ? _pickupLocationController.text
                    : null)
              : (_locationController.text.isNotEmpty
                    ? _locationController.text
                    : null),
          initialLatitude: isStore ? _merchantLatitude : _latitude,
          initialLongitude: isStore ? _merchantLongitude : _longitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isStore) {
          _pickupLocationController.text = result.address;
          if (_storeLocationController.text.isEmpty) {
            _storeLocationController.text = result.address;
          }
          _merchantLatitude = result.latitude;
          _merchantLongitude = result.longitude;
          if (result.governorate != null && result.governorate!.isNotEmpty) {
            _storeGovernorate = result.governorate;
            _storeGovernorateController.text = result.governorate!;
          }
          if (result.city != null && result.city!.isNotEmpty) {
            _storeCity = result.city;
            _storeAreaController.text = result.city!;
          }
        } else {
          _locationController.text = result.address;
          if (_deliveryAddressController.text.isEmpty) {
            _deliveryAddressController.text = result.address;
          }
          _latitude = result.latitude;
          _longitude = result.longitude;
          if (result.governorate != null && result.governorate!.isNotEmpty) {
            _deliveryGovernorate = result.governorate;
            _deliveryGovernorateController.text = result.governorate!;
          }
          if (result.city != null && result.city!.isNotEmpty) {
            _deliveryCity = result.city;
            _deliveryAreaController.text = result.city!;
          }
        }
      });
    }
  }

  void _showGovernoratePicker(bool isStore) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickerSheet(
        title: 'اختر المحافظة',
        items: EgyptLocations.governorates,
        selected: isStore ? _storeGovernorate : _deliveryGovernorate,
        onSelect: (gov) {
          setState(() {
            if (isStore) {
              _storeGovernorate = gov;
              _storeGovernorateController.text = gov;
              _storeCity = null;
              _storeAreaController.clear();
            } else {
              _deliveryGovernorate = gov;
              _deliveryGovernorateController.text = gov;
              _deliveryCity = null;
              _deliveryAreaController.clear();
            }
          });
        },
      ),
    );
  }

  void _showCityPicker(bool isStore) {
    final gov = isStore ? _storeGovernorate : _deliveryGovernorate;
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
        selected: isStore ? _storeCity : _deliveryCity,
        onSelect: (city) => setState(() {
          if (isStore) {
            _storeCity = city;
            _storeAreaController.text = city;
          } else {
            _deliveryCity = city;
            _deliveryAreaController.text = city;
          }
        }),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      if (widget.editingOrder != null) {
        final updatedOrder = OrderEntity(
          id: widget.editingOrder!.id,
          orderNumber: widget.editingOrder!.orderNumber,
          details: _detailsController.text.trim(),
          storeDescription: _storeLocationController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          deliveryAddress: _deliveryAddressController.text.trim(),
          phone: _phoneController.text.trim(),
          clientName: _nameController.text.trim(),
          orderPrice: double.tryParse(_priceController.text) ?? 0,
          deliveryFee: double.tryParse(_deliveryFeeController.text) ?? 0,
          latitude: _latitude,
          longitude: _longitude,
          merchantLatitude: _merchantLatitude,
          merchantLongitude: _merchantLongitude,
          status: widget.editingOrder!.status,
          createdAt: widget.editingOrder!.createdAt,
        );

        final success = await widget.cubit.updateOrder(updatedOrder);

        if (mounted) {
          setState(() => _isSubmitting = false);
        }

        if (success) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تعديل الطلب بنجاح!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          _showErrorSnackBar(widget.cubit.errorMessage ?? 'فشل تعديل الطلب');
        }
      } else {
        final newOrder = OrderEntity(
          id: '',
          orderNumber: '',
          details: _detailsController.text.trim(),
          storeDescription: _storeLocationController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          deliveryAddress: _deliveryAddressController.text.trim(),
          phone: _phoneController.text.trim(),
          clientName: _nameController.text.trim(),
          orderPrice: double.tryParse(_priceController.text) ?? 0,
          deliveryFee: double.tryParse(_deliveryFeeController.text) ?? 0,
          latitude: _latitude,
          longitude: _longitude,
          merchantLatitude: _merchantLatitude,
          merchantLongitude: _merchantLongitude,
          status: OrderStatus.pending,
          createdAt: DateTime.now(),
          couponCode: _isCouponValid
              ? _couponController.text.trim().toUpperCase()
              : null,
        );

        final success = await widget.cubit.createOrder(newOrder);

        if (mounted) {
          setState(() => _isSubmitting = false);
        }

        if (success) {
          _logOrderPlacementEvent(newOrder);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إنشاء الطلب بنجاح!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          _showErrorSnackBar(widget.cubit.errorMessage ?? 'فشل إضافة الطلب');
        }
      }
    }
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
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 18,
              color: Colors.black87,
            ),
          ),
          title: Text(
            widget.editingOrder != null ? 'تعديل الطلب' : 'اضافة طلب',
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
                  label: 'اكتب الطلب اللي محتاجه',
                  hint: 'مثال: لبن، خبز، دواء، أوردر مطعم ...',
                  prefixIcon: FontAwesomeIcons.box,
                  controller: _detailsController,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'تحب المندوب يشتري منين؟',
                  hint: 'اسم المتجر أو عنوان مكان الشراء',
                  controller: _storeLocationController,
                  prefixIcon: FontAwesomeIcons.shoppingBag,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'موقع الاستلام',
                  hint: 'اختر موقع الاستلام من العناوين المحفوظة أو الخريطة',
                  controller: _pickupLocationController,
                  prefixIcon: FontAwesomeIcons.locationDot,
                  suffixIcon: FontAwesomeIcons.chevronDown,
                  prefixColor: const Color(0xFFE05B3A),
                  onTap: () => _showSavedAddresses(true),
                  readOnly: true,
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
                        controller: _storeGovernorateController,
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
                        controller: _storeAreaController,
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
                  label: 'مبلغ الطلبات',
                  hint: 'أدخل المبلغ المتوقع لشراء الطلبات',
                  prefixIcon: FontAwesomeIcons.moneyBill,
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'ملاحظات للكابتن (اختياري)',
                  hint: 'أي تعليمات خاصة أو ملاحظات',
                  prefixIcon: FontAwesomeIcons.noteSticky,
                  controller: _notesController,
                  maxLines: 2,
                  validator: (v) => null,
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'عنوان التوصيل',
                  hint: 'اكتب العنوان بالتفصيل',
                  prefixIcon: FontAwesomeIcons.locationDot,
                  controller: _deliveryAddressController,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'موقع التوصيل',
                  hint: 'اختر الموقع من الخريطة أو حدد المنطقة',
                  controller: _locationController,
                  prefixIcon: FontAwesomeIcons.locationDot,
                  suffixIcon: FontAwesomeIcons.chevronDown,
                  prefixColor: AppColors.primary,
                  onTap: () => _showSavedAddresses(false),
                  readOnly: true,
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
                        controller: _deliveryGovernorateController,
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
                        controller: _deliveryAreaController,
                        onTap: () => _showCityPicker(false),
                        readOnly: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PriceSuggestionWidget(
                  fromArea: _storeCity,
                  toArea: _deliveryCity,
                  priceController: _deliveryFeeController,
                ),
                // const SizedBox(height: 8),
                // _buildField(
                //   label: 'سعر التوصيل *',
                //   hint: 'سعر التوصيل للمناطق المحددة',
                //   prefixIcon: FontAwesomeIcons.moneyBill,
                //   controller: _deliveryFeeController,
                //   keyboardType: TextInputType.number,
                //   readOnly:
                //       DeliveryPricing.getSuggestedPrice(
                //         _storeCity,
                //         _deliveryCity,
                //       ) !=
                //       null,
                //   validator: (v) =>
                //       v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                // ),
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
                        validator: (v) => null,
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
                              : const Color(0xFF1E4BA1),
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
                        '${((double.tryParse(_deliveryFeeController.text) ?? 0.0) - _discountApplied).clamp(0.0, double.infinity).toInt()} ج.م',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E4BA1),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _buildField(
                  label: 'رقم الهاتف',
                  hint: 'للتواصل معك عند الحاجة',
                  prefixIcon: FontAwesomeIcons.phone,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _buildField(
                  label: 'اسم العميل',
                  hint: 'اكتب اسمك',
                  prefixIcon: FontAwesomeIcons.user,
                  controller: _nameController,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E4BA1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            widget.editingOrder != null
                                ? 'حفظ التعديلات'
                                : 'إرسال الطلب',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
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
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    prefixIcon,
    Color? prefixColor,
    suffixIcon,
    Color? suffixColor,
    VoidCallback? onTap,
    bool readOnly = false,
    String? Function(String?)? validator,
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
        const SizedBox(height: 8),
        CustomTextField(
          hintText: hint,
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          rightWidget: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FaIcon(
                    prefixIcon,
                    color: prefixColor ?? AppColors.primary,
                    size: 18,
                  ),
                )
              : null,
          leftWidget: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 8, left: 8),
                  child: FaIcon(
                    suffixIcon,
                    size: 18,
                    color: suffixColor ?? prefixColor ?? AppColors.primary,
                  ),
                )
              : null,
          onTap: onTap,
          readOnly: readOnly,
          validator:
              validator ??
              (v) => v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
        ),
      ],
    );
  }

  void _logOrderPlacementEvent(OrderEntity order) async {
    try {
      final afService = sl<AppsFlyerService>();
      final prefs = await SharedPreferences.getInstance();

      final String userIdKey = 'placed_orders_count_${order.merchantId}';
      int currentCount = prefs.getInt(userIdKey) ?? 0;
      currentCount += 1;
      await prefs.setInt(userIdKey, currentCount);

      // 1. Log Place Order Event
      afService.logEvent('af_place_order', {
        'price': order.orderPrice,
        'delivery_fee': order.deliveryFee,
        'client_name': order.clientName,
      });

      // 2. Log Repeat Order Event if count > 1
      if (currentCount > 1) {
        afService.logEvent('repeat_order', {
          'order_count': currentCount,
          'price': order.orderPrice,
        });
      }
    } catch (e) {
      debugPrint('Error logging placement event: $e');
    }
  }
}
