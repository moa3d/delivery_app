import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_logo_container.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../controllers/auth_controller.dart';
import 'widgets/sign_up_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginTab = true;
  final AuthController _controller = Get.find<AuthController>();

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
              isDark ? AppColors.darkBackground : Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Obx(() =>
              AbsorbPointer(
                absorbing: _controller.isLoading.value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      const CustomLogoContainer(
                        size: 40,
                        imagePath: 'assets/images/logo.png',
                        backgroundColor: AppColors.primaryOrange,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "NUMNOW Courier",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'start'.tr,
                        style: const TextStyle(
                            color: AppColors.textGrey, fontSize: 13),
                      ),
                      const SizedBox(height: 15),

                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.grey
                              .shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildTabItem(title: 'login'.tr,
                                isActive: _isLoginTab,
                                isDark: isDark,
                                onTap: () =>
                                    setState(() => _isLoginTab = true)),
                            const SizedBox(width: 8),
                            _buildTabItem(title: 'signup'.tr,
                                isActive: !_isLoginTab,
                                isDark: isDark,
                                onTap: () =>
                                    setState(() => _isLoginTab = false)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _isLoginTab
                              ? _buildLoginForm()
                              : const SignUpForm(),
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildSubmitButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              )),
        ),
      ),
    );
  }

  Widget _buildTabItem(
      {required String title, required bool isActive, required bool isDark, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(title, style: TextStyle(
                  color: isActive ? Colors.white : (isDark
                      ? AppColors.textGrey
                      : Colors.black45),
                  fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('phone'.tr),
        CustomTextField(
          hint: 'phone'.tr, icon: Icons.phone_outlined,
          controller: _controller.loginPhoneController,
          textDirection: TextDirection.ltr,
        ),
        const SizedBox(height: 15),
        _buildLabel('pass'.tr),
        CustomTextField(
          hint: 'pass'.tr, icon: Icons.lock_outline,
          isPassword: true, controller: _controller.loginPasswordController,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => Get.toNamed('/forgot-password'),
            child: Text('forgot'.tr,
                style: const TextStyle(color: AppColors.primaryOrange)),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
        child: Text(text,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 14)),
      );

  /// التسجيل والدخول تبويبان في شاشة واحدة، فنجاح التسجيل ينقل السائق
  /// إلى تبويب الدخول برقمه المعبّأ مسبقاً بدل أن يبقى على نموذج فارغ.
  Future<void> _submit() async {
    if (_isLoginTab) {
      await _controller.login();
      return;
    }
    final created = await _controller.register();
    if (created && mounted) setState(() => _isLoginTab = true);
  }

  Widget _buildSubmitButton() =>
      SizedBox(
        width: double.infinity, height: 55,
        child: ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            elevation: 5,
          ),
          child: _controller.isLoading.value
              ? const SizedBox(height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : Text(_isLoginTab ? 'login'.tr : 'signup'.tr,
              style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
      );
}