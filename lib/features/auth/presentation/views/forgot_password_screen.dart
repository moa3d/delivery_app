import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:delivery_app/core/widgets/custom_text_field.dart';
import 'package:delivery_app/routes/app_routes.dart';

/// v4.3 — الخطوة الأولى من إعادة تعيين كلمة المرور: طلب رمز OTP عبر SMS
/// برقم الهاتف حصراً. لم يعد هناك خيار إيميل في هذه الميزة حتى لو كان
/// للسائق بريد مسجَّل في حسابه.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _phoneController = TextEditingController();

  bool _isPhoneValid = false;

  /// عدّاد الانتظار عند 429 — الباك يمنع طلب رمز جديد قبل 60 ثانية
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _submit() async {
    // نفس المطبِّع المستخدم في تسجيل الدخول: مطابقة الرقم في الباك حرفية
    final phone = _authController.validatePhone(_phoneController.text);
    if (phone == null) {
      Get.snackbar("alert".tr, "invalid_phone_format".tr,
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final result = await _authController.forgotPassword(phone);
    if (!mounted) return;

    if (result.success) {
      // الرسالة تُمرَّر للشاشة التالية: في مرحلة الاختبار الحالية يأتي الرمز
      // ضمن نصها من الباك، فيراه المختبِر بدل انتظار الـSMS.
      Get.toNamed(AppRoutes.resetPassword, arguments: {
        'phone': phone,
        'message': result.message,
      });
      return;
    }

    Get.snackbar("alert".tr, result.message ?? "connection_error".tr,
        backgroundColor: Colors.redAccent, colorText: Colors.white);
    if (result.retryAfterSeconds != null) {
      _startCooldown(result.retryAfterSeconds!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(isDark),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF3D2621), AppColors.darkBackground]
                : [Colors.orange.shade50, Colors.grey.shade100],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                _buildHeaderIcon(),
                const SizedBox(height: 30),
                _buildTitleSection(isDark),
                const SizedBox(height: 40),
                _buildInputCard(isDark),
                const SizedBox(height: 25),
                _buildSubmitButton(),
                const SizedBox(height: 25),
                _buildSmsNote(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Get.back(),
        icon: Icon(
          Icons.arrow_back,
          color: isDark ? Colors.white : Colors.black87,
          size: 20,
        ),
      ),
      title: Text(
        "back_to_login".tr,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.lock_outline,
        size: 50,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTitleSection(bool isDark) {
    return Column(
      children: [
        Text(
          "forgot_pass_title".tr,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "forgot_pass_subtitle".tr,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard(bool isDark) {
    final cardColor =
        isDark ? AppColors.darkCard.withValues(alpha: 0.5) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "phone_label".tr,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          CustomTextField(
            onChanged: (val) => setState(
                () => _isPhoneValid = _authController.validatePhone(val) != null),
            hint: "reset_phone_hint".tr,
            icon: Icons.phone_outlined,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Obx(() {
      final isWaiting = _secondsLeft > 0;
      final isDisabled =
          _authController.isLoading.value || !_isPhoneValid || isWaiting;
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: isDisabled ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: (_isPhoneValid && !isWaiting)
                ? AppColors.primaryOrange
                : const Color(0xFFB54F37),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: _authController.isLoading.value
              ? const CircularProgressIndicator(color: Colors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isWaiting ? Icons.timer_outlined : Icons.send_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isWaiting
                          ? "resend_code_in"
                              .trParams({'seconds': '$_secondsLeft'})
                          : "send_code_btn".tr,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }

  Widget _buildSmsNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(43, 127, 255, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sms_outlined,
            color: Colors.blue,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "sms_note".tr,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
