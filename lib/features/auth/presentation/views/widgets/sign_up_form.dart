import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:delivery_app/core/widgets/custom_dropdown_field.dart';
import 'package:delivery_app/core/widgets/custom_text_field.dart';
import 'package:delivery_app/core/widgets/upload_tile.dart';
import 'package:delivery_app/features/auth/presentation/views/widgets/auth_form_wrapper.dart';

/// ويدجت نموذج إنشاء الحساب الجديد
/// تم تصميمه ليكون سهل التمرير ومنظماً في أقسام منطقية (بيانات شخصية، بيانات المركبة، الوثائق)
class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  // الوصول للمتحكم لإدارة البيانات والحالة
  final AuthController authController = Get.find<AuthController>();

  Future<void> _pickImage(String targetType) async {
    try {
      // نفس الضغط وفحص الحجم المستخدم في رفع المستندات لاحقاً
      final image = await authController.pickUploadImage();

      if (image != null) {
        File selectedFile = File(image.path);
        switch (targetType) {
          case 'profile':
            authController.profileImage.value = selectedFile;
            break;
          case 'id':
            authController.idCardFile.value = selectedFile;
            break;
          case 'license':
            authController.licenseFile.value = selectedFile;
            break;
          case 'reg':
            authController.registrationFile.value = selectedFile;
            break;
        }
      }
    } catch (e) {
      debugPrint("خطأ في اختيار الصورة: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return AuthFormWrapper(
      verticalSpacing: 12,
      children: [
        _buildSectionHeader(Icons.person_outline, "personal_info".tr, isDark),

        // اختيار الصورة الشخصية بتصميم دائري عصري
        Center(child: _buildProfileAvatar(isDark)),

        _buildLabel("full_name".tr),
        CustomTextField(
          hint: 'full_name_hint'.tr,
          icon: Icons.person_outline,
          controller: authController.fullNameController,
        ),

        _buildLabel('phone'.tr),
        CustomTextField(
          hint: 'phone_hint'.tr,
          icon: Icons.phone_outlined,
          controller: authController.phoneController,
          textDirection: TextDirection.ltr,
        ),

        _buildLabel("email".tr),
        CustomTextField(
          hint: 'email_hint'.tr,
          icon: Icons.email_outlined,
          controller: authController.emailController,
        ),

        _buildLabel("pass".tr),
        CustomTextField(
          hint: 'pass_hint'.tr,
          icon: Icons.lock_outline,
          isPassword: true,
          controller: authController.passwordController,
        ),

        const SizedBox(height: 10),
        const Divider(thickness: 1),

        _buildSectionHeader(
            Icons.directions_car_outlined, "vehicle_info".tr, isDark),

        _buildLabel("vehicle_type".tr),
        _buildVehicleSelection(),

        _buildLabel("plate_num".tr),
        CustomTextField(
          hint: 'ABC-1234',
          icon: Icons.numbers,
          controller: authController.plateController,
          textDirection: TextDirection.ltr,
        ),

        _buildLabel("city_zone".tr),
        Obx(() =>
            CustomDropdownField(
              hint: "select_city".tr,
              prefixIcon: Icons.location_on_outlined,
              items: const ["Damascus", "Aleppo", "Homs", "Lattakia", "Hama"],
              value: authController.selectedCity.value,
              onChanged: (val) => authController.selectedCity.value = val,
            )),

        const SizedBox(height: 10),
        const Divider(thickness: 1),

        // --- القسم الثالث: الوثائق الرسمية ---
        _buildSectionHeader(
            Icons.file_present_outlined, "upload_docs".tr, isDark),

        Obx(() =>
            Column(
              children: [
                _buildUploadItem("id_card".tr, "upload_id".tr,
                    authController.idCardFile.value, () => _pickImage('id')),
                _buildUploadItem("license".tr, "upload_license".tr,
                    authController.licenseFile.value, () =>
                        _pickImage('license')),
                _buildUploadItem("vehicle_reg".tr, "upload_reg".tr,
                    authController.registrationFile.value, () =>
                        _pickImage('reg')),
              ],
            )),

        const SizedBox(height: 15),
        _buildAdminNote(isDark),
      ],
    );
  }

  /// بناء واجهة اختيار الصورة الشخصية
  Widget _buildProfileAvatar(bool isDark) {
    return Obx(() =>
        Stack(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: isDark ? AppColors.darkCard : Colors.grey
                  .shade200,
              backgroundImage: authController.profileImage.value != null
                  ? FileImage(authController.profileImage.value!)
                  : null,
              child: authController.profileImage.value == null
                  ? const Icon(Icons.person, color: Colors.grey, size: 55)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _pickImage('profile'),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryOrange,
                  child: const Icon(
                      Icons.camera_alt, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ));
  }

  /// أداة اختيار نوع المركبة بتصميم البطاقات التفاعلية
  Widget _buildVehicleSelection() {
    return Obx(() =>
        Row(
          children: [
            _vehicleCard('Car', Icons.directions_car_filled_outlined, 'car'.tr),
            const SizedBox(width: 10),
            _vehicleCard(
                'Motorcycle', Icons.pedal_bike_outlined, 'motorcycle'.tr),
            const SizedBox(width: 10),
            _vehicleCard(
                'Bicycle', Icons.directions_bike_outlined, 'bicycle'.tr),
          ],
        ));
  }

  Widget _vehicleCard(String type, IconData icon, String label) {
    bool isSelected = authController.selectedVehicle.value == type;
    return Expanded(
      child: InkWell(
        onTap: () => authController.selectedVehicle.value = type,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryOrange.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: isSelected ? AppColors.primaryOrange : Colors.grey
                    .withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppColors.primaryOrange : Colors.grey,
                  size: 28),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(
                  color: isSelected ? AppColors.primaryOrange : Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight
                      .normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadItem(String label, String hint, File? file,
      VoidCallback action) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        UploadTile(
          title: file == null ? hint : "file_selected".tr,
          subtitle: "file_format_note".tr,
          file: file,
          onTap: action,
          icon: Icons.cloud_upload_outlined,
        ),
      ],
    );
  }

  Widget _buildLabel(String text) =>
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 5),
        child: Text(text, style: const TextStyle(color: AppColors.textGrey,
            fontSize: 13,
            fontWeight: FontWeight.w500)),
      );

  Widget _buildSectionHeader(IconData icon, String title, bool isDark) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryOrange, size: 22),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
          ],
        ),
      );

  Widget _buildAdminNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text("admin_review_msg".tr,
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey))),
        ],
      ),
    );
  }
}