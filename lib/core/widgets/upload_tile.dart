import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// حالة المستند كما يُرجعها الباك في `documents[].status`،
/// مضافاً إليها `missing` لِما لم يُرفع بعد.
enum DocStatus { missing, pending, approved, rejected }

DocStatus docStatusFromString(String? raw) {
  switch (raw) {
    case 'approved':
      return DocStatus.approved;
    case 'rejected':
      return DocStatus.rejected;
    case 'pending':
      return DocStatus.pending;
    default:
      return DocStatus.missing;
  }
}

class UploadTile extends StatelessWidget {
  final String title, subtitle;
  final File? file;

  /// `null` يعطّل النقر (مثلاً أثناء رفع جارٍ)
  final VoidCallback? onTap;
  final IconData icon;
  final Color? color;
  final bool isNotFound;
  final Widget? trailing;

  /// حالة المستند على السيرفر. عند تمريرها تُقدَّم على [isNotFound]
  /// و[file] في تحديد اللون والأيقونة والنص المساعد.
  final DocStatus? status;

  /// سبب الرفض القادم من الأدمن — يُعرض فقط مع [DocStatus.rejected]
  final String? rejectionReason;

  /// نص الحالة المترجم (مثل "قيد المراجعة") — يحل محل [subtitle] عند وجوده
  final String? statusLabel;

  const UploadTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.file,
    required this.onTap,
    required this.icon,
    this.color,
    this.isNotFound = false,
    this.trailing,
    this.status,
    this.rejectionReason,
    this.statusLabel,
  });

  /// الحالة الفعلية: نُفضّل [status] القادمة من السيرفر، ونرجع لسلوك
  /// [file]/[isNotFound] القديم حين لا تُمرَّر (شاشة التسجيل مثلاً).
  DocStatus get _effectiveStatus {
    if (status != null) return status!;
    if (file != null) return DocStatus.approved;
    return isNotFound ? DocStatus.missing : DocStatus.pending;
  }

  Color get _accent {
    switch (_effectiveStatus) {
      case DocStatus.approved:
        return Colors.green;
      case DocStatus.rejected:
        return Colors.redAccent;
      case DocStatus.missing:
        return Colors.red;
      case DocStatus.pending:
        return status == null ? AppColors.textGrey : Colors.orange;
    }
  }

  IconData get _statusIcon {
    switch (_effectiveStatus) {
      case DocStatus.approved:
        return Icons.check_circle;
      case DocStatus.rejected:
        return Icons.cancel;
      case DocStatus.missing:
        return Icons.priority_high;
      case DocStatus.pending:
        return status == null ? Icons.arrow_forward_ios : Icons.access_time_filled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final accent = _accent;
    final st = _effectiveStatus;

    // الحد يبقى محايداً في الحالة "قيد المراجعة" الافتراضية القديمة
    final borderColor = (status == null && st == DocStatus.pending)
        ? AppColors.textGrey.withValues(alpha: 0.1)
        : accent.withValues(alpha: 0.5);

    final helper = statusLabel ?? subtitle;
    final reason = st == DocStatus.rejected ? rejectionReason : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground
                        : accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    st == DocStatus.missing ? icon : Icons.insert_drive_file,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        helper,
                        style: TextStyle(
                          color: statusLabel != null
                              ? accent
                              : AppColors.textGrey,
                          fontSize: 11,
                          fontWeight: statusLabel != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ?? Icon(_statusIcon, color: accent, size: 18),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reason,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
