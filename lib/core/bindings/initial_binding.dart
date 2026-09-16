import 'package:get/get.dart';

import '../../data/services/app_lifecycle_service.dart';
import '../../data/services/socket_service.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // السوكيت أولاً: AuthController قد يحتاجه فور إنشائه
    Get.put(SocketService(), permanent: true);
    Get.put(AuthController(), permanent: true);

    // مراقب دورة حياة التطبيق: يُعيد الاتصال والمزامنة عند العودة من الخلفية
    Get.put(AppLifecycleService(), permanent: true);
  }
}
