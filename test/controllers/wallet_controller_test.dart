import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/features/wallet/presentation/controllers/wallet_controller.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    setUpGetTestMode();
  });

  tearDown(() {
    resetDioInterceptors();
    tearDownGetTestMode();
  });

  group('WalletController', () {
    test('initial state has correct defaults', () async {
      final controller = WalletController();
      await Future.delayed(Duration.zero);
      expect(controller.isLoading.value, false);
      expect(controller.walletSummary.isEmpty, true);
      expect(controller.cashOrders.length, 0);
      expect(controller.transactions.length, 0);
      expect(controller.selectedPeriod.value, 'all');
      expect(controller.selectedCashFilter.value, 'all');
    });

    test('fetchWalletSummary loads wallet data', () async {
      mockDioGet('api/driver/wallet', {
        'success': true,
        'wallet': {'balance': 50000, 'pending': 2000},
      });
      final controller = WalletController();
      await controller.fetchWalletSummary();
      expect(controller.walletSummary['balance'], 50000);
      expect(controller.isLoading.value, false);
    });

    test('fetchCashOrders loads cash orders', () async {
      mockDioGet('api/driver/cash-orders', {
        'success': true,
        'orders': [
          {'_id': 'c1', 'amount': 3000, 'driverPaymentStatus': 'pending'},
          {'_id': 'c2', 'amount': 5000, 'driverPaymentStatus': 'settled'},
        ],
        'summary': {'totalPending': 3000, 'totalSettled': 5000},
      });
      final controller = WalletController();
      await controller.fetchCashOrders();
      expect(controller.cashOrders.length, 2);
      expect(controller.cashSummary['totalPending'], 3000);
    });

    test('fetchFinancialTransactions loads transactions with period', () async {
      mockDioGet('financial-transactions', {
        'success': true,
        'orders': [{'_id': 't1', 'amount': 1000}],
        'balances': {'current': 60000},
        'earnings': {'today': 10000},
      });
      final controller = WalletController();
      await controller.fetchFinancialTransactions(period: 'today');
      expect(controller.transactions.length, 1);
      expect(controller.selectedPeriod.value, 'today');
      expect(controller.balances['current'], 60000);
      expect(controller.earnings['today'], 10000);
    });

    test('fetchAllWalletData calls all three fetch methods', () async {
      mockDioGet('api/driver/wallet', {
        'success': true, 'wallet': {'balance': 100},
      });
      mockDioGet('api/driver/cash-orders', {
        'success': true, 'orders': [], 'summary': {},
      });
      mockDioGet('financial-transactions', {
        'success': true, 'orders': [], 'balances': {}, 'earnings': {},
      });
      final controller = WalletController();
      await controller.fetchAllWalletData();
      expect(controller.walletSummary['balance'], 100);
    });

    test('filteredCashOrders returns all when filter is all', () {
      final controller = WalletController();
      controller.cashOrders.value = [
        {'driverPaymentStatus': 'pending'},
        {'driverPaymentStatus': 'settled'},
      ];
      final result = controller.filteredCashOrders;
      expect(result.length, 2);
    });

    test('filteredCashOrders filters by selectedCashFilter', () {
      final controller = WalletController();
      controller.cashOrders.value = [
        {'driverPaymentStatus': 'pending'},
        {'driverPaymentStatus': 'settled'},
        {'driverPaymentStatus': 'pending'},
      ];
      controller.selectedCashFilter.value = 'pending';
      final result = controller.filteredCashOrders;
      expect(result.length, 2);
    });
  });
}
