import 'dart:developer';

import 'package:get/get.dart';
import 'package:delivery_app/data/api_client/dio_client.dart';

class WalletController extends GetxController {
  final _dio = DioClient().instance;

  //  للبيانات
  var isLoading = false.obs;

  // بيانات الشاشة الأولى
  var walletSummary = {}.obs;

  // بيانات الشاشة الثانية
  var cashOrders = [].obs;
  var cashSummary = {}.obs;

  // بيانات الشاشة الثالثة
  var transactions = [].obs;
  var balances = {}.obs;
  var earnings = {}.obs;
  var selectedPeriod = "all".obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllWalletData();
  }


  var selectedCashFilter = 'all'.obs;

  List get filteredCashOrders {
    if (selectedCashFilter.value == 'all') return cashOrders;
    return cashOrders.where((o) =>
    (o is Map) &&
    (o['driverPaymentStatus']?.toString() ?? '').toLowerCase() ==
        selectedCashFilter.value.toLowerCase()).toList();
  }
  Future<void> fetchAllWalletData() async {
    await Future.wait([
      fetchWalletSummary(),
      fetchCashOrders(),
      fetchFinancialTransactions(),
    ]);
  }

  // 1. جلب ملخص المحفظة (getWallet)
  Future<void> fetchWalletSummary() async {
    try {
      isLoading.value = true;
      var response = await _dio.get("api/driver/wallet");
      if (response.statusCode == 200 && response.data['success']) {
        walletSummary.value = response.data['wallet'];
      }
    } catch (e) {
      log("Error fetching wallet: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // 2. جلب الطلبات النقدية (getDriverCashOrders)
  Future<void> fetchCashOrders() async {
    try {
      var response = await _dio.get("api/driver/cash-orders");
      if (response.statusCode == 200 && response.data['success']) {
        cashOrders.value = response.data['orders'] ?? [];
        cashSummary.value = response.data['summary'];
      }
    } catch (e) {
      log("Error fetching cash orders: $e");
    }
  }

  // 3. جلب المعاملات المالية
  Future<void> fetchFinancialTransactions({String period = "all"}) async {
    try {
      selectedPeriod.value = period;
      var response = await _dio.get("api/driver/financial-transactions",
          queryParameters: {"period": period});
      if (response.statusCode == 200 && response.data['success']) {
        transactions.value = response.data['orders'];
        balances.value = response.data['balances'];
        earnings.value = response.data['earnings'];
      }
    } catch (e) {
      log("Error fetching transactions: $e");
    }
  }
}