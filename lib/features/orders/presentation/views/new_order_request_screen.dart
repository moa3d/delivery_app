import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/new_order_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../data/services/location_service.dart';

class NewOrderRequestScreen extends StatefulWidget {
  const NewOrderRequestScreen({super.key});

  /// أجر السائق من حمولة العرض.
  ///
  /// الترتيب مقصود: `deliveryFee` هو رسم الزبون، ويصير **صفراً** على أي طلب
  /// فيه عرض توصيل مجاني بينما يتقاضى السائق أجره كاملاً من
  /// `originalDeliveryFee` (الأدمن يتحمّل الفرق — راجع
  /// backendNUMNOW/controllers/driver.controller.js:1555). قراءته أولاً كانت
  /// ستعرض 0.00 بدل الأجر الحقيقي لحظة إضافة الباك للحقول.
  ///
  /// الباك لا يرسل أياً منها اليوم في `order:driverRequest`، فتعود "—".
  /// راجع BACKEND_TASK_driver_offer_data.md البند (1).
  static String earningOf(dynamic data) => _fmtMoney(
        data?['driverEarning'] ??
            data?['originalDeliveryFee'] ??
            data?['deliveryFee'],
      );

  /// تنسيق مبلغ مالي — "—" عند غياب القيمة بدل 0.00 الوهمي.
  static String _fmtMoney(dynamic v) {
    if (v == null) return "—";
    final n = num.tryParse(v.toString());
    return n == null ? "—" : n.toDouble().toStringAsFixed(2);
  }


  @override
  State<NewOrderRequestScreen> createState() => _NewOrderRequestScreenState();
}

class _NewOrderRequestScreenState extends State<NewOrderRequestScreen> {
  final controller = Get.put(NewOrderController());

  String _getCurrency() {
    if (!Get.isRegistered<AuthController>()) return "";
    final country =
        Get.find<AuthController>().driverData['country']?.toString() ?? "SY";
    switch (country) {
      case 'DE': return "currency_eur".tr;
      case 'US': return "currency_usd".tr;
      default: return "currency_syp".tr;
    }
  }

  @override
  void initState() {
    super.initState();
    final dynamic rawData = Get.arguments;

    final int timeout = (rawData is Map && rawData['timeoutSeconds'] != null)
        ? (int.tryParse(rawData['timeoutSeconds'].toString()) ?? 25)
        : 25;

    // العدّاد يملكه المتحكّم الآن — مصدر واحد للحقيقة، ويُلغى فوراً
    // عند القبول فلا يُطلق رفضاً بعد قرار القبول.
    controller.startRequest(
      orderId: _extractOrderId(rawData),
      timeoutSeconds: timeout,
    );
  }

  String _extractOrderId(dynamic rawData) {
    if (rawData is! Map) return "";
    return rawData['orderId']?.toString() ??
        rawData['_id']?.toString() ??
        rawData['order']?['_id']?.toString() ??
        rawData['id']?.toString() ?? "";
  }

  // ─────────────────────────────────────────────────────────
  // استخراج بيانات العرض.
  // الباك حالياً لا يرسل في order:driverRequest إلا: orderId, orderNumber,
  // restaurantLocation, deliveryAddress, totalPrice, items, timeoutSeconds —
  // لذا نحسب ما يمكن حسابه محلياً ونعرض "—" لما يستحيل حسابه بدل قيم وهمية.
  // ─────────────────────────────────────────────────────────

  /// إحداثيات [lng, lat] من كائن GeoJSON أو مصفوفة مباشرة.
  static List? _coordsOf(dynamic geoPoint) {
    if (geoPoint is Map && geoPoint['coordinates'] is List) {
      final c = geoPoint['coordinates'] as List;
      return c.length >= 2 ? c : null;
    }
    if (geoPoint is List && geoPoint.length >= 2) return geoPoint;
    return null;
  }

