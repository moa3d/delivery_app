import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payment_collection_controller.dart';


class PaymentCollectionScreen extends StatelessWidget {
  const PaymentCollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PaymentCollectionController());
    final dynamic orderData = Get.arguments;

    final String totalAmount = orderData?['totalPrice']?.toString() ?? "0.00";
    final String foodCost = orderData?['itemsPrice']?.toString() ?? "0.00";
    final String deliveryFee = orderData?['deliveryFee']?.toString() ?? "0.00";

    const bgColor = Color(0xFF101828);
    const cardColor = Color(0xFF1D2939);
    const accentOrange = Color(0xFFFF5630);
    const warningGold = Color(0xFFF79009);
    const textGrey = Color(0xFF98A2B3);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("collect_cash_label".tr,
                style: const TextStyle(color: textGrey, fontSize: 11)),
            Text("payment_collection_title".tr, style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Center(
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: warningGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: warningGold.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(color: warningGold.withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 5)
                  ],
                ),
                child: const Icon(
                    Icons.account_balance_wallet_rounded, color: warningGold,
                    size: 70),
              ),
            ),
            const SizedBox(height: 30),
            Text("collect_payment_header".tr, style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("collect_cash_instruction".tr,
                style: const TextStyle(color: textGrey, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 35),

            _buildSummaryCard(
                cardColor, warningGold, foodCost, deliveryFee, totalAmount,
                accentOrange),
            const SizedBox(height: 24),

            _buildConfirmationToggle(
                controller, cardColor, accentOrange, textGrey),
            const SizedBox(height: 24),

            _buildSecurityNotice(warningGold, textGrey),
            const SizedBox(height: 35),

            _buildActionButtons(
                controller, accentOrange, textGrey, totalAmount),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Color bg, Color gold, String food, String delivery,
      String total, Color orange) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(
        children: [
          Row(children: [
            Icon(Icons.receipt_long_rounded, color: gold, size: 20),
            const SizedBox(width: 10),
            Text("order_summary_label".tr, style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          _row("food_cost_label".tr, "$food ل.س", Colors.grey),
          const SizedBox(height: 12),
          _row("delivery_fee_label".tr, "$delivery ل.س", Colors.grey),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Colors.white10, height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("total_amount_label".tr, style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
              Text("$total ل.س", style: TextStyle(
                  color: orange, fontSize: 26, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationToggle(PaymentCollectionController ctrl, Color bg,
      Color orange, Color tg) {
    return GestureDetector(
      onTap: () => ctrl.toggleConfirmation(!ctrl.isConfirmed.value),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
        child: Row(
          children: [
            Obx(() =>
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ctrl.isConfirmed.value ? orange : Colors.transparent,
                    border: Border.all(
                        color: ctrl.isConfirmed.value ? orange : tg, width: 2),
                  ),
                  child: ctrl.isConfirmed.value ? const Icon(
                      Icons.check, size: 16, color: Colors.white) : null,
                )),
            const SizedBox(width: 15),
            Expanded(child: Text("confirm_cash_collected_check".tr,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.4))),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNotice(Color gold, Color tg) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withValues(alpha: 0.15))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security_rounded, color: gold, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("important_notice_label".tr, style: TextStyle(
                  color: gold, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text("collection_security_msg".tr,
                  style: TextStyle(color: tg, fontSize: 11, height: 1.4)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PaymentCollectionController ctrl, Color orange,
      Color tg, String total) {
    return Column(
      children: [
        Obx(() =>
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: ctrl.isConfirmed.value
                    ? () => Get.back(result: true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ctrl.isConfirmed.value
                      ? orange
                      : const Color(0xFF344054),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: Text("confirm_received_btn".tr, style: TextStyle(
                    color: ctrl.isConfirmed.value ? Colors.white : tg,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
              ),
            )),
        const SizedBox(height: 12),
        Text("$total ل.س ${"required_from_cust_hint".tr}",
            style: TextStyle(color: tg, fontSize: 11)),
      ],
    );
  }

  Widget _row(String l, String v, Color c) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: TextStyle(color: c, fontSize: 14)),
            Text(v, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600))
          ]);
}