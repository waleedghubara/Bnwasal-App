// ignore_for_file: unused_field, deprecated_member_use, avoid_print

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:we_deliver/core/cache/cache_helper.dart';
import 'package:we_deliver/core/api/end_point.dart';
import 'package:we_deliver/core/di/injection_container.dart' as di;

import '../../domain/entities/shipment.dart';
import 'package:we_deliver/features/profile/presentation/bloc/review_cubit.dart';
import '../../domain/usecases/get_shipment_by_id_usecase.dart';
import '../../domain/usecases/update_shipment_status_usecase.dart';
import '../../../../core/theme/colors.dart';
import 'package:we_deliver/core/utils/constants.dart';

class TrackShipmentScreen extends StatefulWidget {
  final Shipment shipment;

  const TrackShipmentScreen({super.key, required this.shipment});

  @override
  State<TrackShipmentScreen> createState() => _TrackShipmentScreenState();
}

class _TrackShipmentScreenState extends State<TrackShipmentScreen> {
  final ReviewCubit _reviewCubit = di.sl<ReviewCubit>();
  String _userRating = '—';
  bool _hasReviewed = false;
  bool _ratingDialogShown = false;
  late Shipment _localShipment;
  bool _isDelivery = false;
  bool _isRoleLoaded = false;
  bool _isTripSummaryExpanded = true;
  io.Socket? _socket;
  StreamSubscription<Position>? _positionSubscription;

  bool _hasStatus(List<String> statuses) {
    final s = _localShipment.status.trim().toLowerCase().replaceAll('_', ' ');
    return statuses.any((target) {
      final t = target.trim().toLowerCase().replaceAll('_', ' ');
      return s == t;
    });
  }

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  BitmapDescriptor? _driverIcon;

  late LatLng _origin;
  late LatLng _destination;
  late LatLng _driverPos;

  LatLng get _routeStart {
    final hasDriverLocation =
        _localShipment.driverLatitude != null &&
        _localShipment.driverLongitude != null &&
        _localShipment.driverLatitude != 0.0 &&
        _localShipment.driverLongitude != 0.0;

    final isPending = _hasStatus([
      ShipmentStatus.newShipment,
      ShipmentStatus.negotiation,
      ShipmentStatus.awaitingPayment,
      ShipmentStatus.readyForAssignment,
    ]);

    if (isPending || !hasDriverLocation) {
      return _origin;
    }

    final isDeliveredOrDelivering = _hasStatus([
      ShipmentStatus.pickedUp,
      ShipmentStatus.inTransit,
      ShipmentStatus.delivered,
      ShipmentStatus.completed,
      ShipmentStatus.cancelled,
    ]);

    if (!isDeliveredOrDelivering) {
      return _driverPos;
    } else {
      if (_localShipment.startLatitude != null &&
          _localShipment.startLongitude != null &&
          _localShipment.startLatitude != 0.0 &&
          _localShipment.startLongitude != 0.0) {
        return LatLng(
          _localShipment.startLatitude!,
          _localShipment.startLongitude!,
        );
      }
      return _driverPos;
    }
  }

  LatLng get _routeEnd {
    final hasDriverLocation =
        _localShipment.driverLatitude != null &&
        _localShipment.driverLongitude != null &&
        _localShipment.driverLatitude != 0.0 &&
        _localShipment.driverLongitude != 0.0;

    final isPending = _hasStatus([
      ShipmentStatus.newShipment,
      ShipmentStatus.negotiation,
      ShipmentStatus.awaitingPayment,
      ShipmentStatus.readyForAssignment,
    ]);

    if (isPending || !hasDriverLocation) {
      return _destination;
    }

    final isDeliveredOrDelivering = _hasStatus([
      ShipmentStatus.pickedUp,
      ShipmentStatus.inTransit,
      ShipmentStatus.delivered,
      ShipmentStatus.completed,
      ShipmentStatus.cancelled,
    ]);

    if (!isDeliveredOrDelivering) {
      return _origin;
    } else {
      return _destination;
    }
  }

  bool get _isOnDeliveryLeg {
    return _hasStatus([
      ShipmentStatus.pickedUp,
      ShipmentStatus.inTransit,
      ShipmentStatus.delivered,
    ]);
  }

  final String _googleApiKey = AppConstants.googleMapsApiKey;

  String _timeRemaining = 'جاري حساب الوقت...';
  int _totalTripMinutes = 15;
  double _totalRouteDistanceMeters = 0.0;
  int _activeStepIndex = 1;

  Offset? _driverScreenOffset;

  // Movement status variables
  bool _isDriverMoving = false;
  bool _isMerchantMoving = false;
  double _driverRotation = 0.0;
  Timer? _movementTimeoutTimer;
  Timer? _merchantMovementTimeoutTimer;
  LatLng? _lastPos;
  LatLng? _lastMerchantPos;

  /// Map marker position — frozen while stationary; only moves when GPS confirms travel.
  LatLng? _anchoredPos;

  /// Last GPS point used to measure walked distance along the route.
  LatLng? _lastRouteAdvanceGpsPos;
  DateTime? _lastSocketEmitTime; // throttle server emissions
  /// Furthest index reached on the planned route (never moves backward).
  int _routeProgressIndex = 0;
  static const double _minWalkedMetersForRouteAdvance = 5.5;
  static const double _minGpsDeltaForMoving = 5.5;
  static const double _maxDeltaWhenStationary = 4.0;
  static const double _maxSpeedWhenStationary =
      0.55; // ~2 km/h — stop within ~1s
  static const double _minSpeedMsForMoving = 0.9;
  double _lastKnownSpeedMs = 1.4; // default ~5 km/h walking
  bool? _lastRouteWasDeliveryLeg;

  // Navigation mode — when true the camera tracks the driver with tilt+bearing
  bool _isNavigationMode = true;
  // Tracks whether the user is manually panning so we can show the re-center button
  bool _isUserPanning = false;

  Future<void> _updateDriverScreenPosition() async {
    if (!mounted || _mapController == null) return;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    try {
      final screenCoordinate = await _mapController!.getScreenCoordinate(
        _driverPos,
      );
      if (!mounted) return;
      setState(() {
        _driverScreenOffset = Offset(
          screenCoordinate.x.toDouble() / devicePixelRatio,
          screenCoordinate.y.toDouble() / devicePixelRatio,
        );
      });
    } catch (_) {}
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> _getCaptainGpsFix() async {
    if (!await _ensureLocationPermission()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  void _emitCaptainLocation(
    double latitude,
    double longitude, {
    bool isMoving = false,
    double bearing = 0,
    double speed = 0,
  }) {
    final payload = {
      'shipmentId': _localShipment.id,
      'latitude': latitude,
      'longitude': longitude,
      'bearing': bearing,
      'isMoving': isMoving,
      'speed': speed,
      'isDriver': true,
    };
    if (_socket?.connected == true) {
      _socket!.emit('updateLocation', payload);
      _lastSocketEmitTime = DateTime.now();
    }
  }

  /// Captain: precise GPS on open + route to pickup or delivery target.
  Future<void> _refreshCaptainLocationAndRoute() async {
    final pos = await _getCaptainGpsFix();
    if (pos == null || !mounted) return;

    final latLng = LatLng(pos.latitude, pos.longitude);
    _lastPos = latLng;
    _anchoredPos = latLng;
    _lastRouteAdvanceGpsPos = latLng;

    final deliveryLeg = _isOnDeliveryLeg;
    if (_lastRouteWasDeliveryLeg != null &&
        _lastRouteWasDeliveryLeg != deliveryLeg) {
      _routeProgressIndex = 0;
    }
    _lastRouteWasDeliveryLeg = deliveryLeg;

    setState(() {
      _driverPos = latLng;
      _updateDriverMarker();
      _localShipment = _localShipment.copyWith(
        driverLatitude: pos.latitude,
        driverLongitude: pos.longitude,
      );
    });

    _emitCaptainLocation(
      pos.latitude,
      pos.longitude,
      bearing: _driverRotation,
      isMoving: false,
      speed: pos.speed.clamp(0.0, double.infinity),
    );

    await _getPolyline();
    if (!mounted) return;

    setState(() {
      _routeProgressIndex = 0;
      _updatePolylinesFromDriverPos();
      _timeRemaining = _formatRemainingTime(_remainingPolylineMeters());
    });

    _fitMapToPolyline();
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: 17.5,
          bearing: _driverRotation,
          tilt: _isNavigationMode ? 45.0 : 0,
        ),
      ),
    );
    _updateDriverScreenPosition();
  }

