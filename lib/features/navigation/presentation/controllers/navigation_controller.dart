import 'package:get/get.dart';

/// التحكم في التنقل بين أقسام التطبيق الأربعة
class NavigationController extends GetxController {
  var selectedIndex = 0.obs;

  /// تغيير الصفحة الحالية وتحديث الواجهة
  void changePage(int index) {
    selectedIndex.value = index;
  }
}