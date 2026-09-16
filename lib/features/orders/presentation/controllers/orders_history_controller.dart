import 'dart:developer';

import 'package:delivery_app/data/api_client/dio_client.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class OrdersHistoryController extends GetxController {
  final _dio = DioClient().instance;

  var isLoading = false.obs;
  var orders = [].obs;

  // إحصائيات اليوم
  var todayOrdersCount = 0.obs;
  var todayEarnings = 0.0.obs;
  var totalOrdersCount = 0.obs;

  // فلاتر البحث
  var selectedStatus = "all".obs; // all, completed, cancelled
  var selectedDate = "".obs; // YYYY-MM-DD

  @override
  void onInit() {
    super.onInit();
    fetchOrdersHistory();
  }

  Future<void> fetchOrdersHistory() async {
    try {
      isLoading.value = true;

      Map<String, dynamic> queryParams = {
        "status": selectedStatus.value,
      };

      if (selectedDate.value.isNotEmpty) {
        queryParams["date"] = selectedDate.value;
      }

      var response = await _dio.get(
          "api/driver/orders-history", queryParameters: queryParams);

      if (response.statusCode == 200 && response.data['success']) {
        orders.value = response.data['orders'];
        todayOrdersCount.value = response.data['today']['ordersCount'];
        todayEarnings.value =
            (response.data['today']['earnings'] as num).toDouble();
        totalOrdersCount.value = response.data['totalOrdersCount'];
      }
    } catch (e) {
      log("Error fetching history: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void updateStatusFilter(String status) {
    selectedStatus.value = status;
    fetchOrdersHistory();
  }

  void updateDateFilter(DateTime date) {
    selectedDate.value = DateFormat('yyyy-MM-dd').format(date);
    fetchOrdersHistory();
  }

  void clearDateFilter() {
    selectedDate.value = "";
    fetchOrdersHistory();
  }
}