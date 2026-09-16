import 'dart:async';
import 'dart:developer';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'socket_service.dart';

/// حالة صلاحية الموقع بصيغة مبسّطة للواجهات
enum LocationAccessState {
  unknown,
  serviceDisabled,
  denied,
  deniedForever,
  granted,
}

/// خدمة الموقع المركزية للتطبيق.
///
/// كانت الشاشات سابقاً تفتح `Geolocator.getPositionStream` كلٌّ على حدة
/// (HomeScreen و DeliveryMapScreen)، ما سبّب مشكلتين:
///   1. توقّف إرسال الموقع فور مغادرة الشاشة أو تصغير التطبيق، بينما الباك أند
///      يبحث عن السائقين بآخر موقع مسجّل → طلبات لا تصل، أو تصل بموقع قديم.
///   2. تيّاران متوازيان أثناء التوصيل = استهلاك بطارية مضاعف.
///
/// الآن يوجد تيّار واحد يملكه هذا الـ Service، ويستمر بالعمل في الخلفية عبر
/// Foreground Service على أندرويد و Background Location Updates على iOS.
class LocationService extends GetxService {
  static LocationService get to => Get.find<LocationService>();

  /// آخر موقع معروف — تراقبه الشاشات بدل فتح تيّار خاص بها
  final Rxn<LatLng> currentLocation = Rxn<LatLng>();

  /// هل حصلنا على إحداثيات حقيقية من الجهاز؟
  /// قبل أن تصبح `true` لا نُرسل أي شيء للسيرفر إطلاقاً.
  final RxBool hasFix = false.obs;

  /// هل التيّار يعمل حالياً؟
  final RxBool isTracking = false.obs;

  /// هل نحن في وضع "متصل" (نُرسل الموقع للسيرفر + إشعار دائم)؟
  final RxBool isPushingToServer = false.obs;

  final Rx<LocationAccessState> accessState =
      LocationAccessState.unknown.obs;

  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  DateTime? _lastPushAt;

  /// الباك أند يطبّق throttle مدته 5 ثوانٍ على `driver:updateLocation`،
  /// فلا فائدة من الإرسال بوتيرة أسرع.
  static const Duration _minPushGap = Duration(seconds: 6);

  /// إعادة إرسال آخر موقع دورياً حتى لو لم يتحرّك السائق، كي لا تتقادم
  /// بيانات `$near` على السيرفر.
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  static const int _distanceFilterMeters = 10;

  /// يُطفأ تلقائياً إذا رفض النظام وضع الخلفية (Info.plist ناقص على iOS).
  /// عندها نستمر بالتتبّع في المقدّمة بدل أن يسقط التطبيق.
  bool _allowBackground = true;

  /// تُستدعى من `Get.putAsync` عند إقلاع التطبيق.
  /// تُحمّل آخر موقع معروف للعرض الفوري على الخريطة دون إرسال أي شيء.
  Future<LocationService> init() async {
    await _primeFromLastKnown();
    return this;
  }

