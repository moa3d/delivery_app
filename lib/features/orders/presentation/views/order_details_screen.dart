import 'dart:async';
import 'package:delivery_app/core/widgets/active_order_pop_guard.dart';
import 'package:delivery_app/core/widgets/custom_leading.dart';
import 'package:delivery_app/data/services/socket_service.dart';
import 'package:delivery_app/features/orders/presentation/controllers/past_order_details_controller.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:delivery_app/features/orders/presentation/views/pickup_confirmation_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';


class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? orderData;

  const OrderDetailsScreen({super.key, this.orderData});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  String currentStatus = "picked_up";
  Map<String, dynamic>? fullData;
  bool isLoading = false;
  dynamic _statusHandler;

  @override
  void initState() {
    super.initState();
    final dynamic data = widget.orderData ?? Get.arguments;
    fullData = data;

    if (data != null) {
      currentStatus = data['orderStatus'] ?? "picked_up";
      _fetchFullDetails(data['_id']?.toString() ?? data['id']?.toString());
    }

    _statusHandler = (statusData) {
      if (mounted &&
          statusData['orderId'].toString() == data?['_id']?.toString()) {
        setState(() {
          currentStatus = statusData['status'];
        });
      }
    };
    Get
        .find<SocketService>()
        .socket
        ?.on("order:statusUpdated", _statusHandler);
  }

  Future<void> _fetchFullDetails(String? orderId) async {
    if (orderId == null) return;
    setState(() => isLoading = true);
    final order = await fetchDriverOrderDetails(orderId);
    if (!mounted) return;
    setState(() {
      if (order != null) fullData = order;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    if (_statusHandler != null) {
      Get
          .find<SocketService>()
          .socket
          ?.off("order:statusUpdated", _statusHandler);
    }
    super.dispose();
  }

  String _getCurrency() {
    final authController = Get.find<AuthController>();
    final country = authController.driverData['country'] ?? "SY";
    switch (country) {
      case 'DE': return "currency_eur".tr;
      case 'US': return "currency_usd".tr;
      default: return "currency_syp".tr;
    }
  }

  bool _shouldShowTax() {
    final authController = Get.find<AuthController>();
    return authController.driverData['country'] == "DE";
  }

  /// إطلاق مباشر بلا `canLaunchUrl`: الفحص يُرجع false على iOS لأي scheme غير
  /// معلَن في `LSApplicationQueriesSchemes`، وعلى أندرويد 11+ لأي هدف غير معلَن
  /// في `<queries>` — فكان الزر يصمت بلا سبب على المنصّتين. الإطلاق نفسه لا
  /// يخضع لهذين القيدين، وهو ما تفعله أزرار الاتصال والرسالة في شاشة الخريطة.
  /// وعند تعذّر الإطلاق فعلاً (جهاز بلا تطبيق هاتف) تظهر رسالة بدل الصمت.
  Future<void> _launchExternal(Uri uri, String failureKey) async {
    try {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _showLaunchFailure(failureKey);
    } catch (_) {
      _showLaunchFailure(failureKey);
    }
  }

  void _showLaunchFailure(String failureKey) {
    Get.snackbar("alert".tr, failureKey.tr,
        backgroundColor: Colors.redAccent, colorText: Colors.white);
  }

  void _navigateLocation(List? coordinates) {
    if (coordinates == null || coordinates.length < 2) return;
    _launchExternal(
      Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${coordinates[1]},${coordinates[0]}'),
      'open_map_failed',
    );
  }

  void _makeCall(String? phone) {
    if (phone == null || phone.isEmpty) return;
    _launchExternal(Uri.parse('tel:$phone'), 'call_failed');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final data = fullData;
    final currency = _getCurrency();

    final restaurant = data?['restaurantId'] ?? data?['restaurant'] ?? {};
    final user = data?['userId'] ?? data?['customer'] ?? {};
    final orderNumber = data?['orderNumber'] ?? "...";
    final items = data?['items'] as List? ?? [];

    String restaurantAddress = "Address N/A";
    if (restaurant['address'] is Map) {
      restaurantAddress = restaurant['address']['fullAddress'] ?? "Address N/A";
    } else if (restaurant['address'] is String) {
      restaurantAddress = restaurant['address'];
    }

    List? restaurantCoords;
    if (restaurant['location'] is Map) {
      restaurantCoords = restaurant['location']['coordinates'];
    } else if (restaurant['location'] is List) {
      restaurantCoords = restaurant['location'];
    }

    String deliveryAddress = "Address N/A";
    if (data?['deliveryAddress'] is Map) {
      deliveryAddress =
          data?['deliveryAddress']['fullAddress'] ?? "Address N/A";
    } else if (data?['deliveryAddress'] is String) {
      deliveryAddress = data?['deliveryAddress'];
    }

    final dynamic pricingData = data?['pricing'];
    final totalPrice = (data?['totalPrice'] ?? pricingData?['totalPrice'] ??
        "0.00").toString();

    final pricing = {
      'itemsPrice': (pricingData?['itemsPrice'] ?? data?['itemsPrice'] ??
          "0.00").toString(),
      'deliveryFee': (pricingData?['deliveryFee'] ?? data?['deliveryFee'] ??
          "0.00").toString(),
      'taxPrice': (pricingData?['taxPrice'] ?? data?['taxPrice'] ?? "0.00")
          .toString(),
    };

    final paymentMethod = data?['paymentMethod'] ?? "cash";

    final bgColor = isDark ? const Color(0xFF101828) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;
    final textGrey = isDark ? const Color(0xFF98A2B3) : Colors.grey.shade600;
    const primaryRed = Color(0xFFFF5630);
    const infoBlue = Color(0xFF2E90FA);
    const warningGold = Color(0xFFF79009);
    const purpleAccent = Color(0xFF7F56D9);

    return ActiveOrderPopGuard(
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // ملاحظة: الزر يستدعي (عبر CustomLeading الافتراضية) Navigator.maybePop
        // لا Get.back() — وهذا ضروري لأن PopScope لا يعترض إلا مسار
        // maybePop، بينما pop()/Get.back() المباشر يتجاوزه كلياً.
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CustomLeading(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("order_details_title".tr,
                style: TextStyle(color: textGrey, fontSize: 12)),
            Text("Order #$orderNumber",
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          _buildTopStatusBadge(_statusLabel(currentStatus), _statusColor(currentStatus)),
          const SizedBox(width: 8),
          if (data?['driverPaymentStatus'] != null && data!['driverPaymentStatus'] != 'not_applicable')
            _buildTopStatusBadge(
              data['driverPaymentStatus'] == 'settled' ? 'driver_payment_settled'.tr : 'driver_payment_pending'.tr,
              data['driverPaymentStatus'] == 'settled' ? const Color(0xFF12B76A) : const Color(0xFFF79009),
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOrderProgressCard(
                isDark, cardColor, currentStatus, primaryRed, warningGold),
            const SizedBox(height: 16),
            _buildInfoCard(
              isDark, cardColor, textGrey,
              title: "restaurant_details".tr,
              name: restaurant['name'] ?? "...",
              address: restaurantAddress,
              phone: restaurant['phone'] ?? "N/A",
              imageUrl: restaurant['image']?['url'],
              icon: Icons.storefront,
              iconColor: primaryRed,
              buttonLabel: "confirm_pickup_btn".tr,
              buttonColor: primaryRed,
              buttonIcon: Icons.check_circle_outline,
              onButtonPressed: () =>
                  Get.to(() => PickUpConfirmationScreen(orderData: data)),
              onNavigatePressed: () => _navigateLocation(restaurantCoords),
              onCallPressed: () => _makeCall(restaurant['phone']),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              isDark, cardColor, textGrey,
              title: "customer_details".tr,
              name: user['name'] ?? user['customerName'] ?? "Customer",
              address: deliveryAddress,
              phone: user['phone'] ?? "N/A",
              icon: Icons.person_outline,
              iconColor: infoBlue,
              onCallPressed: () => _makeCall(user['phone']),
            ),
            const SizedBox(height: 16),
            _buildOrderItemsCard(
                isDark, cardColor, textGrey, items, purpleAccent, currency),
            const SizedBox(height: 16),
            _buildPricingSummaryCard(
                isDark,
                cardColor,
                textGrey,
                pricing,
                totalPrice,
                primaryRed,
                currency),
            const SizedBox(height: 16),
            _buildPaymentMethodCard(
                isDark,
                cardColor,
                textGrey,
                paymentMethod,
                totalPrice,
                warningGold,
                currency),
            const SizedBox(height: 16),
            if (data?['notes'] != null && data!['notes'].toString().isNotEmpty)
              _buildOrderNotesCard(isDark, cardColor, data['notes'].toString(), textGrey),
            if (data?['notes'] != null && data!['notes'].toString().isNotEmpty)
              const SizedBox(height: 16),
            _buildOrderTimelineCard(isDark, cardColor, data),
            const SizedBox(height: 16),
            _buildBottomNote(isDark, purpleAccent),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTopStatusBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(label, style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'step_assigned'.tr;
      case 'accepted': return 'step_accepted'.tr;
      case 'preparing': return 'step_preparing'.tr;
      case 'ready': return 'step_ready'.tr;
      case 'picked_up': return 'step_picked_up'.tr;
      case 'on_the_way': return 'step_delivering'.tr;
      case 'delivered': return 'step_delivered'.tr;
      case 'cancelled': return 'step_cancelled'.tr;
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered': return const Color(0xFF12B76A);
      case 'cancelled': return const Color(0xFFF04438);
      case 'on_the_way': return const Color(0xFF2E90FA);
      case 'picked_up': return const Color(0xFFF79009);
      case 'preparing': return const Color(0xFF7F56D9);
      case 'ready': return const Color(0xFF2E90FA);
      default: return const Color(0xFFF79009);
    }
  }

  Widget _buildOrderProgressCard(bool isDark, Color cardColor, String status,
      Color red, Color gold) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("order_progress".tr,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildStepper(isDark, status, red, gold),
        ],
      ),
    );
  }

  Widget _buildStepper(bool isDark, String status, Color red, Color gold) {
    final List<String> allSteps = [
      "step_assigned",
      "step_accepted",
      "step_preparing",
      "step_ready",
      "step_picked_up",
      "step_delivering",
      "step_delivered",
    ];

    const statusOrder = [
      "pending",
      "accepted",
      "preparing",
      "ready",
      "picked_up",
      "on_the_way",
      "delivered",
    ];

    final currentIdx = statusOrder.indexOf(status);
    final effectiveIdx = currentIdx >= 0 ? currentIdx : 0;

    final List<Map<String, dynamic>> steps = allSteps.asMap().entries.map((entry) {
      final idx = entry.key;
      final titleKey = entry.value;
      String state;
      if (idx < effectiveIdx) {
        state = "completed";
      } else if (idx == effectiveIdx) {
        state = "current";
      } else {
        state = "pending";
      }
      return {
        "title": titleKey.tr,
        "state": state,
        if (titleKey == "step_picked_up" && state == "current") "sub": "in_progress".tr,
      };
    }).toList();

    return Column(
      children: steps
          .asMap()
          .entries
          .map((entry) {
        int idx = entry.key;
        var step = entry.value;
        String state = step['state'];
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _buildStepIcon(state, red),
                  if (idx != steps.length - 1)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: (state == "completed")
                            ? const Color(0xFF12B76A)
                            : const Color(0xFF344054),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step['title'],
                              style: TextStyle(
                                  color: state == "pending"
                                      ? const Color(0xFF98A2B3)
                                      : (isDark ? Colors.white : Colors.black),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          if (step['sub'] != null && state == "current")
                            Text(step['sub'],
                                style: TextStyle(color: red, fontSize: 12)),
                        ],
                      ),
                      if (step['badge'] != null) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gold.withValues(alpha: 0.3))),
                          child: Text(step['badge'],
                              style: TextStyle(color: gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepIcon(String state, Color red) {
    if (state == "completed") {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
            color: Color(0xFF12B76A), shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    }
    if (state == "current") {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
            border: Border.all(color: red, width: 2), shape: BoxShape.circle),
        child: Center(
            child: Container(width: 8,
                height: 8,
                decoration: BoxDecoration(color: red, shape: BoxShape.circle))),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF344054), width: 2),
          shape: BoxShape.circle),
      child: Center(
          child: Container(width: 4,
              height: 4,
              decoration: const BoxDecoration(
                  color: Color(0xFF344054), shape: BoxShape.circle))),
    );
  }

  Widget _buildInfoCard(bool isDark, Color cardColor, Color textGrey,
      {required String title,
        required String name,
        required String address,
        required String phone,
        required IconData icon,
        required Color iconColor,
        String? imageUrl,
        String? buttonLabel,
        Color? buttonColor,
        IconData? buttonIcon,
        VoidCallback? onButtonPressed,
        VoidCallback? onNavigatePressed,
        VoidCallback? onCallPressed}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (onNavigatePressed != null)
                IconButton(
                    icon: Icon(
                        Icons.near_me_outlined, color: iconColor, size: 20),
                    onPressed: onNavigatePressed),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  image: imageUrl != null && imageUrl.isNotEmpty
                      ? DecorationImage(
                      image: NetworkImage(imageUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: imageUrl == null || imageUrl.isEmpty ? Icon(
                    icon, color: iconColor, size: 32) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: Color(0xFF98A2B3), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(address, style: TextStyle(
                            color: textGrey, fontSize: 13), maxLines: 2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onCallPressed,
                      child: Row(
                        children: [
                          Icon(
                              Icons.phone_outlined, color: iconColor, size: 16),
                          const SizedBox(width: 8),
                          Text("\u200e$phone",
                              style: TextStyle(color: iconColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: Icon(
                    buttonIcon ?? Icons.near_me, color: Colors.white, size: 18),
                label: Text(buttonLabel,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(bool isDark, Color cardBg, Color textGrey,
      List items, Color purple, String currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: purple, size: 20),
              const SizedBox(width: 12),
              Text("order_items_label".tr,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text("${items.length} ${"items_unit".tr}",
                    style: TextStyle(color: purple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) {
            final extras = item['extras'] as List? ??
                item['options'] as List? ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${item['name'] ?? 'Item'} ×${item['quantity'] ??
                            1}",
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold)),
                        if (extras.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: extras.map((ex) {
                                final exName = ex is Map ? ex['name'] : ex
                                    .toString();
                                return Text("• $exName", style: TextStyle(
                                    color: textGrey.withValues(alpha: 0.8),
                                    fontSize: 11));
                              }).toList(),
                            ),
                          ),
                        if (item['note'] != null && item['note']
                            .toString()
                            .isNotEmpty)
                          Text("${"note_label".tr}: ${item['note']}",
                              style: TextStyle(color: textGrey, fontSize: 12)),
                        Text(
                            "${item['price'] ?? '0.00'} $currency ${"each".tr}",
                            style: TextStyle(color: textGrey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text("${item['totalPrice'] ?? '0.00'} $currency",
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPricingSummaryCard(bool isDark, Color cardBg, Color textGrey,
      dynamic pricing, String total, Color red, String currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          _priceRow(textGrey, isDark, "subtotal".tr,
              "${pricing['itemsPrice'] ?? '0.00'} $currency"),
          _priceRow(textGrey, isDark, "delivery_fee_label".tr,
              "${pricing['deliveryFee'] ?? '0.00'} $currency"),
          if (_shouldShowTax()) _priceRow(textGrey, isDark, "tax_label".tr,
              "${pricing['taxPrice'] ?? '0.00'} $currency"),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("total_amount".tr,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              Text("$total $currency",
                  style: TextStyle(
                      color: red, fontWeight: FontWeight.bold, fontSize: 24)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(Color textGrey, bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textGrey)),
          Text(value, style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(bool isDark, Color cardBg, Color textGrey,
      String method, String total, Color gold, String currency) {
    // كان هذا المعامل يُستقبل ولا يُقرأ، فيُعرض كل طلب — حتى المدفوع
    // أونلاين — على أنه "اجمع الكاش"، والزبون يدفع مرتين.
    // أي قيمة غير "cash" تعني مدفوعاً مسبقاً.
    final bool isCash = method.trim().toLowerCase() == 'cash';
    final Color accent = isCash ? gold : Colors.green;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.1)),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                    isCash
                        ? Icons.account_balance_wallet_outlined
                        : Icons.credit_card,
                    color: accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("payment_method".tr,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold)),
                    Text(
                        isCash
                            ? "cash_on_delivery".tr
                            : "paid_online_title".tr,
                        style: TextStyle(color: textGrey, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.3))),
                child: Text(isCash ? "cash_label".tr : "paid_online_label".tr,
                    style: TextStyle(color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey
                  .shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                        isCash
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: accent,
                        size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          isCash
                              ? "collect_from_customer".tr
                              : "no_collection_title".tr,
                          style: TextStyle(
                              color: accent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    isCash
                        ? "collect_cash_msg"
                            .trParams({'amount': "$total $currency"})
                        : "no_collection_msg".tr,
                    style: TextStyle(
                        color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                            .shade700, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTimelineCard(bool isDark, Color cardBg, dynamic data) {
    String formattedTime(String? date) {
      if (date == null) return "";
      try {
        return DateFormat('h:mm a').format(DateTime.parse(date));
      } catch (e) {
        return "";
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, color: Color(0xFFF79009), size: 20),
              const SizedBox(width: 12),
              Text("order_timeline".tr,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _timelineRow(
              isDark, "order_placed".tr, formattedTime(data?['createdAt']),
              true),
          _timelineRow(
              isDark, "step_accepted".tr, formattedTime(data?['createdAt']),
              true),
          _timelineRow(isDark, "driver_on_way".tr, "In Progress", true,
              icon: Icons.access_time, iconColor: const Color(0xFFF79009)),
        ],
      ),
    );
  }

  Widget _timelineRow(bool isDark, String title, String time, bool isDone,
      {IconData? icon, Color? iconColor}) {
    Color success = const Color(0xFF12B76A);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone
                  ? (iconColor?.withValues(alpha: 0.1) ?? success.withValues(alpha: 0.1))
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey
                  .shade200),
              shape: BoxShape.circle,
            ),
            child: Icon(isDone && icon == null ? Icons.check_circle : (icon ??
                Icons.circle_outlined),
                color: isDone ? (iconColor ?? success) : const Color(
                    0xFF475467), size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: isDone
                          ? (isDark ? Colors.white : Colors.black)
                          : const Color(0xFF475467),
                      fontWeight: FontWeight.bold)),
              if (time.isNotEmpty)
                Text(time, style: TextStyle(
                    color: isDone ? (iconColor ?? success) : Colors.transparent,
                    fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNotesCard(bool isDark, Color cardBg, String notes, Color textGrey) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E90FA).withValues(alpha: 0.1)),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.note_alt_outlined, color: Color(0xFF2E90FA), size: 20),
              const SizedBox(width: 12),
              Text("order_notes".tr,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(notes,
              style: TextStyle(color: textGrey, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBottomNote(bool isDark, Color purple) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: purple, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text("order_details_note".tr,
                  style: TextStyle(
                      color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                          .shade700, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}