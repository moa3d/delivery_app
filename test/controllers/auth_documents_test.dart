import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';
import '../helpers/test_helpers.dart';

/// حمولة `GET api/driver/dirver-info` الحقيقية كما يبنيها
/// `driver.controller.js:getDriverInfo` — مصفوفة `documents` وحدها،
/// بلا أي حقول مسطّحة مثل `idImage`. كانت الشاشة تقرأ الحقول المسطّحة
/// فتُظهر المستندات الثلاثة ناقصة إلى الأبد.
Map<String, dynamic> driverInfoPayload(
  List<Map<String, dynamic>> documents, {
  String country = 'SY',
}) =>
    {
      'success': true,
      'driver': {
        '_id': 'drv_1',
        'name': 'سائق تجريبي',
        'status': 'pending',
        'availability': 'offline',
        'country': country,
        'documents': documents,
      },
    };

Map<String, dynamic> doc(
  String type, {
  String status = 'pending',
  String? url = 'https://cdn.example/img.jpg',
  String? rejectionReason,
}) =>
    {
      '_id': 'doc_$type',
      'type': type,
      'status': status,
      'image': url == null ? null : {'url': url, 'public_id': 'p_$type'},
      'rejectionReason': ?rejectionReason,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mockPathProvider();

  setUp(setUpGetTestMode);
  tearDown(() {
    resetDioInterceptors();
    tearDownGetTestMode();
  });

  Future<AuthController> loadWith(List<Map<String, dynamic>> documents) async {
    mockDioGet('dirver-info', driverInfoPayload(documents));
    final controller = AuthController();
    await controller.fetchDriverData();
    return controller;
  }

  group('AuthController — تطبيع documents[]', () {
    test('مستند مرفوع ومعتمد يُقرأ عبر اسم حقل الرفع', () async {
      final c = await loadWith([doc('id', status: 'approved')]);

      expect(c.hasDocument('idImage'), isTrue);
      expect(c.documentStatus('idImage'), 'approved');
      expect(c.documentRejectionReason('idImage'), isNull);
    });

    test('المستند غير المرسل حالته missing', () async {
      final c = await loadWith([doc('id')]);

      expect(c.hasDocument('drivingLicenseImage'), isFalse);
      expect(c.documentStatus('drivingLicenseImage'), 'missing');
    });

    test('مستند بلا صورة يُعتبر ناقصاً وإن كان موجوداً بالمصفوفة', () async {
      final c = await loadWith([doc('vehicle_registration', url: null)]);

      expect(c.hasDocument('vehicleRegistrationImage'), isFalse);
      expect(c.documentStatus('vehicleRegistrationImage'), 'missing');
    });

    test('سبب الرفض يظهر للمستند المرفوض فقط', () async {
      final c = await loadWith([
        doc('id', status: 'rejected', rejectionReason: 'الصورة غير واضحة'),
        doc('driving_license', status: 'approved'),
      ]);

      expect(c.documentStatus('idImage'), 'rejected');
      expect(c.documentRejectionReason('idImage'), 'الصورة غير واضحة');
      // لا سبب رفض لمستند معتمد
      expect(c.documentRejectionReason('drivingLicenseImage'), isNull);
    });

    test('رفض واحد يكفي لإبقاء allDocumentsSubmitted = false', () async {
      final c = await loadWith([
        doc('id', status: 'approved'),
        doc('driving_license', status: 'pending'),
        doc('vehicle_registration',
            status: 'rejected', rejectionReason: 'منتهية'),
      ]);

      expect(c.allDocumentsSubmitted, isFalse);
    });

    test('كل المستندات مرفوعة وغير مرفوضة → allDocumentsSubmitted', () async {
      final c = await loadWith([
        doc('id', status: 'approved'),
        doc('driving_license', status: 'pending'),
        doc('vehicle_registration', status: 'approved'),
      ]);

      expect(c.allDocumentsSubmitted, isTrue);
    });

    test('مصفوفة documents مفقودة لا تُسقط الشاشة', () async {
      mockDioGet('dirver-info', {
        'success': true,
        'driver': {'_id': 'drv_1', 'status': 'pending'},
      });
      final c = AuthController();
      await c.fetchDriverData();

      expect(c.documents, isEmpty);
      expect(c.documentStatus('idImage'), 'missing');
      expect(c.allDocumentsSubmitted, isFalse);
    });

    test('مدخل تالف في المصفوفة يُتجاهل بلا استثناء', () async {
      final c = await loadWith([
        doc('id', status: 'approved'),
        {'type': null, 'status': 'approved'},
      ]);

      expect(c.documents.length, 1);
      expect(c.documentStatus('idImage'), 'approved');
    });

    test('الجلب الثاني يستبدل المستندات ولا يُراكمها', () async {
      final c = await loadWith([
        doc('id', status: 'rejected', rejectionReason: 'غير واضحة'),
      ]);
      expect(c.documentStatus('idImage'), 'rejected');

      // بعد إعادة الرفع يعود المستند pending ويختفي سبب الرفض
      resetDioInterceptors();
      mockDioGet('dirver-info', driverInfoPayload([doc('id')]));
      await c.fetchDriverData();

      expect(c.documents.length, 1);
      expect(c.documentStatus('idImage'), 'pending');
      expect(c.documentRejectionReason('idImage'), isNull);
    });
  });

  group('AuthController — رمز العملة', () {
    test('السائق الألماني لا يرى ليرة سورية', () async {
      mockDioGet('dirver-info', driverInfoPayload([], country: 'DE'));
      final c = AuthController();
      await c.fetchDriverData();

      expect(c.currencySymbol, 'currency_eur'.tr);
      expect(c.currencySymbol, isNot('currency_syp'.tr));
    });

    test('السائق السوري يرى الليرة السورية', () async {
      mockDioGet('dirver-info', driverInfoPayload([]));
      final c = AuthController();
      await c.fetchDriverData();

      expect(c.currencySymbol, 'currency_syp'.tr);
    });
  });
}
