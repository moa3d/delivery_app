import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:delivery_app/core/constants/app_colors.dart';
import 'package:delivery_app/core/widgets/custom_leading.dart';
import 'package:delivery_app/data/services/notification_store.dart';

/// شاشة الإشعارات — تقرأ من السجل المحلي المبني من رسائل FCM.
///
/// لا يوجد راوت إشعارات في الباك (ولا تخزين مفعّل فيه)، فالقائمة تبدأ من
/// لحظة تثبيت التطبيق ولا تُزامَن بين الأجهزة.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : Colors.grey.shade50;

    // الخدمة تُسجَّل في main قبل runApp؛ إن تعذّر ذلك نعرض قائمة فارغة
    // بدل إسقاط الشاشة.
    final store = Get.isRegistered<NotificationStore>()
        ? Get.find<NotificationStore>()
        : null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading:
            const Padding(padding: EdgeInsets.all(8.0), child: CustomLeading()),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("notifications".tr,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Obx(() => Text(
                "${"unread_count".tr} ${store?.unreadCount ?? 0}",
                style: TextStyle(
                    color: AppColors.primaryOrange.withValues(alpha: 0.8),
                    fontSize: 12),
              )),
        ]),
        actions: [
          Obx(() {
            final canMark = (store?.unreadCount ?? 0) > 0;
            return TextButton(
              onPressed: canMark ? store!.markAllRead : null,
              child: Text("mark_all_read".tr,
                  style: TextStyle(
                      color: canMark ? Colors.green : Colors.grey,
                      fontSize: 13)),
            );
          }),
          const SizedBox(width: 10)
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF3D2621), AppColors.darkBackground]
                    : [Colors.orange.shade50, Colors.grey.shade100])),
        child: Obx(() {
          final items = store?.items ?? <AppNotification>[].obs;
          if (items.isEmpty) return _buildEmptyState(isDark);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              return _buildNotificationItem(
                n: n,
                isDark: isDark,
                onTap: () => store?.markRead(n.id),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none,
              size: 70, color: AppColors.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 15),
          Text(
            "no_notifications".tr,
            style: TextStyle(
                color: isDark ? AppColors.textGrey : Colors.black54,
                fontSize: 15),
          ),
        ],
      ),
    );
  }

  /// أيقونة ولون حسب نوع الإشعار القادم من الباك (`data.type`)
  (IconData, Color) _visualFor(String type) {
    switch (type) {
      case 'order:driverRequest':
        return (Icons.inventory_2, Colors.green);
      case 'order:statusUpdated':
        return (Icons.check_circle, Colors.teal);
      default:
        return (Icons.notifications, AppColors.primaryOrange);
    }
  }

  String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return "time_just_now".tr;
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes} ${"time_minutes_ago".tr}";
    }
    if (diff.inHours < 24) return "${diff.inHours} ${"time_hours_ago".tr}";
    return "${diff.inDays} ${"time_days_ago".tr}";
  }

  Widget _buildNotificationItem({
    required AppNotification n,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final (icon, iconColor) = _visualFor(n.type);
    final isUnread = !n.read;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isUnread
                    ? iconColor.withValues(alpha: 0.2)
                    : Colors.transparent),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Text(n.title,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (isUnread)
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle))
                ]),
                const SizedBox(height: 5),
                Text(n.body,
                    style: TextStyle(
                        color: isDark ? AppColors.textGrey : Colors.black54,
                        fontSize: 13,
                        height: 1.4)),
                const SizedBox(height: 10),
                Text(_relativeTime(n.receivedAt),
                    style: TextStyle(
                        color: isDark
                            ? AppColors.textGrey.withValues(alpha: 0.6)
                            : Colors.black38,
                        fontSize: 11)),
              ])),
        ]),
      ),
    );
  }
}
