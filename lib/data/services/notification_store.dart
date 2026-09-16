import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// إشعار واحد كما وصل من FCM.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? orderId;
  final DateTime receivedAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
    this.orderId,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        orderId: orderId,
        receivedAt: receivedAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'orderId': orderId,
        'receivedAt': receivedAt.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<dynamic, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        type: json['type']?.toString() ?? 'custom',
        orderId: json['orderId']?.toString(),
        receivedAt:
            DateTime.tryParse(json['receivedAt']?.toString() ?? '') ??
                DateTime.now(),
        read: json['read'] == true,
      );
}

/// سجل الإشعارات المحلي.
///
/// الباك لا يملك أي راوت إشعارات (لا للسائق ولا للمستخدم)، والتخزين في
/// `utils/notificationDispatcher.js` معطّل بالتصميم
/// (`PERSISTED_NOTIFICATION_KEYS` مجموعة فارغة)، فلا يوجد سجل يُجلب من
/// السيرفر. لذلك نبني السجل محلياً من رسائل FCM الواردة.
///
/// حدّان معروفان: السجل يبدأ من لحظة تثبيت التطبيق، ولا يُزامَن بين
/// أجهزة السائق. كما أن الإشعارات التي تصل والتطبيق مغلق ولا يفتحها
/// السائق لا تُسجَّل هنا — GetStorage ليست آمنة عبر الأيزوليتات، ونُفضّل
/// فقدان سطر في القائمة على إتلاف المخزن كاملاً.
class NotificationStore extends GetxService {
  static const _storageKey = 'notifications';
  static const _maxItems = 50;

  final _storage = GetStorage();
  final items = <AppNotification>[].obs;

  NotificationStore load() {
    try {
      final raw = _storage.read(_storageKey);
      if (raw is List) {
        items.assignAll(raw
            .whereType<Map>()
            .map(AppNotification.fromJson)
            .where((n) => n.id.isNotEmpty));
        _sort();
      }
    } catch (_) {
      // مخزن تالف أو بصيغة قديمة — نبدأ من فارغ بدل إسقاط الإقلاع
      items.clear();
    }
    return this;
  }

  int get unreadCount => items.where((n) => !n.read).length;

  void add(AppNotification notification) {
    if (notification.id.isEmpty) return;
    // نفس الرسالة قد تصل مرتين (وصول ثم فتح من الإشعار)
    if (items.any((n) => n.id == notification.id)) return;

    items.insert(0, notification);
    if (items.length > _maxItems) items.removeRange(_maxItems, items.length);
    _persist();
  }

  void markAllRead() {
    if (unreadCount == 0) return;
    items.assignAll(items.map((n) => n.copyWith(read: true)));
    _persist();
  }

  void markRead(String id) {
    final i = items.indexWhere((n) => n.id == id);
    if (i == -1 || items[i].read) return;
    items[i] = items[i].copyWith(read: true);
    items.refresh();
    _persist();
  }

  void clear() {
    items.clear();
    _persist();
  }

  void _sort() =>
      items.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

  void _persist() {
    try {
      _storage.write(_storageKey, items.map((n) => n.toJson()).toList());
    } catch (_) {
      // الكتابة المحلية ليست حرجة — لا نُزعج السائق بخطأ تخزين
    }
  }
}
