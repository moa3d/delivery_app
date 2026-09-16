import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';

/// يمنع الرجوع العرضي (زر AppBar / سحبة النظام) أثناء تدفّق طلب نشط.
///
/// السبب: تطبيقات التوصيل لا تسمح للسائق بمغادرة تدفّق الطلب صدفةً —
/// الباك اند يحمي حالة الطلب من أي انتقال غير قانوني (findOneAndUpdate
/// بشرط الحالة السابقة في driver.socket.js)، لكن الواجهة كانت تسمح
/// بالخروج الكامل من الشاشات الأربع (تفاصيل الطلب، تأكيد الاستلام،
/// خريطة التوصيل، إثبات التسليم) دون أي تحذير.
///
/// هذا الحارس **وقائي فقط** (يمنع الرجوع المتعمّد عبر الواجهة). لا يحمي
/// من إغلاق التطبيق القسري أو تعطّله أو نفاد البطارية — تلك الحالات
/// يعالجها مساراً منفصلاً: fetchActiveOrderOnStartup في auth_controller
/// الذي يُعيد توجيه السائق للشاشة الصحيحة حسب حالة الطلب الفعلية عند
/// إعادة فتح التطبيق. الحلّان متكاملان لا بديلان أحدهما عن الآخر.
class ActiveOrderPopGuard extends StatelessWidget {
  final Widget child;

  const ActiveOrderPopGuard({super.key, required this.child});

  void _confirmLeave(BuildContext context) {
    Get.defaultDialog(
      title: 'active_order_exit_title'.tr,
      middleText: 'active_order_exit_message'.tr,
      textConfirm: 'active_order_exit_confirm'.tr,
      textCancel: 'active_order_exit_cancel'.tr,
      confirmTextColor: Colors.white,
      onConfirm: () {
        // يُغلق الحوار فقط (route منفصل عن الشاشة المحروسة) — لا يتأثر
        // بـ canPop:false الخاص بالـ PopScope أدناه.
        Get.back();
        // مغادرة حقيقية إلى الرئيسية — عملية push/remove لا pop، فلا
        // تمرّ عبر PopScope فتتجنّب أي حلقة تكرار.
        Get.offAllNamed(AppRoutes.mainNavigation);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeave(context);
      },
      child: child,
    );
  }
}
