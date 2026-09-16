import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// يبني علامات خرائط غوغل رسماً مباشراً على `Canvas`.
///
/// خرائط غوغل تقبل صوراً نقطية (`BitmapDescriptor`) فقط، بينما كانت العلامات
/// في `flutter_map` widgets عادية. الطريق البديل — بناء شجرة widgets خارج
/// الشاشة والتقاطها — يعتمد واجهات داخلية (`RenderObjectToWidgetAdapter`،
/// `ViewConfiguration`) تغيّرت أكثر من مرة بين إصدارات Flutter. الرسم على
/// Canvas واجهة مستقرة ونتيجته حتمية، فاعتمدناه.
///
/// البناء غير متزامن ومكلف نسبياً، لذا تُخزَّن النتائج في [_cache] بمفتاح
/// يصف الشكل — إعادة بناء الشاشة لا تعيد رسم العلامة نفسها.
class MarkerBitmap {
  MarkerBitmap._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// دقة الرسم. العلامة تُرسم بمقاس منطقي مضروب بهذه النسبة ثم تُسلَّم
  /// لغوغل مع `imagePixelRatio` نفسها، فتظهر حادّة على الشاشات عالية الكثافة.
  static const double _pixelRatio = 3.0;

  /// علامة دائرية ملوّنة بأيقونة بيضاء في مركزها — تقابل علامات شاشة التتبّع.
  static Future<BitmapDescriptor> circleIcon({
    required IconData icon,
    required Color color,
    double diameter = 44,
    Color iconColor = Colors.white,
  }) {
    final key = 'circle_${icon.codePoint}_${color.toARGB32()}_$diameter';
    return _build(key, Size(diameter, diameter), (canvas, size) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.width / 2;

      // ظل خفيف يفصل العلامة عن الخريطة تحتها
      canvas.drawCircle(
        center.translate(0, 3 * _pixelRatio),
        radius - 3 * _pixelRatio,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      canvas.drawCircle(
        center,
        radius - 4 * _pixelRatio,
        Paint()..color = color,
      );

      _paintIcon(
        canvas,
        icon: icon,
        color: iconColor,
        fontSize: 24 * _pixelRatio,
        center: center,
      );
    });
  }

  /// علامة بأيقونة فوق شارة نصية — تقابل علامات تطبيق السائق ذات التسمية.
  static Future<BitmapDescriptor> labeledPin({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    final key = 'pin_${icon.codePoint}_${color.toARGB32()}_$label';
    return _build(key, const Size(120, 68), (canvas, size) {
      final iconSize = 30.0 * _pixelRatio;

      _paintIcon(
        canvas,
        icon: icon,
        color: color,
        fontSize: iconSize,
        center: Offset(size.width / 2, iconSize / 2 + 2 * _pixelRatio),
      );

      final textPainter = _text(
        label,
        TextStyle(
          color: Colors.white,
          fontSize: 11 * _pixelRatio,
          fontWeight: FontWeight.bold,
        ),
      );

      final padH = 8 * _pixelRatio;
      final padV = 4 * _pixelRatio;
      final chipWidth = textPainter.width + padH * 2;
      final chipHeight = textPainter.height + padV * 2;
      final chipLeft = (size.width - chipWidth) / 2;
      final chipTop = iconSize + 4 * _pixelRatio;

      final chipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(chipLeft, chipTop, chipWidth, chipHeight),
        Radius.circular(6 * _pixelRatio),
      );

      canvas.drawRRect(
        chipRect.shift(Offset(0, 2 * _pixelRatio)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawRRect(chipRect, Paint()..color = color);

      textPainter.paint(canvas, Offset(chipLeft + padH, chipTop + padV));
    });
  }

  /// يرسم أيقونة Material كمحرف نصي من خطّها — الطريقة المستقرة الوحيدة
  /// لرسم `IconData` على Canvas بلا شجرة widgets.
  static void _paintIcon(
    Canvas canvas, {
    required IconData icon,
    required Color color,
    required double fontSize,
    required Offset center,
  }) {
    final painter = _text(
      String.fromCharCode(icon.codePoint),
      TextStyle(
        fontSize: fontSize,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  static TextPainter _text(String value, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static Future<BitmapDescriptor> _build(
    String cacheKey,
    Size logicalSize,
    void Function(Canvas canvas, Size size) paint,
  ) async {
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final size = Size(
      logicalSize.width * _pixelRatio,
      logicalSize.height * _pixelRatio,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas, size);

    final image = await recorder.endRecording().toImage(
          size.width.ceil(),
          size.height.ceil(),
        );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (bytes == null) return BitmapDescriptor.defaultMarker;

    final descriptor = BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      imagePixelRatio: _pixelRatio,
    );
    _cache[cacheKey] = descriptor;
    return descriptor;
  }
}