  /// اسم المطعم: من الـ payload إن وُجد، وإلا بمطابقة إحداثيات المطعم
  /// مع قائمة المطاعم المحمّلة مسبقاً في الشاشة الرئيسية، وإلا "—".
  static String _resolveRestaurantName(dynamic data) {
    final direct = data?['restaurantName']?.toString() ??
        data?['restaurantId']?['name']?.toString();
    if (direct != null &&
        direct.trim().isNotEmpty &&
        direct != 'null' &&
        direct != '—') {
      return direct;
    }

    final coords = _coordsOf(data?['restaurantLocation']);
    if (coords != null && Get.isRegistered<AuthController>()) {
      try {
        final restaurants = Get.find<AuthController>().nearbyRestaurants;
        double? bestDist;
        String? bestName;
        for (final r in restaurants) {
          final d = GeoUtils.distanceKm(coords, _coordsOf(r['location']));
          if (d == null) continue;
          final n = r['name']?.toString();
          if (n == null || n.trim().isEmpty) continue;
          if (bestDist == null || d < bestDist) {
            bestDist = d;
            bestName = n;
          }
        }
        if (bestName != null) return bestName;
      } catch (_) {
        // فشل الاستنتاج ليس حرجاً — نظهر "—" فقط
      }
    }
    return "—";
  }

  /// تنسيق مسافة بالكيلومتر — "—" حين يتعذّر الحساب (لا إصلاح GPS بعد،
  /// أو إحداثيات ناقصة/غير صالحة كما تُرجعها GeoUtils).
  static String _fmtDistance(double? km) =>
      km == null ? "—" : "${km.toStringAsFixed(1)} ${"km_unit".tr}";

