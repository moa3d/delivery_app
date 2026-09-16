import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/features/navigation/presentation/controllers/navigation_controller.dart';

void main() {
  group('NavigationController', () {
    test('initial selectedIndex is 0', () {
      final controller = NavigationController();
      expect(controller.selectedIndex.value, 0);
    });

    test('changePage updates selectedIndex', () {
      final controller = NavigationController();
      controller.changePage(2);
      expect(controller.selectedIndex.value, 2);
    });

    test('changePage accepts any index', () {
      final controller = NavigationController();
      controller.changePage(3);
      expect(controller.selectedIndex.value, 3);
    });
  });
}
