import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:delivery_app/core/widgets/shimmer_widgets.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/wallet_controller.dart';

class FinancialTransactionsScreen extends StatefulWidget {
  const FinancialTransactionsScreen({super.key});

  @override
  State<FinancialTransactionsScreen> createState() =>
      _FinancialTransactionsScreenState();
}

class _FinancialTransactionsScreenState
    extends State<FinancialTransactionsScreen> {
  String get _currency => Get.isRegistered<AuthController>()
      ? Get.find<AuthController>().currencySymbol
      : 'currency_syp'.tr;

  String _money(dynamic v) =>
      (num.tryParse('${v ?? 0}') ?? 0).toDouble().toStringAsFixed(2);

  /// أجر السائق الحقيقي لهذا الطلب.
  ///
  /// باك v4.2: هذا الراوت يُبقي `deliveryFee` = رسم الزبون (يصير 0 مع عرض
  /// توصيل مجاني) ويضع أجر السائق في `breakdown.deliveryFeeEarning` —
  /// بعكس `orders-history` الذي صار يضع الأجر في `deliveryFee` نفسه.
  /// قراءة `deliveryFee` هنا كانت تعرض +0.00 كأجر على طلبات العروض.
  String _earning(dynamic order) =>
      _money(order?['breakdown']?['deliveryFeeEarning'] ?? order?['deliveryFee']);

  String _netEffect(dynamic order) => _money(order?['breakdown']?['netEffect'] ??
      order?['breakdown']?['deliveryFeeEarning'] ??
      order?['deliveryFee']);

  int? expandedIndex = 0;
  final walletController = Get.find<WalletController>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF101828) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;
    const successGreen = Color(0xFF12B76A);
    const accentOrange = Color(0xFFFF5630);
    const infoBlue = Color(0xFF2E90FA);
    final textGrey = isDark ? const Color(0xFF98A2B3) : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
              Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Get.back(id: 1),
        ),
        title: Column(
          children: [
            Text(
              "financial_transactions_title".tr,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "complete_history_desc".tr,
              style: TextStyle(color: textGrey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: textGrey),
            onPressed: () {},
          ),
        ],
        centerTitle: true,
      ),
      body: Obx(() {
        if (walletController.isLoading.value &&
            walletController.transactions.isEmpty) {
          return const ShimmerTransactionsSkeleton();
        }

        final balances = walletController.balances;
        final earnings = walletController.earnings;
        final orders = walletController.transactions;

        return RefreshIndicator(
          onRefresh: () =>
              walletController.fetchFinancialTransactions(
                period: walletController.selectedPeriod.value,
              ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentBalanceCard(
                    isDark, balances['currentBalance'], successGreen),
                const SizedBox(height: 16),
                _buildHeldBalanceCard(
                    isDark, balances['restaurantHeldBalance'], textGrey),
                const SizedBox(height: 24),
                _buildEarningsSummary(
                    isDark, earnings, accentOrange, successGreen, textGrey),
                const SizedBox(height: 24),
                _buildHowItWorksBox(isDark, infoBlue, textGrey),
                const SizedBox(height: 24),
                _buildTimeFilters(isDark, accentOrange, cardColor, textGrey),
                const SizedBox(height: 24),
                Text(
                  "recent_transactions".tr,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (orders.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text("no_orders_found".tr, style: const TextStyle(
                          color: Colors.grey)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orders.length,
                    itemBuilder: (context, index) =>
                        _buildTransactionItem(
                          isDark,
                          index,
                          orders[index],
                          cardColor,
                          successGreen,
                          textGrey,
                        ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentBalanceCard(bool isDark, dynamic amount, Color green) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                        Icons.account_balance_wallet, color: green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "current_balance".tr,
                    style: TextStyle(color: green,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "${_money(amount)} $_currency",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "available_withdrawal".tr,
                style: TextStyle(color: green.withValues(alpha: 0.7), fontSize: 12),
              ),
            ],
          ),
          Icon(Icons.trending_up, color: green, size: 40),
        ],
      ),
    );
  }

  Widget _buildHeldBalanceCard(bool isDark, dynamic amount, Color textGrey) {
    const goldColor = Color(0xFFB88E2F);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1B16) : Colors.orange.shade50
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: goldColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.storefront, color: goldColor, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "restaurant_held_balance".tr,
                    style: TextStyle(
                        color: textGrey.withValues(alpha: 0.8), fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_money(amount)} $_currency",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey
                  .shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: goldColor, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "security_deposit_msg".tr,
                    style: TextStyle(color: goldColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSummary(bool isDark, dynamic earnings, Color orange,
      Color green, Color textGrey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("total_earnings".tr,
                  style: TextStyle(color: textGrey, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                "${_money(earnings['totalEarnings'])} $_currency",
                style: TextStyle(
                    color: orange, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "orders_count".trParams(
                    {'count': (earnings['ordersCount'] ?? 0).toString()}),
                style: TextStyle(color: textGrey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                "weekly_growth".trParams(
                    {'percent': (earnings['weeklyChange'] ?? 0).toString()}),
                style: TextStyle(
                    color: green, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksBox(bool isDark, Color blue, Color textGrey) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: blue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.attach_money, color: blue, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "how_cash_work".tr,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  Text("understanding_flow".tr,
                      style: TextStyle(color: textGrey, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1D2939).withValues(alpha: 0.5) : Colors
                  .grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildStep(isDark, 1, "step_1_title".tr, "step_1_desc".tr,
                    const Color(0xFF12B76A)),
                _buildStep(isDark, 2, "step_2_title".tr, "step_2_desc".tr,
                    const Color(0xFFB88E2F)),
                _buildStep(isDark, 3, "step_3_title".tr, "step_3_desc".tr, blue,
                    isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: blue.withValues(alpha: 0.2)),
            ),
            child: Text(
              "example_text".tr,
              style: TextStyle(
                  color: isDark ? blue.withValues(alpha: 0.8) : blue,
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(bool isDark, int num, String title, String desc,
      Color color,
      {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(
                child: Text(num.toString(),
                    style: TextStyle(color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc,
                    style: TextStyle(
                        color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                            .shade700,
                        fontSize: 12,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilters(bool isDark, Color orange, Color cardBg,
      Color textGrey) {
    final periods = {
      "all": "all_time".tr,
      "today": "earnings_today".tr,
      "week": "this_week".tr,
      "month": "this_month".tr
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.entries.map((e) {
          bool isSelected = walletController.selectedPeriod.value == e.key;
          return GestureDetector(
            onTap: () =>
                walletController.fetchFinancialTransactions(period: e.key),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  color: isSelected ? orange : cardBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(e.value,
                  style: TextStyle(
                      color: isSelected ? Colors.white : textGrey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionItem(bool isDark, int index, dynamic order,
      Color cardBg, Color green, Color textGrey) {
    bool isExpanded = expandedIndex == index;
    final bool isCash = (order['paymentMethod'] ?? 'Cash') == 'Cash';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: cardBg,
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
          GestureDetector(
            onTap: () =>
                setState(() => expandedIndex = isExpanded ? null : index),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isCash
                                    ? const Color(0xFFB88E2F)
                                    : Colors.green)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                  isCash ? Icons.account_balance_wallet : Icons
                                      .credit_card,
                                  color: isCash
                                      ? const Color(0xFFB88E2F)
                                      : Colors.green,
                                  size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment
                                        .center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text("Order #${order['orderNumber']}",
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.05)
                                                : Colors.black.withValues(alpha: 
                                                0.05),
                                            borderRadius: BorderRadius.circular(
                                                6)),
                                        child: Text(isCash
                                            ? "cash_label".tr
                                            : "online_label".tr,
                                            style: TextStyle(
                                                color: isCash ? const Color(
                                                    0xFFB88E2F) : Colors.green,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(order['restaurant']?['name'] ?? "—",
                                      style: TextStyle(
                                          color: textGrey, fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("+${_earning(order)} $_currency",
                              style:
                              TextStyle(color: green,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text("your_earning".tr, style: TextStyle(
                              color: textGrey, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM d, h:mm a').format(
                          DateTime.parse(order['createdAt'])),
                          style: TextStyle(
                              color: isDark ? Colors.white24 : Colors.black26,
                              fontSize: 12)),
                      Icon(isExpanded ? Icons.keyboard_arrow_up : Icons
                          .keyboard_arrow_down,
                          color: isDark ? Colors.white24 : Colors.black26,
                          size: 22),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildMiniBox(isDark, "order_value".tr,
                            "${_money(order['itemsPrice'])} $_currency",
                            isDark ? const Color(0xFF101828) : Colors.grey
                                .shade100),
                        const SizedBox(width: 8),
                        _buildMiniBox(
                            isDark, "delivery_fee_label".tr,
                            "${_money(order['deliveryFee'])} $_currency",
                            isDark ? const Color(0xFF101828) : Colors.grey
                                .shade100),
                        const SizedBox(width: 8),
                        _buildMiniBox(isDark, "deducted_label".tr,
                            "-${_money(order['itemsPrice'])} $_currency",
                            const Color(0xFFF79009).withValues(alpha: 0.1),
                            textColor: const Color(0xFFF79009)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildBreakdownSection(isDark, order, green),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(bool isDark, dynamic order, Color green) {
    final dividerColor = isDark ? Colors.white10 : Colors.black12;
    final valueStyle =
    TextStyle(color: isDark ? Colors.white : Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 
                  0.05))),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Color(0xFFFF5630),
                  size: 18),
              const SizedBox(width: 12),
              Text("complete_breakdown".tr,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 20),
          _buildRow(
              "order_value".tr, "${_money(order['itemsPrice'])} $_currency", valueStyle,
              isDark),
          const SizedBox(height: 12),
          _buildRow(
              "delivery_fee_earning".tr, "+${_earning(order)} $_currency",
              valueStyle.copyWith(color: green), isDark),
          Divider(color: dividerColor, height: 24),
          _buildRow("deducted_from_rest".tr, "-${_money(order['itemsPrice'])} $_currency",
              valueStyle.copyWith(color: const Color(0xFFF79009)), isDark),
          const SizedBox(height: 8),
          Text("deduction_desc".tr,
              style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black38,
                  fontSize: 10,
                  height: 1.4)),
          Divider(color: dividerColor, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("net_effect".tr,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Text("+${_netEffect(order)} $_currency",
                  style: TextStyle(
                      color: green, fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String val, TextStyle vStyle, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: isDark ? const Color(0xFF98A2B3) : Colors.grey.shade600,
                fontSize: 14)),
        Text(val, style: vStyle),
      ],
    );
  }

  Widget _buildMiniBox(bool isDark, String label, String val, Color bg,
      {Color textColor = Colors.white}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(label,
              style:
              TextStyle(color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                  .shade600, fontSize: 10)),
          const SizedBox(height: 6),
          Text(val,
              style: TextStyle(
                  color: isDark ? textColor : (textColor == Colors.white
                      ? Colors.black
                      : textColor),
                  fontWeight: FontWeight.bold,
                  fontSize: 14))
        ]),
      ),
    );
  }
}