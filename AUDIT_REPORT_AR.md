# تقرير تدقيق شامل — تطبيق توصيل NomNow (سائق)

**التاريخ:** 2026-09-09
**النطاق:** جميع ملفات `lib/` و `pubspec.yaml` لمنظومة التطبيق
**الحالة:** تدقيق كامل دون أي تعديل على الملفات

---

## ملخص تنفيذي

تم فحص البنية الكاملة للتطبيق (التي تتبع فكرة "Professional Restructure"): نقطة الدخول `main.dart`، الطبقة الأساسية `core/` (الثيم، الترجمة، الأدوات)، طبقة البيانات `data/` (Socket, Location, Notification, API)، وكل المزايا `features/` (auth, home, orders, wallet, notifications, settings, navigation, splash)، بالإضافة إلى توجيه المسارات `routes/` وملف `pubspec.yaml`.

التقرير أدناه مصنّف حسب الخطورة. كل بند يتضمن المستند والملف والموقع بدقّة حيث أمكن.

---

## 🔴 خطورة حرجة / عالية

### 1. شاشة "تحصيل الدفع" (PaymentCollection) غير قابلة للوصول — "شاشة ميتة" (v2 relic)
- **الملف:** `lib/features/orders/presentation/views/payment_collection_screen.dart`
- **التفصيل:** هذه الشاشة ومتحكمها `PaymentCollectionController` **لا يُشار إليهما في أي مكان** في التطبيق إلا في تعريفهما الخاص واستيرادهما في `orders_binding.dart`. بحث شامل عبر `lib/` أظهر صفر استخدام خارج التعريف الذاتي. لا يوجد لهما مسار في `AppRoutes` ولا `AppPages`.
- **النتيجة:** هذه الميزة بقايا من بنية (v2) ولم تُدمج في البنية الجديدة. الكود ميت، وواجهته `PaymentCollectionController` المُحقنة بـ `lazyPut` غير مجدية.
- التحقق: `AppRoutes` يضم 15 مسارًا ولا يتضمن `payment_collection` أو `proof_of_delivery` — وكلا الشاشتين يُدفعان كـ Widget مباشرة.

### 2. لا توجد معالجة لانقطاع الإنترنت (no-internet) إطلاقًا
- **الملف:** `pubspec.yaml` — **غياب** حزمة `connectivity_plus`.
- **الملف/الاستدعاء:** `data/api_client/dio_client.dart` (كامل) — لا يوجد أي `onError` أو تقاطُع لرصد انقطاع الشبكة.
- **التفصيل:** بحث كامل لم يصادف `connectivity_plus` أو `ConnectivityResult` أو أي منطق "offline". عند انقطاع الإنترنت، سيفشل كل طلب شبكة بصمت أو بخطأ Dio غير مُعالج، ولن يصل السائق لأي رسالة "لا يوجد اتصال". هذا أمر خطير في تطبيق توصيل يعتمد على Socket.

### 3. لا يوجد تقاطُع لانتهاء / فشل توكن المصادقة (401/token expiry) في طبقة الـ API
- **الملف:** `lib/data/api_client/dio_client.dart`
- **التفصيل:** الملف مُهيّأ بوقت مهلة 40 ثانية ويضيف التوكن في رأس الطلب، لكنه **لا يحتوي أي `InterceptorsWrapper`** للمعرّف 401 ولا أي إعادة توجيه لتسجيل الخروج عند انتهاء التوكن.
- **النتيجة:** عند انتهاء التوكن أثناء استخدام نقطة نهاية تقدّم لأمر ما (مثل رفع صورة أو تسوية)، سيفشل الطلب بدون إخراج السائق للتسجيل، وقد يبقى في حالة "مُعلّق" داخل معالجة الطلب.

### 4. عميل الـ API لا يملك معالجة أخطاء على مستوى الشبكة تؤدي إلى توجيه مستخدم ودّي
- **الملف:** `lib/data/api_client/dio_client.dart`
- **التفصيل:** لا `onError` إطلاقًا. كل الأخطاء (DNS، مهلة، خادم، تحويل صيغة) ستُرمى كاستثناءات خام قد تُفرّغ كـ "التبويب الأسود" بدون رسالة تُفهَم للمستخدم. المعالجة موزّعة ومجزّأة في كل نقطة استدعاء على حدة بدل تمركزها في طبقة العميل.

