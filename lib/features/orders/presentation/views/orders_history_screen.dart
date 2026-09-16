import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:delivery_app/features/orders/presentation/controllers/orders_history_controller.dart';
import 'package:delivery_app/features/orders/presentation/controllers/past_order_details_controller.dart';
import 'package:delivery_app/core/widgets/shimmer_widgets.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';

import '../../../navigation/presentation/controllers/navigation_controller.dart';

class OrdersHistoryScreen extends StatelessWidget {
  const OrdersHistoryScreen({super.key});

  /// رمز عملة السائق — مصدر واحد مشترك في AuthController بدل نسخة محلية
  /// كانت تقارن قيماً ('syria'/'germany') لا يرسلها الباك إطلاقاً.
  String get _currency => Get.isRegistered<AuthController>()
      ? Get.find<AuthController>().currencySymbol
      : 'currency_syp'.tr;

  String _money(dynamic v) =>
      (num.tryParse('${v ?? 0}') ?? 0).toDouble().toStringAsFixed(2);

  /// `DateTime.parse` غير المحمي داخل ListView.builder كان يُسقط الشاشة
  /// كاملةً لو وصل `createdAt` فارغاً أو بصيغة غير متوقّعة
  String _formatDate(dynamic raw) {
    final date = raw == null ? null : DateTime.tryParse(raw.toString());
    return date == null ? "—" : DateFormat('EEEE, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OrdersHistoryController());
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF101828) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;
    const accentOrange = Color(0xFFFF5630);
    final textGrey = isDark ? const Color(0xFF98A2B3) : Colors.grey.shade600;
    const successGreen = Color(0xFF12B76A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Get.find<NavigationController>().changePage(0),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "orders_history_title".tr,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Obx(() =>
                Text(
                  "orders_count".trParams(
                      {'count': controller.orders.length.toString()}),
                  style: TextStyle(color: textGrey, fontSize: 12),
                )),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today_outlined,
                color: isDark ? Colors.white : Colors.black, size: 20),
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) controller.updateDateFilter(picked);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. بطاقات الإحصائيات العلوية
          Padding(
            padding: const EdgeInsets.all(20),
            child: Obx(() =>
                Row(
                  children: [
                    _buildSummaryCard(
                      "orders_today".tr,
                      controller.todayOrdersCount.value.toString(),
                      Icons.inventory_2_outlined,
                      const Color(0xFF2E90FA),
                      cardColor,
                      isDark,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryCard(
                      "earnings_today".tr,
                      "${controller.todayEarnings.value.toStringAsFixed(2)} $_currency",
                      Icons.attach_money,
                      accentOrange,
                      cardColor,
                      isDark,
                    ),
                  ],
                )),
          ),

          // 2. شريط الفلاتر
          _buildFilterBar(controller, accentOrange, isDark),
          const SizedBox(height: 10),

          // 3. قائمة الطلبات
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const ShimmerOrdersHistorySkeleton();
              }
              if (controller.orders.isEmpty) {
                return Center(
                  child: Text(
                    "no_orders_found".tr,
                    style: TextStyle(color: textGrey),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.orders.length,
                itemBuilder: (context, index) =>
                    _buildOrderCard(
                      controller.orders[index],
                      cardColor,
                      accentOrange,
                      textGrey,
                      successGreen,
                      isDark,
                    ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon,
      Color color, Color cardBg, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? []
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                            .shade600, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // مبلغ بحجم 24 داخل بطاقة ضيّقة — نُصغّره بدل لفّه أو قصّه
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(OrdersHistoryController controller, Color accent,
      bool isDark) {
    return Obx(() {
      final filters = [
        {'id': 'all', 'label': 'all_orders_filter'.tr},
        {'id': 'completed', 'label': 'completed_filter'.tr},
        {'id': 'cancelled', 'label': 'cancelled_filter'.tr},
      ];

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
            bool isSelected = controller.selectedStatus.value == f['id'];
            return GestureDetector(
              onTap: () => controller.updateStatusFilter(f['id']!),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFF98A2B3) : Colors.grey
                        .shade600),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight
                        .normal,
                  ),
                ),
              ),
            );
          }).toList(),
          ),
        ),
      );
    });
  }

  Widget _buildOrderCard(dynamic order, Color cardBg, Color accent,
      Color textGrey, Color success, bool isDark) {
    final bool isCash = (order['paymentMethod'] ?? 'Cash') == 'Cash';

    return GestureDetector(
      onTap: () {
        final detailController = Get.put(PastOrderDetailsController());
        detailController.setOrderAndFetch(order['_id']);
        Get.toNamed('/past-order-details', id: 2);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? []
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.restaurant, color: accent, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // اسم المطعم قد يكون طويلاً — Expanded يمنع دفع
                          // شارة الدفع خارج حدود البطاقة
                          Expanded(
                            child: Text(
                              order['restaurant']?['name'] ?? "Restaurant",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPaymentBadge(isCash),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order['customer']?['name'] ?? "Customer",
                        style: TextStyle(color: textGrey, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order['deliveryAddress'] is Map
                            ? order['deliveryAddress']['fullAddress'] ?? "Address"
                            : order['deliveryAddress']?.toString() ?? "Address",
                        style: TextStyle(
                            color: textGrey.withValues(alpha: 0.7), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: success, size: 24),
              ],
            ),
            const SizedBox(height: 20),
            // التاريخ والمبلغان كانوا بلا قيد عرض، والـ Spacer لا ينكمش —
            // فيطفح الصف مع المبالغ السورية الطويلة
            Row(
              children: [
                Icon(Icons.access_time, color: textGrey, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _formatDate(order['createdAt']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textGrey, fontSize: 12),
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: _buildPriceInfo("order_total".tr,
                      "${_money(order['totalPrice'])} $_currency",
                      isDark ? Colors.white : Colors.black, isDark),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: _buildPriceInfo("your_earning".tr,
                      "${_money(order['deliveryFee'])} $_currency",
                      accent, isDark),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Order #${order['orderNumber']}",
              style: TextStyle(color: textGrey.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(bool isCash) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF79009).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF79009).withValues(alpha: 0.2)),
      ),
      child: Text(
        isCash ? "cash_label".tr : "online_label".tr,
        style: const TextStyle(color: Color(0xFFF79009),
            fontSize: 10,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPriceInfo(String label, String value, Color valueColor,
      bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(
              color: isDark ? const Color(0xFF98A2B3) : Colors.grey.shade600,
              fontSize: 10),
        ),
        // المبالغ السورية طويلة — نُصغّرها بدل قصّها
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

}