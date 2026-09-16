import 'package:get/get.dart';
import 'package:delivery_app/features/wallet/presentation/controllers/wallet_controller.dart';

class CashCollectionController extends GetxController {
  final isLoading = true.obs;
  final orders = [].obs;
  final summary = {}.obs;
  final selectedFilter = 'all'.obs;

  @override
  void onInit() {
    _loadFromWallet();
    super.onInit();
  }

  void _loadFromWallet() {
    final wallet = Get.find<WalletController>();
    orders.assignAll(wallet.cashOrders);
    summary.value = wallet.cashSummary;
    isLoading.value = false;

    ever(wallet.cashOrders, (data) {
      orders.assignAll(data);
    });
    ever(wallet.cashSummary, (data) {
      summary.value = data;
    });
  }

  List get filteredOrders {
    if (selectedFilter.value == 'all') return orders;
    return orders.where((o) =>
    o['driverPaymentStatus']
        .toString()
        .toLowerCase() == selectedFilter.value.toLowerCase()).toList();
  }
}