---

## 🟠 خطورة متوسطة

### 5. الترجمة الألمانية غير مكتملة — 103 مفتاحًا مفقودًا (fallback إلى الإنجليزية)
- **الملف:** `lib/core/localization/message.dart`
- **التحقق الخوارزمي:** القسم الإنجليزي يضم 388 مفتاحًا، العربي 398، والألماني **287 فقط**.
- **المفتاحات المفقودة في الألماني (من أصل الإنجليزي):** تشمل مفاتيح إشعارات كاملة (`notif_payment_title/desc`, `notif_peak_title/desc`, `notif_delivery_done_title/desc`, `notif_doc_expire_title/desc`, `notif_time_3h/5h/1d`, `load_older_notif`)، ومفاتيح شاشة كاملة لصفحات التوصيل والاستلام (`pickup_confirm_title/sub`, `scan_qr_tab`, `order_num_tab`, `enter_order_num_label`, `pickup_warning_text`, `qr_position_hint`, `orders_to_pickup_label`, `confirm_to_continue`)، وأخرى مثل `otp_title/subtitle`, `forgot_pass_title`, `upload_id/license/reg`, `select_city/select_vehicle`, `vehicle_type`, `available_withdrawal`, `current_balance`, `recent_transactions`, `weekly_growth`, `total_earnings`, `go_online`, إلخ.
- **النتيجة:** المستخدم الألماني سيرى نصوصًا إنجليزية (بسبب `fallbackLocale: Locale('en')`) في ما لا يقل عن 103 موضعًا — بعضها مُحرَّك أساسي (شاشة تأكيد الاستلام، شاشة OTP، صفحة الرفع).

### 6. نقص في الترجمة الإنجليزية — 10 مفاتيح موجودة بالعربي/الألماني لكنها غائبة بالإنجليزية
- **الملف:** `lib/core/localization/message.dart`
- **المفتاحات الغائبة في EN (موجودة في AR):**
  - `contact_email_label` — **مُستخدم في** `settings_screen.dart:82` (عنوان البريد الإلكتروني). المستخدم الإنجليزي سيرى المفتاح الخام.
  - `map_on_the_way_status` — معرّف في AR و DE لكن ليس EN (نص "في الطريق / unterwegs").
  - إضافة مفاتيح موجودة في AR و DE لكن غائبة في EN وتُستخدم في الشاشات: `online_msg` (مُستخدم في `home_screen.dart:480` — "You're Online")، `exceeded_threshold_msg` (`wallet_screen.dart:346`)، `check_email_subtitle`، `didnt_receive_email`، `forgot_pass_subtitle` (`forgot_password_screen.dart:131`)، `spam_folder_note` (`forgot_password_screen.dart:254`)، `under_review_subtitle` (`completion_document_screen.dart:66`).
- **ملاحظة تحقق:** بعد فحص الكتلة EN بدقة عبر مطابقة الأقواس، المؤكد غياب `contact_email_label` و `map_on_the_way_status` من EN. لأن `en` هو **fallbackLocale**، فغياب مفتاح منه يعني عرض الاسم الخام للمفتاح (مثل `contact_email_label`) للمستخدم الإنجليزي.

### 7. تناقض في العملة بين الشاشات (حسّاس لحالة الأحرف country)
- **الملف/الدوال:**
  - `order_details_screen.dart` و `new_order_request_screen.dart` و `past_order_details_screen.dart` تُطابق **أحرفًا كبيرة** `'DE'` / `'US'` / (`default: SYP`).
  - `orders_history_screen.dart` تُطابق **أحرفًا صغيرة** `'syria'` / `'germany'` وتعيد نصوصًا صريحة `'SYP'` / `'EUR'` / `'USD'`.
