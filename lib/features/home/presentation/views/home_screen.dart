import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:delivery_app/core/map/map_styles.dart';
import 'package:delivery_app/core/map/marker_bitmap.dart';

import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/data/services/location_service.dart';
import 'package:delivery_app/data/services/socket_service.dart';
import 'package:delivery_app/features/orders/presentation/controllers/orders_history_controller.dart';
import 'package:delivery_app/features/wallet/presentation/controllers/wallet_controller.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';

import '../../../../core/widgets/custom_leading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SocketService _socketService = Get.find<SocketService>();
  final LocationService _location = Get.find<LocationService>();
  final WalletController _walletController = Get.put(WalletController());

  /// مصدر بطاقة «أرباح اليوم»: today.earnings من orders-history =
  /// مجموع أجور التوصيل لطلبات اليوم المسلّمة — وليس إجمالي الكاش.
  /// (/wallet للسائق السوري لا يرجع أجر التوصيل اليومي إطلاقاً)
  late final OrdersHistoryController _historyController;

  final AuthController _authController = Get.find<AuthController>();
  // يصل من onMapCreated — لا يتوفّر قبل بناء الخريطة فعلياً
  GoogleMapController? _mapController;

  // أيقونتان ثابتتان تُرسمان مرة واحدة: علامة السائق وعلامة المطعم.
  // رسمهما مع كل تحديث موقع (كل 10 أمتار) هدر واضح.
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _restaurantIcon;

  /// مركز افتراضي للخريطة قبل وصول أول قراءة GPS — للعرض فقط،
  /// ولا يُرسل للسيرفر أبداً (كانت الإحداثيات المثبتة سابقاً تُرسل فعلياً).
  static const LatLng _fallbackCenter = LatLng(33.5138, 36.2765);

  LatLng get _mapCenter => _location.currentLocation.value ?? _fallbackCenter;

  /// مصدر الحقيقة هو AuthController.isOnline (permanent) — لا متغير محلي هنا
  /// حتى تبقى كل الشاشات متزامنة ولا يظهر كاش GetStorage أخضر كاذب بعد
  /// إعادة التشغيل. أثناء isStatusSyncing يظهر المؤشر رمادياً (غير مؤكد).
  bool get _online => _authController.isOnline.value;

  /// متصل بالسيرفر لكن القناة الفعلية مكسورة: سوكيت مفصول أو GPS ميت أو
  /// السيرفر يرفض push الموقع. النقطة برتقالية بدل الخضراء حتى لا يظن
  /// السائق أنه يستقبل طلبات.
  /// نقرأ `connected` (RxBool) لا `isConnected` (getter عادي): داخل Obx
  /// وحدها النسخة التفاعلية تُعيد البناء عند سقوط السوكيت أو عودته.
  bool get _isDegraded =>
      _online &&
      (!_socketService.connected.value ||
          !_location.isTracking.value ||
          _socketService.locationPushFailing.value);

  /// يصبح false عندما يبتعد مركز الخريطة عن موقع السائق (سحب أو تحريك)
  final RxBool _isCenteredOnDriver = true.obs;

  /// تنبيه صوتي/مرئي فقط عند موت GPS وهو متصل — بلا تزوير الحالة محلياً.
  /// (السابق كان يقلب المؤشر offline محلياً بينما السيرفر ما زال online).
  Worker? _trackingWarnWorker;

  @override
  void initState() {
    super.initState();
    _initializeHomeData();
    _watchTrackingHealth();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    final driver = await MarkerBitmap.circleIcon(
      icon: Icons.directions_car,
      color: AppColors.primaryOrange,
      diameter: 48,
    );
    final restaurant = await MarkerBitmap.circleIcon(
      icon: Icons.restaurant,
      color: Colors.white,
      iconColor: AppColors.primaryOrange,
      diameter: 40,
    );
    if (!mounted) return;
    setState(() {
      _driverIcon = driver;
      _restaurantIcon = restaurant;
    });
  }

  void _watchTrackingHealth() {
    _trackingWarnWorker = ever(_location.isTracking, (bool tracking) {
      if (!mounted) return;
      // نُنبّه فقط — الحالة الحقيقية تبقى من السيرفر وتُعرض برتقالية عبر
      // _isDegraded بدل قلبها offline كاذباً.
      // حارسان ضد الإنذار الكاذب: أثناء قلب المفتاح (التوقف المؤقت للتيار
      // عند الانتقال push=true/false مقصود) وأثناء المزامنة الأولى.
      if (_authController.isTogglingStatus.value) return;
      if (_authController.isStatusSyncing.value) return;
      if (!tracking && _online) {
        Get.snackbar(
          "alert".tr,
          "connection_error".tr,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    });
  }

  void _initializeHomeData() {
    // أرباح التوصيل: إن كان متحكم السجل مسجلاً مسبقاً نحدّثه، وإلا
    // فإنشاؤه يجلب تلقائياً عبر onInit — بلا طلبات مكررة في الحالتين.
    if (Get.isRegistered<OrdersHistoryController>()) {
      _historyController = Get.find<OrdersHistoryController>();
      _historyController.fetchOrdersHistory();
    } else {
      _historyController = Get.put(OrdersHistoryController());
    }

    // لا نطلب الصلاحية هنا — نافذة طلب الصلاحية قد تظهر فوق السبلاش
    // إذا كان المستخدم غير مسجل دخول. الصلاحية تُطلب فقط عند تفعيل
    // مفتاح "متصل" في _toggleStatus.
    // التتبّع للعرض على الخريطة يعمل تلقائياً عبر LocationService
    // (آخر موقع معروف بدون إرسال).
    _walletController.fetchWalletSummary();

    // المزامنة الوحيدة مع السيرفر — هي التي تضبط isOnline و تُطفئ syncing.
    // لا قراءة لـ GetStorage هنا عمداً: الكاش قد يكون online من جلسة سابقة.
    _authController.fetchDriverData();

    _authController.fetchNearbyRestaurants();
  }

  Future<void> _toggleStatus(bool val) async {
    // قفل ضد الضغط المتكرر: السوكيت لا يؤكد النجاح فالتبديل المتسابق
    // كان يترك المؤشر أخضر كاذباً.
    if (_authController.isTogglingStatus.value) return;
    _authController.isTogglingStatus.value = true;
    try {
      if (val) {
        // لا نسمح بالاتصال قبل التأكد من الصلاحيات ومن وجود إحداثيات حقيقية،
        // وإلا بحث السيرفر عن السائق بموقع خاطئ أو قديم.
        final started = await _location.start(pushToServer: true);
        if (!started) {
          _showLocationProblem();
          return;
        }

        if (_location.currentLocation.value == null) {
          await _location.refreshOnce(push: true);
        }
        if (_location.currentLocation.value == null) {
          await _location.setOnlineMode(false);
          Get.snackbar(
            "alert".tr,
            "waiting_gps_fix".tr,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return;
        }

        // بلا تحديث متفائل: المؤشر يبقى رمادي/قديم حتى يؤكد السيرفر عبر
        // fetchDriverData أدناه (أو driver:currentStatus).
        _socketService.goOnline();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_location.currentLocation.value!, 15.0),
        );
      } else {
        _socketService.goOffline();
        await _location.setOnlineMode(false);
      }

      // الباك يؤكّد النجاح بحدث driver:currentStatus، وSocketService يمرّره
      // إلى applyServerAvailability — ننتظر التأكيد بدل تأخير ثابت، ونسقط
      // إلى HTTP إن لم يصل الحدث (فشل صامت أو حدث ضائع).
      final confirmed = await _awaitServerStatus(val);
      if (!mounted) return;
      if (!confirmed) {
        await _authController.fetchDriverData();
        if (!mounted) return;
      }

      if (_authController.isOnline.value != val) {
        Get.snackbar(
          "alert".tr,
          "status_change_failed".tr,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      // مثال: استثناء من طلب صلاحية الموقع أو من تيّار GPS ميت
      debugPrint('toggle status failed: $e');
      if (!mounted) return;
      Get.snackbar(
        "alert".tr,
        "status_change_failed".tr,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } finally {
      _authController.isTogglingStatus.value = false;
    }
  }

  /// ينتظر تأكيد السيرفر للحالة المطلوبة (يصل عادة في أجزاء من الثانية عبر
  /// `driver:currentStatus`). يُرجع false عند انتهاء المهلة فيتولى نداء
  /// HTTP الحسم.
  Future<bool> _awaitServerStatus(bool expected) async {
    if (_authController.isOnline.value == expected) return true;

    final completer = Completer<bool>();
    final timer = Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) completer.complete(false);
    });
    final worker = ever<bool>(_authController.isOnline, (value) {
      if (value == expected && !completer.isCompleted) completer.complete(true);
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      worker.dispose();
    }
  }

  void _showLocationProblem() {
    final String msg;
    switch (_location.accessState.value) {
      case LocationAccessState.serviceDisabled:
        msg = "enable_gps_msg".tr;
        break;
      case LocationAccessState.deniedForever:
        msg = "location_permission_forever_msg".tr;
        break;
      default:
        msg = "location_permission_msg".tr;
    }
    Get.snackbar(
      "alert".tr,
      msg,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    // لا نوقف LocationService هنا — التتبّع يجب أن يستمر بعد مغادرة الشاشة
    _trackingWarnWorker?.dispose();
    // GoogleMapController تتكفّل به الودجة نفسها عند إزالتها
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey.shade100,
      appBar: _buildAppBar(isDark),
      body: Stack(
        children: [
          _buildMapLayer(isDark),
          _buildOverlayUI(isDark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                isDark ? const Color(0xFF3D2621) : Colors.orange.shade100,
                isDark ? AppColors.darkBackground : Colors.white,
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark ? [] : [
            const BoxShadow(color: Colors.black12, blurRadius: 4)
          ],
        ),
        child: CustomLeading(
            icon: Icons.menu, onPressed: () => Get.toNamed('/settings')),
      ),
      // المؤشر يقرأ مصدر الحقيقة الوحيد + صحة القناة:
      // رمادي = offline أو جارٍ المزامنة/التبديل (غير مؤكد)، أخضر = online سليم،
      // برتقالي = online على السيرفر لكن السوكيت/GPS مكسور (لن تصلك طلبات).
      title: Obx(() {
        // قراءات صريحة داخل Obx لضمان إعادة البناء عند تغيّر أي مصدر —
        // نفس منطق _online/_isDegraded لكن بلا اعتماد على getters وسيطة.
        final serverOnline = _authController.isOnline.value;
        final syncing = _authController.isStatusSyncing.value;
        final toggling = _authController.isTogglingStatus.value;
        final socketOk = _socketService.connected.value;
        final tracking = _location.isTracking.value;
        final pushFailing = _socketService.locationPushFailing.value;

        final unconfirmed = syncing || toggling;
        final online = serverOnline && !unconfirmed;
        final degraded =
            !unconfirmed && serverOnline && (!socketOk || !tracking || pushFailing);
        final dot = unconfirmed
            ? Colors.grey.shade400
            : !online
                ? Colors.grey
                : degraded
                    ? Colors.orange
                    : Colors.green;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 4, backgroundColor: dot),
            const SizedBox(width: 8),
            Text(online ? "online".tr : "offline".tr,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        );
      }),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CustomLeading(icon: Icons.notifications,
              onPressed: () => Get.toNamed('/notifications')),
        ),
      ],
    );
  }

  Widget _buildMapLayer(bool isDark) {
    // الخريطة كلها داخل Obx الآن. سابقاً كان Obx يلفّ طبقات العلامات وحدها
    // لتفادي إعادة بناء TileLayer وكل البلاطات مع كل تحديث موقع. مع خرائط
    // غوغل لا وجود لبلاطات في شجرة Flutter — الخريطة عرض أصلي (platform
    // view) يُحدَّث بفروق مجموعة العلامات فقط، فلا تكلفة لإعادة البناء.
    return Obx(() {
      final driverPos = _location.currentLocation.value;
      _authController.nearbyRestaurants.length; // تتبّع التغيّر داخل Obx

      return GoogleMap(
        initialCameraPosition: CameraPosition(target: _mapCenter, zoom: 15.0),
        onMapCreated: (controller) => _mapController = controller,
        style: isDark ? MapStyles.dark : null,
        onCameraMove: (position) {
          final driver = _location.currentLocation.value;
          if (driver == null) return;
          // عتبة 500 متر: تحرّك بسيط باليد لا يُظهر الزر دائماً.
          // ملاحظة: onCameraMove في غوغل لا يميّز حركة اليد عن الحركة
          // البرمجية (بعكس hasGesture سابقاً)، لكن التمركز البرمجي يضبط
          // _isCenteredOnDriver بنفسه بعده فلا يظهر الزر خطأً.
          final distance = Geolocator.distanceBetween(
            position.target.latitude,
            position.target.longitude,
            driver.latitude,
            driver.longitude,
          );
          _isCenteredOnDriver.value = distance < 500;
        },
        markers: {
          ..._buildRestaurantMarkers(),
          if (driverPos != null && _driverIcon != null)
            Marker(
              markerId: const MarkerId('driver'),
              position: driverPos,
              icon: _driverIcon!,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 1,
            ),
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      );
    });
  }

  Set<Marker> _buildRestaurantMarkers() {
    if (_restaurantIcon == null) return const <Marker>{};
    final markers = <Marker>{};
    for (final r in _authController.nearbyRestaurants) {
      final lat = r['location']?['coordinates']?[1] as double?;
      final lng = r['location']?['coordinates']?[0] as double?;
      if (lat == null || lng == null) continue;
      markers.add(
        Marker(
          // المعرّف من إحداثيات المطعم: مستقر بين عمليات إعادة البناء
          // فلا تُعاد العلامة رسماً بلا سبب.
          markerId: MarkerId('restaurant_${lat}_$lng'),
          position: LatLng(lat, lng),
          icon: _restaurantIcon!,
          anchor: const Offset(0.5, 0.5),
          onTap: () => _showRestaurantInfo(r),
        ),
      );
    }
    return markers;
  }

  void _showRestaurantInfo(Map<String, dynamic> restaurant) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant, color: AppColors.primaryOrange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(restaurant['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (restaurant['address'] is Map)
                        Text(restaurant['address']['fullAddress'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      if (restaurant['address'] is String)
                        Text(restaurant['address'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                if (restaurant['rating'] != null)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('${restaurant['rating']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayUI(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildStatusCard(isDark),
          Obx(() => _socketService.locationPushFailing.value
              ? _buildLocationWarning()
              : const SizedBox.shrink()),
          // قناة مكسورة أثناء online: سوكيت مفصول أو GPS ميت — تنبيه إضافي
          // (locationPushFailing له شارة مستقلة أعلاه).
          Obx(() {
            if (!_online || _socketService.locationPushFailing.value) {
              return const SizedBox.shrink();
            }
            if (_socketService.connected.value &&
                _location.isTracking.value) {
              return const SizedBox.shrink();
            }
            return _buildDegradedWarning();
          }),
          const Spacer(),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Obx(() => _isCenteredOnDriver.value
                ? const SizedBox.shrink()
                : _buildLocateMeButton(isDark)),
          ),
          const SizedBox(height: 10),
          _buildRestaurantListButton(isDark),
          const SizedBox(height: 10),
          _buildQuickStats(isDark),
          const SizedBox(height: 20),
          Obx(() {
            // قراءة صريحة للمصدر الوحيد حتى يتحدث الزر مع المؤشر دائماً.
            final serverOnline = _authController.isOnline.value;
            _authController.isStatusSyncing.value;
            return serverOnline
                ? _buildWaitingOrdersButton()
                : _buildBottomGuidance(isDark);
          }),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// تحذير القناة المتدهورة: متصل على السيرفر لكن الطلبات لن تصلك الآن.
  Widget _buildDegradedWarning() {
    final bool socketDown = !_socketService.connected.value;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              socketDown ? "connection_error".tr : "waiting_gps_fix".tr,
              style: const TextStyle(
                  color: Colors.orange, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// السيرفر يرفض تحديثات الموقع (`driver:updateLocation:error`) — بلا هذه
  /// الشارة كان السائق يظن نفسه ظاهراً للنظام بينما لا يصله أي طلب.
  Widget _buildLocationWarning() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Colors.deepOrange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "location_push_failed".tr,
              style: const TextStyle(
                  color: Colors.deepOrange, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.2)),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Obx(() {
        final bool online = _online;
        final bool busy =
            _authController.isTogglingStatus.value ||
                _authController.isStatusSyncing.value;
        // _isDegraded يقرأ صحة القناة داخلياً فيُعيد Obx البناء عند تغيرها.
        final bool degraded = online && !busy && _isDegraded;
        return Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !online
                        ? (isDark
                            ? const Color(0xFF2D323F)
                            : Colors.grey.shade200)
                        : degraded
                            ? Colors.orange
                            : AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.power_settings_new,
                      color: online ? Colors.white : (isDark
                          ? Colors.white70
                          : Colors.grey)),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("status_label".tr, style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12)),
                    Text(online ? "online_msg".tr : "go_online_msg".tr,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                if (busy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: online,
                      trackOutlineColor: const WidgetStatePropertyAll(
                          Colors.transparent),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey.shade400,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.primaryOrange,
                      // قفل أثناء التبديل/المزامنة لمنع السباق.
                      onChanged: _toggleStatus,
                    ),
                  ),
              ],
            ),
            if (online) ...[
              const SizedBox(height: 10),
              Divider(thickness: 0.3,
                  color: isDark ? Colors.grey : Colors.grey.shade300),
              Align(alignment: AlignmentDirectional.centerStart,
                  child: Text("ready_accept_msg".tr, style: const TextStyle(
                      color: AppColors.primaryOrange, fontSize: 14))),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildQuickStats(bool isDark) {
    return Obx(() {
      final summary = _walletController.walletSummary;
      return Row(
        children: [
          // أرباح السائق من أجور التوصيل فقط (today.earnings) —
          // سابقاً كانت تعرض totalCollectedToday وهو إجمالي الكاش من الزبائن
          _buildStatCard(
              "earnings_today".tr,
              "${_historyController.todayEarnings.value.toStringAsFixed(2)} ل.س",
              Icons.attach_money, Colors.orange, Icons.trending_up, isDark),
          const SizedBox(width: 15),
          _buildStatCard(
              "orders_today".tr, (summary['todayOrdersCount'] ?? 0).toString(),
              Icons.inventory_2_outlined, Colors.blue, Icons.access_time,
              isDark),
        ],
      );
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color iconColor, IconData trendIcon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: iconColor, size: 20)),
                Icon(trendIcon, color: iconColor.withValues(alpha: 0.6), size: 16),
              ],
            ),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(
                color: AppColors.textGrey, fontSize: 12)),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocateMeButton(bool isDark) {
    return GestureDetector(
      onTap: _centerOnDriver,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.my_location,
            color: AppColors.primaryOrange, size: 22),
      ),
    );
  }

  void _centerOnDriver() {
    final pos = _location.currentLocation.value;
    if (pos == null) {
      Get.snackbar(
        "alert".tr,
        "waiting_gps_fix".tr,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    // newLatLng يحافظ على مستوى التكبير الحالي — نفس سلوك
    // move(pos, camera.zoom) السابق
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
    _isCenteredOnDriver.value = true;
  }

  Widget _buildWaitingOrdersButton() {
    return Container(
      width: double.infinity, height: 50,
      decoration: BoxDecoration(
        color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Text("waiting_orders".tr, style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantListButton(bool isDark) {
    return Obx(() {
      final count = _authController.nearbyRestaurants.length;
      if (count == 0) return const SizedBox.shrink();
      return GestureDetector(
        onTap: _showRestaurantList,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: isDark ? [] : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.restaurant, color: AppColors.primaryOrange, size: 20),
              const SizedBox(width: 10),
              Text('$count ${"nearby_restaurants".tr}',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
              const Spacer(),
              Icon(Icons.keyboard_arrow_up,
                  color: isDark ? Colors.white70 : Colors.grey),
            ],
          ),
        ),
      );
    });
  }

  void _showRestaurantList() {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.5,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text("nearby_restaurants".tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                final restaurants = _authController.nearbyRestaurants;
                if (restaurants.isEmpty) {
                  return Center(child: Text("no_nearby_restaurants".tr));
                }
                return ListView.separated(
                  itemCount: restaurants.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final r = restaurants[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.restaurant, color: AppColors.primaryOrange),
                      ),
                      title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        (r['address'] is Map) ? r['address']['fullAddress'] ?? '' : (r['address']?.toString() ?? ''),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      trailing: r['rating'] != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text('${r['rating']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )
                          : null,
                      onTap: () {
                        Get.back();
                        final lat = r['location']?['coordinates']?[1] as double?;
                        final lng = r['location']?['coordinates']?[0] as double?;
                        if (lat != null && lng != null) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.0),
                          );
                        }
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomGuidance(bool isDark) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
      child: Column(
        children: [
          Icon(Icons.info_outline,
              color: AppColors.primaryOrange.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text("offline_guidance_msg".tr, textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