  @override
  void initState() {
    super.initState();
    _localShipment = widget.shipment;

    _origin = LatLng(
      _localShipment.merchantLatitude ?? 30.0595,
      _localShipment.merchantLongitude ?? 31.3285,
    );
    _destination = LatLng(
      _localShipment.toLatitude ?? 30.0074,
      _localShipment.toLongitude ?? 31.4913,
    );
    final hasDrv =
        _localShipment.driverLatitude != null &&
        _localShipment.driverLongitude != null &&
        _localShipment.driverLatitude != 0.0 &&
        _localShipment.driverLongitude != 0.0;
    _driverPos = LatLng(
      hasDrv ? _localShipment.driverLatitude! : _origin.latitude,
      hasDrv ? _localShipment.driverLongitude! : _origin.longitude,
    );

    _initAll();
  }

  Future<void> _initAll() async {
    await _checkRole();
    await _fetchLatestShipmentDetails();
    if (mounted) {
      setState(() {
        _isRoleLoaded = true;
      });
    }
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDelivery = prefs.getBool('isDelivery') ?? false;
      });
      _loadDriverIcon();
      _initSocket();
    }
  }

  void _initSocket() async {
    final token = await SecureCacheHelper().getData(key: ApiKey.token);

    _socket = io.io(
      EndPoint.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setAuth({'token': token ?? ''})
          .build(),
    );
    _socket!.connect();

    _socket!.onConnect((_) {
      print('🔌 Track Socket Connected: ${_socket!.id}');
      _socket!.emit('joinRoom', 'shipment_${_localShipment.id}');
      if (_isDelivery) {
        _emitCaptainLocation(
          _driverPos.latitude,
          _driverPos.longitude,
          bearing: _driverRotation,
          isMoving: _isDriverMoving,
        );
      }
    });

    _socket!.on('locationUpdate', (data) {
      if (data == null) return;

      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      final newPos = LatLng(lat, lng);
      final isDriverUpdate = data['isDriver'] as bool? ?? true;

      if (_isDelivery && isDriverUpdate) return;
      if (!_isDelivery && !isDriverUpdate) return;

      final bearing = data['bearing'] != null
          ? (data['bearing'] as num).toDouble()
          : (_isDelivery
                ? _calculateBearing(_origin, newPos)
                : _calculateBearing(_driverPos, newPos));
      final isMoving = data['isMoving'] as bool? ?? false;

      if (mounted) {
        setState(() {
          if (!_isDelivery) {
            _localShipment = _localShipment.copyWith(
              driverLatitude: lat,
              driverLongitude: lng,
            );
            _driverPos = newPos;
            _driverRotation = bearing;
            _updateDriverMarker(rotation: bearing);
          } else {
            _origin = newPos;
            _addBaseMarkers();
            _localShipment = _localShipment.copyWith(
              merchantLatitude: lat,
              merchantLongitude: lng,
            );
          }

          bool shouldRefetch = false;
          if (_polylineCoordinates.isNotEmpty) {
            double minDistance = double.maxFinite;
            for (var pt in _polylineCoordinates) {
              double dist = Geolocator.distanceBetween(
                newPos.latitude,
                newPos.longitude,
                pt.latitude,
                pt.longitude,
              );
              if (dist < minDistance) {
                minDistance = dist;
              }
            }
            if (minDistance > 150) {
              shouldRefetch = true;
            }
          } else {
            shouldRefetch = true;
          }

          if (shouldRefetch) {
            _getPolyline().then((_) {
              if (mounted) setState(() {});
            });
          } else {
            if (!_isDelivery && isMoving) {
              _updatePolylinesFromDriverPos(advancing: true);
            }
          }

          double distanceInMeters = Geolocator.distanceBetween(
            _driverPos.latitude,
            _driverPos.longitude,
            _routeEnd.latitude,
            _routeEnd.longitude,
          );
          _timeRemaining = _formatRemainingTime(distanceInMeters);
        });
        if (_isDelivery) {
          _onMerchantLocationReceived(newPos, forceMoving: isMoving);
        } else {
          _onLocationReceived(newPos, forceMoving: isMoving);
        }
        _updateDriverScreenPosition();
      }
    });

    _socket!.on('statusUpdate', (data) {
      print('🔔 Status updated via Socket: $data');
      _fetchLatestShipmentDetails();
    });

    _socket!.onDisconnect((_) {
      print('🔌 Track Socket Disconnected');
    });
  }

  Future<void> _loadRatingAndReviewStatus() async {
    if (!mounted) return;

    // 1. Fetch user rating for the other party
    final otherUserId = _isDelivery
        ? _localShipment.merchantId
        : _localShipment.driverId;
    if (otherUserId != null) {
      final summary = await _reviewCubit.getUserRating(otherUserId);
      if (summary != null && mounted) {
        setState(() {
          _userRating = summary.formattedRating;
        });
      }
    }

    // 2. Check review status
    final status = await _reviewCubit.checkReviewStatus(_localShipment.id);
    if (status != null && mounted) {
      setState(() {
        _hasReviewed = status.hasReviewed;
      });

      // 3. Auto-trigger rating dialog if shipment is completed and not reviewed yet
      if (_hasStatus([ShipmentStatus.completed]) &&
          !status.hasReviewed &&
          !_ratingDialogShown &&
          context.mounted) {
        final name = _isDelivery
            ? (_localShipment.clientName ?? 'التاجر')
            : (_localShipment.driverName ?? 'المندوب');
        _showRatingDialog(context, name, isRatingDriver: !_isDelivery);
      }
    }
  }

  Future<void> _fetchLatestShipmentDetails() async {
    try {
      final shipment = await di.sl<GetShipmentByIdUseCase>().call(
        _localShipment.id,
      );
      if (mounted) {
        setState(() {
          _localShipment = shipment;
          _origin = LatLng(
            _localShipment.merchantLatitude ?? 30.0595,
            _localShipment.merchantLongitude ?? 31.3285,
          );
          _destination = LatLng(
            _localShipment.toLatitude ?? 30.0074,
            _localShipment.toLongitude ?? 31.4913,
          );
          if (!_isDelivery) {
            final hasDrv =
                _localShipment.driverLatitude != null &&
                _localShipment.driverLongitude != null &&
                _localShipment.driverLatitude != 0.0 &&
                _localShipment.driverLongitude != 0.0;
            _driverPos = LatLng(
              hasDrv ? _localShipment.driverLatitude! : _origin.latitude,
              hasDrv ? _localShipment.driverLongitude! : _origin.longitude,
            );
          }
          _updateMilestoneSteps();
        });
        _loadDriverIcon();
        _addBaseMarkers();
        if (_isDelivery) {
          await _refreshCaptainLocationAndRoute();
        } else {
          await _getPolyline();
          _seedRouteProgressFromDriverPosition();
          _fitMapToPolyline();
        }
        _loadRatingAndReviewStatus();
      }
    } catch (e) {
      print('❌ Failed to fetch shipment details: $e');
    }
  }

  void _updateMilestoneSteps() {
    if (_hasStatus([
      ShipmentStatus.assignedToCaptain,
      'assigned to captain',
      'تم قبول الطلب',
      'تم قبول الكابتن للمهمة',
      'جديدة',
      'جديد',
      'pending',
      ShipmentStatus.readyForAssignment,
      'ready for assignment',
      'في انتظار المندوب',
      ShipmentStatus.captainArrived,
      'captain arrived',
      'في الطريق للاستلام',
      'فى الطريق للاستلام',
      'جاري الاستلام',
    ])) {
      _activeStepIndex = 1; // 1. تم قبول الطلب (المطلوب: تم استلام الشحنة)
      if (_isDelivery) {
        _startGpsStreaming();
      } else {
        _stopGpsStreaming();
      }
    } else if (_hasStatus([
      ShipmentStatus.pickedUp,
      'picked up',
      'تم استلام الشحنة',
      'تم الاستلام',
      'تم استلام الشحنة / شراء الطلبات',
      ShipmentStatus.inTransit,
      'in transit',
      'في الطريق للتسليم',
      'فى الطريق للتسليم',
      'جاري التوصيل',
      'قيد التوصيل',
    ])) {
      _activeStepIndex = 2; // 2. تم استلام الشحنة (المطلوب: تم التسليم)
      if (_isDelivery) {
        _startGpsStreaming();
      } else {
        _stopGpsStreaming();
      }
    } else if (_hasStatus([
      ShipmentStatus.delivered,
      'delivered',
      'تم التسليم بنجاح',
      'تم التوصيل بنجاح',
      'تم التوصيل',
      'تم التسليم',
    ])) {
      _activeStepIndex = 3; // 3. تم التوصيل بنجاح
      _stopGpsStreaming();
    } else if (_hasStatus([
      ShipmentStatus.completed,
      'completed',
      'مكتملة',
      'مكتمل',
      'منتهية',
      'finished',
    ])) {
      _activeStepIndex = 4; // 4. مكتمل
      _stopGpsStreaming();
    } else if (_hasStatus([
      ShipmentStatus.cancelled,
      'cancelled',
      'ملغاة',
      'ملغي',
      'مرفوض',
    ])) {
      _activeStepIndex = 10;
      _stopGpsStreaming();
    }
  }

  void _onLocationReceived(LatLng newPos, {bool? forceMoving}) {
    if (forceMoving != null) {
      setState(() {
        _isDriverMoving = forceMoving;
      });
    }

    _lastPos = newPos;

    _movementTimeoutTimer?.cancel();
    _movementTimeoutTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isDriverMoving = false;
        });
      }
    });
  }

  void _onMerchantLocationReceived(LatLng newPos, {bool? forceMoving}) {
    if (forceMoving != null) {
      setState(() {
        _isMerchantMoving = forceMoving;
      });
    } else {
      if (_lastMerchantPos != null) {
        final distance = Geolocator.distanceBetween(
          _lastMerchantPos!.latitude,
          _lastMerchantPos!.longitude,
          newPos.latitude,
          newPos.longitude,
        );
        if (distance > 2) {
          setState(() {
            _isMerchantMoving = true;
          });
        }
      } else {
        setState(() {
          _isMerchantMoving = true;
        });
      }
    }

    _lastMerchantPos = newPos;

    _merchantMovementTimeoutTimer?.cancel();
    _merchantMovementTimeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() {
          _isMerchantMoving = false;
        });
      }
    });
  }

  LocationSettings _captainStreamSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
  }

  bool _captainGpsIndicatesMoving(Position position, LatLng rawPos) {
    final anchor = _anchoredPos ?? _driverPos;
    final deltaFromAnchor = Geolocator.distanceBetween(
      anchor.latitude,
      anchor.longitude,
      rawPos.latitude,
      rawPos.longitude,
    );
    final speed = position.speed.clamp(0.0, double.infinity);

    // Stopped: react within ~1 second (low speed + almost no movement).
    if (speed <= _maxSpeedWhenStationary &&
        deltaFromAnchor < _maxDeltaWhenStationary) {
      return false;
    }

    if (position.accuracy > 18) return false;
    if (speed >= _minSpeedMsForMoving && position.accuracy <= 15) return true;
    if (deltaFromAnchor >= _minGpsDeltaForMoving && position.accuracy <= 18) {
      return true;
    }
    return false;
  }

  /// Route polyline starts exactly at captain GPS, not an offset road node.
  void _snapRouteToExactCaptainPosition() {
    if (_polylineCoordinates.isEmpty) return;
    final exact = _anchoredPos ?? _driverPos;
    final gap = Geolocator.distanceBetween(
      exact.latitude,
      exact.longitude,
      _polylineCoordinates.first.latitude,
      _polylineCoordinates.first.longitude,
    );
    if (gap > 2) {
      _polylineCoordinates = [exact, ..._polylineCoordinates];
    } else {
      _polylineCoordinates[0] = exact;
    }
  }

  double _remainingPolylineMeters() {
    if (_polylineCoordinates.isEmpty) {
      return Geolocator.distanceBetween(
        _driverPos.latitude,
        _driverPos.longitude,
        _routeEnd.latitude,
        _routeEnd.longitude,
      );
    }
    int idx = _routeProgressIndex;
    if (!_isDelivery) {
      double minDistance = double.maxFinite;
      for (int i = 0; i < _polylineCoordinates.length; i++) {
        final dist = Geolocator.distanceBetween(
          _driverPos.latitude,
          _driverPos.longitude,
          _polylineCoordinates[i].latitude,
          _polylineCoordinates[i].longitude,
        );
        if (dist < minDistance) {
          minDistance = dist;
          idx = i;
        }
      }
    }
    if (idx >= _polylineCoordinates.length - 1) return 0;
    return _calculatePolylineDistance(_polylineCoordinates.sublist(idx));
  }

  /// Advance yellow "done" segment only by real walked GPS distance on the route.
  void _advanceRouteProgressByWalkedGps(LatLng gpsPos) {
    if (_polylineCoordinates.length < 2) return;

    final from = _lastRouteAdvanceGpsPos ?? _anchoredPos ?? _driverPos;
    final walked = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      gpsPos.latitude,
      gpsPos.longitude,
    );
    if (walked < _minWalkedMetersForRouteAdvance) return;

    double distToRoute = double.maxFinite;
    for (final pt in _polylineCoordinates) {
      final d = Geolocator.distanceBetween(
        gpsPos.latitude,
        gpsPos.longitude,
        pt.latitude,
        pt.longitude,
      );
      if (d < distToRoute) distToRoute = d;
    }
    if (distToRoute > 70) return;

    double budget = walked;
    int idx = _routeProgressIndex;
    while (idx < _polylineCoordinates.length - 1 && budget > 0) {
      final seg = Geolocator.distanceBetween(
        _polylineCoordinates[idx].latitude,
        _polylineCoordinates[idx].longitude,
        _polylineCoordinates[idx + 1].latitude,
        _polylineCoordinates[idx + 1].longitude,
      );
      if (budget >= seg) {
        budget -= seg;
        idx++;
      } else {
        break;
      }
    }

    if (idx > _routeProgressIndex) {
      _routeProgressIndex = idx;
      _updatePolylinesFromDriverPos();
    }
    _lastRouteAdvanceGpsPos = gpsPos;
  }

  void _startGpsStreaming() async {
    if (!_isDelivery) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return;
    }

    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _captainStreamSettings(),
        ).listen((Position position) {
          if (position.accuracy > 18) return;

          final rawPos = LatLng(position.latitude, position.longitude);
          final speed = position.speed.clamp(0.0, double.infinity);
          final isMoving = _captainGpsIndicatesMoving(position, rawPos);

          // ── Stationary: freeze marker + route progress; heartbeat only ─────────
          if (!isMoving) {
            final anchor = _anchoredPos ?? _driverPos;
            final now = DateTime.now();
            final msSinceLast = _lastSocketEmitTime != null
                ? now.difference(_lastSocketEmitTime!).inMilliseconds
                : 99999;
            if (msSinceLast >= 10000) {
              _emitCaptainLocation(
                anchor.latitude,
                anchor.longitude,
                bearing: _driverRotation,
                isMoving: false,
              );
            }
            if (mounted) {
              setState(() {
                _isDriverMoving = false;
                _timeRemaining = _formatRemainingTime(
                  _remainingPolylineMeters(),
                );
              });
            }
            return;
          }

          if (speed >= _minSpeedMsForMoving) {
            _lastKnownSpeedMs = speed;
          }

          final prevForBearing = _anchoredPos ?? _driverPos;
          double bearing = _driverRotation;
          final rawBearing = _calculateBearing(prevForBearing, rawPos);
          bearing = (_driverRotation * 0.7 + rawBearing * 0.3) % 360;

          final now = DateTime.now();
          final msSinceLast = _lastSocketEmitTime != null
              ? now.difference(_lastSocketEmitTime!).inMilliseconds
              : 99999;
          if (isMoving || msSinceLast >= 10000) {
            _emitCaptainLocation(
              rawPos.latitude,
              rawPos.longitude,
              bearing: bearing,
              isMoving: true,
              speed: speed,
            );
          }

          _lastPos = rawPos;
          _anchoredPos = rawPos;

          if (!mounted) return;

          setState(() {
            _localShipment = _localShipment.copyWith(
              driverLatitude: rawPos.latitude,
              driverLongitude: rawPos.longitude,
              startLatitude: _localShipment.startLatitude ?? rawPos.latitude,
              startLongitude: _localShipment.startLongitude ?? rawPos.longitude,
            );
            _driverRotation = bearing;
            _driverPos = rawPos;
            _isDriverMoving = true;
            _updateDriverMarker(rotation: bearing);

            if (_isNavigationMode) {
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _driverPos,
                    zoom: 17.5,
                    bearing: bearing,
                    tilt: 45.0,
                  ),
                ),
              );
            }

            bool shouldRefetch = false;
            if (_polylineCoordinates.isNotEmpty) {
              double minDistance = double.maxFinite;
              for (final pt in _polylineCoordinates) {
                final d = Geolocator.distanceBetween(
                  rawPos.latitude,
                  rawPos.longitude,
                  pt.latitude,
                  pt.longitude,
                );
                if (d < minDistance) minDistance = d;
              }
              if (minDistance > 150) shouldRefetch = true;
            } else {
              shouldRefetch = true;
            }

            if (shouldRefetch) {
              _lastRouteAdvanceGpsPos = rawPos;
              _getPolyline().then((_) {
                if (mounted) setState(() {});
              });
            } else {
              _advanceRouteProgressByWalkedGps(rawPos);
            }

            _timeRemaining = _formatRemainingTime(_remainingPolylineMeters());
          });
          _onLocationReceived(rawPos, forceMoving: true);
          _updateDriverScreenPosition();
        });
  }

  void _stopGpsStreaming() {
    _positionSubscription?.cancel();
    _movementTimeoutTimer?.cancel();
  }

  Future<void> _confirmDelivery() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition();
      await di.sl<Dio>().post(
        '${EndPoint.baseUrl}${EndPoint.confirmShipmentDelivery(_localShipment.id.toString())}',
        data: {'latitude': position.latitude, 'longitude': position.longitude},
      );
      if (mounted) {
        Navigator.pop(context); // pop loader
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد تسليم الشحنة بنجاح واكتمال الطلب'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchLatestShipmentDetails();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // pop loader
        String msg = 'فشل التأكيد';
        if (e is DioException) {
          if (e.response?.data is Map) {
            msg = e.response!.data['message'] ?? 'فشل التأكيد';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التأكيد: $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMandatoryPickupConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF2E7D32),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تأكيد استلام الشحنة *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'يرجى التأكد من استلام الشحنة من موقع الاستلام بحالة سليمة ومطابقة للبيانات.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'هذه الخطوة إجبارية لبدء التوصيل إلى العميل.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatusOnServer(ShipmentStatus.pickedUp);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'تأكيد الاستلام الآن',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMandatoryDeliveryConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تأكيد التوصيل بنجاح *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'يرجى التأكد من تسليم الشحنة للعميل المستلم واستلام المبلغ المطلوب بالكامل.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF2E7D32),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'هذه الخطوة إجبارية لإتمام وتأكيد الشحنة واحتساب أرباحك.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatusOnServer('Delivered');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'تأكيد التوصيل الآن',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatusOnServer(String status) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      double? lat;
      double? lng;
      if ((status == ShipmentStatus.pickedUp ||
              status == ShipmentStatus.delivered) &&
          _isDelivery) {
        lat = _driverPos.latitude;
        lng = _driverPos.longitude;
      }

      await di.sl<UpdateShipmentStatusUseCase>().call(
        _localShipment.id,
        status,
        latitude: lat,
        longitude: lng,
      );

      if (mounted) {
        if (status == ShipmentStatus.delivered ||
            status == 'منتهية' ||
            status == 'completed') {}
        Navigator.pop(context); // Pop loading
        _fetchLatestShipmentDetails();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في التحديث: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateDriverMarker({double rotation = 0.0}) {
    _markers.removeWhere((m) => m.markerId.value == 'driver');

    final isNewOrPending = _hasStatus([
      ShipmentStatus.newShipment,
      ShipmentStatus.negotiation,
      ShipmentStatus.awaitingPayment,
      ShipmentStatus.readyForAssignment,
    ]);

    final hasDriverPos =
        _driverPos.latitude != 0.0 && _driverPos.longitude != 0.0;

    if (isNewOrPending || !hasDriverPos) {
      return;
    }

    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverPos,
        rotation: rotation,
        anchor: const Offset(0.5, 0.5),
        icon:
            _driverIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'المندوب'),
      ),
    );
  }

  Future<void> _loadDriverIcon() async {
    // The moving marker always represents the captain/driver.
    // Use driverAvatar in all cases — _isDelivery only means the CURRENT USER is the driver,
    // not that the marker should show a different person.
    final avatarUrl = _localShipment.driverAvatar;
    final fullAvatarUrl = avatarUrl != null && avatarUrl.isNotEmpty
        ? '${EndPoint.imageBaseUrl}$avatarUrl'
        : 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-1.2.1&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80';

    // Driver viewing their own marker → smaller (less obtrusive).
    // Merchant/client watching the driver → larger so it's easy to spot.
    final int markerSize = _isDelivery ? 80 : 120;

    try {
      _driverIcon = await _getCircularMarkerWithImage(
        fullAvatarUrl,
        size: markerSize,
      );
    } catch (_) {
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
    }
    if (mounted) {
      setState(() {
        _updateDriverMarker();
      });
    }
  }

  Future<void> _initMap() async {
    if (_isDelivery && _polylineCoordinates.isEmpty) {
      await _refreshCaptainLocationAndRoute();
    } else {
      _addBaseMarkers();
      if (_polylineCoordinates.isEmpty) {
        await _getPolyline();
      }
      if (_isDelivery) {
        _updatePolylinesFromDriverPos();
      }
      _fitMapToPolyline();
    }
  }

  void _addBaseMarkers() {
    setState(() {
      _markers.removeWhere(
        (m) =>
            m.markerId.value == 'origin' || m.markerId.value == 'destination',
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: _origin,
          infoWindow: const InfoWindow(title: 'نقطة الاستلام'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination,
          infoWindow: const InfoWindow(title: 'نقطة التسليم'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  Future<void> _getPolyline() async {
    bool success = await _fetchGoogleRoute();
    if (!success) {
      success = await _fetchOSRMRoute();
    }
    if (!success) {
      _setupFallbackRoute();
    }
  }

  String _directionsTravelMode() {
    final speedKmh = _lastKnownSpeedMs * 3.6;
    if (speedKmh < 7) return 'walking';
    if (speedKmh < 18) return 'bicycling';
    return 'driving';
  }

  Future<bool> _fetchGoogleRoute() async {
    try {
      final start = _routeStart;
      final end = _routeEnd;
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${start.latitude},${start.longitude}',
          'destination': '${end.latitude},${end.longitude}',
          'key': _googleApiKey,
          'mode': _directionsTravelMode(),
        },
      );

      if (response.data['status'] == 'OK') {
        final route = response.data['routes'][0];
        final points = route['overview_polyline']['points'];
        final leg = route['legs'][0];
        final distanceMeters = (leg['distance']['value'] as num).toDouble();
        final durationSeconds = (leg['duration']['value'] as num).toDouble();

        _updateRouteOnMap(points, distanceMeters, durationSeconds);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _fetchOSRMRoute() async {
    try {
      final start = _routeStart;
      final end = _routeEnd;
      final String url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}'
          '?overview=full&geometries=polyline';

      final response = await Dio().get(url);

      if (response.data['code'] == 'Ok') {
        final route = response.data['routes'][0];
        final points = route['geometry'];
        final durationSeconds = (route['duration'] as num).toDouble();
        final distanceMeters = (route['distance'] as num).toDouble();

        _updateRouteOnMap(points, distanceMeters, durationSeconds);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _updateRouteOnMap(
    String encodedPolyline,
    double distanceMeters,
    double durationSeconds,
  ) {
    List<PointLatLng> result = PolylinePoints.decodePolyline(encodedPolyline);

    if (result.isNotEmpty) {
      _polylineCoordinates = result
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      if (_isDelivery) {
        _snapRouteToExactCaptainPosition();
      }
      _routeProgressIndex = 0;
      _lastRouteAdvanceGpsPos = _anchoredPos ?? _driverPos;

      _totalRouteDistanceMeters = _calculatePolylineDistance(
        _polylineCoordinates,
      );
      // Fallback: if sum calculation is 0, use API distance
      if (_totalRouteDistanceMeters <= 0.0) {
        _totalRouteDistanceMeters = distanceMeters;
      }
      _totalTripMinutes = (durationSeconds / 60.0).round();

      setState(() {
        _timeRemaining = _formatRemainingTime(_remainingPolylineMeters());
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: _polylineCoordinates,
            color: AppColors.primary,
            width: 6,
            zIndex: 2,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );
        _updateDriverMarker();
      });

      _fitMapToPolyline();
    }
  }

  void _fitMapToPolyline() {
    if (_polylineCoordinates.isEmpty) return;

    double minLat = _polylineCoordinates.first.latitude;
    double minLng = _polylineCoordinates.first.longitude;
    double maxLat = _polylineCoordinates.first.latitude;
    double maxLng = _polylineCoordinates.first.longitude;

    for (var point in _polylineCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        70,
      ),
    );
  }

  void _setupFallbackRoute() {
    List<LatLng> points = [
      _origin,
      LatLng(_origin.latitude - 0.01, _origin.longitude + 0.02),
      LatLng(_origin.latitude - 0.03, _origin.longitude + 0.05),
      LatLng(_origin.latitude - 0.04, _origin.longitude + 0.10),
      _destination,
    ];

    List<LatLng> smoothPoints = [];
    for (int i = 0; i < points.length - 1; i++) {
      for (int j = 0; j < 20; j++) {
        double t = j / 20;
        double lat =
            points[i].latitude +
            (points[i + 1].latitude - points[i].latitude) * t;
        double lng =
            points[i].longitude +
            (points[i + 1].longitude - points[i].longitude) * t;
        smoothPoints.add(LatLng(lat, lng));
      }
    }
    smoothPoints.add(_destination);

    _polylineCoordinates = smoothPoints;
    if (_isDelivery) {
      _snapRouteToExactCaptainPosition();
    }
    _routeProgressIndex = 0;
    _lastRouteAdvanceGpsPos = _anchoredPos ?? _driverPos;

    _totalRouteDistanceMeters = _calculatePolylineDistance(smoothPoints);
    _totalTripMinutes = (_totalRouteDistanceMeters / 11.1 / 60)
        .round(); // ~40 km/h

    setState(() {
      _timeRemaining = _formatRemainingTime(_remainingPolylineMeters());
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _polylineCoordinates,
          color: AppColors.primary,
          width: 4,
          patterns: [PatternItem.dash(15), PatternItem.gap(10)],
        ),
      );
      _updateDriverMarker();
    });
  }

  /// One-time sync for merchant view: progress follows captain's last known position.
  void _seedRouteProgressFromDriverPosition() {
    if (_polylineCoordinates.isEmpty) return;

    int closestIndex = 0;
    double minDistance = double.maxFinite;
    for (int i = 0; i < _polylineCoordinates.length; i++) {
      final dist = Geolocator.distanceBetween(
        _driverPos.latitude,
        _driverPos.longitude,
        _polylineCoordinates[i].latitude,
        _polylineCoordinates[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }
    _routeProgressIndex = closestIndex;
    _updatePolylinesFromDriverPos();
  }

  List<LatLng> _routePointsFromExactCaptain(List<LatLng> tail, LatLng exact) {
    if (tail.isEmpty) return [exact];
    final gap = Geolocator.distanceBetween(
      exact.latitude,
      exact.longitude,
      tail.first.latitude,
      tail.first.longitude,
    );
    if (gap > 2) return [exact, ...tail];
    return [exact, ...tail.skip(1)];
  }

  void _updatePolylinesFromDriverPos({bool advancing = false}) {
    if (_polylineCoordinates.isEmpty) return;

    // Captain: progress only via _advanceRouteProgressByWalkedGps (never snap to closest point).
    // Merchant watching socket: allow forward snap when driver is moving.
    int closestIndex = _routeProgressIndex;
    if (advancing && !_isDelivery) {
      final searchStart = max(0, _routeProgressIndex - 2);
      double minDistance = double.maxFinite;
      for (int i = searchStart; i < _polylineCoordinates.length; i++) {
        final dist = Geolocator.distanceBetween(
          _driverPos.latitude,
          _driverPos.longitude,
          _polylineCoordinates[i].latitude,
          _polylineCoordinates[i].longitude,
        );
        if (dist < minDistance) {
          minDistance = dist;
          closestIndex = i;
        }
      }
      if (closestIndex > _routeProgressIndex) {
        _routeProgressIndex = closestIndex;
      } else {
        closestIndex = _routeProgressIndex;
      }
    } else {
      closestIndex = _routeProgressIndex;
    }

    _polylines.clear();
    if (closestIndex > 0) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_traversed'),
          points: _polylineCoordinates.sublist(0, closestIndex + 1),
          color: const Color(0xFFFFB000), // Yellow
          width: 7,
          zIndex: 3,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }
    if (closestIndex < _polylineCoordinates.length - 1) {
      final exact = _anchoredPos ?? _driverPos;
      final tail = _polylineCoordinates.sublist(closestIndex);
      final remainingPoints = _routePointsFromExactCaptain(tail, exact);
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_remaining'),
          points: remainingPoints,
          color: AppColors.primary,
          width: 7,
          zIndex: 3,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          patterns: [PatternItem.dash(22), PatternItem.gap(12)],
        ),
      );
    }
  }

  double _calculatePolylineDistance(List<LatLng> points) {
    double distance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      distance += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return distance;
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      final double kms = distanceInMeters / 1000;
      return '${kms.toStringAsFixed(1)} كم';
    } else {
      return '${distanceInMeters.round()} متر';
    }
  }

  String _formatRemainingTime(double remainingDistanceInMeters) {
    if (remainingDistanceInMeters <= 5.0) {
      if (_localShipment.status == ShipmentStatus.assignedToCaptain) {
        return _isDelivery ? 'وصلت للمتجر' : 'وصل المندوب للمتجر';
      } else {
        return _isDelivery ? 'وصلت لوجهتك' : 'وصل المندوب للعميل';
      }
    }

    int totalMinutes = 0;
    if (_totalRouteDistanceMeters > 0 && _totalTripMinutes > 0) {
      double ratio = remainingDistanceInMeters / _totalRouteDistanceMeters;
      ratio = ratio.clamp(0.0, 1.2);
      totalMinutes = (_totalTripMinutes * ratio).ceil();
    } else {
      final speedMs = _lastKnownSpeedMs.clamp(0.8, 30.0);
      totalMinutes = (remainingDistanceInMeters / speedMs / 60).ceil();
    }

    if (totalMinutes <= 0) {
      totalMinutes = 1;
    }

    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours ساعة و $minutes دقيقة';
      } else {
        return '$hours ساعة';
      }
    } else {
      return '$minutes دقيقة';
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * (pi / 180);
    double lon1 = start.longitude * (pi / 180);
    double lat2 = end.latitude * (pi / 180);
    double lon2 = end.longitude * (pi / 180);

    double dLon = lon2 - lon1;
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double brng = atan2(y, x);

    return (brng * (180 / pi) + 360) % 360;
  }

  Future<BitmapDescriptor> _getCircularMarkerWithImage(
    String url, {
    int size = 120,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = AppColors.primary;
    final double radius = size / 2;

    canvas.drawCircle(Offset(radius, radius), radius, paint);

    try {
      final ui.Image image = await _loadNetworkImage(url);
      final double innerRadius = radius * 0.85;

      final Path clipPath = Path()
        ..addOval(
          Rect.fromCircle(center: Offset(radius, radius), radius: innerRadius),
        );
      canvas.clipPath(clipPath);

      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(
          center: Offset(radius, radius),
          radius: innerRadius,
        ),
        image: image,
        fit: BoxFit.cover,
      );
    } catch (e) {
      debugPrint('Error loading marker image: $e');
    }

    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );
    final ByteData? byteData = await markerAsImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<ui.Image> _loadNetworkImage(String url) async {
    final Completer<ui.Image> completer = Completer();
    final NetworkImage networkImage = NetworkImage(url);
    final ImageStream stream = networkImage.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
        }
        stream.removeListener(listener);
      },
      onError: (exception, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  String _formatDateTime(DateTime dateTime) {
    final minuteStr = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'م' : 'ص';
    final formattedHour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);

    final dayStr = dateTime.day.toString().padLeft(2, '0');
    final monthStr = dateTime.month.toString().padLeft(2, '0');
    final yearStr = dateTime.year.toString();

    return "${formattedHour.toString().padLeft(2, '0')}:$minuteStr $period\n$dayStr.$monthStr.$yearStr";
  }

  void _showRatingDialog(
    BuildContext context,
    String name, {
    bool isRatingDriver = false,
  }) {
    if (_ratingDialogShown) return;
    _ratingDialogShown = true;
    int currentRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Dialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isRatingDriver ? 'تقييم المندوب' : 'تقييم التاجر',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 16),

                        Text(
                          'كيف كانت تجربتك في التعامل مع $name؟',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starVal = index + 1;
                            final isSelected = starVal <= currentRating;
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  currentRating = starVal;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: Icon(
                                  Icons.star_rounded,
                                  color: isSelected
                                      ? const Color(0xFFFFB000)
                                      : Colors.grey.shade300,
                                  size: 36,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: TextField(
                            controller: commentController,
                            maxLines: 3,
                            style: GoogleFonts.cairo(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'اكتب تعليقك هنا (اختياري)...',
                              hintStyle: GoogleFonts.cairo(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context); // close dialog
                              await _reviewCubit.submitReview(
                                shipmentId: _localShipment.id,
                                rating: currentRating,
                                comment: commentController.text.isEmpty
                                    ? null
                                    : commentController.text,
                                tags: null,
                              );
                              await _loadRatingAndReviewStatus();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isRatingDriver
                                          ? 'شكراً لتقييمك للمندوب! تم حفظ التقييم بنجاح.'
                                          : 'شكراً لتقييمك! تم حفظ التقييم بنجاح.',
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Colors.green.shade600,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'تأكيد التقييم',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMilestoneItem({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
    Widget? actionWidget,
  }) {
    final Color dotColor = isCompleted || isActive
        ? const Color(0xFFE55B3C)
        : Colors.grey.shade300;
    final String completionTime = stepNumber == 1
        ? _formatDateTime(_localShipment.createdAt)
        : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFE55B3C) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 3.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: DottedLine(
                        height: 50,
                        color: isCompleted
                            ? const Color(0xFFE55B3C)
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: isCompleted || isActive
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isCompleted || isActive
                        ? Colors.black87
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: isCompleted || isActive
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
                if (isActive && actionWidget != null) ...[
                  const SizedBox(height: 12),
                  actionWidget,
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(width: 16),

          if (completionTime.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  completionTime.split('\n')[0],
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  completionTime.split('\n')[1],
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildMerchantBottomSheet() {
    final displayId = _localShipment.shipmentNumber;

    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.08,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 14),

                    // Shipment Details & Delivery Location Card with Payment Badge
                    _buildShipmentLocationsAndDetailsCard(),
                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "حالة الشحنة",
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'رقم: $displayId',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ═══════════════════════════════════════════════════
                    // الخطوة 1: تم قبول الطلب
                    // ═══════════════════════════════════════════════════
                    _buildMilestoneItem(
                      stepNumber: 1,
                      title: "تم قبول الطلب",
                      subtitle: _activeStepIndex > 1
                          ? "تم قبول الشحنة وبدء التنفيذ"
                          : (_isDelivery
                                ? "لقد قبلت المهمة، توجه للاستلام ثم اضغط تم الاستلام"
                                : "وافق الكابتن على استلام وتوصيل الشحنة"),
                      isCompleted: _activeStepIndex > 1,
                      isActive: _activeStepIndex == 1,
                      isLast: false,
                      actionWidget: _activeStepIndex == 1 && _isDelivery
                          ? SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showMandatoryPickupConfirmation,
                                icon: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  'تم استلام الشحنة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),

                    // ═══════════════════════════════════════════════════
                    // الخطوة 2: تم استلام الشحنة
                    // ═══════════════════════════════════════════════════
                    _buildMilestoneItem(
                      stepNumber: 2,
                      title: "تم استلام الشحنة",
                      subtitle: _activeStepIndex > 2
                          ? "تم استلام الشحنة وتوصيلها للعميل بنجاح"
                          : (_isDelivery
                                ? "الشحنة بحوزتك الآن، يرجى التوجه لتسليمها للعميل"
                                : "تم استلام الشحنة وهي في الطريق للعميل"),
                      isCompleted: _activeStepIndex > 2,
                      isActive: _activeStepIndex == 2,
                      isLast: false,
                      actionWidget: _activeStepIndex == 2 && _isDelivery
                          ? Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showMandatoryDeliveryConfirmation,
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'تم التسليم للعميل',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _updateStatusOnServer(
                                    ShipmentStatus.cancelled,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFF0F1),
                                    foregroundColor: const Color(0xFFE53935),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: Text(
                                    "مرتجع / فشل",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),

                    // ═══════════════════════════════════════════════════
                    // الخطوة 3: تم التوصيل بنجاح
                    // ═══════════════════════════════════════════════════
                    _buildMilestoneItem(
                      stepNumber: 3,
                      title: "تم التوصيل بنجاح",
                      subtitle: _activeStepIndex > 3
                          ? "تم تسليم الشحنة وتأكيدها بنجاح"
                          : (_isDelivery
                                ? "تم التوصيل بنجاح، اضغط لإنهاء الشحنة"
                                : "وصل الكابتن وتم التوصيل بنجاح"),
                      isCompleted: _activeStepIndex > 3,
                      isActive: _activeStepIndex == 3,
                      isLast: false,
                      actionWidget: _activeStepIndex == 3
                          ? (_isDelivery
                                ? ElevatedButton.icon(
                                    onPressed: () => _updateStatusOnServer(
                                      ShipmentStatus.completed,
                                    ),
                                    icon: const Icon(
                                      Icons.task_alt_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'إنهاء واكتمال المهمة',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 8,
                                      ),
                                    ),
                                  )
                                : (!_isDelivery
                                      ? ElevatedButton.icon(
                                          onPressed: _confirmDelivery,
                                          icon: const Icon(
                                            Icons.done_all_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            'تأكيد استلام الشحنة',
                                            style: GoogleFonts.cairo(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF2E7D32,
                                            ),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                        )
                                      : null))
                          : null,
                    ),

                    // ═══════════════════════════════════════════════════
                    // الخطوة 4: مكتمل
                    // ═══════════════════════════════════════════════════
                    _buildMilestoneItem(
                      stepNumber: 4,
                      title: "مكتمل",
                      subtitle: _activeStepIndex >= 4
                          ? "تم إنهاء وتأكيد الشحنة بالكامل بنجاح"
                          : "اكتمال الشحنة بعد إتمام التوصيل",
                      isCompleted: _activeStepIndex >= 4,
                      isActive: _activeStepIndex == 4,
                      isLast: false,
                    ),

                    // ═══════════════════════════════════════════════════
                    // الخطوة 5: تقييم
                    // ═══════════════════════════════════════════════════
                    _buildMilestoneItem(
                      stepNumber: 5,
                      title: "تقييم",
                      subtitle: _hasReviewed
                          ? "شكراً لك! تم إرسال تقييمك بنجاح"
                          : (_isDelivery
                                ? "قم بتقييم التاجر/العميل"
                                : "قم بتقييم تجربة التوصيل والكابتن"),
                      isCompleted: _hasReviewed,
                      isActive: _activeStepIndex >= 4 && !_hasReviewed,
                      isLast: true,
                      actionWidget: _activeStepIndex >= 4
                          ? (_hasReviewed
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'تم التقييم بنجاح',
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () {
                                      _ratingDialogShown = false;
                                      final name = _isDelivery
                                          ? (_localShipment.clientName ??
                                                'التاجر')
                                          : (_localShipment.driverName ??
                                                'المندوب المكلف');
                                      _showRatingDialog(
                                        context,
                                        name,
                                        isRatingDriver: !_isDelivery,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.star_rate_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _isDelivery
                                          ? 'تقييم التاجر/العميل'
                                          : 'تقييم الكابتن',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF78710),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ))
                          : null,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    final avatar = _isDelivery
        ? _localShipment.clientAvatar
        : _localShipment.driverAvatar;
    final name = _isDelivery
        ? (_localShipment.clientName ?? 'التاجر')
        : (_localShipment.driverName ?? 'المندوب المكلف');

    final fullAvatarUrl = avatar != null && avatar.isNotEmpty
        ? '${EndPoint.imageBaseUrl}$avatar'
        : 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-1.2.1&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80';

    final phone = _isDelivery
        ? _localShipment.clientPhone
        : _localShipment.driverPhone;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            fullAvatarUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 50,
              height: 50,
              color: Colors.grey.shade200,
              child: const Icon(Icons.person, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFB000),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _userRating,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  phone ?? 'رقم الهاتف غير متوفر',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        if (phone != null && phone.isNotEmpty)
          GestureDetector(
            onTap: () async {
              final Uri url = Uri.parse('tel:$phone');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا يمكن إجراء المكالمة')),
                  );
                }
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.phone_in_talk,
                color: Color(0xFFE53935),
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openExternalMap(String address, double? lat, double? lng) async {
    Uri url;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else if (address.trim().isNotEmpty) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    } else {
      return;
    }
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildShipmentLocationsAndDetailsCard() {
    final shipment = _localShipment;
    final goodsPrice = (shipment.goodsPrice ?? 0).toInt();
    final deliveryFee = (shipment.negotiatedPrice ?? shipment.price).toInt();
    final captainProfit = (deliveryFee * 0.8).toInt();
    final totalToCollect = goodsPrice + deliveryFee;
    final bool isOnlinePayment = shipment.isPaid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. Payment Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isOnlinePayment ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnlinePayment ? const Color(0xFFA5D6A7) : const Color(0xFFFFE082),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isOnlinePayment ? Icons.credit_card_rounded : Icons.payments_outlined,
                  color: isOnlinePayment ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnlinePayment ? '💳 الشحنة مدفوعة إلكترونياً' : '💵 الدفع عند الاستلام (كاش)',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isOnlinePayment ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnlinePayment
                            ? (_isDelivery
                                ? 'تم دفع قيمة الشحنة والتوصيل إلكترونياً. لا تحصّل أي مبالغ من العميل! ربحك ($captainProfit ج.م) سيُضاف لمحفظتك تلقائياً.'
                                : 'تم دفع قيمة التوصيل إلكترونياً.')
                            : (_isDelivery
                                ? (goodsPrice > 0
                                    ? 'المطلوب تحصيله من المستلم: $totalToCollect ج.م نقدياً (ثمن الشحنة: $goodsPrice ج.م + التوصيل: $deliveryFee ج.م)'
                                    : 'المطلوب تحصيله من المستلم: $deliveryFee ج.م نقدياً')
                                : 'المطلوب سداده نقداً عند الاستلام: $totalToCollect ج.م.'),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: isOnlinePayment ? const Color(0xFF2E7D32) : const Color(0xFFBF360C),
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 1. Locations Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.store_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'موقع الاستلام / التاجر:',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shipment.fromAddress,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openExternalMap(
                  shipment.fromAddress,
                  shipment.merchantLatitude ?? shipment.startLatitude,
                  shipment.merchantLongitude ?? shipment.startLongitude,
                ),
                icon: const Icon(Icons.directions, color: Colors.blue, size: 22),
                tooltip: 'الاتجاهات للتاجر',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'موقع وتسليم الشحنة:',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shipment.toAddress.isNotEmpty ? shipment.toAddress : 'عنوان التوصيل غير محدد',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (shipment.clientName != null && shipment.clientName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'العميل: ${shipment.clientName}${shipment.clientPhone != null ? " (${shipment.clientPhone})" : ""}',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openExternalMap(
                  shipment.toAddress,
                  shipment.toLatitude,
                  shipment.toLongitude,
                ),
                icon: const Icon(Icons.directions, color: Colors.red, size: 22),
                tooltip: 'الاتجاهات للتسليم',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),

          // 2. Shipment Title / Notes
          if (shipment.title != null && shipment.title!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'محتوى الشحنة:',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shipment.title!.trim(),
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (shipment.notes != null && shipment.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.note_alt_outlined,
                    size: 15,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ملاحظات: ${shipment.notes!.trim()}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. Financials Summary Row
          const SizedBox(height: 12),
          Row(
            children: [
              if (goodsPrice > 0) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'سعر الشحنة',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          '$goodsPrice ج.م',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (!_isDelivery) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'أجرة التوصيل',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        Text(
                          '$deliveryFee ج.م',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_isDelivery) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ربحك (80%)',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.green.shade800,
                          ),
                        ),
                        Text(
                          '$captainProfit ج.م',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripSummaryCard() {
    double traversedMeters = 0.0;
    double remainingMeters = 0.0;

    final bool hasDriver = !_hasStatus([
      ShipmentStatus.newShipment,
      ShipmentStatus.negotiation,
      ShipmentStatus.awaitingPayment,
      ShipmentStatus.readyForAssignment,
    ]);
    final bool hasDriverLocation =
        _localShipment.driverLatitude != null &&
        _localShipment.driverLongitude != null &&
        _localShipment.driverLatitude != 0.0 &&
        _localShipment.driverLongitude != 0.0;

    final bool showRealTimeStats = hasDriver && hasDriverLocation;

    if (showRealTimeStats) {
      if (_polylineCoordinates.isNotEmpty) {
        final closestIndex = _routeProgressIndex;
        traversedMeters = closestIndex > 0
            ? _calculatePolylineDistance(
                _polylineCoordinates.sublist(0, closestIndex + 1),
              )
            : 0.0;
        remainingMeters = _calculatePolylineDistance(
          _polylineCoordinates.sublist(closestIndex),
        );
      } else {
        if (_hasStatus([ShipmentStatus.assignedToCaptain])) {
          traversedMeters = 0.0;
          remainingMeters = Geolocator.distanceBetween(
            _driverPos.latitude,
            _driverPos.longitude,
            _origin.latitude,
            _origin.longitude,
          );
        } else {
          final startLat = _localShipment.startLatitude ?? _origin.latitude;
          final startLng = _localShipment.startLongitude ?? _origin.longitude;
          traversedMeters = Geolocator.distanceBetween(
            startLat,
            startLng,
            _driverPos.latitude,
            _driverPos.longitude,
          );
          remainingMeters = Geolocator.distanceBetween(
            _driverPos.latitude,
            _driverPos.longitude,
            _destination.latitude,
            _destination.longitude,
          );
        }
      }
    }

    final String traversedText = showRealTimeStats
        ? _formatDistance(traversedMeters)
        : '0 كم';
    final String remainingText = showRealTimeStats
        ? _formatDistance(remainingMeters)
        : (_hasStatus([ShipmentStatus.assignedToCaptain])
              ? 'جاري التحديد...'
              : _formatDistance(
                  Geolocator.distanceBetween(
                    _origin.latitude,
                    _origin.longitude,
                    _destination.latitude,
                    _destination.longitude,
                  ),
                ));

    final String timeRemainingText = showRealTimeStats
        ? _formatRemainingTime(remainingMeters)
        : (_hasStatus([ShipmentStatus.assignedToCaptain])
              ? 'جاري التحديد...'
              : _formatRemainingTime(
                  Geolocator.distanceBetween(
                    _origin.latitude,
                    _origin.longitude,
                    _destination.latitude,
                    _destination.longitude,
                  ),
                ));

    final bool isHeadingToMerchant = _hasStatus([
      ShipmentStatus.assignedToCaptain,
      ShipmentStatus.captainArrived,
    ]);

    String driverStatusText = '';
    Color driverStatusColor = Colors.grey;

    if (_isDelivery) {
      if (isHeadingToMerchant) {
        driverStatusText = _isMerchantMoving
            ? 'التاجر يتحرك الآن'
            : 'التاجر متوقف حالياً';
        driverStatusColor = _isMerchantMoving ? Colors.green : Colors.red;
      } else {
        driverStatusText = 'جاري التوجه إلى نقطة التسليم';
        driverStatusColor = Colors.blue;
      }
    } else {
      if (!hasDriver) {
        driverStatusText = 'في انتظار قبول كابتن للطلب';
        driverStatusColor = Colors.orange;
      } else if (!hasDriverLocation) {
        driverStatusText = 'جاري تحديد موقع المندوب...';
        driverStatusColor = Colors.blue;
      } else {
        driverStatusText = _isDriverMoving
            ? 'المندوب يتحرك الآن'
            : 'المندوب متوقف حالياً';
        driverStatusColor = _isDriverMoving ? Colors.green : Colors.red;
      }
    }

    final bool isTargetMoving = _isDelivery
        ? (isHeadingToMerchant ? _isMerchantMoving : false)
        : _isDriverMoving;

    double totalDistanceMeters = 0.0;
    if (showRealTimeStats) {
      if (_polylineCoordinates.isNotEmpty) {
        totalDistanceMeters = _calculatePolylineDistance(_polylineCoordinates);
      } else {
        totalDistanceMeters = Geolocator.distanceBetween(
          _routeStart.latitude,
          _routeStart.longitude,
          _routeEnd.latitude,
          _routeEnd.longitude,
        );
      }
    } else {
      totalDistanceMeters = Geolocator.distanceBetween(
        _origin.latitude,
        _origin.longitude,
        _destination.latitude,
        _destination.longitude,
      );
    }

    final double shipmentPrice =
        _localShipment.negotiatedPrice ?? _localShipment.price;
    final double totalDistanceKm = totalDistanceMeters / 1000.0;
    final double pricePerKm = totalDistanceKm > 0
        ? (shipmentPrice / totalDistanceKm)
        : 0.0;

    final String pricePerKmText = pricePerKm > 0
        ? '${pricePerKm.toStringAsFixed(1)} ج/كم'
        : 'جاري الحساب...';
    final String totalDistanceText = _formatDistance(totalDistanceMeters);
    final double topPadding = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            setState(() {
              _isTripSummaryExpanded = true;
            });
          } else if (details.primaryVelocity! < 0) {
            setState(() {
              _isTripSummaryExpanded = false;
            });
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Back Button
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),

                  // Collapsed/Expanded Title Area
                  if (_isTripSummaryExpanded)
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isTripSummaryExpanded = false;
                          });
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: driverStatusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                driverStatusText,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: driverStatusColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isTripSummaryExpanded = true;
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'المتبقي: $timeRemainingText',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($remainingText)',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Collapsed Status Blinker / Toggle Icon
                  if (_isTripSummaryExpanded)
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Colors.grey,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _isTripSummaryExpanded = false;
                        });
                      },
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    )
                  else
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isTripSummaryExpanded = true;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: driverStatusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTargetMoving ? 'يتحرك' : 'متوقف',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: driverStatusColor,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _isTripSummaryExpanded
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.monetization_on_outlined,
                                    size: 15,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'سعر الكيلو: ',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    pricePerKmText,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.map_outlined,
                                    size: 15,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'المسافة الكلية: ',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    totalDistanceText,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryColumn(
                                icon: Icons.check_circle_outline,
                                iconColor: Colors.green,
                                label: 'المقطوعة',
                                value: traversedText,
                              ),
                              _buildVerticalDivider(),
                              _buildSummaryColumn(
                                icon: Icons.trending_flat,
                                iconColor: AppColors.primary2,
                                label: 'المتبقية',
                                value: remainingText,
                              ),
                              _buildVerticalDivider(),
                              _buildSummaryColumn(
                                icon: Icons.access_time,
                                iconColor: Colors.orange,
                                label: 'الوقت المتبقي',
                                value: timeRemainingText,
                              ),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryColumn({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 30, color: Colors.grey.shade300);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRoleLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              // Default Google Maps colors — all roads, labels, and buildings visible.
              mapType: MapType.normal,
              buildingsEnabled: true,
              compassEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              initialCameraPosition: CameraPosition(
                target: _driverPos,
                zoom: 16,
                tilt: _isDelivery && _isNavigationMode ? 45 : 0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _initMap();
                _updateDriverScreenPosition();
              },
              onCameraMove: (position) {
                _updateDriverScreenPosition();
                if (_isNavigationMode && mounted) {
                  setState(() {
                    _isNavigationMode = false;
                    _isUserPanning = true;
                  });
                }
              },
              markers: _markers,
              polylines: _polylines,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),

            if (_driverScreenOffset != null)
              // Positioned(
              //   left: _driverScreenOffset!.dx,
              //   top: _driverScreenOffset!.dy - 20,
              //   child: FractionalTranslation(
              //     translation: const Offset(-0.5, -1.0),
              //     child: Column(
              //       mainAxisSize: MainAxisSize.min,
              //       children: [
              //         Container(
              //           padding: const EdgeInsets.symmetric(
              //             horizontal: 12,
              //             vertical: 6,
              //           ),
              //           decoration: BoxDecoration(
              //             color: const Color(0xFFE55B3C),
              //             borderRadius: BorderRadius.circular(10),
              //             boxShadow: [
              //               BoxShadow(
              //                 color: Colors.black.withValues(alpha: 0.1),
              //                 blurRadius: 6,
              //                 offset: const Offset(0, 3),
              //               ),
              //             ],
              //           ),
              //           child: Text(
              //             _timeRemaining,
              //             style: GoogleFonts.cairo(
              //               color: Colors.white,
              //               fontWeight: FontWeight.bold,
              //               fontSize: 11,
              //             ),
              //           ),
              //         ),
              //         CustomPaint(
              //           size: const Size(10, 5),
              //           painter: TrianglePainter(
              //             color: const Color(0xFFE55B3C),
              //           ),
              //         ),
              //         const SizedBox(height: 4),
              //         Container(
              //           width: 36,
              //           height: 36,
              //           decoration: BoxDecoration(
              //             color: Colors.white,
              //             shape: BoxShape.circle,
              //             border: Border.all(
              //               color: const Color(0xFFE55B3C),
              //               width: 2,
              //             ),
              //             boxShadow: [
              //               BoxShadow(
              //                 color: Colors.black.withValues(alpha: 0.15),
              //                 blurRadius: 6,
              //                 offset: const Offset(0, 3),
              //               ),
              //             ],
              //           ),
              //           child: const Center(
              //             child: Icon(
              //               Icons.local_shipping_outlined,
              //               color: Color(0xFFE55B3C),
              //               size: 18,
              //             ),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTripSummaryCard(),
              ),

            // ── Re-center / Navigation button (driver only) ──────────────────
            if (_isDelivery)
              Positioned(
                bottom: 220,
                left: 16,
                child: GestureDetector(
                  onTap: _snapToNavigationMode,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isNavigationMode
                          ? AppColors.primary
                          : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: _isNavigationMode
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _isNavigationMode
                          ? Icons.navigation_rounded
                          : Icons.navigation_outlined,
                      color: _isNavigationMode
                          ? Colors.white
                          : AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),

            _buildMerchantBottomSheet(),
          ],
        ),
      ),
    );
  }

  /// Snaps camera back to driver position in full GPS navigation mode.
  void _snapToNavigationMode() {
    setState(() {
      _isNavigationMode = true;
      _isUserPanning = false;
    });
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _driverPos,
          zoom: 17.5,
          bearing: _driverRotation,
          tilt: 45.0,
        ),
      ),
    );
  }
} // end of _TrackShipmentScreenState

class DottedLine extends StatelessWidget {
  final double height;
  final Color color;
  final double dashHeight;
  final double dashGap;

  const DottedLine({
    super.key,
    required this.height,
    this.color = Colors.grey,
    this.dashHeight = 4,
    this.dashGap = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: List.generate((height / (dashHeight + dashGap)).floor(), (
          index,
        ) {
          return Container(
            width: 2,
            height: dashHeight,
            color: color,
            margin: EdgeInsets.only(bottom: dashGap),
          );
        }),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
