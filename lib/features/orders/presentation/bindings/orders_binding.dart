import 'package:get/get.dart';
import '../controllers/orders_history_controller.dart';
import '../controllers/new_order_controller.dart';
import '../controllers/past_order_details_controller.dart';
import '../controllers/payment_collection_controller.dart';

class OrdersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OrdersHistoryController>(() => OrdersHistoryController());
    Get.lazyPut<NewOrderController>(() => NewOrderController());
    Get.lazyPut<PastOrderDetailsController>(() => PastOrderDetailsController());
    Get.lazyPut<PaymentCollectionController>(() =>
        PaymentCollectionController());
  }
}