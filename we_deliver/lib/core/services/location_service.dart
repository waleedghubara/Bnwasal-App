import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:we_deliver/features/shipment/data/datasources/egypt_locations.dart';
import 'package:we_deliver/core/utils/constants.dart';

class GeocodingResult {
  final String address;
  final double latitude;
  final double longitude;
  final String? governorate;
  final String? city;

  const GeocodingResult({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.governorate,
    this.city,
  });
}

class LocationService {
  String get _googleApiKey => AppConstants.googleMapsApiKey;
  final _dio = Dio();

  Position? _lastKnownAccuratePosition;
  StreamSubscription<Position>? _positionSubscription;

  Position? get lastKnownAccuratePosition => _lastKnownAccuratePosition;

  /// Check permission and start automatic tracking if allowed.
  Future<void> initializeLocationTracking() async {
    debugPrint('[LocationService] Checking location permission to initialize automatic tracking...');
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          startTracking();
        } else {
          debugPrint('[LocationService] Location services are disabled. Cannot start tracking.');
        }
      } else {
        debugPrint('[LocationService] Permission not granted previously ($permission). Skipping automatic tracking.');
      }
    } catch (e) {
      debugPrint('[LocationService] Error in initializeLocationTracking: $e');
    }
  }

  /// Start listening to high accuracy GPS coordinates stream.
  void startTracking() {
    if (_positionSubscription != null) {
      debugPrint('[LocationService] Already tracking location.');
      return;
    }
    debugPrint('[LocationService] Starting background GPS location stream (High Accuracy)...');
    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      );
      
      _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
        (Position position) {
          _lastKnownAccuratePosition = position;
          debugPrint('[LocationService] Periodic GPS Update: Lat=${position.latitude}, Lng=${position.longitude}, Acc=${position.accuracy}m');
        },
        onError: (err) {
          debugPrint('[LocationService] Error in periodic location stream: $err');
        }
      );
    } catch (e) {
      debugPrint('[LocationService] Error starting location stream: $e');
    }
  }

  /// Stop listening to coordinates stream.
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    debugPrint('[LocationService] Stopped background GPS location stream.');
  }

  /// Request and check location permissions.
  /// Returns [true] if permission is granted, [false] otherwise.
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    debugPrint('[LocationService] Checking if location service is enabled...');
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationService] Location services are disabled.');
      return false;
    }

    debugPrint('[LocationService] Checking current location permission status...');
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      debugPrint('[LocationService] Permission denied. Requesting permission...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationService] Permission request denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationService] Permission permanently denied.');
      return false;
    }

    debugPrint('[LocationService] Location permission granted successfully.');
    return true;
  }

  /// Get the current position of the user.
  /// Returns [Position] if successful, [null] otherwise.
  Future<Position?> getCurrentLocation() async {
    if (_lastKnownAccuratePosition != null) {
      debugPrint('[LocationService] Returning cached accurate position: '
          '${_lastKnownAccuratePosition!.latitude}, ${_lastKnownAccuratePosition!.longitude}');
      return _lastKnownAccuratePosition;
    }

    final hasPermission = await handleLocationPermission();
    if (!hasPermission) {
      debugPrint('[LocationService] Cannot get current location due to permission failure.');
      return null;
    }

    // Force start background tracking if not already started
    startTracking();

    try {
      debugPrint('[LocationService] Fetching current position (High Accuracy)...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _lastKnownAccuratePosition = position;
      debugPrint('[LocationService] Current position fetched: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('[LocationService] Failed fetching current position with high accuracy: $e');
      try {
        debugPrint('[LocationService] Trying fallback to last known position...');
        final fallbackPos = await Geolocator.getLastKnownPosition();
        if (fallbackPos != null) {
          _lastKnownAccuratePosition = fallbackPos;
          debugPrint('[LocationService] Fallback position resolved: ${fallbackPos.latitude}, ${fallbackPos.longitude}');
        }
        return fallbackPos;
      } catch (err) {
        debugPrint('[LocationService] Failed to retrieve fallback position: $err');
        return null;
      }
    }
  }

  /// Resolves Egypt governorate and city from Google Address Components.
  Map<String, String?> resolveLocationFromAddressComponents(List<dynamic> components) {
    String? matchedGov;
    String? matchedCity;

    debugPrint('[LocationService] Parsing address components: ${components.length} components found.');

    // 1. Identify Governorate (administrative_area_level_1)
    for (var component in components) {
      final types = List<String>.from(component['types'] ?? []);
      final longName = component['long_name']?.toString() ?? '';
      
      if (types.contains('administrative_area_level_1')) {
        if (longName.contains('الإسكندرية') || longName.toLowerCase().contains('alexandria')) {
          matchedGov = 'الإسكندرية';
        } else if (longName.contains('القاهرة') || longName.toLowerCase().contains('cairo')) {
          matchedGov = 'القاهرة';
        } else if (longName.contains('الجيزة') || longName.toLowerCase().contains('giza')) {
          matchedGov = 'الجيزة';
        } else {
          matchedGov = longName.replaceAll('Governorate', '').replaceAll('محافظة', '').trim();
        }
        debugPrint('[LocationService] Resolved governorate: $matchedGov (from raw: "$longName")');
      }
    }

    // 2. Try matching Alexandria city/area keys from EgyptLocations
    final alexCities = EgyptLocations.citiesFor('الإسكندرية');
    for (var component in components) {
      final longName = component['long_name']?.toString() ?? '';
      final shortName = component['short_name']?.toString() ?? '';
      
      for (var city in alexCities) {
        if (longName == city || 
            shortName == city || 
            longName.contains(city) || 
            shortName.contains(city)) {
          matchedCity = city;
          matchedGov = 'الإسكندرية'; // Ensure Alexandria is matching
          debugPrint('[LocationService] Matched Alexandria city/area component: "$city" (from raw long: "$longName", short: "$shortName")');
          break;
        }
      }
      if (matchedCity != null) break;
    }

    // 3. Fallback for other governorates to identify city/district
    if (matchedCity == null) {
      for (var component in components) {
        final types = List<String>.from(component['types'] ?? []);
        final longName = component['long_name']?.toString() ?? '';
        if (types.contains('sublocality') ||
            types.contains('neighborhood') ||
            types.contains('locality') ||
            types.contains('administrative_area_level_2')) {
          matchedCity = longName
              .replaceAll('قسم ', '')
              .replaceAll('حي ', '')
              .replaceAll('مدينة ', '')
              .replaceAll('مركز ', '')
              .trim();
          debugPrint('[LocationService] Non-Alexandria city fallback: "$matchedCity" (from raw: "$longName", types: $types)');
          break;
        }
      }
    }

    return {
      'governorate': matchedGov,
      'city': matchedCity,
    };
  }

  /// Reverse geocode using Google Geocoding API with Native OS Geocoder fallback.
  Future<GeocodingResult?> reverseGeocodeGoogle(double lat, double lng) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=ar';
    debugPrint('[LocationService] reverseGeocodeGoogle: lat=$lat, lng=$lng');
    
    try {
      final response = await _dio.get(url);
      final status = response.data['status']?.toString() ?? '';
      debugPrint('[LocationService] reverseGeocodeGoogle status: $status');
      
      if (response.statusCode == 200 && status == 'OK') {
        final results = response.data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final firstResult = results[0];
          final formattedAddress = firstResult['formatted_address'] as String? ?? '';
          final addressComponents = firstResult['address_components'] as List? ?? [];
          final resolved = resolveLocationFromAddressComponents(addressComponents);
          
          final latLng = firstResult['geometry']['location'];
          final resolvedLat = (latLng['lat'] as num).toDouble();
          final resolvedLng = (latLng['lng'] as num).toDouble();

          final result = GeocodingResult(
            address: formattedAddress,
            latitude: resolvedLat,
            longitude: resolvedLng,
            governorate: resolved['governorate'],
            city: resolved['city'],
          );
          debugPrint('[LocationService] Reverse geocode success: address="${result.address}", gov="${result.governorate}", city="${result.city}"');
          return result;
        }
      } else {
        debugPrint('[LocationService] Reverse geocode failed API check (Status: $status). Trying native geocoding fallback...');
        return await _reverseGeocodeNativeFallback(lat, lng);
      }
    } catch (e) {
      debugPrint('[LocationService] Error in reverseGeocodeGoogle: $e. Trying native fallback...');
      return await _reverseGeocodeNativeFallback(lat, lng);
    }
    return null;
  }

  /// Native Geocoding fallback using device services (free, offline/OS geocoder)
  Future<GeocodingResult?> _reverseGeocodeNativeFallback(double lat, double lng) async {
    try {
      debugPrint('[LocationService] Performing native reverse geocoding fallback...');
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final street = p.street ?? '';
        final subLocality = p.subLocality ?? '';
        final locality = p.locality ?? '';
        final adminArea = p.administrativeArea ?? '';
        final country = p.country ?? '';
        
        final parts = [
          if (street.isNotEmpty) street,
          if (subLocality.isNotEmpty) subLocality,
          if (locality.isNotEmpty) locality,
          if (adminArea.isNotEmpty) adminArea,
          if (country.isNotEmpty) country,
        ];
        final formatted = parts.join('، ');

        String? matchedGov;
        String? matchedCity;
        
        if (adminArea.contains('الإسكندرية') || adminArea.toLowerCase().contains('alexandria') ||
            locality.contains('الإسكندرية') || locality.toLowerCase().contains('alexandria')) {
          matchedGov = 'الإسكندرية';
        } else if (adminArea.contains('القاهرة') || adminArea.toLowerCase().contains('cairo') ||
                   locality.contains('القاهرة') || locality.toLowerCase().contains('cairo')) {
          matchedGov = 'القاهرة';
        } else if (adminArea.contains('الجيزة') || adminArea.toLowerCase().contains('giza') ||
                   locality.contains('الجيزة') || locality.toLowerCase().contains('giza')) {
          matchedGov = 'الجيزة';
        } else {
          matchedGov = adminArea.replaceAll('Governorate', '').replaceAll('محافظة', '').trim();
        }

        final alexCities = EgyptLocations.citiesFor('الإسكندرية');
        for (var city in alexCities) {
          if (subLocality == city || locality == city || street.contains(city) ||
              subLocality.contains(city) || locality.contains(city)) {
            matchedCity = city;
            matchedGov = 'الإسكندرية';
            break;
          }
        }

        if (matchedCity == null && subLocality.isNotEmpty) {
          matchedCity = subLocality.replaceAll('قسم ', '').replaceAll('حي ', '').trim();
        }

        final fallbackResult = GeocodingResult(
          address: formatted,
          latitude: lat,
          longitude: lng,
          governorate: matchedGov,
          city: matchedCity,
        );
        debugPrint('[LocationService] Native reverse geocode fallback success: '
            'address="${fallbackResult.address}", gov="${fallbackResult.governorate}", city="${fallbackResult.city}"');
        return fallbackResult;
      }
    } catch (err) {
      debugPrint('[LocationService] Native geocoding fallback failed: $err');
    }
    return null;
  }

  /// Google Places Autocomplete API constrained to Egypt, optionally biased to coordinates.
  Future<List<dynamic>> searchAutocompleteGoogle(String query, {double? biasLat, double? biasLng}) async {
    if (query.trim().isEmpty) return [];
    
    var url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleApiKey&language=ar&components=country:eg';
    if (biasLat != null && biasLng != null) {
      url += '&location=$biasLat,$biasLng&radius=50000';
    }
    
    debugPrint('[LocationService] searchAutocompleteGoogle: query="$query" biasLat=$biasLat biasLng=$biasLng');
    try {
      final response = await _dio.get(url);
      final status = response.data['status']?.toString() ?? '';
      final errorMessage = response.data['error_message']?.toString() ?? 'No error message';
      
      if (response.statusCode == 200) {
        final predictions = response.data['predictions'] as List? ?? [];
        debugPrint('[LocationService] Autocomplete results count: ${predictions.length} (status: $status, error: $errorMessage, key: ${_googleApiKey.length > 8 ? "${_googleApiKey.substring(0, 8)}..." : _googleApiKey})');
        return predictions;
      }
    } catch (e) {
      debugPrint('[LocationService] Error in searchAutocompleteGoogle: $e');
    }
    return [];
  }

  /// Fetch place coordinates and address components by Google Place ID.
  Future<GeocodingResult?> getPlaceDetailsGoogle(String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleApiKey&language=ar';
    debugPrint('[LocationService] getPlaceDetailsGoogle: placeId=$placeId');
    try {
      final response = await _dio.get(url);
      final status = response.data['status']?.toString() ?? '';
      debugPrint('[LocationService] getPlaceDetailsGoogle status: $status');
      
      if (response.statusCode == 200 && status == 'OK') {
        final resultData = response.data['result'];
        final formattedAddress = resultData['formatted_address'] as String? ?? '';
        final addressComponents = resultData['address_components'] as List? ?? [];
        final resolved = resolveLocationFromAddressComponents(addressComponents);
        
        final loc = resultData['geometry']['location'];
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();

        final result = GeocodingResult(
          address: formattedAddress,
          latitude: lat,
          longitude: lng,
          governorate: resolved['governorate'],
          city: resolved['city'],
        );
        debugPrint('[LocationService] Place details success: address="${result.address}", gov="${result.governorate}", city="${result.city}"');
        return result;
      }
    } catch (e) {
      debugPrint('[LocationService] Error in getPlaceDetailsGoogle: $e');
    }
    return null;
  }

  /// Google Geocoding API constrained to Egypt and biased to visible viewport bounds or center.
  Future<GeocodingResult?> geocodeAddressGoogle(String query, {double? biasLat, double? biasLng, String? bounds}) async {
    if (query.trim().isEmpty) return null;
    
    var url = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$_googleApiKey&language=ar&components=country:eg';
    if (bounds != null) {
      url += '&bounds=$bounds';
    } else if (biasLat != null && biasLng != null) {
      final swLat = biasLat - 0.5;
      final swLng = biasLng - 0.5;
      final neLat = biasLat + 0.5;
      final neLng = biasLng + 0.5;
      url += '&bounds=$swLat,$swLng|$neLat,$neLng';
    }
    
    debugPrint('[LocationService] geocodeAddressGoogle: query="$query" bounds="$bounds" biasLat=$biasLat biasLng=$biasLng');
    try {
      final response = await _dio.get(url);
      final status = response.data['status']?.toString() ?? '';
      final errorMessage = response.data['error_message']?.toString() ?? 'No error message';
      debugPrint('[LocationService] geocodeAddressGoogle status: $status, error: $errorMessage, key: ${_googleApiKey.length > 8 ? "${_googleApiKey.substring(0, 8)}..." : _googleApiKey}');
      
      if (response.statusCode == 200 && status == 'OK') {
        final results = response.data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final firstResult = results[0];
          final formattedAddress = firstResult['formatted_address'] as String? ?? '';
          final addressComponents = firstResult['address_components'] as List? ?? [];
          final resolved = resolveLocationFromAddressComponents(addressComponents);
          
          final latLng = firstResult['geometry']['location'];
          final lat = (latLng['lat'] as num).toDouble();
          final lng = (latLng['lng'] as num).toDouble();

          final result = GeocodingResult(
            address: formattedAddress,
            latitude: lat,
            longitude: lng,
            governorate: resolved['governorate'],
            city: resolved['city'],
          );
          debugPrint('[LocationService] Geocoding success: address="${result.address}", gov="${result.governorate}", city="${result.city}"');
          return result;
        }
      } else {
        debugPrint('[LocationService] Geocoding failed API check (Status: $status). Trying native geocoding search fallback...');
        return await _geocodeAddressNativeFallback(query);
      }
    } catch (e) {
      debugPrint('[LocationService] Error in geocodeAddressGoogle: $e. Trying native fallback...');
      return await _geocodeAddressNativeFallback(query);
    }
    return null;
  }

  /// Native Geocoding Search fallback using device services (free, offline/OS geocoder)
  Future<GeocodingResult?> _geocodeAddressNativeFallback(String query) async {
    try {
      debugPrint('[LocationService] Performing native geocoding search fallback for: "$query"');
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        
        // Retrieve address name components for coordinates using native reverse geocoder
        final reverseResult = await _reverseGeocodeNativeFallback(loc.latitude, loc.longitude);
        if (reverseResult != null) {
          return reverseResult;
        }
        
        return GeocodingResult(
          address: query,
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      }
    } catch (err) {
      debugPrint('[LocationService] Native geocoding search fallback failed: $err');
    }
    return null;
  }
}
