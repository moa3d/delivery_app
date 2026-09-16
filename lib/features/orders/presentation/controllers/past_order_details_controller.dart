import 'dart:developer';

import 'package:delivery_app/data/api_client/dio_client.dart';
import 'package:get/get.dart';

/// نقطة النداء الوحيدة لـ `api/driver/orders/:id`.
///
/// كانت الشاشة الحيّة (`OrderDetailsScreen`) تنادي نفس الراوت بـ Dio خام
/// داخل StatefulWidget بموازاة هذا المتحكم — نسختان تتفرّقان عند أي تغيير
/// في شكل الرد.
Future<Map<String, dynamic>?> fetchDriverOrderDetails(String orderId) async {
  try {
    final response =
        await DioClient().instance.get("api/driver/orders/$orderId");
    if (response.statusCode == 200 && response.data['success'] == true) {
      final order = response.data['order'];
      if (order is Map) return Map<String, dynamic>.from(order);
    }
  } catch (e) {
    log("🔥 Error fetching details: $e");
  }
  return null;
}

class PastOrderDetailsController extends GetxController {
  var isLoading = false.obs;
  var orderDetails = {}.obs;

  // دالة يتم استدعاؤها من شاشة السجل قبل الانتقال
  void setOrderAndFetch(String orderId) {
    orderDetails.value = {}; // مسح البيانات القديمة
    fetchOrderDetails(orderId);
  }

  Future<void> fetchOrderDetails(String orderId) async {
    isLoading.value = true;
    final order = await fetchDriverOrderDetails(orderId);
    if (order != null) orderDetails.value = order;
    isLoading.value = false;
  }
}