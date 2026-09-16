import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/features/orders/presentation/views/new_order_request_screen.dart';

/// اختيار أجر السائق من حمولة `order:driverRequest`.
///
/// الحالة الحرجة: مع عرض توصيل مجاني يرسل الباك `deliveryFee = 0` بينما
/// أجر السائق الحقيقي في `originalDeliveryFee` — الأدمن يتحمّل الفرق لا
/// السائق. قراءة `deliveryFee` أولاً كانت ستعرض 0.00 بدل الأجر.
/// راجع BACKEND_TASK_driver_offer_data.md البند (1).
void main() {
  group('NewOrderRequestScreen.earningOf', () {
    test('الحمولة الحالية بلا أي حقل مالي → —', () {
      // ما يرسله الباك اليوم فعلاً (order.service.js:131-140)
      expect(
        NewOrderRequestScreen.earningOf({
          'orderId': 'o1',
          'orderNumber': 'N-1',
          'totalPrice': 45000,
        }),
        '—',
      );
    });

    test('driverEarning يُقدَّم على الباقي', () {
      expect(
        NewOrderRequestScreen.earningOf({
          'driverEarning': 1000,
          'originalDeliveryFee': 999,
          'deliveryFee': 0,
        }),
        '1000.00',
      );
    });

    test('عرض توصيل مجاني: deliveryFee صفر لا يحجب الأجر الحقيقي', () {
      expect(
        NewOrderRequestScreen.earningOf({
          'originalDeliveryFee': 1000,
          'deliveryFee': 0,
        }),
        '1000.00',
      );
    });

    test('طلب عادي: deliveryFee وحده كافٍ', () {
      expect(
        NewOrderRequestScreen.earningOf({'deliveryFee': 1000}),
        '1000.00',
      );
    });

    test('originalDeliveryFee = null يسقط إلى deliveryFee', () {
      // الافتراضي في models/Order.js:77 هو null لا 0
      expect(
        NewOrderRequestScreen.earningOf({
          'originalDeliveryFee': null,
          'deliveryFee': 3,
        }),
        '3.00',
      );
    });

    test('أجر صفري حقيقي يُعرض 0.00 لا —', () {
      expect(
        NewOrderRequestScreen.earningOf({'driverEarning': 0}),
        '0.00',
      );
    });

    test('رقم نصّي يُقبل (FCM يحوّل كل القيم إلى نصوص)', () {
      expect(
        NewOrderRequestScreen.earningOf({'driverEarning': '1000.5'}),
        '1000.50',
      );
    });

    test('قيمة غير رقمية → — بدل استثناء', () {
      expect(NewOrderRequestScreen.earningOf({'driverEarning': 'abc'}), '—');
    });

    test('حمولة null أو غير Map لا تُسقط الشاشة', () {
      expect(NewOrderRequestScreen.earningOf(null), '—');
      expect(NewOrderRequestScreen.earningOf(const {}), '—');
    });
  });
}
