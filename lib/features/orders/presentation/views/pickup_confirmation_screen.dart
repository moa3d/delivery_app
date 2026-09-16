import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/core/widgets/active_order_pop_guard.dart';
import 'package:delivery_app/data/services/socket_service.dart';
import '../../../../core/widgets/custom_leading.dart';
import 'delivery_map_screen.dart';

class PickUpConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic>? orderData;

  const PickUpConfirmationScreen({super.key, this.orderData});

  @override
  State<PickUpConfirmationScreen> createState() =>
      _PickUpConfirmationScreenState();
}

class _PickUpConfirmationScreenState extends State<PickUpConfirmationScreen> {
  bool isQrScanSelected = false;
  late TextEditingController orderNumberController;

  @override
  void initState() {
    super.initState();
    orderNumberController = TextEditingController(
        text: widget.orderData?['orderNumber']?.toString() ?? "");
  }

  void _confirmPickUp() {
    if (widget.orderData != null) {
      final String orderId = widget.orderData!['_id']?.toString() ?? "";
      if (orderId.isNotEmpty) {
        if (!isQrScanSelected && orderNumberController.text.trim().isEmpty) {
          Get.snackbar("alert".tr, "enter_order_number".tr,
              backgroundColor: Colors.orange, colorText: Colors.white);
          return;
        }
        final socketService = Get.find<SocketService>();
        // الباك إند ينقل الطلب مباشرة إلى on_the_way عبر order:startDelivery
        // (لا يوجد حدث order:pickup منفصل في الباك)
        socketService.startDelivery(orderId);
        Get.to(() => DeliveryMapScreen(orderData: widget.orderData));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = widget.orderData?['restaurantId']?['name'] ??
        "Restaurant";
    final orderNumber = widget.orderData?['orderNumber'] ?? "0000";
    final itemsCount = (widget.orderData?['items'] as List?)?.length ?? 0;

    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.grey
        .shade100;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    return ActiveOrderPopGuard(
      child: Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Padding(
            padding: EdgeInsets.all(8.0),
            child: CustomLeading()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("pickup_confirm_title".tr,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18)),
            Text("Order #$orderNumber", style: const TextStyle(
                color: AppColors.textGrey, fontSize: 12)),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF3D2621), AppColors.darkBackground]
                : [Colors.orange.shade50, Colors.grey.shade100],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildCenterIcon(),
              const SizedBox(height: 20),
              Text("arrived_rest_status".tr,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("confirm_to_continue".tr, style: const TextStyle(
                  color: AppColors.textGrey, fontSize: 16)),
              const SizedBox(height: 30),
              _buildToggleButtons(cardColor, isDark),
              const SizedBox(height: 25),
              isQrScanSelected
                  ? _buildQRScannerWidget(cardColor, isDark)
                  : _buildOrderInputField(cardColor, isDark),
              const SizedBox(height: 25),
              _buildPickUpList(
                  cardColor, isDark, restaurantName, orderNumber, itemsCount),
              const SizedBox(height: 20),
              _buildWarningBox(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: isDark ? const Color(0xFF101828) : Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConfirmButton(),
            const SizedBox(height: 10),
            Text("tap_confirm_hint".tr, style: const TextStyle(
                color: AppColors.textGrey, fontSize: 12)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCenterIcon() =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5)
          ],
        ),
        child: const Icon(Icons.inventory_2, color: Colors.white, size: 50),
      );

  Widget _buildToggleButtons(Color cardColor, bool isDark) =>
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark ? [] : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
            ]),
        child: Row(
          children: [
            Expanded(
                child: _toggleItem(
                    "scan_qr_tab".tr, Icons.qr_code_scanner, isQrScanSelected,
                        () => setState(() => isQrScanSelected = true))),
            Expanded(
                child: _toggleItem(
                    "order_num_tab".tr, Icons.numbers, !isQrScanSelected,
                        () => setState(() => isQrScanSelected = false)))
          ],
        ),
      );

  Widget _toggleItem(String label, IconData icon, bool isSelected,
      VoidCallback onTap) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryOrange : Colors
                      .transparent,
                  borderRadius: BorderRadius.circular(15)),
              child: Column(children: [
                Icon(icon,
                    color: isSelected ? Colors.white : AppColors.textGrey),
                const SizedBox(height: 5),
                Text(label,
                    style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textGrey,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight
                            .normal))
              ])));

  Widget _buildOrderInputField(Color cardColor, bool isDark) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark ? [] : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("enter_order_num_label".tr,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14)),
            const SizedBox(height: 15),
            TextField(
                controller: orderNumberController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18),
                decoration: InputDecoration(
                    prefixIcon: const Icon(
                        Icons.tag, color: AppColors.textGrey),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E222D) : Colors.grey
                        .shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 15),
            Text("ask_staff_hint".tr, style: const TextStyle(
                color: AppColors.textGrey, fontSize: 13)),
          ],
        ),
      );

  Widget _buildQRScannerWidget(Color cardColor, bool isDark) =>
      Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark ? [] : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
            ]),
        child: Column(
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222D) : Colors.grey
                      .shade200,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.qr_code_2,
                      size: 140,
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors
                          .black.withValues(alpha: 0.05)),
                  _buildScannerCorners(),
                  _buildAnimatedScannerLine(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text("qr_position_hint".tr, style: const TextStyle(
                color: AppColors.textGrey, fontSize: 13)),
          ],
        ),
      );

  Widget _buildScannerCorners() =>
      SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          children: [
            Align(alignment: Alignment.topLeft,
                child: _corner(top: true, left: true)),
            Align(alignment: Alignment.topRight,
                child: _corner(top: true, left: false)),
            Align(alignment: Alignment.bottomLeft,
                child: _corner(top: false, left: true)),
            Align(alignment: Alignment.bottomRight,
                child: _corner(top: false, left: false)),
          ],
        ),
      );

  Widget _corner({required bool top, required bool left}) =>
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(
                color: AppColors.primaryOrange, width: 4) : BorderSide.none,
            bottom: !top ? const BorderSide(
                color: AppColors.primaryOrange, width: 4) : BorderSide.none,
            left: left ? const BorderSide(
                color: AppColors.primaryOrange, width: 4) : BorderSide.none,
            right: !left ? const BorderSide(
                color: AppColors.primaryOrange, width: 4) : BorderSide.none,
          ),
        ),
      );

  Widget _buildAnimatedScannerLine() =>
      Container(
        width: 140,
        height: 2,
        decoration: BoxDecoration(
          color: AppColors.primaryOrange,
          boxShadow: [
            BoxShadow(color: AppColors.primaryOrange.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2)
          ],
        ),
      );

  Widget _buildPickUpList(Color cardColor, bool isDark, String name,
      dynamic num, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                  Icons.inventory_2_outlined, color: AppColors.primaryOrange,
                  size: 20),
              const SizedBox(width: 10),
              Text("${"orders_to_pickup_label".tr} (1)",
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          _orderItem("1", name, "#$num • $count ${"items_unit".tr}", isDark),
        ],
      ),
    );
  }

  Widget _orderItem(String index, String name, String details, bool isDark) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222D) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black
                    .withValues(alpha: 0.05))),
        child: Row(
          children: [
            Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                    color: isDark ? Colors.brown.shade800 : Colors.orange
                        .shade100,
                    borderRadius: const BorderRadius.all(Radius.circular(12))),
                child: Center(
                    child: Text(index, style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold)))),
            const SizedBox(width: 15),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold)),
                  Text(details, style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 12))
                ])),
            const Icon(Icons.check_circle_outline, color: AppColors.textGrey,
                size: 20),
          ],
        ),
      );

  Widget _buildWarningBox() =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
                child: Text("pickup_warning_text".tr, style: const TextStyle(
                    color: Colors.orange, fontSize: 12))),
          ],
        ),
      );

  Widget _buildConfirmButton() =>
      SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton.icon(
          onPressed: _confirmPickUp,
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: Text("confirm_pickup_btn".tr,
              style: const TextStyle(color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20))),
        ),
      );
}