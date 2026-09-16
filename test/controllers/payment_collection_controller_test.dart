import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/features/orders/presentation/controllers/payment_collection_controller.dart';

void main() {
  group('PaymentCollectionController', () {
    test('initial isConfirmed is false', () {
      final controller = PaymentCollectionController();
      expect(controller.isConfirmed.value, false);
    });

    test('toggleConfirmation sets to true when value is true', () {
      final controller = PaymentCollectionController();
      controller.toggleConfirmation(true);
      expect(controller.isConfirmed.value, true);
    });

    test('toggleConfirmation sets to false when value is false', () {
      final controller = PaymentCollectionController();
      controller.toggleConfirmation(true);
      controller.toggleConfirmation(false);
      expect(controller.isConfirmed.value, false);
    });

    test('toggleConfirmation sets to false when value is null', () {
      final controller = PaymentCollectionController();
      controller.toggleConfirmation(true);
      controller.toggleConfirmation(null);
      expect(controller.isConfirmed.value, false);
    });
  });
}
