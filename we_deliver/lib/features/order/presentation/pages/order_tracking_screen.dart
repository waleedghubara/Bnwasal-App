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

import '../../domain/entities/order.dart';
import 'package:we_deliver/features/profile/presentation/bloc/review_cubit.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../../../core/theme/colors.dart';
import 'package:we_deliver/core/utils/constants.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderEntity order;
  final Map<String, dynamic>? shipmentData;

  const OrderTrackingScreen({
    super.key,
    required this.order,
    this.shipmentData,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final ReviewCubit _reviewCubit = di.sl<ReviewCubit>();
  String _userRating = '—';
  bool _hasReviewed = false;
  bool _ratingDialogShown = false;
  late OrderEntity _localOrder;
  bool _isDelivery = false;
  bool _isRoleLoaded = false;
  bool _isTripSummaryExpanded = true;
  io.Socket? _socket;
  StreamSubscription<Position>? _positionSubscription;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  BitmapDescriptor? _driverIcon;

  late LatLng _origin;
  late LatLng _destination;
  late LatLng _driverPos;

  LatLng get _routeStart {
    final status = _localOrder.status;
    // بعد التسليم النهائي نعرض المسار من نقطة البداية الفعلية
    final isTerminal =
        status == 'Delivered' ||
        status == 'Completed' ||
        status == 'Cancelled' ||
        status == 'Rejected';
    if (!isTerminal) {
      return _driverPos;
    } else {
      if (_localOrder.startLatitude != null &&
          _localOrder.startLongitude != null) {
        return LatLng(_localOrder.startLatitude!, _localOrder.startLongitude!);
      }
      return _driverPos;
    }
  }

  LatLng get _routeEnd {
    final status = _localOrder.status;
    // عندما يكون الكابتن متجهاً لمتجر الشراء أو يشتري الطلب
    if (status == 'Assigned To Captain' || status == 'Captain Arrived') {
      return _origin; // متجه للمتجر
    }
    return _destination; // متجه للتسليم
  }

  final String _googleApiKey = AppConstants.googleMapsApiKey;

  String _timeRemaining = 'جاري حساب الوقت...';
  int _totalTripMinutes = 15;
  double _totalRouteDistanceMeters = 0.0;
  int _activeStepIndex = 1;
  String _feeCollectionMode = 'after_agreement';

  Offset? _driverScreenOffset;

  // Movement status variables
  bool _isDriverMoving = false;
  bool _isMerchantMoving = false;
  double _driverRotation = 0.0;
  Timer? _movementTimeoutTimer;
  Timer? _merchantMovementTimeoutTimer;
  LatLng? _lastPos;
  LatLng? _lastMerchantPos;
  DateTime? _lastSocketEmitTime; // throttle server emissions

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

  @override
  void initState() {
    super.initState();
    _localOrder = widget.order;

    _origin = LatLng(
      _localOrder.merchantLatitude ?? 30.0595,
      _localOrder.merchantLongitude ?? 31.3285,
    );
    _destination = LatLng(
      _localOrder.latitude ?? 30.0074,
      _localOrder.longitude ?? 31.4913,
    );
    _driverPos = LatLng(
      _localOrder.driverLatitude ?? _origin.latitude,
      _localOrder.driverLongitude ?? _origin.longitude,
    );

    _initAll();
  }

  Future<void> _initAll() async {
    await _checkRole();
    await _fetchLatestOrderDetails();
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
        _feeCollectionMode =
            prefs.getString('fee_collection_mode') ?? 'after_agreement';
      });
      _loadDriverIcon();
      _initSocket();
    }
    try {
      final dio = di.sl<Dio>();
      final response = await dio.get(
        '${EndPoint.baseUrl}${EndPoint.appConfig}',
      );
      if (response.statusCode == 200 && response.data != null) {
        final configData = response.data['data'] as Map<String, dynamic>;
        final serverMode =
            configData['fee_collection_mode']?.toString() ?? 'after_agreement';
        if (mounted && serverMode != _feeCollectionMode) {
          setState(() {
            _feeCollectionMode = serverMode;
            _updateMilestoneSteps();
          });
          await prefs.setString('fee_collection_mode', serverMode);
        }
      }
    } catch (e) {
      print('❌ Failed to fetch config on tracking screen: $e');
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
      print('🔌 Track Order Socket Connected: ${_socket!.id}');
      _socket!.emit('joinRoom', 'order_${_localOrder.id}');
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
            _localOrder = _localOrder.copyWith(
              driverLatitude: lat,
              driverLongitude: lng,
            );
            _driverPos = newPos;
            _driverRotation = bearing;
            _updateDriverMarker(rotation: bearing);
          } else {
            _origin = newPos;
            _addBaseMarkers();
            _localOrder = _localOrder.copyWith(
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
            if (!_isDelivery) {
              _updatePolylinesFromDriverPos();
            }
          }

          _timeRemaining = _formatRemainingTime(_remainingPolylineMeters());
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
      _fetchLatestOrderDetails();
    });

    _socket!.onDisconnect((_) {
      print('🔌 Track Order Socket Disconnected');
    });
  }

  Future<void> _loadRatingAndReviewStatus() async {
    if (!mounted) return;

    // 1. Fetch user rating for the other party
    final otherUserId = _isDelivery
        ? _localOrder.merchantId
        : _localOrder.captainId;
    if (otherUserId != null) {
      final summary = await _reviewCubit.getUserRating(otherUserId);
      if (summary != null && mounted) {
        setState(() {
          _userRating = summary.formattedRating;
        });
      }
    }

    // 2. Check review status locally from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final hasReviewed =
          prefs.getBool('hasReviewed_order_${_localOrder.id}') ?? false;
      setState(() {
        _hasReviewed = hasReviewed;
      });

      // Auto-trigger rating dialog if order is completed and not reviewed yet
      final status = _localOrder.status;
      final isCompleted =
          status == 'منتهي' ||
          status == OrderStatus.completed ||
          status == 'Completed';
      if (isCompleted &&
          !hasReviewed &&
          !_ratingDialogShown &&
          context.mounted) {
        final name = _isDelivery
            ? (_localOrder.merchantName ?? _localOrder.clientName)
            : (_localOrder.captainName ?? 'المندوب');
        _showRatingDialog(context, name, isRatingDriver: !_isDelivery);
      }
    }
  }

  Future<void> _fetchLatestOrderDetails() async {
    try {
      final order = await di.sl<GetOrderByIdUseCase>().call(_localOrder.id);
      if (mounted) {
        setState(() {
          _localOrder = order;
          _origin = LatLng(
            _localOrder.merchantLatitude ?? 30.0595,
            _localOrder.merchantLongitude ?? 31.3285,
          );
          _destination = LatLng(
            _localOrder.latitude ?? 30.0074,
            _localOrder.longitude ?? 31.4913,
          );
          if (!_isDelivery) {
            _driverPos = LatLng(
              _localOrder.driverLatitude ?? _origin.latitude,
              _localOrder.driverLongitude ?? _origin.longitude,
            );
          } else {
            Geolocator.getLastKnownPosition().then((pos) {
              if (pos != null && mounted) {
                setState(() {
                  _driverPos = LatLng(pos.latitude, pos.longitude);
                });
              }
            });
          }
          _updateMilestoneSteps();
        });
        _loadDriverIcon();
        _addBaseMarkers();
        await _getPolyline();
        _fitMapToPolyline();
        _loadRatingAndReviewStatus();
      }
    } catch (e) {
      print('❌ Failed to fetch order details: $e');
    }
  }

  void _updateMilestoneSteps() {
    final status = _localOrder.status.trim().toLowerCase();
    if (status == 'assigned to captain' ||
        status == 'تم قبول الكابتن للمهمة' ||
        status == 'تم قبول الطلب' ||
        status == 'pending review' ||
        status == 'بانتظار القبول' ||
        status == 'new' ||
        status == 'جديد' ||
        status == 'جديدة' ||
        status == 'pending' ||
        status == 'ready for assignment' ||
        status == 'في انتظار المندوب' ||
        status == 'بانتظار المندوب' ||
        status == 'captain arrived' ||
        status == 'في الطريق للاستلام' ||
        status == 'فى الطريق للاستلام' ||
        status == 'جاري الاستلام') {
      _activeStepIndex = 1; // 1. تم قبول الطلب (المطلوب: تم شراء الطلبات / الاستلام)
      if (_isDelivery) {
        _startGpsStreaming();
      } else {
        _stopGpsStreaming();
      }
    } else if (status == 'picked up' ||
        status == 'تم استلام الطلب' ||
        status == 'تم شراء الطلبات' ||
        status == 'تم شراء الطلب' ||
        status == 'تم الشراء' ||
        status == 'in transit' ||
        status == 'في الطريق للتسليم' ||
        status == 'فى الطريق للتسليم' ||
        status == 'جاري التوصيل' ||
        status == 'قيد التوصيل') {
      _activeStepIndex = 2; // 2. تم شراء الطلبات (المطلوب: تم التوصيل بنجاح)
      if (_isDelivery) {
        _startGpsStreaming();
      } else {
        _stopGpsStreaming();
      }
    } else if (status == 'delivered' ||
        status == 'تم التسليم بنجاح' ||
        status == 'تم التوصيل بنجاح' ||
        status == 'تم التوصيل') {
      _activeStepIndex = 3; // 3. تم التوصيل بنجاح
      _stopGpsStreaming();
    } else if (status == 'completed' ||
        status == 'مكتملة' ||
        status == 'مكتمل' ||
        status == 'منتهية' ||
        status == 'finished') {
      _activeStepIndex = 4; // 4. مكتمل
      _stopGpsStreaming();
    } else if (status == 'cancelled' ||
        status == 'rejected' ||
        status == 'ملغي' ||
        status == 'ملغاة' ||
        status == 'مرفوض') {
      _activeStepIndex = 10;
      _stopGpsStreaming();
    }
  }

  void _onLocationReceived(LatLng newPos, {bool? forceMoving}) {
    if (forceMoving != null) {
      setState(() {
        _isDriverMoving = forceMoving;
      });
    } else {
      if (_lastPos != null) {
        final distance = Geolocator.distanceBetween(
          _lastPos!.latitude,
          _lastPos!.longitude,
          newPos.latitude,
          newPos.longitude,
        );
        if (distance > 2) {
          setState(() {
            _isDriverMoving = true;
          });
        }
      } else {
        setState(() {
          _isDriverMoving = true;
        });
      }
    }

    _lastPos = newPos;

    _movementTimeoutTimer?.cancel();
    _movementTimeoutTimer = Timer(const Duration(seconds: 12), () {
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
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 8,
          ),
        ).listen((Position position) {
          if (position.accuracy > 25) return;

          final pos = LatLng(position.latitude, position.longitude);
          final double speed = position.speed.clamp(0.0, double.infinity);

          bool isMoving = speed > 0.5;
          if (!isMoving && _lastPos != null) {
            final delta = Geolocator.distanceBetween(
              _lastPos!.latitude,
              _lastPos!.longitude,
              pos.latitude,
              pos.longitude,
            );
            if (delta >= 5) isMoving = true;
          }

          double bearing = _driverRotation;
          if (isMoving && _lastPos != null) {
            final rawBearing = _calculateBearing(_lastPos!, pos);
            bearing = (_driverRotation * 0.7 + rawBearing * 0.3) % 360;
          }

          final now = DateTime.now();
          final msSinceLast = _lastSocketEmitTime != null
              ? now.difference(_lastSocketEmitTime!).inMilliseconds
              : 99999;
          final bool shouldEmit = isMoving || msSinceLast >= 10000;

          if (shouldEmit) {
            _socket?.emit('updateLocation', {
              'orderId': _localOrder.id,
              'latitude': pos.latitude,
              'longitude': pos.longitude,
              'bearing': bearing,
              'isMoving': isMoving,
              'speed': speed,
              'isDriver': _isDelivery,
            });
            _lastSocketEmitTime = now;
          }

          _lastPos = pos;
          if (mounted) {
            setState(() {
              _localOrder = _localOrder.copyWith(
                driverLatitude: pos.latitude,
                driverLongitude: pos.longitude,
                startLatitude: _localOrder.startLatitude ?? pos.latitude,
                startLongitude: _localOrder.startLongitude ?? pos.longitude,
              );
              _driverRotation = bearing;
              _driverPos = pos;
              _isDriverMoving = isMoving;
              _updateDriverMarker(rotation: bearing);

              if (isMoving && _isNavigationMode) {
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
                for (var pt in _polylineCoordinates) {
                  final d = Geolocator.distanceBetween(
                    pos.latitude,
                    pos.longitude,
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
                _getPolyline().then((_) {
                  if (mounted) setState(() {});
                });
              } else {
                _updatePolylinesFromDriverPos();
              }

              _timeRemaining = _formatRemainingTime(_remainingPolylineMeters());
            });
            _onLocationReceived(pos, forceMoving: isMoving);
            _updateDriverScreenPosition();
          }
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
      final token = await SecureCacheHelper().getData(key: ApiKey.token);
      await di.sl<Dio>().post(
        '${EndPoint.baseUrl}${EndPoint.confirmOrderDelivery(_localOrder.id.toString())}',
        data: {'latitude': position.latitude, 'longitude': position.longitude},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        Navigator.pop(context); // pop loader
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد استلام الطلب بنجاح واكتمال العملية'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchLatestOrderDetails();
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

  void _showMandatoryPurchaseConfirmation() {
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
                  Icons.shopping_bag_outlined,
                  color: Color(0xFF2E7D32),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تأكيد شراء الطلبات *',
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
                'يرجى التأكد من شراء واستلام جميع أصناف ومشتريات الطلب بدقة وبحالة سليمة.',
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
                        'هذه الخطوة إجبارية لبدء التوصيل إلى عنوان العميل.',
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
                _updateStatusOnServer('Picked Up');
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
                'تأكيد الشراء الآن',
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
                'يرجى التأكد من تسليم المشتريات للعميل واستلام قيمة الطلب ورسوم التوصيل بالكامل.',
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
                        'هذه الخطوة إجبارية لاكتمال الطلب واحتساب أرباحك.',
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

      await di.sl<UpdateOrderStatusUseCase>().call(
        _localOrder.id,
        status,
        latitude: status == 'Delivered' ? _driverPos.latitude : null,
        longitude: status == 'Delivered' ? _driverPos.longitude : null,
      );

      if (mounted) {
        Navigator.pop(context); // Pop loading
        _fetchLatestOrderDetails();
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

    // لا يُظهر المندوب إلا بعد تعيينه
    final isPreAssignment =
        _localOrder.status == 'Pending Review' ||
        _localOrder.status == 'Ready For Assignment' ||
        _localOrder.status == 'بانتظار القبول';

    final hasDriverPos =
        _driverPos.latitude != 0.0 && _driverPos.longitude != 0.0;

    if (isPreAssignment || !hasDriverPos) {
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
    final avatarUrl = _localOrder.captainAvatar;
    final fullAvatarUrl = avatarUrl != null && avatarUrl.isNotEmpty
        ? '${EndPoint.imageBaseUrl}$avatarUrl'
        : 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-1.2.1&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80';

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
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        if (_isDelivery) {
          _driverPos = LatLng(position.latitude, position.longitude);
        } else {
          _origin = LatLng(position.latitude, position.longitude);
        }
      });

      _socket?.emit('updateLocation', {
        'orderId': _localOrder.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isDriver': _isDelivery,
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    _addBaseMarkers();
    await _getPolyline();
    _fitMapToPolyline();
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
          infoWindow: const InfoWindow(title: 'مكان الشراء'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination,
          infoWindow: const InfoWindow(title: 'موقع التوصيل'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  Future<void> _getPolyline() async {
    final status = _localOrder.status;
    final allowedStatuses = [
      'Assigned To Captain',
      'Captain Arrived',
      'Picked Up',
      'تم الاستلام',
      'جاري التنفيذ',
      'In Transit',
      'جاري التوصيل',
      'تم التنفيذ',
      'Delivered',
      'تم التوصيل',
      'منتهي',
      'Completed',
      'مكتملة',
    ];
    if (!allowedStatuses.contains(status)) {
      setState(() {
        _polylineCoordinates.clear();
        _polylines.clear();
      });
      return;
    }
    bool success = await _fetchGoogleRoute();
    if (!success) {
      success = await _fetchOSRMRoute();
    }
    if (!success) {
      _setupFallbackRoute();
    }
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
          'mode': 'driving',
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

      _totalRouteDistanceMeters = _calculatePolylineDistance(
        _polylineCoordinates,
      );
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
            width: 5,
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

  void _updatePolylinesFromDriverPos() {
    if (_polylineCoordinates.isEmpty) return;

    int closestIndex = 0;
    double minDistance = double.maxFinite;
    for (int i = 0; i < _polylineCoordinates.length; i++) {
      double dist = Geolocator.distanceBetween(
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

    _polylines.clear();
    if (closestIndex > 0) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_traversed'),
          points: _polylineCoordinates.sublist(0, closestIndex + 1),
          color: const Color(0xFFFFB000), // Yellow
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }
    if (closestIndex < _polylineCoordinates.length - 1) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_remaining'),
          points: _polylineCoordinates.sublist(closestIndex),
          color: AppColors.primary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
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
    int idx = 0;
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
    if (idx >= _polylineCoordinates.length - 1) return 0;
    return _calculatePolylineDistance(_polylineCoordinates.sublist(idx));
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
      // عندما يكون متجهاً للمتجر أو يشتري الطلب
      if (_localOrder.status == 'Assigned To Captain' ||
          _localOrder.status == 'Captain Arrived' ||
          _localOrder.status == 'Picked Up') {
        return _isDelivery ? 'وصلت للمتجر' : 'وصل المندوب للمتجر';
      } else {
        return _isDelivery ? 'وصلت لوجهتك' : 'وصل المندوب للعميل';
      }
    }

    int totalMinutes = 0;
    if (_totalRouteDistanceMeters > 0) {
      double ratio = remainingDistanceInMeters / _totalRouteDistanceMeters;
      ratio = ratio.clamp(0.0, 1.2);
      totalMinutes = (_totalTripMinutes * ratio).ceil();
    } else {
      final double minutesDecimal = remainingDistanceInMeters / 500;
      totalMinutes = minutesDecimal.ceil();
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

  void _updateMapStyle() async {
    const String style = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#c9c9c9"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#a6a6a6"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [{"color": "#bdbdbd"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#d6e4f0"}]
  },
  {
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#6b6b6b"}]
  }
]
''';
    _mapController?.setMapStyle(style);
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
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                'hasReviewed_order_${_localOrder.id}',
                                true,
                              );

                              try {
                                await _reviewCubit.submitReview(
                                  shipmentId: 'order_${_localOrder.id}',
                                  rating: currentRating,
                                  comment: commentController.text.isEmpty
                                      ? null
                                      : commentController.text,
                                  tags: null,
                                );
                              } catch (e) {
                                debugPrint('Error submitting review: $e');
                              }

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
        ? _formatDateTime(_localOrder.createdAt)
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
    final displayId = _localOrder.orderNumber;

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

                    // Order Details & Delivery Location Card
                    _buildOrderLocationsAndDetailsCard(),
                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "حالة الطلب",
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
                    const SizedBox(
                      height: 24,
                    ), // ═══════════════════════════════════════════════════
                    // الخطوة 1: تم قبول الطلب
                    // ═══════════════════════════════════════════════════
                    _buildMilestoneItem(
                      stepNumber: 1,
                      title: 'تم قبول الطلب',
                      subtitle: _activeStepIndex > 1
                          ? 'تم قبول الطلب وبدء التنفيذ'
                          : (_isDelivery
                                ? 'لقد قبلت الطلب، اضغط تأكيد بعد شراء وتجهيز الطلبات'
                                : 'وافق الكابتن على شراء وتوصيل طلبك'),
                      isCompleted: _activeStepIndex > 1,
                      isActive: _activeStepIndex == 1,
                      isLast: false,
                      actionWidget: _activeStepIndex == 1 && _isDelivery
                          ? ElevatedButton.icon(
                              onPressed: _showMandatoryPurchaseConfirmation,
                              icon: const Icon(
                                Icons.shopping_bag_outlined,
                                size: 16,
                              ),
                              label: Text(
                                'تم شراء الطلبات * إجباري',
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
                          : null,
                    ),

                    // ═══════════════════════════════════════════════════
                    // الخطوة 2: تم شراء الطلبات * اجبارى
                    // ═══════════════════════════════════════════════════
                    _buildMilestoneItem(
                      stepNumber: 2,
                      title: 'تم شراء الطلبات * إجباري',
                      subtitle: _activeStepIndex > 2
                          ? 'تم شراء وتجهيز الطلب وهو في الطريق للتسليم'
                          : (_isDelivery
                                ? 'تم تجهيز الطلب، توجه لعنوان العميل واضغط تأكيد التوصيل عند التسليم'
                                : 'تم شراء طلبك والكابتن في طريقه للتسليم'),
                      isCompleted: _activeStepIndex > 2,
                      isActive: _activeStepIndex == 2,
                      isLast: false,
                      actionWidget: _activeStepIndex == 2 && _isDelivery
                          ? Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _showMandatoryDeliveryConfirmation,
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'تم التوصيل بنجاح * إجباري',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
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
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _updateStatusOnServer('Cancelled'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFF0F1),
                                      foregroundColor: const Color(0xFFE53935),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: Text(
                                      'مرتجع / فشل',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),

                    // ═══════════════════════════════════════════════════
                    // الخطوة 3: تم التوصيل بنجاح * اجبارى
                    // ═══════════════════════════════════════════════════
                    _buildMilestoneItem(
                      stepNumber: 3,
                      title: 'تم التوصيل بنجاح * إجباري',
                      subtitle: _activeStepIndex > 3
                          ? 'تم تسليم الطلب وتأكيده بنجاح'
                          : (_isDelivery
                                ? 'تم التوصيل بنجاح، اضغط لإنهاء الطلب'
                                : 'وصل الكابتن بطلبك وتم التوصيل بنجاح'),
                      isCompleted: _activeStepIndex > 3,
                      isActive: _activeStepIndex == 3,
                      isLast: false,
                      actionWidget: _activeStepIndex == 3
                          ? (_isDelivery
                                ? ElevatedButton.icon(
                                    onPressed: () =>
                                        _updateStatusOnServer('Completed'),
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
                                            'تأكيد استلام الطلب',
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
                      title: 'مكتمل',
                      subtitle: _activeStepIndex >= 4
                          ? 'تم إنهاء وتأكيد الرحلة بالكامل بنجاح'
                          : 'اكتمال الرحلة بعد إتمام التوصيل',
                      isCompleted: _activeStepIndex >= 4,
                      isActive: _activeStepIndex == 4,
                      isLast: false,
                    ),

                    // ═══════════════════════════════════════════════════
                    // الخطوة 5: تقييم
                    // ═══════════════════════════════════════════════════
_buildMilestoneItem(
                      stepNumber: 5,
                      title: 'تقييم',
                      subtitle: _hasReviewed
                          ? 'شكراً لك! تم إرسال تقييمك بنجاح'
                          : (_isDelivery
                                ? 'قم بتقييم التاجر/العميل'
                                : 'قم بتقييم تجربة التوصيل والكابتن'),
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
                                          ? (_localOrder.merchantName ??
                                                'التاجر')
                                          : (_localOrder.captainName ??
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
                                      'تقييم الخدمة',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade700,
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
        ? _localOrder.merchantAvatar
        : _localOrder.captainAvatar;
    final name = _isDelivery
        ? (_localOrder.merchantName ?? 'التاجر')
        : (_localOrder.captainName ?? 'المندوب المكلف');
    final phone = _isDelivery
        ? _localOrder.merchantPhone
        : _localOrder.captainPhone;

    final fullAvatarUrl = avatar != null && avatar.isNotEmpty
        ? '${EndPoint.imageBaseUrl}$avatar'
        : 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-1.2.1&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80';

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

  Widget _buildOrderLocationsAndDetailsCard() {
    final order = _localOrder;
    final orderPrice = order.orderPrice.toInt();
    final deliveryFee = order.deliveryFee.toInt();
    final captainProfit = (deliveryFee * 0.8).toInt();
    final totalOrderAndDelivery = orderPrice + deliveryFee;
    final bool isOnlinePayment = order.isPaid;

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
                        isOnlinePayment ? '💳 مدفوع إلكترونياً بالكامل' : '💵 الدفع عند الاستلام (كاش)',
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
                                ? 'الطلب وثمن المنتجات والتوصيل مدفوعة أونلاين. لا تحصّل أي مبالغ من العميل! ربحك ($captainProfit ج.م) سيُضاف لمحفظتك تلقائياً.'
                                : 'تم سداد قيمة المنتجات ورسوم التوصيل إلكترونياً.')
                            : (_isDelivery
                                ? 'المطلوب تحصيله من العميل: $totalOrderAndDelivery ج.م نقدياً'
                                : 'المطلوب سداده نقداً للكابتن عند الاستلام: $totalOrderAndDelivery ج.م.'),
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
                      'موقع الاستلام / المتجر:',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.pickupAddress,
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
                  order.pickupAddress,
                  order.merchantLatitude,
                  order.merchantLongitude,
                ),
                icon: const Icon(Icons.directions, color: Colors.blue, size: 22),
                tooltip: 'الاتجاهات للمتجر',
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
                      'موقع وتفاصيل التسليم:',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.deliveryAddress.isNotEmpty
                          ? order.deliveryAddress
                          : 'عنوان التوصيل غير محدد',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (order.clientName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'العميل: ${order.clientName}${order.phone.isNotEmpty ? " (${order.phone})" : ""}',
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
                  order.deliveryAddress,
                  order.latitude,
                  order.longitude,
                ),
                icon: const Icon(Icons.directions, color: Colors.red, size: 22),
                tooltip: 'الاتجاهات للعميل',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),

          // 2. Custom Order Details (if any text is present)
          if (order.details.trim().isNotEmpty) ...[
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
                        Icons.receipt_long_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'تفاصيل ومحتوى الطلب:',
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
                    order.details.trim(),
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

          // 3. Notes (if present)
          if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
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
                      'ملاحظات: ${order.notes!.trim()}',
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

          // 4. Financials Summary Row
          const SizedBox(height: 12),
          Row(
            children: [
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
                        'سعر الطلب',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        '$orderPrice ج.م',
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
              if (!_isDelivery) ...[
                const SizedBox(width: 6),
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
                          'رسوم التوصيل',
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

    final isPreAssignment =
        _localOrder.status == 'Pending Review' ||
        _localOrder.status == 'Ready For Assignment' ||
        _localOrder.status == 'بانتظار القبول';
    final bool hasDriver = !isPreAssignment;
    final bool hasDriverLocation =
        _localOrder.driverLatitude != null &&
        _localOrder.driverLongitude != null;

    final isDelivering =
        _localOrder.status == 'Assigned To Captain' ||
        _localOrder.status == 'Captain Arrived' ||
        _localOrder.status == 'Picked Up' ||
        _localOrder.status == 'In Transit' ||
        _localOrder.status == 'Delivered' ||
        _localOrder.status == 'Completed';

    final bool showRealTimeStats =
        hasDriver && hasDriverLocation && isDelivering;

    if (showRealTimeStats) {
      if (_polylineCoordinates.isNotEmpty) {
        remainingMeters = _remainingPolylineMeters();
        traversedMeters = _totalRouteDistanceMeters - remainingMeters;
        if (traversedMeters < 0) traversedMeters = 0;
      } else {
        if (_localOrder.status == 'تم القبول') {
          traversedMeters = 0.0;
          remainingMeters = Geolocator.distanceBetween(
            _driverPos.latitude,
            _driverPos.longitude,
            _origin.latitude,
            _origin.longitude,
          );
        } else {
          final startLat = _localOrder.startLatitude ?? _origin.latitude;
          final startLng = _localOrder.startLongitude ?? _origin.longitude;
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
        : (_localOrder.status == 'تم القبول' ||
                  _localOrder.status == 'تم الشراء'
              ? 'بانتظار بدء التوصيل'
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
        : (_localOrder.status == 'تم القبول' ||
                  _localOrder.status == 'تم الشراء'
              ? 'بانتظار بدء التوصيل'
              : _formatRemainingTime(
                  Geolocator.distanceBetween(
                    _origin.latitude,
                    _origin.longitude,
                    _destination.latitude,
                    _destination.longitude,
                  ),
                ));

    final bool isHeadingToMerchant =
        _localOrder.status == 'Assigned To Captain' ||
        _localOrder.status == 'Captain Arrived';

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

    final double shipmentPrice = _localOrder.deliveryFee;
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
          key: const ValueKey('order_tracking_trip_summary_card_container'),
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
              initialCameraPosition: CameraPosition(target: _origin, zoom: 13),
              onMapCreated: (controller) {
                _mapController = controller;
                _updateMapStyle();
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

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTripSummaryCard(),
            ),

            if (_isDelivery)
              Positioned(
                bottom: 220,
                left: 16,
                child: GestureDetector(
                  onTap: _snapToNavigationMode,
                  child: AnimatedContainer(
                    key: const ValueKey(
                      'order_tracking_navigation_btn_container',
                    ),
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
}

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
