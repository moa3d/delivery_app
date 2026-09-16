import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';
import '../helpers/test_helpers.dart';

void main() {
  // AuthController ينشئ GetStorage ويستخدم Get.offAllNamed/snackbar —
  // كلاهما يتطلب binding مُهيّأً، وبدون هذا السطر كانت كل اختبارات هذا
  // الملف تفشل بـ "Binding has not yet been initialized".
  TestWidgetsFlutterBinding.ensureInitialized();
  mockPathProvider();

  setUp(() {
    setUpGetTestMode();
  });

  tearDown(() {
    resetDioInterceptors();
    tearDownGetTestMode();
  });

  group('AuthController (unit)', () {
    test('isLoggedIn returns false initially', () {
      final controller = AuthController();
      // GetStorage.read() returns null by default even without path_provider
      expect(controller.isLoggedIn(), false);
    });

    // handleError يستدعي Get.snackbar التي تحتاج overlay حقيقياً — لذلك
    // هذه الاختبارات testWidgets مع GetMaterialApp مرسومة فعلاً، بدل
    // test العادي الذي كان يفشل بـ "Null check operator used on a null value".
    // handleError قد يوجّه إلى /blocked أو /documents-completion أو /login —
    // نُسجّل بدائل فارغة حتى لا يفشل التوجيه بـ "Could not find a generator".
    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(
        home: const Scaffold(),
        getPages: [
          for (final route in const [
            '/blocked',
            '/documents-completion',
            '/login',
          ])
            GetPage(name: route, page: () => const Scaffold()),
        ],
      ));
    }

    DioException dioError({int? statusCode, Object? data, DioExceptionType? type}) =>
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: type ?? DioExceptionType.badResponse,
          response: statusCode == null
              ? null
              : Response(
                  requestOptions: RequestOptions(path: ''),
                  statusCode: statusCode,
                  data: data,
                ),
        );

    testWidgets('handleError with blocked status does not throw',
        (tester) async {
      await pumpApp(tester);
      AuthController().handleError(dioError(
        statusCode: 403,
        data: {'message': 'Your account has been blocked'},
      ));
      await tester.pump();
      // السناك بار يبقى بأنيميشن نشط عند نهاية الاختبار — نُغلقه ونُسكّن
      // الشجرة، وإلا فشل الاختبار بـ "disposed with an active Ticker".
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('handleError with non-403 does not throw', (tester) async {
      await pumpApp(tester);
      AuthController().handleError(dioError(
        statusCode: 400,
        data: {'message': 'Bad request'},
      ));
      await tester.pump();
      // السناك بار يبقى بأنيميشن نشط عند نهاية الاختبار — نُغلقه ونُسكّن
      // الشجرة، وإلا فشل الاختبار بـ "disposed with an active Ticker".
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('handleError with connection error does not throw',
        (tester) async {
      await pumpApp(tester);
      AuthController()
          .handleError(dioError(type: DioExceptionType.connectionTimeout));
      await tester.pump();
      // السناك بار يبقى بأنيميشن نشط عند نهاية الاختبار — نُغلقه ونُسكّن
      // الشجرة، وإلا فشل الاختبار بـ "disposed with an active Ticker".
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });
  });
}
