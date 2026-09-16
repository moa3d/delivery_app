import 'dart:math' as math;

/// أدوات جغرافية مساعدة — حساب المسافات بين إحداثيات GPS.
///
/// الباك حالياً لا يرسل المسافات الجاهزة في عرض الطلب الجديد
/// (order:driverRequest يحمل الإحداثيات فقط)، لذا نحسبها محلياً.
class GeoUtils {
  GeoUtils._();

  /// نصف قطر الأرض بالكيلومتر.
  static const double _earthRadiusKm = 6371.0;

  /// حساب المسافة بين نقطتين بصيغة Haversine.
  ///
  /// [coordsA] و [coordsB] بترتيب GeoJSON القياسي `[lng, lat]`.
  /// يُرجع null إذا كانت أي قيمة مفقودة أو خارج النطاق الجغرافي الصحيح
  /// (نفس فلاتر الباك في driver.service.js) حتى لا نعرض مسافة وهمية.
  static double? distanceKm(List? coordsA, List? coordsB) {
    final a = _validated(coordsA);
    final b = _validated(coordsB);
    if (a == null || b == null) return null;

    return haversineKm(a.$2, a.$1, b.$2, b.$1);
  }

  /// Haversine مباشر بالإحداثيات (lat, lng).
  static double? haversineKm(
    double? lat1,
    double? lng1,
    double? lat2,
    double? lng2,
  ) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return null;
    }
    if (!_isValid(lat1, lng1) || !_isValid(lat2, lng2)) return null;

    // تجاهل نقطة (0,0) — القيمة الافتراضية المخزنة للسائق قبل أول تحديث موقع
    if (_isZeroFix(lat1, lng1) || _isZeroFix(lat2, lng2)) return null;

    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// استخراج وتحقق من زوج [lng, lat] بترتيب GeoJSON.
  static (double, double)? _validated(List? coords) {
    if (coords == null || coords.length < 2) return null;
    final lng = num.tryParse('${coords[0]}')?.toDouble();
    final lat = num.tryParse('${coords[1]}')?.toDouble();
    if (lng == null || lat == null) return null;
    if (!_isValid(lat, lng)) return null;
    return (lng, lat);
  }

  static bool _isValid(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  static bool _isZeroFix(double lat, double lng) => lat == 0 && lng == 0;

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
