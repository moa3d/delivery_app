import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/core/theme/theme_controller.dart';
import 'package:delivery_app/core/widgets/shimmer_widgets.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';

import '../../../../core/widgets/custom_leading.dart';
import '../../../navigation/presentation/controllers/navigation_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF101828) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1D2939) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF2D1B18), const Color(0xFF101828)]
                : [Colors.orange.shade50, Colors.grey.shade50],
          ),
        ),
        child: SafeArea(
          child: Obx(() {
            final driver = authController.driverData;
            if (driver.isEmpty) {
              return const Center(
                child: ShimmerSettingsSkeleton(),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildHeader(isDark),
                  const SizedBox(height: 25),
                  _buildTopProfileCard(driver, isDark, cardColor),
                  const SizedBox(height: 30),

                  // قسم معلومات الحساب
                  _buildSectionTitle("account_section".tr),
                  _buildGroupedTiles(
                    [
                      _buildTile(
                        Icons.person,
                        "profile_label".tr,
                        driver['name'] ?? "",
                        Colors.blue,
                        isDark,
                        onTap: () => _showEditProfileDialog(
                          context,
                          authController,
                          isDark,
                        ),
                      ),
                      _buildTile(
                        Icons.phone,
                        "phone_label".tr,
                        "\u200e${driver['phone'] ?? ""}",
                        Colors.green,
                        isDark,
                        trailing: const SizedBox.shrink(),
                      ),
                      _buildTile(
                        Icons.email,
                        "contact_email_label".tr,
                        driver['email'] ?? "",
                        Colors.purple,
                        isDark,
                        trailing: const SizedBox.shrink(),
                      ),
                    ],
                    isDark,
                    cardColor,
                  ),

                  const SizedBox(height: 25),
                  _buildSectionTitle("security_section".tr),
                  _buildGroupedTiles(
                    [
                      _buildTile(
                        Icons.lock,
                        "change_password_label".tr,
                        "update_pass_sub".tr,
                        Colors.redAccent,
                        isDark,
                        onTap: () => _showChangePasswordDialog(
                          context,
                          authController,
                          isDark,
                        ),
                      ),
                    ],
                    isDark,
                    cardColor,
                  ),

                  const SizedBox(height: 25),
                  _buildSectionTitle("documents_section".tr),
                  _buildGroupedTiles(
                    [
                      _buildTile(
                        Icons.assignment,
                        "verification_label".tr,
                        driver['status'] ?? "pending_status".tr,
                        Colors.teal,
                        isDark,
                        trailing: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                      ),
                    ],
                    isDark,
                    cardColor,
                  ),

                  // ── معلومات المركبة (قراءة فقط) ──
                  // الحقول كانت تُرسل عند التسجيل ثم لا تظهر في أي مكان،
                  // رغم أن dirver-info يرجعها دائماً. الباك لا يدعم تعديلها
                  // عبر update-info إلا vehicletype/vehicleplate (ويعيدان
                  // الحالة إلى pending)، لذا العرض فقط دون أي تعديل.
                  const SizedBox(height: 25),
                  _buildSectionTitle("vehicle_info_section".tr),
                  _buildGroupedTiles(
                    [
                      _buildTile(
                        _vehicleIcon(driver['vehicletype']),
                        "vehicle_type_label".tr,
                        _vehicleLabel(driver['vehicletype']),
                        Colors.indigo,
                        isDark,
                        trailing: const SizedBox.shrink(),
                      ),
                      _buildTile(
                        Icons.pin,
                        "vehicle_plate_label".tr,
                        "\u200e${_orDash(driver['vehicleplate'])}",
                        Colors.brown,
                        isDark,
                        trailing: const SizedBox.shrink(),
                      ),
                      _buildTile(
                        Icons.location_city,
                        "zone_label".tr,
                        _orDash(driver['zone']),
                        Colors.cyan,
                        isDark,
                        trailing: const SizedBox.shrink(),
                      ),
                      _buildTile(
                        Icons.public,
                        "country_label".tr,
                        _countryLabel(driver['country']),
                        Colors.blueGrey,
                        isDark,
                        trailing: const SizedBox.shrink(),
                      ),
                    ],
                    isDark,
                    cardColor,
                  ),

                  const SizedBox(height: 25),
                  _buildSectionTitle("preferences_section".tr),
                  _buildGroupedTiles(
                    [
                      _buildTile(
                        Icons.language,
                        "language_label".tr,
                        "current_lang".tr,
                        Colors.blueAccent,
                        isDark,
                        onTap: () => _showLanguageDialog(
                          context,
                          authController,
                          isDark,
                        ),
                      ),
                      // الوضع الليلي/النهاري — اختيار داخلي محفوظ
                      // بدل الالتزام بوضع النظام فقط
                      _buildTile(
                        Get.find<ThemeController>().themeMode.value ==
                                ThemeMode.dark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        "theme_label".tr,
                        Get.find<ThemeController>().currentModeLabel,
                        Colors.deepPurple,
                        isDark,
                        onTap: () => _showThemeDialog(context, isDark),
                      ),
                      _buildTile(
                        Icons.verified_user,
                        "privacy_settings_label".tr,
                        "control_data_sub".tr,
                        Colors.greenAccent,
                        isDark,
                        onTap: () =>
                            _showPrivacyDialog(context, authController, isDark),
                      ),
                    ],
                    isDark,
                    cardColor,
                  ),

                  const SizedBox(height: 30),
                  _buildLogoutButton(authController, isDark, cardColor),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // --- دوال الحوار (Dialogs) المضافة للمطابقة الكاملة ---

  void _showPrivacyDialog(
    BuildContext context,
    AuthController controller,
    bool isDark,
  ) {
    RxBool shareLocation = (controller.driverData['shareLocation'] ?? true).obs;
    RxBool showRating = (controller.driverData['showRating'] ?? true).obs;
    Get.dialog(
      Dialog(
        backgroundColor: isDark ? const Color(0xFF1D2939) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(
                "privacy_settings_label".tr,
                "control_data_sub".tr,
                isDark,
              ),
              const SizedBox(height: 30),
              _buildPrivacySwitchTile(
                "share_location_label".tr,
                "share_location_sub".tr,
                shareLocation,
                isDark,
              ),
              const SizedBox(height: 15),
              _buildPrivacySwitchTile(
                "show_rating_label".tr,
                "show_rating_sub".tr,
                showRating,
                isDark,
              ),
              const SizedBox(height: 35),
              _dialogButton(
                "done_btn".tr,
                const Color(0xFF00C853),
                () => controller.updateDriverProfile({
                  "shareLocation": shareLocation.value,
                  "showRating": showRating.value,
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    AuthController controller,
    bool isDark,
  ) {
    String currentLang = Get.locale?.languageCode ?? 'en';
    final List<Map<String, String>> languages = [
      {"name": "English", "code": "en"},
      {"name": "Arabic", "code": "ar"},
      {"name": "German", "code": "de"},
    ];
    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1D2939) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogHeader("language_label".tr, "language_sub".tr, isDark),
                  const SizedBox(height: 25),
                  ...languages.map((lang) {
                    bool isSelected = currentLang == lang['code'];
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => currentLang = lang['code']!),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF101828)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2970FF)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang['name']!,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF2970FF),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  _dialogButton(
                    "done_btn".tr,
                    const Color(0xFF2970FF),
                    () => controller.updateLanguage(currentLang),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// حوار اختيار الوضع الليلي/النهاري — بنفس نمط حوار اللغة:
  /// اختيار محلي داخل الحوار ثم تطبيق وحفظ عند الضغط على «تم».
  void _showThemeDialog(BuildContext context, bool isDark) {
    final themeController = Get.find<ThemeController>();
    ThemeMode currentMode = themeController.themeMode.value;
    final List<Map<String, dynamic>> modes = [
      {"mode": ThemeMode.system, "label": "theme_system".tr},
      {"mode": ThemeMode.light, "label": "theme_light".tr},
      {"mode": ThemeMode.dark, "label": "theme_dark".tr},
    ];
    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1D2939) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogHeader("theme_label".tr, "theme_sub".tr, isDark),
                  const SizedBox(height: 25),
                  ...modes.map((m) {
                    bool isSelected = currentMode == m['mode'];
                    return GestureDetector(
                      onTap: () => setDialogState(() {
                        currentMode = m['mode'] as ThemeMode;
                        // تطبيق فوري للمعاينة داخل التطبيق
                        themeController.setMode(currentMode);
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF101828)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2970FF)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  m['mode'] == ThemeMode.dark
                                      ? Icons.dark_mode
                                      : m['mode'] == ThemeMode.light
                                          ? Icons.light_mode
                                          : Icons.settings_suggest,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  m['label'] as String,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF2970FF),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  _dialogButton("done_btn".tr, const Color(0xFF2970FF),
                      () => Get.back()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    AuthController controller,
    bool isDark,
  ) {
    final currentPass = TextEditingController();
    final newPass = TextEditingController();
    final confirmPass = TextEditingController();
    RxBool showCurrent = false.obs;
    RxBool showNew = false.obs;
    RxBool showConfirm = false.obs;
    Get.dialog(
      Dialog(
        backgroundColor: isDark ? const Color(0xFF1D2939) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogHeader(
                  "change_password_label".tr,
                  "update_pass_sub".tr,
                  isDark,
                ),
                const SizedBox(height: 25),
                _buildPassLabel("current_pass_label".tr, isDark),
                _buildPasswordField(currentPass, showCurrent, isDark),
                const SizedBox(height: 15),
                _buildPassLabel("new_pass_label".tr, isDark),
                _buildPasswordField(newPass, showNew, isDark),
                const SizedBox(height: 15),
                _buildPassLabel("confirm_pass_label".tr, isDark),
                _buildPasswordField(confirmPass, showConfirm, isDark),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(child: _buildCancelBtn(isDark)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dialogButton(
                        "save_btn".tr,
                        const Color(0xFFFF1744),
                        () {
                          if (newPass.text != confirmPass.text) {
                            Get.snackbar("error".tr, "passwords_not_match".tr);
                            return;
                          }
                          controller.changePassword(
                            currentPass.text,
                            newPass.text,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    AuthController controller,
    bool isDark,
  ) {
    final textController = TextEditingController(
      text: controller.driverData['name'],
    );
    RxBool isValid = (textController.text.length > 2).obs;
    _showStyledDialog(
      context,
      title: "edit_profile_title".tr,
      subtitle: "update_pass_sub".tr,
      label: "full_name_label".tr,
      controller: textController,
      isValid: isValid,
      validText: "valid_name".tr,
      accentColor: const Color(0xFF2970FF),
      isDark: isDark,
      onSave: () =>
          controller.updateDriverProfile({"name": textController.text}),
      onChanged: (val) => isValid.value = val.length > 2,
    );
  }

  void _showStyledDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String label,
    required TextEditingController controller,
    required RxBool isValid,
    required String validText,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onSave,
    required Function(String) onChanged,
  }) {
    Get.dialog(
      Dialog(
        backgroundColor: isDark ? const Color(0xFF1D2939) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogHeader(title, subtitle, isDark),
                const SizedBox(height: 30),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF101828)
                        : Colors.grey.shade100,
                    suffixIcon: isValid.value
                        ? Icon(Icons.check_circle, color: accentColor, size: 20)
                        : null,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isValid.value ? accentColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                if (isValid.value)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: accentColor,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          validText,
                          style: TextStyle(color: accentColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(child: _buildCancelBtn(isDark)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dialogButton("save_btn".tr, accentColor, onSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogHeader(String title, String subtitle, bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: () => Get.back(),
            child: const Icon(Icons.close, color: Colors.grey, size: 22),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
    ],
  );

  Widget _dialogButton(String label, Color color, VoidCallback onPressed) =>
      SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

  Widget _buildPrivacySwitchTile(
    String title,
    String sub,
    RxBool value,
    bool isDark,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF101828) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
        Obx(
          () => Switch(
            value: value.value,
            onChanged: (val) => value.value = val,
            activeTrackColor: const Color(0xFF00C853),
          ),
        ),
      ],
    ),
  );

  Widget _buildPassLabel(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.grey : Colors.grey.shade600,
        fontSize: 13,
      ),
    ),
  );

  Widget _buildPasswordField(
    TextEditingController ctrl,
    RxBool visibility,
    bool isDark,
  ) => Obx(
    () => TextField(
      controller: ctrl,
      obscureText: !visibility.value,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF101828) : Colors.grey.shade100,
        suffixIcon: IconButton(
          icon: Icon(
            visibility.value ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
            size: 20,
          ),
          onPressed: () => visibility.value = !visibility.value,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _buildCancelBtn(bool isDark) => SizedBox(
    height: 55,
    child: ElevatedButton(
      onPressed: () => Get.back(),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark
            ? const Color(0xFF101828)
            : Colors.grey.shade300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Text(
        "cancel_btn".tr,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  Widget _buildHeader(bool isDark) => Row(
    children: [
      CustomLeading(onPressed: () {
        if (Get.currentRoute == '/settings') {
          Get.back();
        } else {
          Get.find<NavigationController>().changePage(0);
        }
      },),
      const SizedBox(width: 15),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "settings_title".tr,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "manage_account_sub".tr,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    ],
  );

  Widget _buildTopProfileCard(Map driver, bool isDark, Color cardColor) {
    final authController = Get.find<AuthController>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2939) : cardColor,
        borderRadius: BorderRadius.circular(25),
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
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => authController.updateProfileImage(),
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange,
                        borderRadius: BorderRadius.circular(20),
                        image:
                            driver['driverImage'] != null &&
                                driver['driverImage']['url'] != null
                            ? DecorationImage(
                                image: NetworkImage(
                                  driver['driverImage']['url'],
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child:
                          driver['driverImage'] == null ||
                              driver['driverImage']['url'] == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 50,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          driver['name'] ?? "",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.check_circle,
                          color: Colors.teal,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "\u200e${driver['phone'] ?? ""}",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStat(
                          "rating_label".tr,
                          "⭐ ${driver['rating']?.toStringAsFixed(1) ?? '0.0'}",
                          isDark,
                        ),
                        const SizedBox(width: 25),
                        Obx(
                          () => _buildStat(
                            "deliveries_label".tr,
                            authController.totalDeliveries.value.toString(),
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: _buildStatusBadge(
                  "active_status".tr,
                  Icons.layers,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatusBadge(
                  "verified_status_badge".tr,
                  Icons.check_circle_outline,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, bool isDark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      Text(
        value,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  Widget _buildStatusBadge(String text, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 5, bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );

  // ── أدوات عرض معلومات المركبة (قراءة فقط) ──

  /// قيمة نصية أو "—" إن كانت فارغة/null — بدل عرض كلمة null
  static String _orDash(dynamic v) {
    final s = v?.toString() ?? '';
    return s.trim().isEmpty ? '—' : s;
  }

  static IconData _vehicleIcon(dynamic type) {
    switch (type?.toString()) {
      case 'bicycle':
        return Icons.pedal_bike;
      case 'motorcycle':
        return Icons.two_wheeler;
      default:
        return Icons.directions_car;
    }
  }

  /// نوع المركبة مترجماً — والقيمة الخام احتياطاً لأي نوع مستقبلي
  static String _vehicleLabel(dynamic type) {
    switch (type?.toString()) {
      case 'bicycle':
        return 'vehicle_bicycle'.tr;
      case 'motorcycle':
        return 'vehicle_motorcycle'.tr;
      case 'car':
        return 'vehicle_car'.tr;
      default:
        return _orDash(type);
    }
  }

  static String _countryLabel(dynamic country) {
    switch (country?.toString()) {
      case 'SY':
        return 'country_sy'.tr;
      case 'DE':
        return 'country_de'.tr;
      default:
        return _orDash(country);
    }
  }

  Widget _buildGroupedTiles(
    List<Widget> tiles,
    bool isDark,
    Color cardColor,
  ) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1D2939) : cardColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: isDark
          ? []
          : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
    ),
    child: Column(children: tiles),
  );

  Widget _buildTile(
    IconData icon,
    String title,
    String sub,
    Color iconColor,
    bool isDark, {
    VoidCallback? onTap,
    Widget? trailing,
  }) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    ),
    title: Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: sub.isNotEmpty
        ? Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12))
        : null,
    trailing:
        trailing ??
        const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
  );

  Widget _buildLogoutButton(
    AuthController controller,
    bool isDark,
    Color cardColor,
  ) => InkWell(
    onTap: () => controller.logout(),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2939) : cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Text(
            "logout_btn".tr,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
}
