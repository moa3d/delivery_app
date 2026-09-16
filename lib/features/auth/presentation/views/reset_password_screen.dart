import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:delivery_app/routes/app_routes.dart';

/// v4.3 — الخطوة الثانية من إعادة تعيين كلمة المرور: إدخال رمز الـSMS
/// وكلمة المرور الجديدة معاً، وإرسالها كلها في `POST /reset-password`
/// (لم يعد هناك `:token` في المسار). تصل إليها الشاشة بالرقم كـargument.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  /// مهلة إعادة الإرسال في الباك (throttle) — 60 ثانية من آخر طلب ناجح
  static const _resendCooldown = 60;

  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String _phone = "";
  String? _serverMessage;

  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _phone = args['phone']?.toString() ?? "";
      _serverMessage = args['message']?.toString();
    }
    // الوصول إلى هنا يعني أن رمزاً أُرسل للتو، فيبدأ العدّاد فوراً بدل
    // انتظار 429 من الباك على أول ضغطة "إعادة إرسال".
    _startCooldown(_resendCooldown);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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

  void _showError(String message) {
    Get.snackbar("alert".tr, message,
        backgroundColor: Colors.redAccent, colorText: Colors.white);
  }

  /// إعادة إرسال الرمز لنفس الرقم — يبقى السائق في مكانه فلا يفقد ما كتبه
  Future<void> _resendCode() async {
    if (_secondsLeft > 0 || _authController.isLoading.value) return;

    final result = await _authController.forgotPassword(_phone);
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _serverMessage = result.message;
        _otpController.clear();
      });
      _startCooldown(_resendCooldown);
      Get.snackbar("success".tr, "reset_sent".tr,
          backgroundColor: Colors.green, colorText: Colors.white);
      return;
    }

    _showError(result.message ?? "connection_error".tr);
    if (result.retryAfterSeconds != null) {
      _startCooldown(result.retryAfterSeconds!);
    }
  }

  Future<void> _submit() async {
    final otp = _otpController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (_phone.isEmpty) {
      _showError("invalid_phone_format".tr);
      return;
    }
    if (otp.isEmpty) {
      _showError("enter_reset_code".tr);
      return;
    }
    if (password.isEmpty || password.length < 6) {
      _showError("password_min_6".tr);
      return;
    }
    if (password != confirm) {
      _showError("passwords_mismatch".tr);
      return;
    }

    final result = await _authController.resetPassword(
      phone: _phone,
      otp: otp,
      newPassword: password,
      confirmPassword: confirm,
    );
    if (!mounted) return;

    if (result.success) {
      // لا خروج قسري من الأجهزة الأخرى في هذا الإصدار (JWT عديم الحالة)،
      // فنكتفي بإعادة السائق إلى تسجيل الدخول بكلمة المرور الجديدة.
      Get.offAllNamed(AppRoutes.login);
      Get.snackbar("success".tr, "password_changed_success".tr,
          backgroundColor: Colors.green, colorText: Colors.white);
      return;
    }

    // رمز خاطئ أو منتهي الصلاحية: يبقى السائق هنا مع خيار إعادة الإرسال
    _showError(result.message ?? "connection_error".tr);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : Colors.grey.shade100;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87),
        ),
        title: Text(
          "back_to_login".tr,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87, fontSize: 16),
        ),
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child:
                    const Icon(Icons.lock_reset, color: Colors.white, size: 45),
              ),
              const SizedBox(height: 25),
              Text(
                "reset_password_title".tr,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (_phone.isNotEmpty)
                Text(
                  "code_sent_to".trParams({'phone': _phone}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.primaryOrange, fontSize: 14),
                ),
              if (_serverMessage != null) ...[
                const SizedBox(height: 15),
                _buildInfoBanner(_serverMessage!, isDark),
              ],
              const SizedBox(height: 30),
              _buildInputCard(cardColor, isDark),
              const SizedBox(height: 10),
              _buildResendRow(),
              const SizedBox(height: 15),
              _buildSubmitButton(),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(Color cardColor, bool isDark) {
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
                    blurRadius: 10)
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("reset_code_label".tr, isDark),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _otpController,
            hint: "enter_code_hint".tr,
            icon: Icons.vpn_key,
            isDark: isDark,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 20),
          _buildLabel("new_password_label".tr, isDark),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _passwordController,
            hint: "min_6_chars_hint".tr,
            icon: Icons.lock_outline,
            isDark: isDark,
            obscure: _obscurePassword,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textGrey,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 20),
          _buildLabel("confirm_password_label".tr, isDark),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _confirmController,
            hint: "reenter_password_hint".tr,
            icon: Icons.lock_outline,
            isDark: isDark,
            obscure: _obscureConfirm,
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textGrey,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Obx(() => SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _authController.isLoading.value ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _authController.isLoading.value
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    "reset_btn".tr,
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
          ),
        ));
  }

  Widget _buildResendRow() {
    return Obx(() {
      final isWaiting = _secondsLeft > 0;
      final isBusy = _authController.isLoading.value;
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(
          onPressed: (isWaiting || isBusy) ? null : _resendCode,
          icon: Icon(
            isWaiting ? Icons.timer_outlined : Icons.refresh,
            size: 18,
            color: isWaiting ? AppColors.textGrey : AppColors.primaryOrange,
          ),
          label: Text(
            isWaiting
                ? "resend_code_in".trParams({'seconds': '$_secondsLeft'})
                : "resend_code".tr,
            style: TextStyle(
              color: isWaiting ? AppColors.textGrey : AppColors.primaryOrange,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildInfoBanner(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(43, 127, 255, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sms_outlined, color: Colors.blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
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

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style:
          TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark
            ? AppColors.darkBackground.withValues(alpha: 0.5)
            : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