  /// تنسيق وقت بالدقائق — "—" عند غياب القيمة بدل أرقام افتراضية.
  static String _fmtTime(dynamic v) {
    if (v == null) return "—";
    final n = num.tryParse(v.toString());
    return n == null ? "—" : n.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF101828) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
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
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildTimerBadge(),
              const SizedBox(height: 30),
              Expanded(
                // Obx ضروري: موقع السائق (LocationService.currentLocation)
                // وقائمة المطاعم (nearbyRestaurants) قد يصلمان "بعد" رسم
                // هذه الشاشة — بدون التفاعلية تبقى المسافة والاسم "—"
                // طوال مهلة القرار رغم توفر البيانات خلال ثوانٍ.
                child: Obx(() {
                  final dynamic liveArgs = Get.arguments;
                  final dynamic liveData = (liveArgs is Map &&
                          liveArgs.containsKey('order'))
                      ? liveArgs['order']
                      : liveArgs;

                  final restaurantName = _resolveRestaurantName(liveData);

                  final restaurantCoords =
                      _coordsOf(liveData?['restaurantLocation']);
                  final deliveryCoords = _coordsOf(
                      liveData?['deliveryAddress'] is Map
                          ? liveData?['deliveryAddress']?['location']
                          : null);

                  // قراءة داخل Obx لضمان إعادة الحساب مع كل إصلاح GPS جديد
                  final driverPos = Get.isRegistered<LocationService>()
                      ? Get.find<LocationService>().currentLocation.value
                      : null;

                  final distToRestaurant = driverPos == null
                      ? null
                      : GeoUtils.distanceKm([
                          driverPos.longitude,
                          driverPos.latitude
                        ], restaurantCoords);
                  final deliveryDistance = GeoUtils.distanceKm(
                      restaurantCoords, deliveryCoords);

                  // الأجر لا يرسله الباك في العرض حالياً — نظهر "—" حتى يُضاف للباك
                  final earnings = NewOrderRequestScreen.earningOf(liveData);

                  // deliveryTime كان يُقرأ ويُمرَّر ولا يُعرض أبداً، ولا مفتاح
                  // ترجمة له — حُذف. الصفّان أدناه يبقيان بانتظار رد الباك
                  // على البند (2) من BACKEND_TASK_driver_offer_data.md.
                  final prepTime = _fmtTime(liveData?['prepTime']);
                  final totalTime = _fmtTime(liveData?['estimatedTotalTime']);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildMainCard(
                            isDark,
                            restaurantName,
                            earnings,
                            _fmtDistance(distToRestaurant),
                            cardColor,
                            prepTime,
                            _fmtDistance(deliveryDistance),
                            totalTime),
                        const SizedBox(height: 30),
                        _buildActionButtons(),
                        const SizedBox(height: 25),
                        Text("busy_status_msg".tr,
                            style: const TextStyle(color: Color(0xFF98A2B3),
                                fontSize: 14)),
                      ],
                    ),
                  );
                }),
              ),
              _buildFakeBottomNav(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4A341A).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFF79009).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                  Icons.timer_outlined, color: Color(0xFFF79009), size: 16),
              const SizedBox(width: 8),
              Text("respond_in".tr, style: const TextStyle(
                  color: Color(0xFFF79009),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
            ],
          ),
          Obx(() =>
              Text("${controller.timeLeft.value}s",
                  style: const TextStyle(color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildMainCard(bool isDark, String name, String earnings, String dist,
      Color cardColor, String prepTime, String deliveryDist, String totalTime) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B44),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF6B44).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5)
              ],
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 24),
          Text("new_order_req".tr, style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 16)),
          const SizedBox(height: 32),
          _infoRow(
              isDark, Icons.near_me, const Color(0xFF2E90FA), "dist_to_rest".tr,
              dist),
          const SizedBox(height: 16),
          _infoRow(isDark, Icons.access_time_filled, const Color(0xFFF79009),
              "prep_time".tr,
              prepTime == "—" ? "—" : "$prepTime ${"min_unit".tr}"),
          const SizedBox(height: 16),
          _infoRow(isDark, Icons.location_on, const Color(0xFF7F56D9),
              "deliv_dist".tr, deliveryDist),
          const SizedBox(height: 32),
          _buildEarningBox(isDark, earnings),
          const SizedBox(height: 24),
          Divider(color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text("est_total_time".tr,
                    style: const TextStyle(
                        color: Color(0xFF98A2B3), fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                    totalTime == "—" ? "—" : "$totalTime ${"min_unit".tr}",
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(bool isDark, IconData icon, Color color, String title,
      String val) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                    color: Color(0xFF98A2B3), fontSize: 11)),
                Text(val, style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningBox(bool isDark, String earnings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF79009).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF79009).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF4A341A),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(
                Icons.attach_money, color: Color(0xFFF79009), size: 24),
          ),
          const SizedBox(width: 16),
          // Expanded ضروري: بدونه يأخذ العمود عرضه الطبيعي فيطفح الصندوق.
          // ظهر فور وصول driverEarning من باك v4.2 — مع "—" كان النص قصيراً
          // فلم تظهر المشكلة، ومع "1000.00 ل.س" بحجم 28 عريض تجاوز العرض.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("your_earning".tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFF79009),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                // FittedBox يصغّر المبالغ الكبيرة (الليرة السورية) بدل قصّها
                // أو لفّها على سطرين
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                      earnings == "—" ? "—" : "$earnings ${_getCurrency()}",
                      maxLines: 1,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Obx(() => Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 60,
            child: OutlinedButton(
              onPressed: () => controller.declineOrder(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFF04438), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.close, color: Color(0xFFF04438), size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text("decline_btn".tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFF04438),
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF6B44).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8))
              ],
            ),
            child: ElevatedButton(
              onPressed: controller.isProcessing.value
                  ? null
                  : () => controller.acceptOrder(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text("accept_btn".tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ));
  }

  Widget _buildFakeBottomNav(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D2939) : Colors.white,
          border: Border(top: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_filled, "Home".tr, true),
          _navItem(
              Icons.account_balance_wallet_outlined, "wallet_title".tr, false),
          _navItem(Icons.assignment_outlined, "orders_history_title".tr, false),
          _navItem(Icons.settings_outlined, "settings_title".tr, false),
        ],
      ),
    );
  }

  /// Expanded لأن العناصر الأربعة بعناوين عربية طويلة («سجل الطلبات»)
  /// كانت تتجاوز عرض الشاشات الضيّقة
  Widget _navItem(IconData icon, String label, bool active) {
    final color =
        active ? const Color(0xFFFF6B44) : const Color(0xFF98A2B3);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}
