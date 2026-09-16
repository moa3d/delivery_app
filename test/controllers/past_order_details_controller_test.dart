import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/features/orders/presentation/controllers/past_order_details_controller.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    setUpGetTestMode();
  });

  tearDown(() {
    resetDioInterceptors();
    tearDownGetTestMode();
  });

  group('PastOrderDetailsController', () {
    test('initial state has correct defaults', () {
      final controller = PastOrderDetailsController();
      expect(controller.isLoading.value, false);
      expect(controller.orderDetails.isEmpty, true);
    });

    test('fetchOrderDetails loads order from API', () async {
      mockDioGet('api/driver/orders/', {
        'success': true,
        'order': {
          '_id': 'ord1', 'orderNumber': 'ORD-001',
          'status': 'delivered', 'totalPrice': 15000,
        },
      });
      final controller = PastOrderDetailsController();
      await controller.fetchOrderDetails('ord1');
      expect(controller.orderDetails['_id'], 'ord1');
      expect(controller.isLoading.value, false);
    });

    test('fetchOrderDetails handles error gracefully', () async {
      mockDioGet('api/driver/orders/', {
        'success': false,
        'order': null,
      });
      final controller = PastOrderDetailsController();
      await controller.fetchOrderDetails('invalid_id');
      expect(controller.orderDetails.isEmpty, true);
      expect(controller.isLoading.value, false);
    });

    test('setOrderAndFetch clears details then fetches', () async {
      mockDioGet('api/driver/orders/', {
        'success': true,
        'order': {'_id': 'ord2', 'orderNumber': 'ORD-002'},
      });
      final controller = PastOrderDetailsController();
      controller.orderDetails.value = {'_id': 'stale'};
      controller.setOrderAndFetch('ord2');
      expect(controller.orderDetails.isEmpty, true);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(controller.orderDetails['_id'], 'ord2');
    });
  });
}
