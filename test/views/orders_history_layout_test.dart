import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:delivery_app/core/localization/message.dart';
import 'package:delivery_app/features/orders/presentation/controllers/orders_history_controller.dart';
import 'package:delivery_app/features/orders/presentation/views/orders_history_screen.dart';
import '../helpers/test_helpers.dart';

/// تخطيط بطاقة الطلب في سجل الطلبات.
///
/// صف التاريخ + المبلغين كان بلا قيد عرض والـ Spacer لا ينكمش، فيطفح مع
/// المبالغ السورية الطويلة (45000.00 ل.س + 1000.00 ل.س).
Map<String, dynamic> historyRow({
  dynamic total = 45000,
  dynamic earning = 1000,
  dynamic createdAt = '2026-09-01T15:45:00.000Z',
}) =>
    {
      '_id': 'o1',
      'orderNumber': 'N-1',
      'orderStatus': 'delivered',
      'driverPaymentStatus': 'pending',
      'paymentMethod': 'cash',
      'createdAt': createdAt,
      'totalPrice': total,
      // باك v4.2: هذا الحقل صار يحمل أجر السائق الحقيقي في هذا الراوت
      'deliveryFee': earning,
      'restaurant': {'name': 'مطعم الاختبار'},
      'customer': {'name': 'زبون الاختبار'},
      'deliveryAddress': 'دمشق، شارع الحمرا، بناء رقم 12',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mockPathProvider();

  setUp(() {
    setUpGetTestMode();
    // OrdersHistoryController.onInit يُطلق طلباً حقيقياً — بدون تمويهه
    // يبقى مؤقّت الاتصال معلّقاً فيفشل الاختبار بـ "A Timer is still pending"
    mockDioGet('orders-history', {
      'success': true,
      'totalOrdersCount': 0,
      'today': {'ordersCount': 0, 'earnings': 0},
      // ليست const: المتحكّم يُسندها مباشرة لـ RxList، والقائمة الثابتة
      // غير قابلة للتعديل فيفشل assignAll لاحقاً
      'orders': <Map<String, dynamic>>[],
    });
  });

  tearDown(() {
    resetDioInterceptors();
    tearDownGetTestMode();
  });

  Future<void> pumpHistory(
    WidgetTester tester,
    List<Map<String, dynamic>> orders, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GetMaterialApp(
      translations: Messages(),
      locale: const Locale('ar'),
      home: const OrdersHistoryScreen(),
    ));

    // onInit يُطلق طلب Dio، وDio يُنشئ مؤقّت مهلة. نُقدّم الساعة الوهمية
    // ليكتمل الطلب المموّه ويُلغى مؤقّته، وإلا فشل الاختبار بـ
    // "A Timer is still pending".
    await tester.pump(const Duration(seconds: 1));

    final c = Get.find<OrdersHistoryController>();
    c.isLoading.value = false;
    c.todayEarnings.value = 5000;
    c.orders.assignAll(orders);
    await tester.pump();
  }

  group('OrdersHistoryScreen — تخطيط بطاقة الطلب', () {
    testWidgets('مبالغ سورية على هاتف ضيّق (360) لا تطفح', (tester) async {
      await pumpHistory(tester, [historyRow()], size: const Size(360, 800));

      expect(find.textContaining('1000.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('مبلغ ضخم على أضيق جهاز (320) لا يطفح', (tester) async {
      await pumpHistory(tester, [historyRow(total: 9999999, earning: 123456)],
          size: const Size(320, 700));

      expect(tester.takeException(), isNull);
    });

    testWidgets('createdAt مفقود لا يُسقط القائمة', (tester) async {
      // DateTime.parse غير المحمي داخل ListView.builder كان يرمي استثناءً
      await pumpHistory(tester, [historyRow(createdAt: null)],
          size: const Size(360, 800));

      expect(find.text('—'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('مبلغ نصّي يُعرض مُنسَّقاً لا خاماً', (tester) async {
      await pumpHistory(tester, [historyRow(earning: '1000.5')],
          size: const Size(360, 800));

      expect(find.textContaining('1000.50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
