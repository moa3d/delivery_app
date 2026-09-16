import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api_client/dio_client.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/navigation/presentation/controllers/navigation_controller.dart';
import '../../features/orders/presentation/controllers/new_order_controller.dart';
import '../../features/orders/presentation/controllers/orders_history_controller.dart';
import '../../features/wallet/presentation/controllers/wallet_controller.dart';
import 'location_service.dart';

class SocketService extends GetxService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  SocketService._internal();

  /// مشتق من DioClient.baseUrl حتى لا يبقى العنوان مثبّتاً بنسختين
  /// مستقلتين تتفرّقان عند تغيير الاستضافة.
  static final String _namespaceUrl =
      '${DioClient.baseUrl.replaceAll(RegExp(r'/+$'), '')}/driver';

  io.Socket? socket;
  final _storage = GetStorage();

  /// Broadcast stream for order:statusUpdated — multiple callers can listen
  StreamController<Map<String, dynamic>> _orderStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get orderStatusStream =>
      _orderStatusController.stream;

  /// حالة الاتصال للعرض في الواجهة (شارة "غير متصل" مثلاً)
  final RxBool connected = false.obs;

  bool get isConnected => socket != null && socket!.connected;

  /// يُرفع عند رفض السيرفر للتوكن، فنتوقّف عن محاولات إعادة الاتصال العمياء
  bool _authRejected = false;

  /// نمنع تكرار معالجة خطأ المصادقة عند تعدّد محاولات إعادة الاتصال
  DateTime? _lastAuthCheck;

  /// الباك يُصدر `driver:updateLocation:error` عند فشل تحديث الموقع، ولم
  /// يكن له أي مستمع — فكان السائق يظن نفسه ظاهراً للنظام وهو ليس كذلك.
  /// نعرضه بعد ثلاث محاولات متتالية فقط، لأن النبضة كل ست ثوانٍ.
  final RxBool locationPushFailing = false.obs;
  int _locationErrorStreak = 0;
  Timer? _locationErrorDecay;

  static const _locationErrorThreshold = 3;

  void connect() {
    // إعادة تهيئة الـ StreamController إذا كان مُغلقاً من جلسة سابقة (بعد logout)
    if (_orderStatusController.isClosed) {
      _orderStatusController =
          StreamController<Map<String, dynamic>>.broadcast();
    }

    final String? token = _storage.read('token');
    if (token == null) {
      log('❌ Socket: No token found, cannot connect.');
      return;
    }

    // اتصال قائم بالفعل — لا نُنشئ نسخة ثانية
    if (socket != null && socket!.connected) {
      log('ℹ️ Socket: already connected');
      return;
    }

    // تنظيف أي نسخة قديمة قبل إنشاء واحدة جديدة
    _teardownSocket();

    _authRejected = false;

    socket = io.io(
      _namespaceUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          // القيمة الافتراضية (double.infinity) = محاولات غير محدودة.
          // لا نستخدم -1 لأن socket.io-client-dart يُفسّرها كأنها تعني
          // "استسلم من أول محاولة" (0 >= -1 = true).
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .build(),
    );

    // ⚠️ تُسجَّل مرة واحدة فقط عند إنشاء السوكيت.
    // كانت سابقاً داخل onConnect، فتتضاعف مع كل إعادة اتصال وتُنتج
    // إشعارات وتنقّلات مكرّرة.
    _setupGlobalListeners();

    socket!.onConnect((_) {
      connected.value = true;
      log('✅ Connected to Driver Socket Namespace');
      _onReconnected();
    });

    socket!.onDisconnect((_) {
      connected.value = false;
      log('❌ Disconnected from Driver Socket');
    });

    socket!.onConnectError(_handleConnectError);
    socket!.onError((err) => log('⚠️ Socket error: $err'));
  }

  /// يُستدعى عند عودة التطبيق من الخلفية أو عند رجوع الشبكة.
  void ensureConnected() {
    if (_authRejected) return;
    if (_storage.read('token') == null) return;

    if (socket == null) {
      connect();
      return;
    }
    if (!socket!.connected) {
      log('🔄 Socket: reconnecting…');
      socket!.connect();
    }
  }

  /// debounce لمنع التنقّل المتكرر بين الشاشات أثناء اتصال متذبذب.
  /// fetchDriverData تستدعي _checkStatus التي قد تُنفّذ Get.offAllNamed.
  DateTime? _lastReconnectSync;

  /// بعد أي اتصال ناجح: نُعيد مزامنة الموقع، لأن ما حدث أثناء
  /// الانقطاع لم يصل للسيرفر.
  void _onReconnected() {
    final now = DateTime.now();
    if (_lastReconnectSync != null &&
        now.difference(_lastReconnectSync!) < const Duration(seconds: 5)) {
      return;
    }
    _lastReconnectSync = now;

    _resetLocationErrorState();

    if (Get.isRegistered<LocationService>()) {
      Get.find<LocationService>().resyncAfterReconnect();
    }
    // لا نستدعي fetchDriverData هنا — تتم المزامنة عبر
    // AppLifecycleService._onResumed مع debounce مناسب.
  }

  void _handleConnectError(dynamic err) {
    connected.value = false;
    final String msg = err?.toString().toLowerCase() ?? '';
    log('⚠️ Connection Error: $err');

    // driverSocketAuth يرفض الاتصال إذا كان الحساب غير معتمد أو التوكن منتهياً.
    // بلا هذه المعالجة يبقى السائق ينتظر طلبات لن تصل أبداً بلا أي تفسير.
    if (!msg.contains('unauthorized')) return;

    // disconnect() يوقف محاولات إعادة الاتصال التلقائية أيضاً
    _authRejected = true;
    socket?.disconnect();

    final now = DateTime.now();
    if (_lastAuthCheck != null &&
        now.difference(_lastAuthCheck!) < const Duration(seconds: 10)) {
      return;
    }
    _lastAuthCheck = now;

    // fetchDriverData يوجّه تلقائياً إلى /blocked أو /documents-completion
    // أو يُخرج السائق عند 401.
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().fetchDriverData();
    }
  }

  // --- مستمعات عالمية (تنبيهات النظام والطلبات) ---

  void _setupGlobalListeners() {
    final s = socket;
    if (s == null) return;

    // 1. طلب توصيل جديد — الباك أند يُرسل "order:driverRequest" حصراً
    s.on('order:driverRequest', _handleNewOrder);

    // 2. تأكيد السيرفر على قبول السائق للطلب (الانتقال للتفاصيل)
    s.on('order:driverRequest:accepted', (data) {
      log('✅ Server confirmed acceptance. Moving to Details.');

      if (Get.isRegistered<NewOrderController>()) {
        Get.find<NewOrderController>().onServerAccepted();
      }

      final orderData =
          data is Map && data.containsKey('order') ? data['order'] : data;

      if (orderData != null) {
        _closeOverlays();
        Get.toNamed('/details-order', arguments: orderData);
      }
    });

    // 3. انتهاء صلاحية الطلب (قبله سائق آخر)
    s.on('order:driverRequest:expired', (data) {
      if (Get.isRegistered<NewOrderController>()) {
        Get.find<NewOrderController>().onRequestClosed();
      }
      _closeOverlays();
      Get.snackbar(
        'alert'.tr,
        data is Map
            ? (data['message'] ?? 'order_no_longer_available'.tr)
            : 'order_no_longer_available'.tr,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      if (Get.currentRoute == '/new-order') Get.back();
    });

    // 4. تجاوز حد الكاش (خاص بسوريا)
    s.on('order:cashLimit:exceeded', (data) {
      if (Get.isRegistered<NewOrderController>()) {
        Get.find<NewOrderController>().onRequestClosed();
      }
      _closeOverlays();

      // الباك يرسل message (مترجمة أصلاً) مع cashCollected و orderTotal —
      // كنا نستخدم cashCreditLimit وحده ونُهمل البقية.
      final map = data is Map ? data : const {};
      final details = <String>[
        if (map['cashCollected'] != null)
          '${'cash_limit_collected'.tr}: ${map['cashCollected']}',
        if (map['orderTotal'] != null)
          '${'cash_limit_order_total'.tr}: ${map['orderTotal']}',
      ];
      final body = (map['message']?.toString().isNotEmpty ?? false)
          ? map['message'].toString()
          : 'cash_limit_body'
              .trParams({'limit': '${map['cashCreditLimit'] ?? ''}'});

      Get.defaultDialog(
        title: 'cash_limit_title'.tr,
        middleText: details.isEmpty
            ? body
            : '$body\n\n${details.join('\n')}',
        textConfirm: 'go_to_wallet'.tr,
        confirmTextColor: Colors.white,
        onConfirm: () {
          Get.back();
          Get.toNamed('/main-navigation');
          if (Get.isRegistered<NavigationController>()) {
            Get.find<NavigationController>().changePage(1);
          }
        },
        textCancel: 'close_btn'.tr,
      );
    });

    // 5. تحديث حالة السائق (Online/Offline/Busy)
    // يُزامَن مع مصدر الحقيقة الوحيد AuthController.isOnline حتى لا يبقى
    // مؤشر الـ AppBar أخضر/رمادي قديماً عند تغيّر الحالة من الخارج.
    s.on('driver:currentStatus', (data) {
      if (data is! Map) return;
      if (Get.isRegistered<AuthController>()) {
        final authController = Get.find<AuthController>();
        authController.driverData['availability'] = data['availability'];
        authController.driverData.refresh();
        authController
            .applyServerAvailability(data['availability']?.toString());
      }
      // مزامنة وضع الإرسال مع الحالة الحقيقية القادمة من السيرفر
      if (Get.isRegistered<LocationService>()) {
        final availability = data['availability']?.toString();
        final shouldPush =
            availability == 'online' || availability == 'busy';
        Get.find<LocationService>().setOnlineMode(shouldPush);
      }
    });

    // 6. تحديثات حالة الطلب (التوصيل، الإلغاء، إلخ)
    s.on('order:statusUpdated', (data) async {
      if (data is! Map) return;
      log("🔄 Order status updated: ${data['status']}");

      if (!_orderStatusController.isClosed) {
        _orderStatusController.add(Map<String, dynamic>.from(data));
      }

      if (data['status'] == 'delivered') {
        await Future.delayed(const Duration(seconds: 1));
        if (Get.isRegistered<WalletController>()) {
          Get.find<WalletController>().fetchAllWalletData();
        }
        // تحديث أرباح اليوم في الشاشة الرئيسية (تُحسب من orders-history)
        if (Get.isRegistered<OrdersHistoryController>()) {
          Get.find<OrdersHistoryController>().fetchOrdersHistory();
        }
        Get.snackbar(
          'success_snack_title'.tr,
          'success_snack_msg'.tr,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        if (Get.currentRoute != '/main-navigation') {
          Get.offAllNamed('/main-navigation');
        }
      }
    });

    // 7. أخطاء تغيير الحالة
    s.on('driver:goOnline:error', (data) => _handleStatusError(data, true));
    s.on('driver:goOffline:error', (data) => _handleStatusError(data, false));

    // 8. رفض الطلب — تأكيد صريح من السيرفر بدل افتراض نجاح الرفض
    s.on('order:driverRequest:rejected', (data) {
      if (Get.isRegistered<NewOrderController>()) {
        Get.find<NewOrderController>().onRequestClosed();
      }
      _closeOverlays();
      if (Get.currentRoute == '/new-order') Get.back();
      Get.snackbar(
        'alert'.tr,
        data is Map
            ? (data['message'] ?? 'order_declined'.tr)
            : 'order_declined'.tr,
        backgroundColor: Colors.blueGrey,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    });

    // 9. فشل إرسال الموقع — كان صامتاً تماماً
    s.on('driver:updateLocation:error', _handleLocationError);

    // 10. أخطاء عامة من السيرفر
    s.on('order:error', (data) {
      if (Get.isRegistered<NewOrderController>()) {
        Get.find<NewOrderController>().onRequestClosed();
      }
      _closeOverlays();
      Get.snackbar(
        'alert'.tr,
        data is Map
            ? (data['message'] ?? 'order_error_generic'.tr)
            : 'order_error_generic'.tr,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    });
  }

  // --- الدوال المساعدة ---

  void _closeOverlays() {
    if (Get.isDialogOpen ?? false) Get.back();
  }

  /// السيرفر لا يُرسل تأكيداً عند نجاح تحديث الموقع، فنعتبر مرور دقيقة
  /// كاملة بلا خطأ دليلاً على عودة الإرسال (النبضة كل 30 ثانية على الأكثر).
  void _handleLocationError(dynamic data) {
    _locationErrorStreak++;
    _locationErrorDecay?.cancel();
    _locationErrorDecay = Timer(const Duration(seconds: 60), () {
      _locationErrorStreak = 0;
      locationPushFailing.value = false;
    });

    if (_locationErrorStreak < _locationErrorThreshold) return;
    if (locationPushFailing.value) return; // نبّهنا مسبقاً — لا نُكرر

    locationPushFailing.value = true;
    log('⚠️ Location push failing: $data');
    Get.snackbar(
      'alert'.tr,
      data is Map && data['message'] != null
          ? data['message'].toString()
          : 'location_push_failed'.tr,
      backgroundColor: Colors.deepOrange,
      colorText: Colors.white,
      duration: const Duration(seconds: 6),
    );
  }

  void _resetLocationErrorState() {
    _locationErrorDecay?.cancel();
    _locationErrorDecay = null;
    _locationErrorStreak = 0;
    locationPushFailing.value = false;
  }

  void _handleStatusError(dynamic data, bool wasGoingOnline) {
    String msg = data is Map
        ? (data['message'] ?? 'wait_confirmation'.tr)
        : 'wait_confirmation'.tr;

    if (data is Map && data['remainingMinutes'] != null) {
      msg = '$msg (${data['remainingMinutes']} ${"minutes".tr})';
    }

    // فشل الانتقال إلى online → لا نُبقي الإشعار الدائم والإرسال يعملان
    if (wasGoingOnline && Get.isRegistered<LocationService>()) {
      Get.find<LocationService>().setOnlineMode(false);
    }

    // إعادة المزامنة مع السيرفر حتى يعود AuthController.isOnline (والمؤشر)
    // إلى القيمة المؤكدة بدل أي تحديث متفائل في الشاشة.
    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().fetchDriverData();
    }

    Get.snackbar(
      'alert'.tr,
      msg,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  void _handleNewOrder(dynamic data) {
    log('🚀 Order Signal Received: $data');

    // لا نُقاطع السائق إذا كان داخل طلب جارٍ أو أمام طلب آخر
    const busyRoutes = {
      '/new-order',
      '/details-order',
      '/pick-up-confirmation',
      '/delivery-map',
    };
    if (busyRoutes.contains(Get.currentRoute)) return;

    final orderData =
        data is Map && data.containsKey('order') ? data['order'] : data;
    if (orderData == null) return;

    Get.toNamed('/new-order', arguments: orderData);
  }

  // --- الدوال التنفيذية (Emitters) ---

  void goOnline() => socket?.emit('driver:goOnline');

  void goOffline() => socket?.emit('driver:goOffline');

  void updateLocation(double lat, double lng) {
    socket?.emit('driver:updateLocation', {'lat': lat, 'lng': lng});
  }

  /// يُرجع false إن كان السوكيت مقطوعاً، بلا إرسال.
  ///
  /// لا نترك الردّ في `sendBuffer` الخاص بـ socket_io_client: المكتبة
  /// تُخزّن كل emit يقع أثناء الانقطاع وتُفرّغه عند عودة الاتصال، فيصل
  /// رفض قديم في نفس لحظة إعادة السيرفر إرسالَ العرض المعلّق (B9) —
  /// فيسحب السائق من `pendingDriverIds` ويُغلق شاشة العرض في وجهه
  /// برسالة «تم رفض الطلب» وهو لم يرفض شيئاً.
  bool respondToOrder(String orderId, String response) {
    if (!isConnected) return false;
    socket!.emit(
      'order:driverResponse',
      {'orderId': orderId, 'response': response},
    );
    return true;
  }

  void startDelivery(String orderId) {
    socket?.emit('order:startDelivery', {'orderId': orderId});
  }

  void completeDelivery(String orderId) {
    socket?.emit('order:delivered', {'orderId': orderId});
  }

  void _teardownSocket() {
    if (socket == null) return;
    socket!.clearListeners();
    socket!.dispose();
    socket = null;
  }

  void disconnect() {
    _teardownSocket();
    connected.value = false;
    _authRejected = false;
    _resetLocationErrorState();
    // لا نُغلق _orderStatusController هنا لأن SocketService مُسجّل permanent؛
    // إغلاقه يمنع إعادة استخدامه عند تسجيل دخول جديد في نفس جلسة التطبيق.
    // يُعاد إنشاؤه تلقائياً في connect() إذا كان مُغلقاً.
    log('📡 Socket disconnected and cleared manually');
  }
}
