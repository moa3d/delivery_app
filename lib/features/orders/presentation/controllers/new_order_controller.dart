import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:delivery_app/data/services/socket_service.dart';

/// متحكّم شاشة طلب التوصيل الجديد.
///
/// كان العدّاد التنازلي يعيش داخل الـ State ولا يُلغى عند الضغط على "قبول"،
/// فإذا تأخّر ردّ السيرفر ثانيتين بعد الثانية الأخيرة كان العدّاد يُطلق
/// `declineOrder` → يُرسل "rejected" للسيرفر ويُغلق نافذة التحميل بينما
/// القبول لا يزال في الطريق. الآن العدّاد والقرار في مكان واحد محميّ بـ
/// [_settled] فلا يمكن أن يقع قراران على نفس الطلب.
class NewOrderController extends GetxController {
  final SocketService _socketService = Get.find<SocketService>();

  /// بانتظار ردّ السيرفر على القبول
  final isProcessing = false.obs;

  /// الثواني المتبقية لعرضها في الشارة
  final timeLeft = 0.obs;

  Timer? _countdown;
  Timer? _acceptTimeout;

  String? _orderId;

  /// تم اتخاذ قرار نهائي بشأن هذا الطلب (قبول أو رفض أو انتهاء مهلة)
  bool _settled = false;

  /// مهلة انتظار ردّ السيرفر — أطول من السابق (10ث) لأن استضافة Render
  /// قد تستيقظ من السبات ببطء.
  static const Duration _serverReplyTimeout = Duration(seconds: 20);

  /// هامش أمان: ننهي العدّ قبل السيرفر بثانيتين لتفادي حالة حدّية
  static const int _safetyMarginSeconds = 2;

  /// تُستدعى من الشاشة عند الفتح.
  void startRequest({required String orderId, required int timeoutSeconds}) {
    _orderId = orderId;
    _settled = false;
    isProcessing.value = false;

    final seconds = (timeoutSeconds - _safetyMarginSeconds);
    timeLeft.value = seconds > 0 ? seconds : 0;

    _countdown?.cancel();
    if (timeLeft.value == 0) {
      _expire();
      return;
    }

    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_settled) return;
      if (timeLeft.value > 1) {
        timeLeft.value--;
      } else {
        timeLeft.value = 0;
        _expire();
      }
    });
  }

  void acceptOrder() {
    if (_settled || isProcessing.value) return;
    final id = _orderId;
    if (id == null || id.isEmpty) return;

    // السوكيت مقطوع: لا نُقفل القرار ولا نُلغي العدّاد، فيبقى العرض قائماً
    // ليحاول السائق ثانية فور عودة الشبكة. والقبول المُرسل الآن سيُخزَّن
    // ويصل متأخراً بلا فائدة (راجع respondToOrder).
    if (!_socketService.isConnected) {
      Get.snackbar(
        'alert'.tr,
        'connection_error'.tr,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    // ⬅️ الإصلاح الجوهري: يُقفل القرار ويُلغى العدّاد قبل أي شيء آخر،
    // فلا يستطيع العدّاد إرسال "rejected" بعد هذه اللحظة.
    _settled = true;
    _countdown?.cancel();
    _countdown = null;

    isProcessing.value = true;
    _socketService.respondToOrder(id, 'accepted');

    Get.dialog(
      const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B44)),
        ),
      ),
      barrierDismissible: false,
    );

    _acceptTimeout = Timer(_serverReplyTimeout, () {
      if (!isProcessing.value) return;

      isProcessing.value = false;
      _closeDialog();

      // لا نُرسل "rejected" هنا: ربما وصل القبول للسيرفر ولم يصلنا الردّ.
      // نُعيد السائق للشاشة الرئيسية ونترك السيرفر يحسم الأمر.
      Get.snackbar(
        'alert'.tr,
        'wait_timeout'.tr,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      _leaveRequestScreen();
    });
  }

  void declineOrder() {
    if (_settled) return;
    _settled = true;
    _countdown?.cancel();
    _countdown = null;

    final id = _orderId;
    if (id != null && id.isNotEmpty) {
      _socketService.respondToOrder(id, 'rejected');
    }
    _leaveRequestScreen();
  }

  /// انتهاء المهلة دون تفاعل من السائق
  void _expire() {
    if (_settled) return;
    _settled = true;
    _countdown?.cancel();
    _countdown = null;

    final id = _orderId;
    if (id != null && id.isNotEmpty) {
      _socketService.respondToOrder(id, 'rejected');
    }
    _leaveRequestScreen();
  }

  /// يستدعيها SocketService عند وصول `order:driverRequest:accepted`
  void onServerAccepted() {
    _acceptTimeout?.cancel();
    _acceptTimeout = null;
    isProcessing.value = false;
    _closeDialog();
  }

  /// يستدعيها SocketService عند `expired` أو `cashLimit` أو `order:error`
  void onRequestClosed() {
    _settled = true;
    _countdown?.cancel();
    _countdown = null;
    _acceptTimeout?.cancel();
    _acceptTimeout = null;
    isProcessing.value = false;
    _closeDialog();
  }

  void _closeDialog() {
    // آمن: _settled يمنع استدعاء this بعد أن يُغلق حوار آخر.
    // onRequestClosed() تُلغي _acceptTimeout قبل استدعاء _closeDialog(),
    // فلا يمكن أن يتزامن إغلاق حوارنا مع فتح حوار آخر (مثل cashLimit).
    if (Get.isDialogOpen ?? false) Get.back();
  }

  void _leaveRequestScreen() {
    _closeDialog();
    if (Get.currentRoute == '/new-order') Get.back();
  }

  @override
  void onClose() {
    _countdown?.cancel();
    _acceptTimeout?.cancel();
    super.onClose();
  }
}
