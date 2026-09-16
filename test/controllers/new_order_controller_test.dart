import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:delivery_app/data/services/socket_service.dart';
import 'package:delivery_app/features/orders/presentation/controllers/new_order_controller.dart';
import '../helpers/test_helpers.dart';

void main() {
  late MockSocketService socket;

  setUp(() {
    setUpGetTestMode();
    socket = MockSocketService();
    // الحالة الطبيعية: سوكيت متصل. الاختبارات التي تعني الانقطاع تُطفئه.
    socket.connected.value = true;
    Get.put<SocketService>(socket);
  });

  tearDown(() {
    tearDownGetTestMode();
  });

  group('NewOrderController', () {
    testWidgets('initial isProcessing is false', (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.onClose();
      expect(controller.isProcessing.value, false);
    });

    testWidgets('acceptOrder sets isProcessing true for valid orderId',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.startRequest(orderId: 'ord_1', timeoutSeconds: 30);
      controller.acceptOrder();
      controller.onClose();
      expect(controller.isProcessing.value, true);
    });

    testWidgets('acceptOrder does nothing when no request was started',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.acceptOrder();
      controller.onClose();
      expect(controller.isProcessing.value, false);
    });

    testWidgets('acceptOrder does nothing for empty orderId',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.startRequest(orderId: '', timeoutSeconds: 30);
      controller.acceptOrder();
      controller.onClose();
      expect(controller.isProcessing.value, false);
    });

    testWidgets('acceptOrder ignores second call while processing',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.startRequest(orderId: 'ord_1', timeoutSeconds: 30);
      controller.acceptOrder();
      controller.acceptOrder();
      controller.onClose();
      expect(controller.isProcessing.value, true);
    });

    testWidgets('declineOrder settles the request without processing',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.startRequest(orderId: 'ord_1', timeoutSeconds: 30);
      controller.declineOrder();
      controller.onClose();
      expect(controller.isProcessing.value, false);
    });

    testWidgets('declineOrder is a no-op when no request was started',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.declineOrder();
      controller.onClose();
      expect(controller.isProcessing.value, false);
    });

    testWidgets('acceptOrder after decline stays settled',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.startRequest(orderId: 'ord_1', timeoutSeconds: 30);
      controller.declineOrder();
      controller.acceptOrder();
      controller.onClose();
      expect(controller.isProcessing.value, false);
    });

    testWidgets('startRequest subtracts the safety margin from the countdown',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.startRequest(orderId: 'ord_1', timeoutSeconds: 30);
      controller.onClose();
      expect(controller.timeLeft.value, 28);
    });

    // ── الانقطاع أثناء العرض (B9) ─────────────────────────────────
    // socket_io_client يُخزّن أي emit أثناء الانقطاع ويُفرّغه عند عودة
    // الاتصال، فيصل الردّ القديم بعد أن يكون السيرفر أعاد إرسال العرض
    // نفسه فيُلغيه. لذلك لا يخرج أي ردّ والسوكيت مقطوع.

    testWidgets('acceptOrder لا يُقفل القرار ولا يُرسل والسوكيت مقطوع',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      socket.connected.value = false;
      final controller = NewOrderController();
      controller.startRequest(orderId: 'ord_1', timeoutSeconds: 30);
      controller.acceptOrder();
      controller.onClose();
      expect(controller.isProcessing.value, false);
      expect(socket.sentResponses, isEmpty);
      // رسالة الانقطاع تترك أنيميشن نشطاً بعد تفكيك الشجرة — نفس معالجة
      // auth_controller_test: نُغلق السناك بار ونُسكّن الشجرة.
      await tester.pump();
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('انتهاء المهلة والسوكيت مقطوع لا يُرسل رفضاً مؤجَّلاً',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      socket.connected.value = false;
      final controller = NewOrderController();
      // مهلة أقصر من هامش الأمان تُطلق _expire فوراً
      controller.startRequest(orderId: 'ord_1', timeoutSeconds: 1);
      controller.onClose();
      expect(socket.sentResponses, isEmpty);
    });

    testWidgets('انتهاء المهلة مع سوكيت متصل يُرسل الرفض كالمعتاد',
        (WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(home: Container()));
      final controller = NewOrderController();
      controller.startRequest(orderId: 'ord_1', timeoutSeconds: 1);
      controller.onClose();
      expect(socket.sentResponses.single['response'], 'rejected');
    });
  });
}
