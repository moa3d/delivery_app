import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../core/widgets/custom_logo_container.dart';
import '../../../../data/services/socket_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // تشغيل منطق التوجيه بعد انقضاء 3 ثوانٍ لضمان رؤية الهوية البصرية
    _startNavigationTimer();
  }

  /// دالة مؤقتة للتحقق من بيانات المستخدم قبل الانتقال للشاشة التالية
  void _startNavigationTimer() {
    Future.delayed(const Duration(seconds: 3), () async {
      final authController = Get.find<AuthController>();

      if (authController.isLoggedIn()) {
        try {
          // نصل السوكيت أولاً حتى تصل تحديثات الحالة وأي طلب جديد
          // أثناء جلب البيانات، لا بعده.
          Get.find<SocketService>().connect();
          await authController.fetchDriverData();

          if (Get.currentRoute == '/splash') {
            Get.offAllNamed('/main-navigation');
          }
        } catch (e) {
          debugPrint("خطأ أثناء جلب بيانات السائق في السبلاش: $e");
        }
      } else {
        // إذا لم يسجل الدخول، يتم نقله لصفحة تسجيل الدخول مباشرة
        Get.offAllNamed('/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? const Color(0xFF3D2621) : Colors.orange.shade100,
              Theme
                  .of(context)
                  .scaffoldBackgroundColor,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // حاوية الشعار المخصصة مع تحديد الحجم والمسار
              const CustomLogoContainer(
                size: 80.0,
                imagePath: 'assets/images/logo.png',
              ),
              const SizedBox(height: 10),
              Text(
                "app_name".tr,
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 30,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "courier".tr,
                style: TextStyle(
                  color: isDark ? AppColors.textGrey : Colors.black54,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