  Future<void> _primeFromLastKnown() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _isPlausible(last.latitude, last.longitude)) {
        currentLocation.value = LatLng(last.latitude, last.longitude);
        hasFix.value = true;
      }
    } catch (e) {
      log('LocationService: last known position failed → $e');
    }
  }

  /// إحداثيات (0,0) تعني عملياً "لا يوجد موقع" — نرفضها كي لا نُفسد
  /// بحث السائقين على السيرفر.
  bool _isPlausible(double lat, double lng) {
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    return true;
  }

  /// التحقّق من الخدمة والصلاحيات وطلبها عند اللزوم.
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      accessState.value = LocationAccessState.serviceDisabled;
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      accessState.value = LocationAccessState.denied;
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      accessState.value = LocationAccessState.deniedForever;
      return false;
    }

    accessState.value = LocationAccessState.granted;
    return true;
  }

  /// بدء التتبّع.
  ///
  /// [pushToServer] = true عندما يكون السائق "متصل": يُفعّل إشعار الخدمة
  /// الأمامية على أندرويد ويُرسل الموقع عبر السوكيت.
  /// [pushToServer] = false للعرض على الخريطة فقط (سائق غير متصل).
  Future<bool> start({required bool pushToServer}) async {
    final ok = await ensurePermission();
    if (!ok) return false;

    // نفس الوضع يعمل أصلاً — لا داعي لإعادة التشغيل
    if (isTracking.value && isPushingToServer.value == pushToServer) {
      return true;
    }

    await _stopStream();
    isPushingToServer.value = pushToServer;

    try {
      _sub = Geolocator.getPositionStream(
        locationSettings:
            _buildSettings(pushToServer, allowBackground: _allowBackground),
      ).listen(
        _onPosition,
        onError: (Object e) {
          log('LocationService: stream error → $e');
          // ⚠️ تصفير isTracking لئلا يظن النظام أن التيّار يعمل بينما مات.
          // بدون هذا يرى السائق "متصل" ولا يصل شيء للسيرفر.
          isTracking.value = false;
        },
        cancelOnError: false,
      );

      isTracking.value = true;

      if (pushToServer) {
        // دفعة أولى فورية حتى لا ينتظر السيرفر أول حركة بمقدار 10 أمتار
        await refreshOnce(push: true);
        _startHeartbeat();
      }

      log('LocationService: started (pushToServer=$pushToServer)');
      return true;
    } catch (e) {
      log('LocationService: failed to start → $e');
      isTracking.value = false;

      // إعادة محاولة واحدة بلا وضع الخلفية — يغطّي حالة نقص
      // UIBackgroundModes:location في Info.plist على iOS.
      if (_allowBackground && pushToServer) {
        _allowBackground = false;
        log('LocationService: retrying without background mode');
        return start(pushToServer: pushToServer);
      }
      return false;
    }
  }

  LocationSettings _buildSettings(bool pushToServer,
      {bool allowBackground = true}) {
    if (GetPlatform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        intervalDuration: const Duration(seconds: 10),
        // الإشعار الدائم مطلوب فقط أثناء وضع الاتصال — وهو ما يُبقي التتبّع
        // حيّاً بعد تصغير التطبيق أو إطفاء الشاشة.
        foregroundNotificationConfig: pushToServer
            ? ForegroundNotificationConfig(
                notificationTitle: 'fg_location_title'.tr,
                notificationText: 'fg_location_body'.tr,
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }

    if (GetPlatform.isIOS) {
      // ⚠️ إلزامي على iOS: يجب أن يحتوي Info.plist على UIBackgroundModes: location
      // وإلا يُلقي النظام استثناءً أصلياً (ObjC exception) لا يلتقطه try/catch.
      // راجع SETUP.md للتفاصيل.
      // ملاحظة: الاستثناء لا يقع هنا عند إنشاء الكائن، بل لاحقاً داخل
      // getPositionStream عندما يضبط النظام allowsBackgroundLocationUpdates.
      // لذلك الحارس الحقيقي موجود في start() على شكل إعادة محاولة.
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: pushToServer && allowBackground,
        allowBackgroundLocationUpdates: pushToServer && allowBackground,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanceFilterMeters,
    );
  }

  void _onPosition(Position pos) {
    if (!_isPlausible(pos.latitude, pos.longitude)) return;

    currentLocation.value = LatLng(pos.latitude, pos.longitude);
    hasFix.value = true;

    if (isPushingToServer.value) {
      _push(pos.latitude, pos.longitude);
    }
  }

  void _push(double lat, double lng, {bool force = false}) {
    if (!_isPlausible(lat, lng)) return;

    if (!force && _lastPushAt != null &&
        DateTime.now().difference(_lastPushAt!) < _minPushGap) {
      return;
    }

    if (!Get.isRegistered<SocketService>()) return;
    final socket = Get.find<SocketService>();
    if (!socket.isConnected) return;

    socket.updateLocation(lat, lng);
    _lastPushAt = DateTime.now();
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      final loc = currentLocation.value;
      if (loc == null || !isPushingToServer.value) return;
      _push(loc.latitude, loc.longitude, force: true);
    });
  }

  /// تبديل وضع الإرسال دون إيقاف التتبّع بالكامل.
  /// تُستدعى عند تشغيل/إطفاء مفتاح "متصل".
  Future<void> setOnlineMode(bool online) async {
    if (online) {
      await start(pushToServer: true);
    } else {
      _heartbeat?.cancel();
      _heartbeat = null;
      // نُبقي التتبّع للعرض على الخريطة لكن بلا إشعار دائم ولا إرسال
      await start(pushToServer: false);
    }
  }

  /// قراءة موقع لحظية (زر "موقعي" على الخريطة مثلاً).
  Future<LatLng?> refreshOnce({bool push = false}) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));

      if (!_isPlausible(pos.latitude, pos.longitude)) return null;

      currentLocation.value = LatLng(pos.latitude, pos.longitude);
      hasFix.value = true;

      if (push && isPushingToServer.value) {
        _push(pos.latitude, pos.longitude, force: true);
      }
      return currentLocation.value;
    } catch (e) {
      log('LocationService: refreshOnce failed → $e');
      return null;
    }
  }

  /// يُعيد إرسال آخر موقع فوراً — تُستدعى بعد إعادة اتصال السوكيت.
  void resyncAfterReconnect() {
    final loc = currentLocation.value;
    if (loc == null || !isPushingToServer.value) return;
    _push(loc.latitude, loc.longitude, force: true);
  }

  Future<void> _stopStream() async {
    await _sub?.cancel();
    _sub = null;
    isTracking.value = false;
  }

  /// إيقاف كامل — عند تسجيل الخروج فقط.
  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    isPushingToServer.value = false;
    await _stopStream();
    log('LocationService: stopped');
  }

  @override
  void onClose() {
    _heartbeat?.cancel();
    _sub?.cancel();
    super.onClose();
  }
}
