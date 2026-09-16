import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/features/auth/presentation/controllers/auth_controller.dart';

/// شاشة تظهر عندما يتم حظر حساب السائق من قبل الإدارة.
///
/// تستطلع حالة الحساب دورياً: الباك لا يبثّ أي حدث للسائق عند رفع الحظر،
/// فبدون الاستطلاع يبقى السائق محتجزاً هنا حتى يُعيد تشغيل التطبيق.
class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  final AuthController _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _auth.startStatusPolling();
  }

  @override
  void dispose() {
    _auth.stopStatusPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF2D1B18), const Color(0xFF101828)]
                : [Colors.red.shade50, Colors.grey.shade50],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _auth.refreshStatusNow,
            color: AppColors.primaryOrange,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.vertical,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // أيقونة الحظر الكبيرة
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.block_flipped,
                            color: Colors.redAccent, size: 85),
                      ),
                      const SizedBox(height: 35),

                      // عناوين التنبيه
                      Text(
                        "blocked_account_title".tr,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "blocked_account_subtitle".tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isDark
                                ? Colors.red.shade300
                                : Colors.red.shade700,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 20),

                      // وصف سبب الحظر أو التعليمات
                      Text(
                        "blocked_account_desc".tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 15, height: 1.5),
                      ),

                      // السبب الذي كتبه الأدمن — يصل في جسم ردّ 403 وحده،
                      // فيبقى مخفياً إلى أن يُنشر B8 في الباك.
                      Obx(() {
                        final reason = _auth.suspensionReason.value;
                        if (reason == null) return const SizedBox.shrink();
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "blocked_reason_label".tr,
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reason,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 14,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 30),

                      // فحص يدوي — رفع الحظر لا يصل عبر السوكيت
                      Obx(() => TextButton.icon(
                            onPressed: _auth.isCheckingStatus.value
                                ? null
                                : _auth.refreshStatusNow,
                            icon: _auth.isCheckingStatus.value
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 18),
                            label: Text("check_status_now".tr),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryOrange),
                          )),

                      const SizedBox(height: 20),

                      // أزرار الإجراءات (دعم فني / خروج)
                      _buildActionButtons(_auth),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// بناء أزرار التواصل مع الدعم أو تسجيل الخروج
  Widget _buildActionButtons(AuthController controller) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              // سيتم ربط خدمة التواصل هنا لاحقاً
            },
            icon: const Icon(Icons.support_agent, color: Colors.white),
            label: Text("contact_support_btn".tr,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15))),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => controller.logout(),
          child: Text(
            "logout_btn".tr,
            style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
      ],
    );
  }
}
