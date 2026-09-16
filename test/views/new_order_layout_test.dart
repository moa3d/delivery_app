import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
// LatLng تأتي الآن من google_maps_flutter بعد الانتقال إليها من flutter_map
// (latlong2 لم تعد ضمن الاعتماديات، وكان هذا الاستيراد يكسر الاختبار).
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:delivery_app/core/localization/message.dart';
import 'package:delivery_app/data/services/location_service.dart';
import 'package:delivery_app/data/services/socket_service.dart';
import 'package:delivery_app/features/orders/presentation/controllers/new_order_controller.dart';
import 'package:delivery_app/features/orders/presentation/views/new_order_request_screen.dart';
import '../helpers/test_helpers.dart';

/// تخطيط شاشة عرض الطلب مع مبالغ حقيقية.
///
/// طفح صندوق «ربحك المتوقع» فور وصول `driverEarning` من باك v4.2: العمود
/// داخل Row كان بلا Expanded — مع "—" كان النص قصيراً فلم تظهر المشكلة،
/// ومع "1000.00 ل.س" بحجم 28 عريض تجاوز عرض الصندوق.
Map<String, dynamic> offer({dynamic earning}) => {
      'orderId': 'o1',
      'orderNumber': 'N-1',
      'restaurantName': 'مطعم الاختبار',
      'restaurantLocation': {
        'type': 'Point',
        'coordinates': [36.2765, 33.5138],
      },
      'deliveryAddress': {
        'fullAddress': 'عنوان التوصيل',
        'location': {
          'type': 'Point',
          'coordinates': [36.2865, 33.5238],
        },
      },
      'totalPrice': 45000,
      'items': const [],
      'timeoutSeconds': 30,
      'driverEarning': ?earning,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mockPathProvider();

  setUp(() {
    setUpGetTestMode();
    // NewOrderController يطلب SocketService في المُنشئ
    Get.put<SocketService>(MockSocketService());
    // الشاشة تقرأ currentLocation داخل Obx؛ بدون تسجيل الخدمة لا يُقرأ أي
    // متغيّر تفاعلي فيرمي GetX "improper use of a GetX".
    // init() لا تُستدعى هنا — المُنشئ وحده لا يلمس قنوات النظام.
    Get.put(LocationService()).currentLocation.value =
        const LatLng(33.5138, 36.2765);
  });

  tearDown(() {
    if (Get.isRegistered<NewOrderController>()) {
      // يُلغي العدّاد التنازلي، وإلا فشل الاختبار بـ "A Timer is still pending"
      Get.find<NewOrderController>().onRequestClosed();
    }
    tearDownGetTestMode();
  });

  /// يرسم شاشة العرض بحمولة حقيقية على عرض جهاز محدَّد
  Future<void> pumpOffer(
    WidgetTester tester,
    Map<String, dynamic> args, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GetMaterialApp(
      // ترجمات حقيقية: بدونها تُعرض أسماء المفاتيح الخام («decline_btn» بدل
      // «رفض») فتظهر حالات طفحان وهمية لا وجود لها في التطبيق
      translations: Messages(),
      locale: const Locale('ar'),
      initialRoute: '/home',
      getPages: [
        GetPage(name: '/home', page: () => const SizedBox.shrink()),
        GetPage(
            name: '/new-order', page: () => const NewOrderRequestScreen()),
      ],
    ));

    Get.toNamed('/new-order', arguments: args);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('NewOrderRequestScreen — تخطيط صندوق الأجر', () {
    testWidgets('مبلغ سوري على هاتف ضيّق (360) لا يطفح', (tester) async {
      await pumpOffer(tester, offer(earning: 1000),
          size: const Size(360, 800));

      expect(find.textContaining('1000.00'), findsOneWidget);
      // RenderFlex overflowed يُبلَّغ عنه كاستثناء في بيئة الاختبار
      expect(tester.takeException(), isNull);
    });

    testWidgets('مبلغ ضخم على أضيق جهاز (320) لا يطفح', (tester) async {
      await pumpOffer(tester, offer(earning: 1234567.89),
          size: const Size(320, 700));

      expect(tester.takeException(), isNull);
    });

    testWidgets('بلا أجر (سلوك ما قبل v4.2) لا يطفح', (tester) async {
      await pumpOffer(tester, offer(), size: const Size(360, 800));

      expect(find.text('—'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
