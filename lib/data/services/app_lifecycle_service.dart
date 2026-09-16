import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/wallet/presentation/controllers/wallet_controller.dart';
import 'location_service.dart';
import 'socket_service.dart';

/// يراقب دورة حياة التطبيق ويُعيد المزامنة عند العودة من الخلفية.
///
/// قبل هذه الخدمة كان السوكيت يتصل مرة واحدة فقط عند الإقلاع أو عند تسجيل
/// الدخول. إذا انقطعت الشبكة أو أوقف النظام الاتصال أثناء وجود التطبيق في
/// الخلفية، كان السائق يعود ليجد نفسه غير متصل دون أي مؤشر — فلا تصله
/// طلبات ولا تحديثات حالة.
class AppLifecycleService extends GetxService with WidgetsBindingObserver {
  static AppLifecycleService get to => Get.find<AppLifecycleService>();

  final _storage = GetStorage();

  DateTime? _lastResumeSync;
  DateTime? _pausedAt;

  /// لا نُعيد المزامنة مع كل رجوع خاطف بين الشاشات
  static const Duration _minSyncGap = Duration(seconds: 5);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  bool get _isLoggedIn => _storage.read('token') != null;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _onResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _pausedAt = DateTime.now();
        // ملاحظة: لا نقطع السوكيت ولا نوقف تتبّع الموقع عمداً — السائق
        // المتصل يجب أن يبقى قابلاً لاستقبال الطلبات والتطبيق مصغّر.
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _onResumed() async {
    if (!_isLoggedIn) return;

    final now = DateTime.now();
    if (_lastResumeSync != null &&
        now.difference(_lastResumeSync!) < _minSyncGap) {
      return;
    }
    _lastResumeSync = now;

    final awayFor = _pausedAt == null
        ? Duration.zero
        : now.difference(_pausedAt!);
    log('🔁 App resumed after ${awayFor.inSeconds}s — resyncing');

    // 1) السوكيت أولاً: كل ما تحته يعتمد عليه
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().ensureConnected();
    }

    // 2) تتبّع الموقع — قد يكون النظام أوقف التيّار أثناء الخلفية
    if (Get.isRegistered<LocationService>()) {
      final loc = Get.find<LocationService>();
      if (!loc.isTracking.value) {
        await loc.start(pushToServer: loc.isPushingToServer.value);
      } else {
        loc.resyncAfterReconnect();
      }
    }

    // 3) الحالة والطلب النشط — نلتقط ما فاتنا أثناء انقطاع السوكيت
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      await auth.fetchDriverData();
      await auth.fetchActiveOrderOnStartup();
    }

    // 4) المحفظة — تسوية الأدمن (settlDriverCash / settleDriverEarnings)
    //    تُصفّر الرصيد على السيرفر بلا أي بثّ للسائق، فكان التطبيق يعرض
    //    رصيداً قديماً حتى إعادة التشغيل.
    if (Get.isRegistered<WalletController>()) {
      await Get.find<WalletController>().fetchAllWalletData();
    }
  }
}
