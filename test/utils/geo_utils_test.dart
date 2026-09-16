import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils.distanceKm', () {
    test('يحسب مسافة معروفة بشكل صحيح', () {
      // دمشق ← حلب ≈ 310 كم
      final d = GeoUtils.distanceKm(
        [36.2021, 33.5138], // حلب [lng, lat]
        [37.1000, 36.2000],
      );
      expect(d, isNotNull);
      expect(d!, greaterThan(280));
      expect(d, lessThan(340));
    });

    test('المسافة بين نفس النقطة = صفر', () {
      final d = GeoUtils.distanceKm([36.2, 33.5], [36.2, 33.5]);
      expect(d, 0.0);
    });

    test('يرجع null عند نقص الإحداثيات', () {
      expect(GeoUtils.distanceKm(null, [36.2, 33.5]), isNull);
      expect(GeoUtils.distanceKm([36.2], [36.2, 33.5]), isNull);
      expect(GeoUtils.distanceKm([], []), isNull);
    });

    test('يرجع null عند قيم غير رقمية', () {
      expect(GeoUtils.distanceKm(['abc', 'x'], [36.2, 33.5]), isNull);
    });

    test('يرجع null عند إحداثيات خارج النطاق الجغرافي', () {
      expect(GeoUtils.distanceKm([200, 33.5], [36.2, 33.5]), isNull);
      expect(GeoUtils.distanceKm([36.2, 95], [36.2, 33.5]), isNull);
    });

    test(
        'يرجع null عند الإصلاح الافتراضي (0,0) — موقع السائق قبل أول تحديث',
        () {
      expect(GeoUtils.distanceKm([0, 0], [36.2, 33.5]), isNull);
    });
  });

  group('GeoUtils.haversineKm', () {
    test('يقبل قيم String القابلة للتحويل عبر distanceKm فقط', () {
      // haversineKm المباشر يتعامل مع double|null فقط
      expect(GeoUtils.haversineKm(null, null, null, null), isNull);
    });

    test('مسافة قصيرة داخل مدينة واحدة معقولة (< 5 كم)', () {
      final d = GeoUtils.distanceKm(
        [36.2765, 33.5101], // وسط دمشق تقريباً
        [36.3000, 33.5200],
      );
      expect(d, isNotNull);
      expect(d!, greaterThan(0));
      expect(d, lessThan(5));
    });
  });
}
