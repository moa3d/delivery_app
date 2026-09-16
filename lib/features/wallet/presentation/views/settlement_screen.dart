import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';

/// شاشة تعليمات إيداع الكاش المحصَّل.
///
/// لا يوجد في الباك أي راوت لتسوية السائق — موديل `Settlement` مخصص
/// للمطاعم وحدها، والتسوية تتم من لوحة الأدمن (`settlDriverCash` /
/// `settleDriverEarnings`). لذلك هذه الشاشة تعليمات فقط: كانت سابقاً
/// تعرض زر "تأكيد الإيداع" الذي ينفّذ `Get.back()` بلا أي إرسال، فيظن
/// السائق أنه أبلغ الإدارة.
class SettlementScreen extends StatelessWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // استلام المبلغ من الـ arguments
    final String amount = Get.arguments?.toString() ?? "0.00";
    final String currency = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().currencySymbol
        : "currency_syp".tr;

    final bgColor = isDark ? const Color(0xFF101828) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;
    const warningGold = Color(0xFFF79009);
    final textGrey = isDark ? const Color(0xFF98A2B3) : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("settle_balance".tr,
                style: TextStyle(color: textGrey, fontSize: 12)),
            Text("process_deposit".tr,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // أيقونة العملة الذهبية
            Center(
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: warningGold.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(35),
                ),
                child: const Icon(Icons.monetization_on,
                    color: Colors.white, size: 60),
              ),
            ),
            const SizedBox(height: 32),
            Text("settlement_required".tr,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("deposit_instruction".tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: textGrey, fontSize: 14)),
            const SizedBox(height: 32),

            // بطاقة المبلغ المطلوب إيداعه
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
              child: Column(
                children: [
                  Text("you_must_deposit".tr,
                      style: TextStyle(color: textGrey, fontSize: 14)),
                  const SizedBox(height: 12),
                  Text("$amount $currency",
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 44,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: warningGold,
                          borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // طرق الإيداع المتاحة — معلوماتية، لا تُرسل للسيرفر
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text("deposit_methods_title".tr,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),

            _buildMethodInfo(
              isDark: isDark,
              cardBg: cardColor,
              title: "cash_at_office".tr,
              sub: "visit_office_desc".tr,
              icon: Icons.store,
              accentColor: const Color(0xFFF04438),
            ),
            const SizedBox(height: 12),
            _buildMethodInfo(
              isDark: isDark,
              cardBg: cardColor,
              title: "digital_transfer".tr,
              sub: "digital_transfer_desc".tr,
              icon: Icons.phone_android,
              accentColor: const Color(0xFF2E90FA),
            ),

            const SizedBox(height: 24),

            // كيف يُحدَّث الرصيد فعلياً
            _buildInfoBox(
              isDark: isDark,
              color: const Color(0xFF2E90FA),
              icon: Icons.info_outline,
              title: "how_balance_updates_title".tr,
              body: "how_balance_updates_desc".tr,
              textGrey: textGrey,
            ),
            const SizedBox(height: 16),

            // تنبيه هام
            _buildInfoBox(
              isDark: isDark,
              color: warningGold,
              icon: Icons.warning_amber_rounded,
              title: "important_notice".tr,
              body: "false_confirmation_warning".tr,
              textGrey: textGrey,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: isDark
                          ? const Color(0xFF344054)
                          : Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("back_btn".tr,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodInfo({
    required bool isDark,
    required Color cardBg,
    required String title,
    required String sub,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.transparent : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(sub,
                    style: TextStyle(
                        color: isDark
                            ? const Color(0xFF98A2B3)
                            : Colors.grey.shade600,
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required bool isDark,
    required Color color,
    required IconData icon,
    required String title,
    required String body,
    required Color textGrey,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        color: isDark ? textGrey : Colors.grey.shade700,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