- **التفصيل:** قيمة `driverData['country']` واحدة، لكن لأن المقارنة حساسة لحالة الأحرف، لو أتت القيمة القادمة من السيرفر `'germany'` فستعرض شاشة سجل الطلبات `EUR` بينما تُسقط شاشات أخرى إلى `default` (SYP) لنفس الطلب. والأسوأ: **`wallet_screen.dart` يرمز بشكل صريح إلى `ل.س` (SYP) دائمًا** بغض النظر عن البلد — أي أن سائقًا ألمانيًا سيرى الليرة السورية في محفظته.
- **النتيجة:** نفس الطلب يعرض رموز عملة مختلفة حسب الشاشة، وتجربة غير صحيحة للمستخدمين غير السوريين.

### 8. شاشة الإشعارات بالكامل "Placeholder" (بيانات مزيّفة وأزرار فارغة)
- **الملف:** `lib/features/notifications/presentation/views/notifications_screen.dart`
- **التفصيل:** الشاشة تعرض بيانات **مُرمّزة** بدل الجلب من الخادم:
  - عدد غير المقروء مثبّت فعليًا على "2".
  - زر "تحديد الكل كمقروء" له معالج فارغ `onPressed: () {}`.
  - عناصر الإشعارات نفسها مكتوبة يدويًا في الكود (تستخدم مفاتيح `notif_payment_title`, `notif_delivery_done_title`, إلخ) بدل قائمة حقيقية.
- **النتيجة:** لا يوجد تكامل فعلي مع أي نقطة نهاية إشعارات؛ الشاشة عرض تجريبي ولا تعكس إشعارات المستخدم الحقيقية.

---

## 🟡 خطورة منخفضة / أمور تنظيف (Code Smells)

### 9. اعتماد ميت: `flutter_local_notifications` معلن وغير مستخدم
- **الملف:** `pubspec.yaml` — الحزمة `flutter_local_notifications: ^21.0.0` معلنة.
- **التحقق:** بحث في كامل `lib/` عن `FlutterLocalNotificationsPlugin|flutter_local_notifications` أسفر عن **صفر** نتيجة. لا يوجد أي كود إشعارات محلي (Local Notification). الإشعارات تعتمد فقط على FCM العرضية.
- **التوصية:** إزالة الحزمة لتقليل حجم البناء وتبسيط التبعيات، أو تنفيذ الإشعارات المحلية إذا كان مقصودًا استخدامها.

### 10. `SettlementController` معرّف داخل نفس ملف `SettlementScreen`
- **الملف:** `lib/features/wallet/presentation/views/settlement_screen.dart`
- **التفصيل:** المتحكم `SettlementController` مُعرَّف **داخل نفس الملف** الذي يحتوي الواجهة — خلافًا لنمط الفصل (controller في مجلد `controllers/`). هذا يخالف باقي البنية (حيث لكل شاشة controller في مجلد مستقل) ويجعل الواجهة sector > controller.
- **النتيجة:** صعوبة الاختبار والفصل، وعدم الاتساق المعماري.

### 11. `PaymentCollectionScreen` دائم الوضع الداكن (dark-only)
- **الملف:** `lib/features/orders/presentation/views/payment_collection_screen.dart`
- **التفصيل:** الشاشة تستخدم ألوانًا داكنة **مُرمّزة** ثابتة في كل الحالات، حتى عندما يكون وضع التطبيق فاتحًا. (وعلى الرغم من أنها غير قابلة للوصول حاليًا — البند 1 — يجب إصلاحها عند إعادة ربطها.)

### 12. عدم اتساق في استراتيجية تسجيل المتحكمات (DI)
- **الملفات:** `home_screen.dart:26` (`Get.put(WalletController())`)، `home_screen.dart:83` (`Get.put(OrdersHistoryController())`)، `wallet_screen.dart:19` (`Get.put(WalletController())`)، `main_wrapper.dart:19` (`Get.put(NavigationController())`)، مقابل `navigation_binding.dart` (`Get.lazyPut(NavigationController + WalletController)`).
- **التفصيل:** نفس النوع (`WalletController`، `NavigationController`) يُسجَّل بواسطة `Get.put` في الشاشات و `Get.lazyPut` في الـ binding. عمليًا `Get.put` بنفس النوع والنوع الافتراضي `tag:null` يعيد نفس النسخة، لذا لا ينتج عن ذلك نسختان متكررتان، لكنه — **أسلوب غير موحّد/مربك**: مصير المتحكم (بقاء/إتلاف) يعتمد على من يفتح الشاشة أولًا، لا على قرار معماري واضح. تُفضَّل استراتيجية واحدة (إمّا كل `Get.put` أو كل `lazyPut` في binding).

