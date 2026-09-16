import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:delivery_app/core/widgets/shimmer_widgets.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/past_order_details_controller.dart';

class PastOrderDetailsScreen extends StatelessWidget {
  const PastOrderDetailsScreen({super.key});

  String _getCurrency() => Get.isRegistered<AuthController>()
      ? Get.find<AuthController>().currencySymbol
      : "currency_syp".tr;

  /// تنسيق مبلغ قادم من الـ API.
  ///
  /// `(x ?? 0).toStringAsFixed(2)` على `dynamic` يرمي NoSuchMethodError لو
  /// وصل المبلغ نصاً — نفس الحارس المستخدم في شاشات المحفظة.
  String _money(dynamic v) =>
      (num.tryParse('${v ?? 0}') ?? 0).toDouble().toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PastOrderDetailsController());
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF101828) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;
    final textGrey = isDark ? const Color(0xFF98A2B3) : Colors.grey.shade600;
    final textColor = isDark ? Colors.white : Colors.black87;

    const accentOrange = Color(0xFFFF5630);
    const successGreen = Color(0xFF12B76A);
    const warningGold = Color(0xFFF79009);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Get.back(id: 2),
        ),
        title: Obx(() {
          final order = controller.orderDetails;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("order_details_title".tr,
                  style: TextStyle(color: textGrey, fontSize: 12)),
              Text("#${order['orderNumber'] ?? '...'}",
                  style: TextStyle(color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          );
        }),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const ShimmerOrderDetailSkeleton();
        }

        final order = controller.orderDetails;
        if (order.isEmpty) {
          return Center(child: Text(
              "no_orders_found".tr, style: TextStyle(color: textGrey)));
        }

        final restaurantAddr = order['restaurant']?['address'];
        final restaurantAddress = restaurantAddr is Map
            ? (restaurantAddr['fullAddress'] ?? "...")
            : (restaurantAddr?.toString() ?? "...");

        final deliveryAddr = order['deliveryAddress'];
        final deliveryAddress = deliveryAddr is Map
            ? (deliveryAddr['fullAddress'] ?? "...")
            : (deliveryAddr?.toString() ?? "...");

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildOrderInfoCard(
                  order, cardColor, warningGold, textGrey, textColor, isDark),
              const SizedBox(height: 16),

              _buildContactCard(
                title: "restaurant_details".tr,
                name: order['restaurant']?['name'] ?? "...",
                address: restaurantAddress,
                icon: Icons.restaurant,
                cardColor: cardColor,
                accent: accentOrange,
                isDark: isDark,
                textGrey: textGrey,
                textColor: textColor,
              ),
              const SizedBox(height: 16),
              _buildContactCard(
                title: "customer_details".tr,
                name: order['customer']?['name'] ?? "...",
                address: deliveryAddress,
                icon: Icons.person,
                cardColor: cardColor,
                accent: const Color(0xFF2E90FA),
                isDark: isDark,
                textGrey: textGrey,
                textColor: textColor,
              ),
              const SizedBox(height: 16),
              _buildOrderItemsCard(
                  order, cardColor, textGrey, textColor, isDark),
              const SizedBox(height: 16),
              _buildFinancialBreakdown(
                  order, cardColor, successGreen, textGrey, textColor, isDark),
              const SizedBox(height: 16),
              _buildTimelineCard(
                  order, cardColor, successGreen, textGrey, textColor, isDark),
              const SizedBox(height: 30),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOrderInfoCard(dynamic order, Color cardBg, Color gold,
      Color textGrey, Color textColor, bool isDark) {
    DateTime? createdAt = order['createdAt'] != null ? DateTime.tryParse(
        order['createdAt']) : null;
    String dateStr = createdAt != null ? DateFormat('EEEE, MMM dd, yyyy')
        .format(createdAt) : "...";
    String timeStr = createdAt != null
        ? DateFormat('h:mm a').format(createdAt)
        : "";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("order_placed".tr,
                        style: TextStyle(color: textGrey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(dateStr,
                        style: TextStyle(color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(timeStr,
                        style: TextStyle(color: textGrey, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gold.withValues(alpha: 0.2))),
                child: Text(
                    order['orderStatus']?.toString().toUpperCase() ?? "...",
                    style: TextStyle(color: gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("payment_method".tr,
                      style: TextStyle(color: textGrey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.payments_outlined, color: gold, size: 16),
                    const SizedBox(width: 8),
                    Text(order['paymentMethod']?.toString().toUpperCase() ??
                        "CASH",
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.bold))
                  ]),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("total_amount".tr,
                      style: TextStyle(color: textGrey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text("${order['totalPrice'] ?? '0.00'} ${_getCurrency()}",
                      style: const TextStyle(
                          color: Color(0xFFFF5630),
                          fontWeight: FontWeight.bold,
                          fontSize: 22)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({required String title,
    required String name,
    required String address,
    required IconData icon,
    required Color cardColor,
    required Color accent,
    required bool isDark,
    required Color textGrey,
    required Color textColor}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: accent, size: 20)),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(
                color: textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          Text(name, style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.location_on_outlined, color: textGrey, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(address,
                style: TextStyle(color: textGrey, fontSize: 13, height: 1.4))),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _buildButton(Icons.call, "call_btn".tr,
                    isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey
                        .shade100, textColor)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildButton(Icons.near_me, "navigate_btn".tr,
                    const Color(0xFF2E90FA).withValues(alpha: 0.1),
                    const Color(0xFF2E90FA))),
          ]),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, String label, Color bg, Color textColor) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withValues(alpha: 0.1))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: textColor, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            color: textColor, fontWeight: FontWeight.bold, fontSize: 14))
      ]),
    );
  }

  Widget _buildOrderItemsCard(dynamic order, Color cardColor, Color textGrey,
      Color textColor, bool isDark) {
    final List items = order['items'] ?? [];
    final pricing = order['pricing'] ?? {};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(children: [
        Row(children: [
          const Icon(
              Icons.shopping_bag_outlined, color: Color(0xFF7F56D9), size: 20),
          const SizedBox(width: 12),
          Text("order_items_label".tr,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFF7F56D9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Text("${items.length} ${"items_unit".tr}",
                  style: const TextStyle(
                      color: Color(0xFF7F56D9),
                      fontSize: 10,
                      fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 24),
        ...items.map((item) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${item['name']} ×${item['quantity']}",
                              style: TextStyle(color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 4),
                          Text("${_money(item['price'])} ${_getCurrency()} ${"each".tr}",
                              style: TextStyle(color: textGrey, fontSize: 12)),
                        ])),
                Text("${_money(item['totalPrice'])} ${_getCurrency()}",
                    style: TextStyle(color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ]),
            )),
        Divider(color: textColor.withValues(alpha: 0.1), height: 32),
        _buildPriceRow(
            "subtotal".tr,
            "${_money(pricing['itemsPrice'])} ${_getCurrency()}", textGrey,
            textColor),
        _buildPriceRow("delivery_fee_label".tr,
            "${_money(pricing['deliveryFee'])} ${_getCurrency()}",
            textGrey, textColor),
        _buildPriceRow(
            "tax_label".tr,
            "${_money(pricing['taxPrice'])} ${_getCurrency()}", textGrey,
            textColor),
        const SizedBox(height: 12),
        // نصّان بلا Flexible يتجاوزان العرض مع المبالغ الكبيرة (السورية)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
            child: Text("total_amount".tr,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text("${_money(pricing['totalPrice'])} ${_getCurrency()}",
                textAlign: TextAlign.end,
                style: const TextStyle(
                    color: Color(0xFFFF5630),
                    fontWeight: FontWeight.bold,
                    fontSize: 24)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildPriceRow(String label, String value, Color labelColor,
      Color valueColor) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
          Text(value, style: TextStyle(
              color: valueColor, fontSize: 14, fontWeight: FontWeight.bold))
        ]));
  }

  Widget _buildFinancialBreakdown(dynamic order, Color cardBg, Color success,
      Color textGrey, Color textColor, bool isDark) {
    final breakdown = order['financialBreakdown'] ?? {};

    // باك v4.2 — `deliveryFeeEarning` صارت تصل في كل الحالات، وحقول تسوية
    // الكاش وحدها هي المشروطة بـ isCashOrder. كان الشرط هنا يخفي البطاقة
    // كاملةً لغير الكاش، فالسائق الألماني لا يرى أجر طلبه إطلاقاً.
    final isCashOrder = breakdown['isCashOrder'] == true;
    final hasEarning = breakdown['deliveryFeeEarning'] != null;
    if (!isCashOrder && !hasEarning) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF79009).withValues(alpha: 0.1)),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.monetization_on_outlined, color: Color(0xFFF79009),
              size: 20),
          const SizedBox(width: 12),
          Text("complete_breakdown".tr,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 24),

        // أجر السائق — يُعرض للطلبات النقدية والبطاقية معاً
        _buildBreakdownRow(Icons.trending_up, "delivery_fee_earning".tr,
            "+${_money(breakdown['deliveryFeeEarning'])} ${_getCurrency()}",
            success, textGrey),

        // ما تحت خاص بتسوية الكاش السورية وحدها — لا معنى له في النظام الألماني
        if (isCashOrder) ...[
          _buildBreakdownRow(
              Icons.account_balance_wallet_outlined, "total_collected".tr,
              "${_money(breakdown['amountCollectedFromCustomer'])} ${_getCurrency()}",
              textColor, textGrey),
          _buildBreakdownRow(Icons.restaurant, "deducted_from_rest".tr,
              "${_money(breakdown['mealPriceWithTax'])} ${_getCurrency()}",
              textColor, textGrey),
          const SizedBox(height: 20),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey
                      .shade100,
                  borderRadius: BorderRadius.circular(16)),
              // نصّان بلا Flexible كانا يتجاوزان العرض على الشاشات الضيّقة
              // وبالنصوص الألمانية الطويلة
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(
                  child: Text("net_effect".tr,
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                      "+${_money(breakdown['netEffectOnBalance'])} ${_getCurrency()}",
                      textAlign: TextAlign.end,
                      style: TextStyle(color: success,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ),
              ])),
        ],
      ]),
    );
  }

  Widget _buildBreakdownRow(IconData icon, String label, String value,
      Color valueColor, Color textGrey) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, color: textGrey, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(
              label, style: TextStyle(color: textGrey, fontSize: 13))),
          Text(value, style: TextStyle(
              color: valueColor, fontWeight: FontWeight.bold, fontSize: 14))
        ]));
  }

  Widget _buildTimelineCard(dynamic order, Color cardBg, Color success,
      Color textGrey, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.history, color: Color(0xFFF79009), size: 20),
          const SizedBox(width: 12),
          Text("order_timeline".tr,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 30),
        _timelineItem(
            "order_placed".tr, _formatTime(order['createdAt']), true, success,
            textGrey, textColor),
        _timelineItem(
            "step_accepted".tr, _formatTime(order['createdAt']), true, success,
            textGrey, textColor),
        _timelineItem("step_delivered".tr,
            _formatTime(order['deliveredByDriverAt'] ?? order['createdAt']),
            true, success, textGrey, textColor,
            isLast: true),
      ]),
    );
  }

  String _formatTime(dynamic date) {
    if (date == null) return "";
    return DateFormat('h:mm a').format(DateTime.parse(date));
  }

  Widget _timelineItem(String title, String time, bool isDone, Color success,
      Color textGrey, Color textColor,
      {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(children: [
        Column(children: [
          Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: isDone ? success : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isDone ? null : Border.all(
                      color: textGrey.withValues(alpha: 0.5))),
              child: isDone ? const Icon(
                  Icons.check, color: Colors.white, size: 14) : null),
          if (!isLast)
            Expanded(
                child: Container(
                    width: 2,
                    color: isDone ? success : textGrey.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4))),
        ]),
        const SizedBox(width: 16),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(time, style: TextStyle(
                      color: isDone ? success : textGrey, fontSize: 12))
                ]))),
      ]),
    );
  }
}