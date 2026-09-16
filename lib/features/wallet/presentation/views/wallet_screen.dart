import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../navigation/presentation/controllers/navigation_controller.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../controllers/wallet_controller.dart';
import 'settlement_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  /// تنسيق آمن للمبالغ — قيم JSON قد تصل String فيكسرها toStringAsFixed.
  static String _money(dynamic v) {
    final n = v is num ? v : num.tryParse('${v ?? ''}');
    return (n ?? 0).toDouble().toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final walletController = Get.put(WalletController());
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF101828) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;
    const accentOrange = Color(0xFFFF5630);
    final textGrey = isDark ? const Color(0xFF98A2B3) : Colors.grey.shade600;
    const successGreen = Color(0xFF12B76A);
    const warningGold = Color(0xFFFF5630);

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
          children: [
            Text(
              "wallet_title".tr,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "financial_overview".tr,
              style: TextStyle(color: textGrey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.account_balance_wallet_outlined, color: textGrey),
            onPressed: () {},
          ),
        ],
        centerTitle: true,
      ),
      body: Obx(() {
        if (walletController.isLoading.value &&
            walletController.walletSummary.isEmpty) {
          return const ShimmerWalletSkeleton();
        }

        final summary = walletController.walletSummary;
        final bool isCashDriver = summary['isCashDriver'] ?? true;

        final num todayTotal = summary['totalCollectedToday'] ??
            summary['todayEarnings'] ?? 0.0;
        final String formattedTodayTotal = _money(todayTotal);

        final double collected =
            (num.tryParse('${summary['cashCollected'] ?? 0}') ?? 0)
                .toDouble();
        // لا افتراض وهمي للحد: 0 أو مفقود يعني أن الأدمن لم يحدد حداً بعد
        final double limit =
            (num.tryParse('${summary['cashCreditLimit'] ?? 0}') ?? 0)
                .toDouble();
        final bool hasLimit = limit > 0;

        // الباك يرسل limitUsagePercent (0-100) — نعتمده مع fallback محلي
        final double percent = hasLimit
            ? (((summary['limitUsagePercent'] as num?)?.toDouble() ??
                    ((collected / limit) * 100))
                .clamp(0.0, 100.0)) /
                100.0
            : 0.0;

        // علم التجاوز من الباك مع fallback محلي — بدل إظهار تحذير دائم
        final bool isExceeded = summary['isLimitExceeded'] ??
            (hasLimit && collected >= limit);

        final String cashAmount = collected.toStringAsFixed(2);

        // ما يجب إيداعه فعلاً = المحصَّل ناقص أجرة السائق. الباك يحسبه في
        // getWallet باسم cashHeldForSettlement؛ كانت شاشة التسوية تستقبل
        // cashCollected فتطالب السائق بإيداع أجرته هو أيضاً.
        final String settlementAmount =
            _money(summary['cashHeldForSettlement'] ?? collected);

        // عدد الطلبات المنتظرة للتسوية — يرسله الباك ولم يكن مستخدماً
        final int pendingOrdersCount =
            (num.tryParse('${summary['pendingOrdersCount'] ?? 0}') ?? 0).toInt();
        final num remaining = hasLimit ? (limit - collected).clamp(0, limit) : 0;

        return RefreshIndicator(
          onRefresh: () => walletController.fetchAllWalletData(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildMainTotalCard(
                  accentOrange,
                  amount: formattedTodayTotal,
                  count: (summary['todayOrdersCount'] ?? 0).toString(),
                ),
                const SizedBox(height: 16),
                if (isCashDriver && hasLimit)
                  _buildDepositLimitCard(
                    isDark,
                    cardColor,
                    amount: cashAmount,
                    percent: percent,
                    limit: limit.toStringAsFixed(0),
                    remaining: remaining.toStringAsFixed(2),
                    isExceeded: isExceeded,
                  ),
                if (isCashDriver && !hasLimit)
                  _buildNoLimitCard(isDark, cardColor, cashAmount),
                const SizedBox(height: 16),
                _buildEarningsCard(
                  isDark,
                  cardColor,
                  amount: _money(summary['pendingDeliveryFee'] ??
                      summary['pendingEarnings']),
                ),
                const SizedBox(height: 16),
                if (isCashDriver)
                  _buildCashHeldCard(
                    isDark,
                    amount: _money(summary['cashHeldForSettlement']),
                    pendingOrdersCount: pendingOrdersCount,
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildSquareAction(
                      isDark,
                      cardColor,
                      Icons.access_time,
                      "view_transactions".tr,
                      "complete_history".tr,
                      warningGold,
                      onTap: () =>
                          Get.toNamed('/financial-transactions', id: 1),
                    ),
                    const SizedBox(width: 12),
                    _buildSquareAction(
                      isDark,
                      cardColor,
                      Icons.trending_up,
                      "settle_balance".tr,
                      "process_deposit".tr,
                      successGreen,
                      onTap: () =>
                          Get.to(() => const SettlementScreen(),
                              arguments: settlementAmount),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (isCashDriver)
                  _buildLargeActionButton(
                    accentOrange,
                    amount: settlementAmount,
                    onPressed: () =>
                        Get.to(() => const SettlementScreen(),
                            arguments: settlementAmount),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMainTotalCard(Color color,
      {required String amount, required String count}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5630), Color(0xFFFF8B66)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4),
              blurRadius: 25,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                  Icons.account_balance_wallet, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                "total_collected_today".tr,
                style: const TextStyle(color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "$amount ل.س",
            style: const TextStyle(
                color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
          ),
          Text(
            "from_cash_orders".trParams({'count': count}),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositLimitCard(bool isDark, Color cardBg,
      {required String amount,
      required double percent,
      required String limit,
      required String remaining,
      required bool isExceeded}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF79009).withValues(alpha: 0.2)),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF79009).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                    Icons.warning_amber_rounded, color: Color(0xFFF79009),
                    size: 24),
              ),
              const SizedBox(width: 16),
              // Expanded يمنع تجاوز المبلغ الطويل لحلقة النسبة الثابتة العرض
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "to_be_deposited".tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: isDark ? const Color(0xFF98A2B3) : Colors
                              .grey.shade600, fontSize: 13),
                    ),
                    // FittedBox يصغّر المبلغ تلقائياً بدل كسر التخطيط
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "$amount ل.س",
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 28,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors
                          .black.withValues(alpha: 0.05),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: percent,
                      strokeWidth: 6,
                      color: const Color(0xFFF79009),
                    ),
                  ),
                  Text(
                    "${(percent * 100).toInt()}%",
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // تحذير التجاوز يظهر فقط عندما يفعل الباك isLimitExceeded —
          // سابقاً كان ظاهراً دائماً حتى دون أي تجاوز
          if (isExceeded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF79009).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                      Icons.access_time, color: Color(0xFFF79009), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "exceeded_threshold_msg".tr,
                      style: const TextStyle(
                          color: Color(0xFFF79009), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Expanded + ellipsis يمنع تجاوز النصين الطويلين معاً
              Expanded(
                child: Text(
                  "limit_label".trParams({'limit': "$limit ل.س"}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                          .shade600, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "remaining_label".trParams({'amount': "$remaining ل.س"}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFF79009),
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بطاقة «بلا حد» — تظهر عندما يكون cashCreditLimit = 0 أي أن الأدمن
  /// لم يحدد حداً ائتمانياً للسائق بعد، فلا معنى لحلقة نسبة مئوية فارغة.
  Widget _buildNoLimitCard(bool isDark, Color cardBg, String amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: const Color(0xFF12B76A).withValues(alpha: 0.2)),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF12B76A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.all_inclusive,
                color: Color(0xFF12B76A), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            "no_limit_label".tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          Text(
            "to_be_deposited".tr,
            style: TextStyle(
                color: isDark ? const Color(0xFF98A2B3) : Colors
                    .grey.shade600, fontSize: 13),
          ),
        ],
      ),
    ),
    const SizedBox(width: 12),
    // FittedBox يمنع تجاوز المبلغ الطويل عند حافة البطاقة
    FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        "$amount ل.س",
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold),
      ),
    ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(bool isDark, Color cardBg,
      {required String amount}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12B76A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                    Icons.attach_money, color: Color(0xFF12B76A), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "your_earnings_label".tr,
                      style: TextStyle(
                          color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                              .shade600, fontSize: 13),
                    ),
                    Text(
                      "$amount ل.س",
                      style: const TextStyle(color: Color(0xFF12B76A),
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF12B76A).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF12B76A).withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check, color: Color(0xFF12B76A), size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "earnings_msg".tr,
                    style: const TextStyle(color: Color(0xFF12B76A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashHeldCard(bool isDark,
      {required String amount, int pendingOrdersCount = 0}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFFF79009).withValues(alpha: 0.05) : Colors
            .orange.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF79009).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF79009).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                    Icons.account_balance_outlined, color: Color(0xFFF79009),
                    size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pendingOrdersCount > 0
                          ? "${"cash_held_label".tr} · ${"pending_orders_count".trParams({'count': '$pendingOrdersCount'})}"
                          : "cash_held_label".tr,
                      style: TextStyle(
                          color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                              .shade600, fontSize: 13),
                    ),
                    Text(
                      "$amount ل.س",
                      style: const TextStyle(color: Color(0xFFF79009),
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey
                  .shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                    Icons.info_outline, color: Color(0xFFF79009), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "cash_disclaimer".tr,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                          .shade700,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Get.toNamed('/cash-collection', id: 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF79009).withValues(alpha: 0.2),
              foregroundColor: const Color(0xFFF79009),
              elevation: 0,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text("view_cash_collections".tr,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareAction(bool isDark, Color cardBg, IconData icon,
      String title, String sub, Color color,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark ? [] : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: TextStyle(
                    color: isDark ? const Color(0xFF98A2B3) : Colors.grey
                        .shade600, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeActionButton(Color color,
      {required String amount, VoidCallback? onPressed}) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: Text(
          "settle_now_btn".trParams({'amount': "$amount ل.س"}),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}