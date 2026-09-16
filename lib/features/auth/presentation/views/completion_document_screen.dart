
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_logo_container.dart';
import '../../../../core/widgets/upload_tile.dart';
import '../controllers/auth_controller.dart';

/// شاشة إكمال المستندات — تعرض حالة كل مستند كما يراها الأدمن
/// (`documents[].status`) وليس مجرد "موجود / غير موجود".
///
/// تستطلع حالة الحساب دورياً لأن الباك لا يبثّ أي حدث للسائق عند
/// اعتماده أو عند مراجعة مستنداته.
class CompletionDocumentScreen extends StatefulWidget {
  const CompletionDocumentScreen({super.key});

  @override
  State<CompletionDocumentScreen> createState() =>
      _CompletionDocumentScreenState();
}

class _CompletionDocumentScreenState extends State<CompletionDocumentScreen> {
  final AuthController _auth = Get.find<AuthController>();

  /// حقل الرفع ← مفتاح اسم المستند المترجم
  static const _docTitleKeys = {
    'idImage': 'id_card',
    'vehicleRegistrationImage': 'vehicle_reg',
    'drivingLicenseImage': 'license',
  };

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

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'doc_status_approved'.tr;
      case 'rejected':
        return 'doc_status_rejected'.tr;
      case 'pending':
        return 'doc_status_pending'.tr;
      default:
        return 'doc_status_missing'.tr;
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final ok = await Get.defaultDialog<bool>(
      title: title,
      middleText: message,
      textConfirm: confirmText,
      textCancel: 'upload_cancel'.tr,
      confirmTextColor: Colors.white,
      onConfirm: () => Get.back(result: true),
    );
    return ok ?? false;
  }

  /// استبدال مستند معتمد يُعيد الحساب كله إلى المراجعة في الباك
  Future<void> _onDocTap(String field, String status) async {
    if (status == 'approved') {
      final ok = await _confirm(
        title: 'reupload_approved_title'.tr,
        message: 'reupload_approved_message'.tr,
        confirmText: 'reupload_confirm'.tr,
      );
      if (!ok) return;
    }
    await _auth.uploadDocument(field);
  }

  /// يسمّي كل مستند قبل فتح المعرض — كان الزر يفتح المعرض ثلاث مرات
  /// متتالية دون أن يعرف السائق أي صورة مطلوبة الآن.
  Future<void> _uploadMissing(List<String> fields) async {
    for (final field in fields) {
      final doc = _docTitleKeys[field]!.tr;
      final ok = await _confirm(
        title: 'pick_doc_title'.trParams({'doc': doc}),
        message: 'pick_doc_message'.trParams({'doc': doc}),
        confirmText: 'upload_continue'.tr,
      );
      if (!ok || !await _auth.uploadDocument(field)) return;
    }
  }

  Widget _docTile({
    required String field,
    required IconData icon,
    required Color color,
  }) {
    final status = _auth.documentStatus(field);
    final uploadingField = _auth.uploadingField.value;
    return UploadTile(
      title: _docTitleKeys[field]!.tr,
      subtitle: 'file_format_note'.tr,
      status: docStatusFromString(status),
      statusLabel: uploadingField == field ? 'uploading'.tr : _statusLabel(status),
      rejectionReason: _auth.documentRejectionReason(field),
      onTap: uploadingField != null ? null : () => _onDocTap(field, status),
      trailing: uploadingField == field
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryOrange,
              ),
            )
          : null,
      icon: icon,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : Colors.grey.shade100;
    final titleColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Obx(() {
        // مستند يحتاج تدخّل السائق: لم يُرفع أصلاً أو رفضه الأدمن
        final needsAction = AuthController.docTypeByField.keys.where((f) {
          final s = _auth.documentStatus(f);
          return s != 'pending' && s != 'approved';
        }).toList();
        final isUploading = _auth.uploadingField.value != null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF3D2621), AppColors.darkBackground]
                  : [Colors.orange.shade50, Colors.grey.shade100],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _auth.refreshStatusNow,
            color: AppColors.primaryOrange,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  CustomLogoContainer(
                    icon: CupertinoIcons.time,
                    size: 60,
                    borderRadius: 18,
                    backgroundColor:
                        const Color(0xffF0B100).withValues(alpha: 0.33),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "under_review_title".tr,
                    style: TextStyle(
                      fontSize: 20,
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "under_review_subtitle".tr,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "document_status".tr,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _docTile(
                    field: 'idImage',
                    icon: Icons.file_present,
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 10),
                  _docTile(
                    field: 'vehicleRegistrationImage',
                    icon: Icons.credit_card,
                    color: Colors.yellowAccent.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 10),
                  _docTile(
                    field: 'drivingLicenseImage',
                    icon: Icons.directions_car,
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 20),
                  if (needsAction.isNotEmpty)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isUploading
                          ? null
                          : () => _uploadMissing(needsAction),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.upload_outlined, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            "upload_missing_btn".tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "docs_all_submitted".tr,
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // فحص يدوي فوري — الاعتماد لا يصل عبر السوكيت
                  TextButton.icon(
                    onPressed: _auth.isCheckingStatus.value
                        ? null
                        : _auth.refreshStatusNow,
                    icon: _auth.isCheckingStatus.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text("check_status_now".tr),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryOrange),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: "${"tips_label".tr}: ",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: "tips_desc".tr)
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
