// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/features/shipment/data/datasources/egypt_locations.dart';
import 'package:we_deliver/features/profile/presentation/bloc/address_cubit.dart';
import 'package:we_deliver/features/profile/presentation/bloc/address_state.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/services/location_service.dart';

class SavedAddressesSheet extends StatefulWidget {
  final bool isPickup;
  final void Function(SavedAddress) onSelect;
  const SavedAddressesSheet({
    super.key,
    this.isPickup = false,
    required this.onSelect,
  });

  @override
  State<SavedAddressesSheet> createState() => _SavedAddressesSheetState();
}

class _SavedAddressesSheetState extends State<SavedAddressesSheet> {
  bool _isLoadingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    context.read<AddressCubit>().loadAddresses();
  }

  Future<void> _fetchAndUseCurrentLocation() async {
    setState(() {
      _isLoadingCurrentLocation = true;
    });

    try {
      final locService = sl<LocationService>();
      final position = await locService.getCurrentLocation();
      if (position != null) {
        final result = await locService.reverseGeocodeGoogle(
          position.latitude,
          position.longitude,
        );
        if (result != null) {
          if (mounted) {
            Navigator.pop(context);
            widget.onSelect(
              SavedAddress(
                id: 'resolved_location',
                title: 'موقعي الحالي',
                address: result.address,
                governorate: result.governorate ?? '',
                city: result.city ?? '',
                latitude: result.latitude,
                longitude: result.longitude,
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحديد موقعك الحالي. تأكد من تفعيل GPS وصلاحية الموقع.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء جلب موقعك: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCurrentLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'العناوين المحفوظة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoadingCurrentLocation)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'جاري جلب موقعك الحالي وتحديد العنوان...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (widget.isPickup) ...[
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'استخدام موقعي الحالي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onTap: _fetchAndUseCurrentLocation,
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.map,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'اختيار موقع جديد من الخريطة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelect(
                    const SavedAddress(
                      id: 'custom_map',
                      title: 'موقع مخصص على الخريطة',
                      address: '',
                      governorate: '',
                      city: '',
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'البحث عن عنوان جديد',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelect(
                    const SavedAddress(
                      id: 'search_address',
                      title: 'البحث عن عنوان جديد',
                      address: '',
                      governorate: '',
                      city: '',
                    ),
                  );
                },
              ),
            ],
            const Divider(),
            Flexible(
              child: BlocBuilder<AddressCubit, AddressState>(
                builder: (context, state) {
                  if (state is AddressLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  } else if (state is AddressError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          state.message,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  } else if (state is AddressLoaded) {
                    final addresses = state.addresses;
                    if (addresses.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'لا توجد عناوين محفوظة حالياً',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: addresses.length,
                      itemBuilder: (context, index) {
                        final addr = addresses[index];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            addr.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            addr.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSelect(addr);
                          },
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class PickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selected;
  final void Function(String) onSelect;
  const PickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<PickerSheet> {
  late List<String> _filtered;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _search.addListener(() {
      final q = _search.text.trim();
      setState(
        () => _filtered = q.isEmpty
            ? widget.items
            : widget.items.where((i) => i.contains(q)).toList(),
      );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search, color: Colors.grey.shade400, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'بحث...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final item = _filtered[i];
                    final isSelected = widget.selected == item;
                    return ListTile(
                      title: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.black87,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onSelect(item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
