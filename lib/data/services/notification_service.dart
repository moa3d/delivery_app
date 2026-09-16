import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../api_client/dio_client.dart';
import 'notification_store.dart';
import 'socket_service.dart';

class NotificationService extends GetxService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final _dio = DioClient().instance;
  final _storage = GetStorage();
  final _local = FlutterLocalNotificationsPlugin();

  /// قناة أندرويد الوحيدة — عالية الأولوية لأن عرض الطلب صالح 30 ثانية فقط
  static const _channel = AndroidNotificationChannel(
    'nomnow_driver_orders',
    'Order alerts',
    description: 'New delivery requests and order updates',
    importance: Importance.high,
  );

  Future<NotificationService> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    await _initLocalNotifications();

    await fetchAndSendToken();
    _fcm.onTokenRefresh.listen((newToken) {
      _sendTokenToServer(newToken);
    });

    _setupInteractedMessages();

    // في المقدمة لا يعرض النظام إشعار FCM تلقائياً — كان هذا المسار
    // يكتفي بـ log، فلا يرى السائق شيئاً والتطبيق مفتوح.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('🔔 [FCM Foreground] Received:');
      _printFullMessage(message);
      _record(message);
      _showLocal(message);
    });

    return this;
  }

  Future<void> _initLocalNotifications() async {
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) _openApp();
        },
      );

      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    } catch (e) {
      // جهاز بلا دعم — الإشعارات الخلفية تبقى تعمل عبر النظام
      log('⚠️ Local notifications unavailable: $e');
    }
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    try {
      await _local.show(
        id: message.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data['orderId']?.toString() ?? message.data['type']?.toString(),
      );
    } catch (e) {
      log('⚠️ show local notification failed: $e');
    }
  }

  /// يحفظ الإشعار في السجل المحلي لتعرضه شاشة الإشعارات
  void _record(RemoteMessage message) {
    if (!Get.isRegistered<NotificationStore>()) return;
    final data = message.data;
    final id = message.messageId ??
        '${data['orderId'] ?? ''}-${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

    Get.find<NotificationStore>().add(AppNotification(
      id: id,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      type: data['type']?.toString() ?? 'custom',
      orderId: data['orderId']?.toString(),
      receivedAt: message.sentTime ?? DateTime.now(),
    ));
  }

  Future<void> fetchAndSendToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      _sendTokenToServer(token);
    }
  }

  void _sendTokenToServer(String token) async {
    try {
      final savedToken = _storage.read('fcmToken');
      if (savedToken == token) return;

      await _dio.patch('api/driver/fcm-token', data: {"fcmToken": token});
      await _storage.write('fcmToken', token);
      log('✅ FCM Token sent to server');
    } catch (e) {
      log('❌ FCM Token update failed: $e');
    }
  }

  void _setupInteractedMessages() async {
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      log('📱 [FCM Terminated] App opened via notification:');
      _handleMessage(initialMessage);
    }
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      log('🔙 [FCM Background] Notification clicked:');
      _handleMessage(message);
    });
  }

  void _handleMessage(RemoteMessage message) {
    _printFullMessage(message);
    _record(message);
    _openApp();
  }

  /// حمولة FCM لطلب جديد تحوي `orderId` و`orderNumber` فقط — بلا المطعم
  /// والأصناف والسعر التي تحتاجها شاشة `/new-order`، ولا يمكن جلبها لأن
  /// `getOrderDetails` يشترط أن يكون الطلب مُسنداً لهذا السائق أصلاً.
  /// لذلك نكتفي بإيقاظ الاتصال: إن كان العرض ما زال قائماً يصل كاملاً عبر
  /// `order:driverRequest` من السوكيت.
  void _openApp() {
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().ensureConnected();
    }
  }

  void _printFullMessage(RemoteMessage message) {
    log('---------------- FCM PAYLOAD START ----------------');
    log('Title: ${message.notification?.title}');
    log('Body: ${message.notification?.body}');
    log('Data (Map): ${message.data}');
    log('----------------- FCM PAYLOAD END -----------------');
  }
}