### 13. إعادة تعبئة البيانات بشكل متكرر عبر push من الشاشات بدل استخدام DynamicRoutes
- **التفصيل:** لاحظنا أن أزرار "سجل الطلبات/المعاملات المالية" في `main_wrapper.dart` تدفع عبر `Get.nestedKey` مع مسارات فورية (`/cash-collection`, `/financial-transactions`) بدل الاستفادة الكاملة من نظام `GetPages` المعرَّف مركزيا في `app_pages.dart`. غير أن هذا متّسق داخليًا مع استخدام `Get.nestedKey(1)`/`Get.back(id:)` — توصية تأملية للتوحيد أكثر من كونها عيبًا.

---

## 🟢 ملاحظات إيجابية / نقاط تحقّق سليمة

- **لا يوجد تسريب ذاكرة في مستمع السوكيت:** `order_details_screen.dart:73-80` يُزيل المستمع `order:statusUpdated` في `dispose()` (عبر `socket?.off(...)`) — سليم.
- **إدارة المستمعات العالمية للسوكيت:** `SocketService._setupGlobalListeners` يُسجَّل مرة واحدة عند إنشاء السوكيت (وليس داخل `onConnect`) لمنع مضاعفة المستمعات مع كل إعادة اتصال.
- **إعادة إنشاء `StreamController` بعد الـ logout:** `SocketService.connect()` يعيد تهيئة `_orderStatusController` إذا كان مغلقًا.
- **تهيئة Firebase/FCM بعد `runApp`** (مع timeout) لتجنّب الشاشة السوداء على أجهزة بلا GMS — معالجة مدروسة موثّقة في v3.0.
- **SocketService/AppLifecycleService مسجّلان permanent ومناسبان لدورة حياة التطبيق.**
- **`ngDialog`/الـ fallback** للمصالحة: اختيار `fallbackLocale: Locale('en')` يمنع تعطّل الترجمة وإن كان يكشف النواقص (البند 5/6).
- **لا توجد علامات TODO/FIXME/HACK/XXX** متبقية في `lib/` (بحث شامل: صفر نتيجة).
- **حقل كلمة المرور لا يملك زر إظهار/إخفاء** — `custom_text_field.dart` (ملاحظة تجربة استخدام، تعزيزية).

---

## خارطة طريق مقترحة (مرتبة حسب الأولوية)

1. **حرج:** إضافة طبقة معالجة انقطاع الشبكة (`connectivity_plus`) وواجهة "لا يوجد اتصال/محاولة إعادة".
2. **حرج:** إضافة `InterceptorsWrapper` في `dio_client.dart` لرصد 401/انتهاء التوكن وإعادة توجيه السائق للدخول مع رسالة واضحة، ومعالجة أخطاء الشبكة بشكل مركزي.
3. **متوسط:** استكمال الترجمة الألمانية (103 مفاتيح) والإنجليزية (10 مفاتيح ناقصة).
4. **متوسط:** توحيد منطق العملة عبر استخراج أداة/دالة مركزية واحدة تستخدمها كل الشاشات، بدل النسخ المتفرقة ذات التطابق الحسّاس لحالة الأحرف.
5. **متوسط:** ربط شاشة الإشعارات بنقطة نهاية حقيقية (وإزالة البيانات المرمّزة والأزرار الفارغة)، وإعادة ربط `PaymentCollectionScreen` (أو إزالتها نهائيًا مع متحكمها إن لم تعد مطلوبة).
6. **منخفض:** إزالة `flutter_local_notifications` الميتة، وفصل `SettlementController` إلى ملفه الخاص، وتوحيد استراتيجية DI، وجعل `PaymentCollectionScreen` محترمًا للوضع الفاتح.
