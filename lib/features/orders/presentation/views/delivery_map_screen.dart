import 'proof_of_delivery_screen.dart';
import 'package:delivery_app/core/widgets/active_order_pop_guard.dart';
import 'package:delivery_app/core/widgets/custom_leading.dart';
import 'package:delivery_app/data/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:delivery_app/core/map/map_styles.dart';
import 'package:delivery_app/core/map/marker_bitmap.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryMapScreen extends StatefulWidget {
  final Map<String, dynamic>? orderData;

  const DeliveryMapScreen({super.key, this.orderData});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  LatLng? customerLocation = const LatLng(0, 0);
  LatLng driverLocation = const LatLng(0, 0);
  // يصل من onMapCreated — لا يتوفّر قبل بناء الخريطة فعلياً
  GoogleMapController? _mapController;

  // أيقونتا العلامتين تُرسمان مرة واحدة عند الإقلاع لا مع كل تحديث موقع
  // (يصل كل 10 أمتار)، فرسمها صورةً نقطية أثقل من إعادة بناء widget.
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _customerIcon;
  final LocationService _location = Get.find<LocationService>();

  /// اشتراك على موقع الخدمة المركزية بدل فتح تيّار GPS ثانٍ.
  /// كان التيّاران (هذه الشاشة + HomeScreen) يعملان معاً أثناء التوصيل.
  Worker? _locationWorker;

  @override
  void initState() {
    super.initState();
    _extractLocations();
    _bindLocation();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    final driver = await MarkerBitmap.labeledPin(
      icon: Icons.navigation,
      color: const Color(0xFFFF5630),
      label: "marker_you".tr,
    );
    final customer = await MarkerBitmap.labeledPin(
      icon: Icons.location_on,
      color: const Color(0xFF2E90FA),
      label: "marker_customer".tr,
    );
    if (!mounted) return;
    setState(() {
      _driverIcon = driver;
      _customerIcon = customer;
    });
  }

  @override
  void dispose() {
    _locationWorker?.dispose();
    // GoogleMapController تتكفّل به الودجة نفسها عند إزالتها
    super.dispose();
  }

  Future<void> _bindLocation() async {
    // أثناء التوصيل يجب أن يكون الإرسال للسيرفر فعّالاً دائماً
    await _location.start(pushToServer: true);

    final initial = _location.currentLocation.value;
    if (initial != null && mounted) {
      setState(() => driverLocation = initial);
      _fitBounds();
    }

    _locationWorker = ever<LatLng?>(_location.currentLocation, (pos) {
      if (pos == null || !mounted) return;
      setState(() => driverLocation = pos);
    });
  }

  /// تحديث الموقع يدوياً وإعادة تركيز الكاميرا
  Future<void> _refreshMyLocation() async {
    final pos = await _location.refreshOnce(push: true);
    if (pos == null) {
      Get.snackbar("alert".tr, "enable_gps_msg".tr);
      return;
    }
    if (!mounted) return;
    setState(() => driverLocation = pos);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16.0));
  }

  /* AI Insight: حساب الحدود الجغرافية (Bounds) ديناميكياً لضمان رؤية السائق والزبون معاً في إطار واحد */
  void _fitBounds() {
    if (driverLocation.latitude == 0 || customerLocation == null || customerLocation!.latitude == 0) return;
    final a = driverLocation;
    final b = customerLocation!;
    final bounds = LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
    // فرق سلوكي مقصود: خرائط غوغل تقبل حشوة واحدة موحّدة فقط، بينما كانت
    // الحشوة السابقة غير متناظرة (180 أعلى لتفادي الترويسة). اخترنا 80
    // كوسط يُبقي النقطتين ظاهرتين تحت الترويسة.
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  /// استخراج إحداثيات الزبون من بيانات الطلب المستلمة
  void _extractLocations() {
    List? custCoords;
    final deliveryAddr = widget.orderData?['deliveryAddress'];

    if (deliveryAddr is Map) {
      if (deliveryAddr['location'] is Map) {
        custCoords = deliveryAddr['location']['coordinates'];
      } else if (deliveryAddr['location'] is List) {
        custCoords = deliveryAddr['location'];
      }
    }

    setState(() {
      if (custCoords != null && custCoords.length >= 2) {
        customerLocation = LatLng(custCoords[1], custCoords[0]);
      } else {
        customerLocation = null;
      }
    });

    if (customerLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Get.snackbar(
            "alert".tr,
            "customer_location_unavailable".tr,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final customerRaw = widget.orderData?['customer'] ?? widget.orderData?['userId'] ?? {};
    final user = customerRaw is Map ? customerRaw : {};
    final userName = user['name'] ?? "Customer";
    final userPhone = user['phone'];

    String deliveryAddress = "Address N/A";
    if (widget.orderData?['deliveryAddress'] is Map) {
      deliveryAddress =
          widget.orderData?['deliveryAddress']['fullAddress'] ?? "Address N/A";
    }

    final orderNote = widget.orderData?['notes'] ?? "no_note".tr;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;
    const accentOrange = Color(0xFFFF5630);
    const infoBlue = Color(0xFF2E90FA);
    final textGrey = isDark ? const Color(0xFF98A2B3) : Colors.grey.shade600;

    return ActiveOrderPopGuard(
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF101828) : Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isDark ? Colors.white : Colors.black87, isDark),
      body: Stack(
        children: [
          _buildRealMap(isDark),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              heroTag: "refresh_loc",
              backgroundColor: isDark ? const Color(0xFF1D2939) : Colors.white,
              onPressed: _refreshMyLocation,
              child: const Icon(Icons.my_location, color: accentOrange),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomDetailsPanel(
          isDark,
          cardColor,
          accentOrange,
          infoBlue,
          textGrey,
          userName,
          deliveryAddress,
          userPhone,
          orderNote),
      ),
    );
  }

  /// ويدجت بناء الخريطة مع دعم الوضع الليلي والخطوط المسارية
  Widget _buildRealMap(bool isDark) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: driverLocation.latitude != 0
            ? driverLocation
            : customerLocation ?? driverLocation,
        zoom: 14.5,
      ),
      onMapCreated: (controller) => _mapController = controller,
      // الوضع الليلي بتنسيق غوغل الأصلي بدل قلب ألوان البلاطات — القلب
      // السابق كان يعكس النصوص والأيقونات أيضاً فتصعب قراءتها.
      style: isDark ? MapStyles.dark : null,
      polylines: {
        if (driverLocation.latitude != 0 && customerLocation != null)
          Polyline(
            polylineId: const PolylineId('route'),
            points: [driverLocation, customerLocation!],
            color: const Color(0xFFFF5630),
            width: 6,
            // يقابل StrokePattern.dotted: نقطة قصيرة تليها فجوة
            patterns: [PatternItem.dot, PatternItem.gap(10)],
          ),
      },
      markers: {
        if (driverLocation.latitude != 0 && _driverIcon != null)
          Marker(
            markerId: const MarkerId('driver'),
            position: driverLocation,
            icon: _driverIcon!,
            anchor: const Offset(0.5, 0.5),
          ),
        if (customerLocation != null && _customerIcon != null)
          Marker(
            markerId: const MarkerId('customer'),
            position: customerLocation!,
            icon: _customerIcon!,
            anchor: const Offset(0.5, 0.5),
          ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  /// بناء شريط التطبيق العلوي الشفاف
  PreferredSizeWidget _buildAppBar(Color textColor, bool isDark) =>
      AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const Padding(
              padding: EdgeInsets.all(8.0),
              child: CustomLeading()),
          title: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("marker_customer".tr,
                style: TextStyle(color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text("delivering_sub".tr,
                style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 12))
          ]),
          actions: [
            _buildBadge(
                "in_transit_badge".tr, Colors.redAccent.withValues(alpha: 0.8)),
            const SizedBox(width: 15)
          ]);

  /// اللوحة السفلية التي تحتوي على معلومات الزبون وأزرار التحكم
  Widget _buildBottomDetailsPanel(bool isDark, Color cardColor,
      Color accentOrange, Color infoBlue,
      Color textGrey, String name, String address, String? phone,
      String note) =>
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101828) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30)),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildCustomerInfo(
                isDark,
                cardColor,
                accentOrange,
                infoBlue,
                textGrey,
                name,
                address,
                phone),
            const SizedBox(height: 16),
            _buildNoteSection(isDark, note),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _buildActionButton(
                      label: "navigate_customer_btn".tr,
                      icon: Icons.near_me_outlined,
                      color: infoBlue,
                      onTap: () {
                        // نستخدم customerLocation المستخرج من deliveryAddress.location.coordinates
                        // (نفس مصدر الخريطة) لضمان التطابق مع الباك إند.
                        if (customerLocation != null &&
                            customerLocation!.latitude != 0) {
                          final lat = customerLocation!.latitude;
                          final lng = customerLocation!.longitude;
                          launchUrl(Uri.parse(
                              "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng"));
                        } else {
                          Get.snackbar("alert".tr, "customer_location_missing".tr,
                              backgroundColor: Colors.orange, colorText: Colors.white);
                        }
                      })),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildActionButton(
                      label: "arrived_customer_btn".tr,
                      icon: Icons.location_on_outlined,
                      color: accentOrange,
                      onTap: () {
                        Get.to(() =>
                            ProofOfDeliveryScreen(
                                orderData: widget.orderData));
                      }))
            ])
          ]));

  /// ويدجت عرض بيانات الزبون وأزرار الاتصال
  Widget _buildCustomerInfo(bool isDark, Color cardColor, Color accentOrange,
      Color infoBlue, Color textGrey,
      String name, String address, String? phone) =>
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
              ]),
          child: Column(children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: infoBlue, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on_outlined, color: textGrey,
                          size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(address,
                              style: TextStyle(color: textGrey, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis))
                    ])
                  ]))
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _buildContactButton(
                      isDark, "call_btn".tr, Icons.phone_outlined,
                      accentOrange, () {
                    if (phone != null) launchUrl(Uri.parse("tel:$phone"));
                  })),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildContactButton(
                      isDark, "message_btn".tr, Icons.chat_bubble_outline,
                      accentOrange, () {
                    final phone = widget.orderData?['userId']?['phone'];
                    if (phone != null) {
                      launchUrl(Uri.parse("sms:$phone"));
                    }
                  }))
            ])
          ]));

  /// قسم الملاحظات الخاصة بالطلب (مثل: البناية، الطابق، إلخ)
  Widget _buildNoteSection(bool isDark, String note) {
    const goldColor = Color(0xFFB88E2F);
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1B16) : Colors.orange.shade50
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: goldColor.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("note_title".tr,
              style: const TextStyle(
                  color: goldColor, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(note,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  height: 1.4))
        ]));
  }

  Widget _buildContactButton(bool isDark, String label, IconData icon,
      Color color, VoidCallback onTap) =>
      ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: color),
          label: Text(label, style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.grey.shade100,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15))));

  Widget _buildActionButton(
      {required IconData icon, required String label, required Color color, required VoidCallback onTap}) =>
      ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 20),
          label:
          Text(label, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0));

  Widget _buildBadge(String text, Color color) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Text(text, style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)));

  /// بطاقة عائمة تعرض الوقت المقدر والمسافة المتبقية
}
