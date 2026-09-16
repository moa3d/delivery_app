import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import 'package:delivery_app/data/services/socket_service.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:delivery_app/features/orders/presentation/views/order_details_screen.dart';
import '../helpers/test_helpers.dart';

/// C-1: بطاقة «طريقة الدفع» كانت تتجاهل `paymentMethod` وتعرض «اجمع الكاش»
/// لكل طلب — حتى المدفوع أونلاين — فيجمع السائق مبلغاً دفعه الزبون مسبقاً.
Map<String, dynamic> order(String method) => {
      '_id': 'ord_1',
      'orderNumber': 'N-1',
      'orderStatus': 'picked_up',
      'paymentMethod': method,
      'totalPrice': 45000,
      'itemsPrice': 44000,
      'deliveryFee': 1000,
      'items': const [],
      'restaurantId': const {'name': 'مطعم', 'address': 'عنوان'},
      'userId': const {'name': 'زبون'},
      'deliveryAddress': const {'fullAddress': 'عنوان التوصيل'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mockPathProvider();

  setUp(() {
    setUpGetTestMode();
    Get.put<SocketService>(MockSocketService());
    // الشاشة تقرأ العملة والضريبة من AuthController بلا حارس
    Get.put<AuthController>(AuthController());
    // نمنع جلب التفاصيل الكاملة من الشبكة: success=false يُبقي بيانات
    // الـconstructor كما هي، فيبقى الاختبار على البطاقة وحدها.
    mockDioGet('orders/', const {'success': false});
  });

  tearDown(() {
    resetDioInterceptors();
    tearDownGetTestMode();
  });

  Future<void> pump(WidgetTester tester, String method) async {
    await tester.pumpWidget(GetMaterialApp(
      home: OrderDetailsScreen(orderData: order(method)),
    ));
    // طلب Dio المموّه يترك مؤقتاً صفري المدة؛ نُفرغه وإلا فشل الاختبار
    // بـ "A Timer is still pending" عند تفكيك الشجرة.
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('OrderDetailsScreen — بطاقة طريقة الدفع', () {
    testWidgets('طلب نقدي: يطلب التحصيل صراحةً', (tester) async {
      await pump(tester, 'cash');

      expect(find.text('cash_on_delivery'), findsOneWidget);
      expect(find.text('collect_from_customer'), findsOneWidget);
      expect(find.text('no_collection_title'), findsNothing);
    });

    testWidgets('طلب بطاقة: لا يطلب أي تحصيل', (tester) async {
      await pump(tester, 'card');

      expect(find.text('paid_online_title'), findsOneWidget);
      expect(find.text('no_collection_title'), findsOneWidget);
      expect(find.text('collect_from_customer'), findsNothing);
    });

    testWidgets('حالة الأحرف لا تقلب القرار', (tester) async {
      await pump(tester, 'Card');

      expect(find.text('no_collection_title'), findsOneWidget);
      expect(find.text('collect_from_customer'), findsNothing);
    });

    testWidgets('طريقة دفع مجهولة تُعامَل كمدفوعة لا كنقدية', (tester) async {
      await pump(tester, 'stripe');

      expect(find.text('no_collection_title'), findsOneWidget);
    });
  });
}
