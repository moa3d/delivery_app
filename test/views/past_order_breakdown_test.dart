import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:delivery_app/features/orders/presentation/controllers/past_order_details_controller.dart';
import 'package:delivery_app/features/orders/presentation/views/past_order_details_screen.dart';
import '../helpers/test_helpers.dart';

/// تفصيل أجر السائق في شاشة الطلب السابق.
///
/// باك v4.2 صار يرسل `financialBreakdown.deliveryFeeEarning` في **كل**
/// الحالات، وحقول تسوية الكاش وحدها مشروطة بـ `isCashOrder`. الشاشة كانت
/// تخفي البطاقة كاملةً لغير الكاش، فالسائق الألماني لا يرى أجره إطلاقاً.
/// راجع BACKEND_TASK_driver_offer_data.md القسم 7-ب.
Map<String, dynamic> cashOrder() => {
      'orderNumber': 'N-1',
      'orderStatus': 'delivered',
      'paymentMethod': 'cash',
      'createdAt': '2026-09-01T10:00:00.000Z',
      'deliveredByDriverAt': '2026-09-01T10:45:00.000Z',
      'restaurant': {'name': 'مطعم', 'address': 'عنوان'},
      'customer': {'name': 'زبون'},
      'deliveryAddress': {'fullAddress': 'عنوان التوصيل'},
      'items': const [],
      'pricing': {
        'itemsPrice': 44000,
        'deliveryFee': 1000,
        'taxPrice': 0,
        'totalPrice': 45000,
      },
      'financialBreakdown': {
        'isCashOrder': true,
        'deliveryFeeEarning': 1000,
        'amountCollectedFromCustomer': 45000,
        'mealPriceWithTax': 44000,
        'netEffectOnBalance': 1000,
      },
    };

Map<String, dynamic> cardOrder() => {
      'orderNumber': 'N-2',
      'orderStatus': 'delivered',
      'paymentMethod': 'card',
      'createdAt': '2026-09-01T10:00:00.000Z',
      'deliveredByDriverAt': '2026-09-01T10:45:00.000Z',
      'restaurant': {'name': 'Restaurant', 'address': 'Adresse'},
      'customer': {'name': 'Kunde'},
      'deliveryAddress': {'fullAddress': 'Lieferadresse'},
      'items': const [],
      'pricing': {
        'itemsPrice': 20,
        'deliveryFee': 3,
        'taxPrice': 1,
        'totalPrice': 24,
      },
      // الشكل الجديد لطلب البطاقة — حقل الأجر وحده، بلا حقول تسوية الكاش
      'financialBreakdown': {
        'isCashOrder': false,
        'deliveryFeeEarning': 3,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mockPathProvider();

  setUp(setUpGetTestMode);
  tearDown(() {
    resetDioInterceptors();
    tearDownGetTestMode();
  });

  Future<void> pumpWith(
      WidgetTester tester, Map<String, dynamic> order) async {
    await tester.pumpWidget(GetMaterialApp(
      home: const PastOrderDetailsScreen(),
    ));
    // الشاشة تُنشئ المتحكّم في build — نملأه بعدها ثم نُعيد الرسم
    final c = Get.find<PastOrderDetailsController>();
    c.isLoading.value = false;
    c.orderDetails.value = order;
    await tester.pump();
  }

  group('PastOrderDetailsScreen — تفصيل الأجر', () {
    testWidgets('طلب بطاقة: الأجر يظهر رغم isCashOrder=false', (tester) async {
      await pumpWith(tester, cardOrder());

      // البطاقة ظاهرة وفيها صف الأجر
      expect(find.text('complete_breakdown'), findsOneWidget);
      expect(find.text('delivery_fee_earning'), findsOneWidget);
      expect(find.textContaining('+3.00'), findsOneWidget);
    });

    testWidgets('طلب بطاقة: حقول تسوية الكاش مخفية', (tester) async {
      await pumpWith(tester, cardOrder());

      expect(find.text('total_collected'), findsNothing);
      expect(find.text('deducted_from_rest'), findsNothing);
      expect(find.text('net_effect'), findsNothing);
    });

    testWidgets('طلب نقدي: كل الحقول تبقى كما كانت', (tester) async {
      await pumpWith(tester, cashOrder());

      expect(find.text('delivery_fee_earning'), findsOneWidget);
      expect(find.text('total_collected'), findsOneWidget);
      expect(find.text('deducted_from_rest'), findsOneWidget);
      expect(find.text('net_effect'), findsOneWidget);
      expect(find.textContaining('+1000.00'), findsWidgets);
    });

    testWidgets('بلا financialBreakdown إطلاقاً: البطاقة تختفي', (tester) async {
      final order = cardOrder()..remove('financialBreakdown');
      await pumpWith(tester, order);

      expect(find.text('complete_breakdown'), findsNothing);
    });

    testWidgets('مبلغ نصّي لا يُسقط الشاشة', (tester) async {
      // (x ?? 0).toStringAsFixed(2) على dynamic كان يرمي NoSuchMethodError
      final order = cardOrder();
      order['financialBreakdown'] = {
        'isCashOrder': false,
        'deliveryFeeEarning': '3.5',
      };
      await pumpWith(tester, order);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('+3.50'), findsOneWidget);
    });
  });
}
