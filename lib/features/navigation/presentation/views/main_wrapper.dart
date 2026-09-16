import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../home/presentation/views/home_screen.dart';
import '../../../orders/presentation/views/orders_history_screen.dart';
import '../../../orders/presentation/views/past_order_details_screen.dart';
import '../../../settings/presentation/views/settings_screen.dart';
import '../../../wallet/presentation/views/cash_collection_screen.dart';
import '../../../wallet/presentation/views/financial_transactions_screen.dart';
import '../../../wallet/presentation/views/wallet_screen.dart';
import '../controllers/navigation_controller.dart';

/// الحاوية الرئيسية للتنقل السفلي (Bottom Navigation)
class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final NavigationController controller = Get.put(NavigationController());
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    // قائمة الشاشات مع دعم التنقل المتداخل للمحفظة والطلبات
    final List<Widget> screens = [
      const HomeScreen(),

      // تبويب المحفظة مع Navigator فرعي للحفاظ على سياق الصفحات
      Navigator(
        key: Get.nestedKey(1),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/cash-collection') {
            return GetPageRoute(page: () => const CashCollectionScreen(),
                transition: Transition.rightToLeft);
          } else if (settings.name == '/financial-transactions') {
            return GetPageRoute(page: () => const FinancialTransactionsScreen(),
                transition: Transition.rightToLeft);
          }
          return GetPageRoute(page: () => const WalletScreen());
        },
      ),

      // تبويب تاريخ الطلبات مع Navigator فرعي ومعالجة الروابط العميقة
      Navigator(
        key: Get.nestedKey(2),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '');
          if (uri.path == '/past-order-details') {
            return GetPageRoute(
              page: () => const PastOrderDetailsScreen(),
              transition: Transition.rightToLeft,
              settings: RouteSettings(
                  name: uri.path, arguments: settings.arguments),
            );
          }
          return GetPageRoute(page: () => const OrdersHistoryScreen());
        },
      ),

      const SettingsScreen(),
    ];

    return Scaffold(
      body: Obx(() =>
          IndexedStack(
            index: controller.selectedIndex.value,
            children: screens,
          )),
      bottomNavigationBar: _buildBottomBar(controller, isDark),
    );
  }

  /// بناء شريط التنقل السفلي بالتصميم والألوان الأصلية
  Widget _buildBottomBar(NavigationController controller, bool isDark) {
    return Obx(() =>
        BottomNavigationBar(
          currentIndex: controller.selectedIndex.value,
          onTap: controller.changePage,
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
          selectedItemColor: const Color(0xFFFF5630),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: 'Home'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: const Icon(Icons.account_balance_wallet),
              label: 'wallet_title'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_outlined),
              activeIcon: const Icon(Icons.assignment),
              label: 'Orders'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: 'Settings'.tr,
            ),
          ],
        ));
  }
}