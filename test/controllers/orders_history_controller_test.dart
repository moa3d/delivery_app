import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/features/orders/presentation/controllers/orders_history_controller.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    setUpGetTestMode();
  });

  tearDown(() {
    resetDioInterceptors();
    tearDownGetTestMode();
  });

  group('OrdersHistoryController', () {
    test('initial state has correct defaults', () async {
      final controller = OrdersHistoryController();
      // Let onInit async settle without mock (will fail silently)
      await Future.delayed(Duration.zero);
      expect(controller.isLoading.value, false);
      expect(controller.orders.length, 0);
      expect(controller.selectedStatus.value, 'all');
      expect(controller.selectedDate.value, '');
    });

    test('fetchOrdersHistory loads orders from API', () async {
      mockDioGet('orders-history', {
        'success': true,
        'orders': [
          {'_id': 'ord1', 'orderNumber': '001', 'status': 'completed'},
        ],
        'today': {'ordersCount': 5, 'earnings': 10000},
        'totalOrdersCount': 50,
      });
      final controller = OrdersHistoryController();
      await controller.fetchOrdersHistory();
      expect(controller.orders.length, 1);
      expect(controller.todayOrdersCount.value, 5);
      expect(controller.todayEarnings.value, 10000);
      expect(controller.totalOrdersCount.value, 50);
      expect(controller.isLoading.value, false);
    });

    test('fetchOrdersHistory handles API error gracefully', () async {
      mockDioGet('orders-history', {
        'success': false,
        'orders': [],
        'today': {'ordersCount': 0, 'earnings': 0},
        'totalOrdersCount': 0,
      });
      final controller = OrdersHistoryController();
      await controller.fetchOrdersHistory();
      expect(controller.orders.length, 0);
      expect(controller.isLoading.value, false);
    });

    test('updateStatusFilter changes status and calls fetchOrdersHistory', () {
      final controller = OrdersHistoryController();
      controller.updateStatusFilter('completed');
      expect(controller.selectedStatus.value, 'completed');
    });

    test('updateDateFilter updates date and calls fetchOrdersHistory', () {
      final date = DateTime(2026, 7, 2);
      final controller = OrdersHistoryController();
      controller.updateDateFilter(date);
      expect(controller.selectedDate.value, '2026-07-02');
    });

    test('clearDateFilter resets date and calls fetchOrdersHistory', () {
      final controller = OrdersHistoryController();
      controller.selectedDate.value = '2026-07-02';
      controller.clearDateFilter();
      expect(controller.selectedDate.value, '');
    });
  });
}
