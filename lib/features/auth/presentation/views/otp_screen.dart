import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';

/// شاشة إدخال رمز التحقق المرسل لهاتف المستخدم
class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final authController = Get.find<AuthController>();
  late final String phone;

  final List<TextEditingController> _controllers = List.generate(
      6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  @override
  void initState() {
    super.initState();
    if (Get.arguments is Map) {
      phone = Get.arguments['phone'] ?? "";
      String? otpFromServer = Get.arguments['otp']?.toString();
      if (otpFromServer != null && otpFromServer.length == 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoFillOtp(otpFromServer);
        });
      }
    } else {
      phone = Get.arguments is String ? Get.arguments : "";
    }
  }

  void _autoFillOtp(String otp) {
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = otp[i];
    }
    _focusNodes[5].requestFocus();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentOtp => _controllers.map((e) => e.text).join();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.grey
        .shade100;
    final cardColor = isDark ? const Color(0xff1F2337) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1E222D), AppColors.darkBackground]
                : [Colors.orange.shade50, Colors.grey.shade100],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                color: cardColor,
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: 5)
                ],
              ),
              margin: const EdgeInsets.all(25),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: isDark ? Colors.white : Colors.black87),
                          onPressed: () => Get.back(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryOrange.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Icon(Icons.phone_in_talk_outlined, size: 60,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "otp_title".tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "otp_subtitle".tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textGrey,
                            fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "\u200e$phone",
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: isDark ? Colors.white : AppColors
                              .primaryOrange,
                          fontSize: 16,
                          fontWeight: FontWeight.w600
                      ),
                    ),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) =>
                            _buildOtpBox(index, isDark)),
                      ),
                    ),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: Obx(() =>
                            ElevatedButton(
                              onPressed:
                              authController.isLoading.value
                                  ? null
                                  : () {
                                if (_currentOtp.length == 6) {
                                  authController.verifyOTP(phone, _currentOtp);
                                } else {
                                  Get.snackbar("error".tr, "otp_error_msg".tr);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                              ),
                              child: authController.isLoading.value
                                  ? const CircularProgressIndicator(
                                  color: Colors.white)
                                  : Text("verify_btn".tr,
                                  style: const TextStyle(fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            )),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          "resend_code".tr,
                          style: const TextStyle(color: AppColors.primaryOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index, bool isDark) {
    return Container(
      width: 40,
      height: 55,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: isDark ? Colors.transparent : Colors.grey.shade300),
                borderRadius: const BorderRadius.all(Radius.circular(12))
            ),
            focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(
                    color: AppColors.primaryOrange, width: 2),
                borderRadius: BorderRadius.all(Radius.circular(12))
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            fillColor: isDark ? AppColors.darkCard : Colors.white,
            filled: true
        ),
      ),
    );
  }
}