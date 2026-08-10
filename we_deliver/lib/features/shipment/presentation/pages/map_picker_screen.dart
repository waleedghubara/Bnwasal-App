import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:we_deliver/core/theme/colors.dart';
import 'package:we_deliver/core/widgets/custom_text_field.dart';
import 'package:we_deliver/core/di/injection_container.dart';
import 'package:we_deliver/core/services/location_service.dart';

class MapPickerResult {
  final String address;
  final double latitude;
  final double longitude;
  final String? governorate;
  final String? city;

  const MapPickerResult({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.governorate,
    this.city,
  });
}

class MapPickerScreen extends StatefulWidget {
  final String? title;
  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;
  final bool isPickup;
  final bool focusSearch;

  const MapPickerScreen({
    super.key,
    this.title,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
    this.isPickup = false,
    this.focusSearch = false,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng _currentPosition = const LatLng(31.2001, 29.9187); // Default to Alexandria

  List<dynamic> _placePredictions = [];
  Timer? _debounce;
  bool _isSearching = false;

  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _address = '';

  String? _resolvedGovernorate;
  String? _resolvedCity;
  LatLngBounds? _visibleBounds;

  @override
  void initState() {
    super.initState();
    debugPrint('[MapPickerScreen] init: isPickup=${widget.isPickup}, focusSearch=${widget.focusSearch}');

    if (widget.initialAddress != null) {
      _searchController.text = widget.initialAddress!;
      _address = widget.initialAddress!;
    }
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _currentPosition = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }

    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('[MapPickerScreen] Auto-focusing search bar as requested...');
        _searchFocusNode.requestFocus();
      });
    }

    if (widget.isPickup && widget.initialLatitude == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('[MapPickerScreen] Triggering auto-fetch location for Pickup...');
        _moveToCurrentLocation();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─── Search Autocomplete ──────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() => _placePredictions = []);
        return;
      }
      try {
        final locService = sl<LocationService>();
        // Bias search queries to map's active center coordinates
        final predictions = await locService.searchAutocompleteGoogle(
          query,
          biasLat: _currentPosition.latitude,
          biasLng: _currentPosition.longitude,
        );
        if (mounted) {
          setState(() => _placePredictions = predictions);
        }
      } catch (e) {
        debugPrint('[MapPickerScreen] Autocomplete search error: $e');
      }
    });
  }

  Future<void> _onPlaceSelected(String placeId, String description) async {
    setState(() {
      _placePredictions = [];
      _searchController.text = description;
      _isSearching = true;
    });

    try {
      final locService = sl<LocationService>();
      final result = await locService.getPlaceDetailsGoogle(placeId);
      if (result != null && mounted) {
        final newPos = LatLng(result.latitude, result.longitude);
        _currentPosition = newPos;
        setState(() {
          _address = result.address;
          _resolvedGovernorate = result.governorate;
          _resolvedCity = result.city;
        });
        final ctrl = await _mapController.future;
        ctrl.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16));
      }
    } catch (e) {
      debugPrint('[MapPickerScreen] Error selecting place: $e');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // ─── Search by button ─────────────────────────────────────────────────────

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final locService = sl<LocationService>();
      String? boundsStr;
      if (_visibleBounds != null) {
        final sw = _visibleBounds!.southwest;
        final ne = _visibleBounds!.northeast;
        boundsStr = '${sw.latitude},${sw.longitude}|${ne.latitude},${ne.longitude}';
      }
      
      final result = await locService.geocodeAddressGoogle(
        query,
        biasLat: _currentPosition.latitude,
        biasLng: _currentPosition.longitude,
        bounds: boundsStr,
      );
      
      if (result != null && mounted) {
        final newPos = LatLng(result.latitude, result.longitude);
        _currentPosition = newPos;
        setState(() {
          _address = result.address;
          _resolvedGovernorate = result.governorate;
          _resolvedCity = result.city;
        });
        final ctrl = await _mapController.future;
        ctrl.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16));
      } else {
        _showSnackBar('لم يتم العثور على عنوان. حاول مرة أخرى.');
      }
    } catch (e) {
      debugPrint('[MapPickerScreen] Error searching address text: $e');
      _showSnackBar('حدث خطأ أثناء البحث عن العنوان. تأكد من اتصالك بالإنترنت.');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // ─── Reverse Geocoding ────────────────────────────────────────────────────

  void _updateAddressFromCoords(LatLng position) async {
    try {
      final locService = sl<LocationService>();
      final result = await locService.reverseGeocodeGoogle(
        position.latitude,
        position.longitude,
      );
      if (result != null && mounted) {
        setState(() {
          _address = result.address;
          _resolvedGovernorate = result.governorate;
          _resolvedCity = result.city;
        });
      }
    } catch (e) {
      debugPrint('[MapPickerScreen] Error in reverse geocoding from map drag: $e');
    }
  }

  // ─── Manual GPS Centering ────────────────────────────────────────────────

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isSearching = true);
    try {
      final locService = sl<LocationService>();
      final position = await locService.getCurrentLocation();
      if (position != null && mounted) {
        final newPos = LatLng(position.latitude, position.longitude);
        _currentPosition = newPos;
        final ctrl = await _mapController.future;
        ctrl.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16));
        _updateAddressFromCoords(newPos);
      } else {
        _showSnackBar('تعذر الحصول على موقعك الحالي. تأكد من تفعيل GPS وصلاحية الموقع.');
      }
    } catch (e) {
      debugPrint('[MapPickerScreen] Error moving map to current location: $e');
      _showSnackBar('حدث خطأ أثناء جلب موقعك الحالي.');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // ─── Map callbacks ────────────────────────────────────────────────────────

  void _onCameraMove(CameraPosition position) {
    _currentPosition = position.target;
    if (_placePredictions.isNotEmpty) {
      setState(() => _placePredictions = []);
    }
  }

  void _onCameraIdle() async {
    _updateAddressFromCoords(_currentPosition);
    try {
      final ctrl = await _mapController.future;
      final bounds = await ctrl.getVisibleRegion();
      _visibleBounds = bounds;
      debugPrint('[MapPickerScreen] Camera idle. Viewport bounds: '
          'sw=(${bounds.southwest.latitude}, ${bounds.southwest.longitude}), '
          'ne=(${bounds.northeast.latitude}, ${bounds.northeast.longitude})');
    } catch (e) {
      debugPrint('[MapPickerScreen] Error getting visible viewport region bounds: $e');
    }
  }

  // ─── Confirm ──────────────────────────────────────────────────────────────

  void _confirm() {
    if (_address.isEmpty) {
      _showSnackBar('يرجى تحديد عنوان صحيح.');
      return;
    }
    debugPrint('[MapPickerScreen] Final Confirm Address: '
        'address="$_address", '
        'coords=(${_currentPosition.latitude}, ${_currentPosition.longitude}), '
        'governorate="$_resolvedGovernorate", '
        'city="$_resolvedCity"');
    
    Navigator.pop(
      context,
      MapPickerResult(
        address: _address,
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        governorate: _resolvedGovernorate,
        city: _resolvedCity,
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
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
            widget.title ?? 'اختيار عنوان التسليم',
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
        body: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ابحث عن العنوان',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CustomTextField(
                    hintText: 'ابحث عن مكان أو شارع...',
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    height: 48,
                    hintColor: const Color.fromARGB(255, 78, 78, 78),
                    hintSize: 13,
                    rightWidget: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 10),
                      child: FaIcon(
                        _isSearching
                            ? FontAwesomeIcons.spinner
                            : FontAwesomeIcons.magnifyingGlass,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    leftWidget: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _placePredictions = []);
                            },
                            child: const Padding(
                              padding: EdgeInsetsDirectional.only(end: 14),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : null,
                    onChanged: _onSearchChanged,
                    onTap: () {},
                  ),
                  // Suggestions dropdown
                  if (_placePredictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _placePredictions.length,
                        separatorBuilder: (_, _) =>
                            Divider(color: Colors.grey.shade100, height: 1),
                        itemBuilder: (context, i) {
                          final p = _placePredictions[i];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _onPlaceSelected(
                                p['place_id'],
                                p['description'],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    FaIcon(
                                      FontAwesomeIcons.locationDot,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        p['description'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _isSearching
                          ? null
                          : () {
                              setState(() => _placePredictions = []);
                              _searchAddress();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isSearching ? 'جاري البحث...' : 'بحث',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Map
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition,
                      zoom: 14,
                    ),
                    onMapCreated: (ctrl) => _mapController.complete(ctrl),
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false, // Hide default Google location button
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapType: MapType.normal,
                  ),
                  // Center pin - fixed location indicator
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_address.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'الموقع المحدد',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          const Icon(
                            Icons.location_on_rounded,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Coordinates overlay
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${_currentPosition.latitude.toStringAsFixed(6)}, ${_currentPosition.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  // Custom floating My Location button
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: GestureDetector(
                      onTap: _moveToCurrentLocation,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom info and confirm
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.locationDot,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _address,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            'خط العرض: ${_currentPosition.latitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            'خط الطول: ${_currentPosition.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'تأكيد العنوان',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
