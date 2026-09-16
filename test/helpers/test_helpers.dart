import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:delivery_app/data/api_client/dio_client.dart';
import 'package:delivery_app/data/services/socket_service.dart';

class MockSocketService extends GetxService implements SocketService {
  @override
  io.Socket? socket;

  final StreamController<Map<String, dynamic>> _orderStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get orderStatusStream =>
      _orderStatusController.stream;

  @override
  final RxBool connected = false.obs;

  @override
  final RxBool locationPushFailing = false.obs;

  @override
  bool get isConnected => connected.value;

  @override
  void connect() {}

  @override
  void ensureConnected() {}

  /// الردود التي خرجت فعلاً — تتيح للاختبارات تأكيد أن شيئاً لم يُرسل
  /// أثناء الانقطاع بدل الاكتفاء بفحص حالة المتحكم.
  final List<Map<String, String>> sentResponses = [];

  @override
  bool respondToOrder(String orderId, String response) {
    if (!isConnected) return false;
    sentResponses.add({'orderId': orderId, 'response': response});
    return true;
  }

  @override
  void goOnline() {}

  @override
  void goOffline() {}

  @override
  void updateLocation(double lat, double lng) {}

  @override
  void startDelivery(String orderId) {}

  @override
  void completeDelivery(String orderId) {}

  @override
  void disconnect() {
    _orderStatusController.close();
  }
}

/// GetStorage يطلب `getApplicationDocumentsDirectory` من path_provider،
/// وهي قناة أصلية غير متاحة في اختبارات الوحدة — بدون هذا الوهم كان
/// إنشاء أي متحكم يعتمد على GetStorage يرمي MissingPluginException.
void mockPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall call) async => Directory.systemTemp.createTempSync().path,
  );
}

void setUpGetTestMode() {
  // الترتيب مهم: Get.reset() يُصفّر testMode، فلو ضبطناه قبلها يضيع
  // ونحصل على "contextless navigation without a GetMaterialApp".
  Get.reset();
  Get.testMode = true;
}

void tearDownGetTestMode() {
  Get.reset();
}

void mockDioPost(String pathContains, Map<String, dynamic> data, {int statusCode = 200}) {
  DioClient().instance.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'POST' && options.path.contains(pathContains)) {
          handler.resolve(Response(
            requestOptions: options,
            data: data,
            statusCode: statusCode,
          ));
        } else {
          handler.next(options);
        }
      },
    ),
  );
}

void mockDioGet(String pathContains, Map<String, dynamic> data, {int statusCode = 200}) {
  DioClient().instance.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'GET' && options.path.contains(pathContains)) {
          handler.resolve(Response(
            requestOptions: options,
            data: data,
            statusCode: statusCode,
          ));
        } else {
          handler.next(options);
        }
      },
    ),
  );
}

void mockDioPatch(String pathContains, Map<String, dynamic> data, {int statusCode = 200}) {
  DioClient().instance.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'PATCH' && options.path.contains(pathContains)) {
          handler.resolve(Response(
            requestOptions: options,
            data: data,
            statusCode: statusCode,
          ));
        } else {
          handler.next(options);
        }
      },
    ),
  );
}

void mockDioDelete(String pathContains, Map<String, dynamic> data, {int statusCode = 200}) {
  DioClient().instance.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'DELETE' && options.path.contains(pathContains)) {
          handler.resolve(Response(
            requestOptions: options,
            data: data,
            statusCode: statusCode,
          ));
        } else {
          handler.next(options);
        }
      },
    ),
  );
}

void resetDioInterceptors() {
  DioClient().instance.interceptors.clear();
}
