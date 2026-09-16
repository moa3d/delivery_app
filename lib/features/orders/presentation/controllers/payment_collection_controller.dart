import 'package:get/get.dart';

class PaymentCollectionController extends GetxController {
  // حالة تأكيد الاستلام
  var isConfirmed = false.obs;

  void toggleConfirmation(bool? value) {
    isConfirmed.value = value ?? false;
  }
}