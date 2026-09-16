import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// متحكم الوضع الليلي/النهاري.
///
/// سابقاً كان التطبيق مثبتاً على ThemeMode.system فقط (يتبع النظام) بلا أي
/// تحكم من المستخدم داخل التطبيق. الآن الاختيار يُحفظ في GetStorage
/// ويُطبَّق فوراً عبر GetMaterialApp المغلّف بـ Obx في main.dart.
class ThemeController extends GetxController {
  final _storage = GetStorage();

  /// مفتاح الحفظ المحلي — قيمه: 'system' | 'light' | 'dark'
  static const String _storageKey = 'theme_mode';

  /// الوضع الحالي — تفاعلي، وقراءته داخل Obx يعيد بناء GetMaterialApp
  final Rx<ThemeMode> themeMode = Rx<ThemeMode>(ThemeMode.system);

  @override
  void onInit() {
    super.onInit();
    themeMode.value = _restore();
  }

  /// استرجاع الوضع المحفوظ مع تراجع آمن إلى وضع النظام عند قيمة غير صالحة
  ThemeMode _restore() {
    final saved = _storage.read<String>(_storageKey);
    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// تغيير الوضع وتطبيقه فوراً وحفظه للجلسات القادمة
  void setMode(ThemeMode mode) {
    themeMode.value = mode;
    _storage.write(_storageKey, _modeToString(mode));
  }

  /// اسم الوضع الحالي مترجماً — لعرضه كوصف تحت عنوان البلاطة في الإعدادات
  String get currentModeLabel {
    switch (themeMode.value) {
      case ThemeMode.light:
        return 'theme_light'.tr;
      case ThemeMode.dark:
        return 'theme_dark'.tr;
      case ThemeMode.system:
        return 'theme_system'.tr;
    }
  }

  static String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
