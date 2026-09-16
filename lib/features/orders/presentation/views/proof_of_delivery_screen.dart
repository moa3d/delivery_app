import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/core/widgets/active_order_pop_guard.dart';
import 'package:delivery_app/data/services/socket_service.dart';

import '../../../../core/widgets/custom_leading.dart';
import '../controllers/payment_collection_controller.dart';
import 'payment_collection_screen.dart';

/// شاشة إثبات التوصيل: تظهر للمندوب عند وصوله للعميل بانتظار تأكيد الاستلام النهائي
class ProofOfDeliveryScreen extends StatefulWidget {
  final Map<String, dynamic>? orderData;

  const ProofOfDeliveryScreen({super.key, this.orderData});

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  // v3.0 — الباك لم يعد يرسل تأكيد عميل وسيط (حُذف order:confirmDelivery
  // وحالة delivered_by_driver). ضغط السائق "تم التسليم" هو الفعل الذي
  // يُنشئ حالة delivered مباشرة. لذا لم يعد الزر ينتظر تأكيداً مسبقاً؛
  // نتتبّع بدلاً من ذلك حالة الإرسال لمنع الضغط المزدوج.
  bool _isSubmitting = false;

  final SocketService _socketService = Get.find<SocketService>();
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  Timer? _confirmTimeout;

  /// مهلة انتظار تأكيد السيرفر بعد إرسال order:delivered — أطول قليلاً
  /// لأن استضافة Render قد تستيقظ من السبات ببطء (نفس منطق new_order).
  static const Duration _serverReplyTimeout = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _listenToServerConfirmation();
  }

  /// v3.0 — حدث delivered لم يعد بوابة تفعيل للزر، بل تأكيد نجاح:
  /// يصل بعد أن يحفظ الباك الحالة فعلياً (تحصيل الكاش + إعادة online)،
  /// فننتقل للرئيسية عنده — لا قبله — لضمان اكتمال العملية على السيرفر.
  void _listenToServerConfirmation() {
    _statusSub = _socketService.orderStatusStream.listen((data) {
      if (data['status'] == 'delivered' && mounted) {
        _confirmTimeout?.cancel();
        Get.snackbar(
          "success_snack_title".tr,
          "success_snack_msg".tr,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.offAllNamed('/main-navigation');
      }
    });
  }

  /// هل الطلب نقدي؟ أي قيمة غير "cash" مدفوعة أونلاين مسبقاً.
  bool get _isCashOrder =>
      (widget.orderData?['paymentMethod']?.toString().trim().toLowerCase() ??
              'cash') ==
          'cash';

  /// يُستدعى عند ضغط زر "تم التسليم".
  Future<void> _submitDelivery() async {
    if (_isSubmitting) return;
    final orderId = widget.orderData?['_id']?.toString() ?? "";
    if (orderId.isEmpty) return;

    // بوابة التحصيل: الطلب النقدي لا يُسلَّم قبل أن يؤكد السائق قبض المبلغ.
    // بدونها كان السيرفر يسجّل delivered ويحتسب الكاش على السائق دون أن
    // يكون قد حصّله — عجز تسوية صامت.
    if (_isCashOrder) {
      // حذف أي نسخة سابقة كي لا تبدأ الشاشة بتأكيد مُفعّل من طلب قديم
      Get.delete<PaymentCollectionController>();
      final collected = await Get.to<bool>(
        () => const PaymentCollectionScreen(),
        arguments: widget.orderData,
      );
      if (collected != true || !mounted) return;
    }

    setState(() => _isSubmitting = true);
    _socketService.completeDelivery(orderId);

    // مهلة أمان: لو لم يصل تأكيد delivered (انقطاع شبكة/سبات السيرفر)،
    // نُعيد تفعيل الزر بدل إبقاء السائق عالقاً في انتظار دائم.
    _confirmTimeout?.cancel();
    _confirmTimeout = Timer(_serverReplyTimeout, () {
      if (!mounted || !_isSubmitting) return;
      setState(() => _isSubmitting = false);
      Get.snackbar(
        "alert".tr,
        "wait_timeout".tr,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _confirmTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // الباك يرجع شكلين مختلفين:
    //    /active-order      → userId (populated)
    //    /orders/:orderId   → customer (مسطّح)
    final customerRaw =
        widget.orderData?['customer'] ?? widget.orderData?['userId'];
    final userName = (customerRaw is Map
            ? customerRaw['name']?.toString()
            : null) ??
        "Customer";
    final deliveryAddress = (widget.orderData?['deliveryAddress'] is Map)
        ? (widget.orderData?['deliveryAddress']['fullAddress'] ?? "")
        : (widget.orderData?['deliveryAddress']?.toString() ?? "");

    final bgColor = isDark ? const Color(0xFF101828) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;

    return ActiveOrderPopGuard(
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDark),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF2D1B18), const Color(0xFF101828)]
                : [Colors.orange.shade50, Colors.grey.shade50],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _buildCenterHeaderIcon(),
                      const SizedBox(height: 30),
                      _buildHeaderText(isDark),
                      const SizedBox(height: 40),
                      _buildCustomerCard(
                          isDark, cardColor, userName, deliveryAddress),
                      const SizedBox(height: 25),
                      _buildInstructionBox(),
                      const SizedBox(height: 30),
                      _buildHintText(),
                      const Spacer(),
                      _buildCompleteActionButton(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// بناء شريط التطبيق العلوي
  PreferredSizeWidget _buildAppBar(bool isDark) => AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: const Padding(
      padding: EdgeInsets.all(8.0),
      child: CustomLeading(),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "proof_delivery_title".tr,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "complete_delivery_sub".tr,
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black54,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  /// أيقونة النجاح المركزية مع التوهج البصري
  Widget _buildCenterHeaderIcon() => Container(
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: AppColors.primaryOrange,
      borderRadius: BorderRadius.circular(25),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryOrange.withValues(alpha: 0.3),
          blurRadius: 40,
          spreadRadius: 10,
        ),
      ],
    ),
    child: const Icon(Icons.check_circle, size: 50, color: Colors.white),
  );

  Widget _buildHeaderText(bool isDark) => Column(
    children: [
      Text(
        "almost_done_title".tr,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        "confirm_details_sub".tr,
        style: TextStyle(
          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54,
          fontSize: 16,
        ),
      ),
    ],
  );

  /// بطاقة معلومات العميل المستلم
  Widget _buildCustomerCard(
    bool isDark,
    Color cardColor,
    String name,
    String address,
  ) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: isDark
          ? []
          : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildInstructionBox() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.green.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check, color: Colors.green, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "confirm_instruction_text".tr,
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _buildHintText() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(
      "tap_confirm_hint".tr,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.redAccent,
        fontSize: 11,
        fontStyle: FontStyle.italic,
      ),
    ),
  );

  /// زر الإنهاء النهائي.
  /// v3.0 — متاح فوراً (ضغط السائق يُنشئ delivered)، ويُعطَّل فقط أثناء
  /// انتظار تأكيد السيرفر لمنع الضغط المزدوج.
  Widget _buildCompleteActionButton() => SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton.icon(
      onPressed: _isSubmitting ? null : _submitDelivery,
      icon: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.check_circle, color: Colors.white),
      label: Text(
        "confirm_delivery_btn".tr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryOrange,
        disabledBackgroundColor: AppColors.primaryOrange.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  );
}
