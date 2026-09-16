# تقرير تدقيق — delivery-app (تدقيق بفريق وكلاء + مقارنة)

## ملخص تنفيذي
المشروع تطبيق سائق توصيل Flutter (GetX + Dio + GetStorage + google_maps + socket_io_client + firebase_messaging)، 59 ملف Dart. دققته فرقة من 4 وكلاء مستقلين (مال/منطق، Flutter/حالة، API/أمان، معمارية)، ثم وحدت نتائجهم وحذفت التكرار بعد التحقق اليدوي من أخطر البنود. الحالة العامة: **شحن غير آمن حالياً** — تحصيل نقدي مكسور قد يسبب دفعاً مزدوجاً، كراش `Get.put` عند التنقل/تغيير اللغة، مفتاح خرائط مسرب، توكن plain بلا expiry، وiOS بلا صلاحيات موقع (الاتصال معطل كلياً على iPhone). أخطر شيء: طلب بطاقة مدفوعة أونلاين يُعرض للسائق كـ "اجمع الكاش" (C-1) مع مسار تسليم يكتمل دون تحصيل أصلاً (C-2).

| الخطورة | العدد |
|---|---|
| 🔴 حرجة | 8 |
| 🟠 عالية | 10 |
| 🟡 متوسطة | 8 |
| 🔵 منخفضة | 5 |

**نطاق الفحص:** قراءة كاملة لـ `lib/data/...` (Dio/Socket/Location/Notification)، `lib/features/wallet/...`، `lib/features/orders/...` (controllers + الشاشات الحرجة)، `lib/features/auth/.../auth_controller.dart`، `lib/main.dart`، `lib/routes/...`، `android/.../AndroidManifest.xml` + `local.properties`، `ios/Runner/Info.plist`، `test/...`. تصفح سريع لـ `core/localization/message.dart` (الأضخم) و`settings_screen.dart`. **تجاهلت ملاحظات المستخدم/اللغة الألمانية عمداً حسب التعليمات.** المشروع يستخدم GetX لا Riverpod، فطبقت قسم Flutter من المهارة على GetX.
**الثوابت (invariants) التي يجب ألا يخرقها النظام:** رصيد المحفظة = مجموع المعاملات؛ لا تحصيل كاش لطلب بطاقة؛ لا تسليم دون تحصيل لطلب كاش؛ الطلب لا يرجع من `delivered` لما قبله؛ القبول/الرفض مرة واحدة؛ الموقع المعروض يطابق السائق المتصل فعلاً لدى السيرفر.

---

## مقارنة بين الوكلاء الأربعة

| المحور | وكيل المال | وكيل Flutter | وكيل API/أمان | وكيل المعمارية | الحكم بعد التوحيد |
|---|---|---|---|---|---|
| شاشة الدفع/التحصيل ميتة | ✅ F2 بالدليل (لا route ولا Get.to) | — | ✅ يدعم (fallback chains) | ✅ F8 (احذف أو اربط، + إثبات Proof ليست ميتة) | **إجماع 3/4 — مؤكد** → C-2 |
| `DateTime.parse` غير محمي يسقط المالية | ✅ F6 | ✅ F2 (حرجة) | ✅ F14 | ✅ F1/F2 | **إجماع 4/4 — مؤكد** → C-8 |
| العملة الصلبة `ل.س` رغم `currencySymbol` | ✅ F7 (8+6+4+1 مواضع) | ✅ F15 | — | ✅ F5 (+ تكرار switch + `_computeTotalSettled` في view) | **إجماع 3/4 — مؤكد** → H-10 |
| `Get.put` في build / حقن مزدوج | — | ✅ F1 (حرجة، 9 مواضع + تعارض Bindings) | — | ✅ F6 (فخ صيانة + كسر اختبار) | **إجماع 2/4 لكن بأدلة متطابقة — مؤكد** → C-3 |
| `socket.on` يدوي يموت بعد reconnect | — | ✅ F4 | ✅ F6 | — | **إجماع 2/4 — مؤكد** → H-5 (ودُمج مع عدم إعادة `goOnline` من C-F5) |
| فشل صامت (0.00 مضللة) + لا 401 مركزي | — (لمحها عبر casts) | — | ✅ F4 | ✅ F1/F2/F4 (حرجة) | **إجماع 2/4 — مؤكد** → C-7 + H-6 |
| casts هشة (`as num`/`as double?`) | ✅ F6 | ✅ F3 | ✅ F14 | ✅ F2 | **إجماع 4/4 — مؤكد** → H-4 |
| استخراج `orderId` غير موحد | ✅ F5 (4 مفاتيح مقابل `_id` فقط) | — | ✅ F17 | — | **إجماع 2/4 — مؤكد** → H-3 |
| مفتاح خرائط مسرب `MAPS_API_KEY` | — | — | ✅ F1 وحدَه | — | **انفراد صحيح — تحققت يدوياً من `local.properties:6` و`AndroidManifest:44-46` → مؤكد** → C-4 |
| iOS بلا مفاتيح موقع | — | — | ✅ F2 وحدَه | — | **انفراد صحيح — تحققت يدوياً (`Info.plist` كامل بلا `NSLocation*` ولا `UIBackgroundModes`) → مؤكد** → C-6 |
| JWT plain بلا expiry | — | — | ✅ F3 وحدَه | ✅ يدعم جزئياً (F4 جلسة شبح) | **مؤكد** → C-5 |
| تحصيل كاش لطلب بطاقة (دفع مزدوج) | ✅ F1 وحدَه | — | — | — | **انفراد صحيح — تحققت يدوياً (`order_details:155` مقابل `:764-795` لا يقرأ `method`) → مؤكد** → C-1 |
| تأكيد استلام بلا تحقق رقم | ✅ F3 (أي رقم + QR وهمي) | — | ✅ F7 (بلا حارس ضغط مزدوج) | — | **متكاملان لا متعارضان** → H-1 |
| حساس لحالة الأحرف `== 'Cash'` | ✅ F4 وحدَه | — | — | — | **مؤكد بالدليل الداخلي (افتراضي `"cash"` + اختبارات `'cash'`)** → H-2 |
| OTP في الاستجابة + زر إعادة ميت | — | — | ✅ F8 وحدَه | ✅ يدعم (`otp` عبر `Get.arguments`) | **مؤكد** → H-7 |
| تعارض ظاهري: طباعة حساسة؟ | — | — | 🔵 PII تُطبع (عناوين/هواتف) | يقول لا طباعة توكن/كلمة مرور | **لا تعارض حقيقي: لا توكن ✅ + نعم PII ✅** → L-2 |
| تصحيح تقرير قديم `AUDIT_REPORT_AR.md` | — | ✅ (إقلاع GMS سليم، سوكيت مسجل مرة) | ✅ (قبول مزدوج ممنوع فعلاً، online بلا تفاؤل) | ✅ (local_notifications مستخدمة، SettlementController غير موجود، إشعارات حقيقية) | **إجماع: التقرير القديم فيه 3 بنود باطلة الآن** |

لا يوجد تعارض جوهري واحد بين الوكلاء. كل ما دخل التقرير الموحد أدناه اجتاز بوابة الدليل (`file:line` مقروء) وبوابة الوصول.

---

## 🔴 مشاكل حرجة

### [C-1] طلب البطاقة يُعرض كـ "اجمع الكاش" — دفع مزدوج
**الموقع:** `lib/features/orders/presentation/views/order_details_screen.dart:155` + `:764-844`
**ما يحدث:** `paymentMethod` يُقرأ (افتراضي `"cash"`) ويُمرر للبطاقة، لكن `_buildPaymentMethodCard(... String method ...)` لا يقرأ `method` إطلاقاً — كل النصوص ثابتة `cash_on_delivery` + `collect_cash_msg`.
**السيناريو:** طلب `paymentMethod: card` مدفوع أونلاين → السائق يرى "اجمع المبلغ نقداً" ويجمعه → الزبون دفع مرتين.
**الأثر:** خسارة مباشرة للزبون ونزاعات ورديات. reachable في كل طلب بطاقة.
**الدليل:**
```dart
final paymentMethod = data?['paymentMethod'] ?? "cash"; // :155
Widget _buildPaymentMethodCard(bool isDark, Color cardBg, Color textGrey,
    String method, String total, Color gold, String currency) { // method لا تُستخدم
  Text("cash_on_delivery".tr, ...); // :795
```
**الإصلاح:**
```dart
final isCash = method.toLowerCase() == 'cash';
if (!isCash) return _buildPaidOnlineCard(...); // "مدفوع أونلاين — لا تجمع شيئاً"
```
**كيف تتحقق:** افتح التفاصيل مع `{'paymentMethod':'card'}` → لا رسالة تحصيل؛ ومع `'cash'` → تظهر.

### [C-2] التسليم يكتمل نقداً دون بوابة تحصيل — شاشة التحصيل ميتة
**الموقع:** `lib/features/orders/presentation/views/proof_of_delivery_screen.dart:62-83` + `lib/features/orders/presentation/views/payment_collection_screen.dart:209` + `lib/routes/app_pages.dart:62-137` (لا route لها) + `lib/features/orders/presentation/bindings/orders_binding.dart:13-14`
**ما يحدث:** زر "تم التسليم" يستدعي `completeDelivery(orderId)` مباشرة دون فحص الدفع. شاشة `PaymentCollectionScreen` لا route لها ولا أي `Get.to` في `lib/` (اتفق 3 وكلاء + grep). المسار الفعلي `DeliveryMap → ProofOfDelivery → delivered` بلا خطوة نقدية.
**السيناريو:** طلب كاش → "تم التسليم" دون تحصيل → السيرفر يسجل `delivered` ويحتسب الكاش عليه → `cashHeldForSettlement` يكبر بلا تحصيل.
**الأثر:** عجز تسوية منهجي. (ملاحظة المعماري: `ProofOfDeliveryScreen` نفسها ليست ميتة — تُدفع من `delivery_map_screen.dart:335-337`.)
**الإصلاح:** قبل `completeDelivery` إذا كان الطلب كاش أجبر المرور عبر التحصيل وانتظر `result == true`؛ وإما اربط `PaymentCollectionScreen` بمسار وزر أو احذفها مع سطر الـ binding.
**كيف تتحقق:** grep عن `PaymentCollectionScreen` تنقلاً → صفر؛ تتبع من `delivery_map:335` إلى `socket.completeDelivery` → لا ذكر لـ `paymentMethod`.

### [C-3] `Get.put` داخل `build` — كراش `already registered` عند التنقل/تغيير اللغة
**الموقع:** `lib/features/orders/presentation/views/orders_history_screen.dart:32`، `past_order_details_screen.dart:24`، `payment_collection_screen.dart:12`، `lib/features/wallet/presentation/views/wallet_screen.dart:19`، `lib/features/navigation/presentation/views/main_wrapper.dart:19`، `lib/features/home/presentation/views/home_screen.dart:30` + `:130`، `new_order_request_screen.dart:40`، `orders_history_screen.dart:266` — تتعارض مع `orders_binding.dart:10-14` و`navigation_binding.dart:8-9` (`lazyPut` لنفس الأنواع)
**ما يحدث:** `get: ^4.7.3` يرمي عند التسجيل الثاني. `Get.put` في `build` يُنفذ مع كل إعادة بناء (ثيم/لغة/تدوير).
**السيناريو:** افتح المحفظة بعد الرئيسية (كلاهما `Get.put(WalletController)`) → كراش؛ أو غيّر اللغة (`Get.updateLocale` يعيد بناء الكل) → كراش. تحققت يدوياً: `orders_history_screen.dart:32` داخل `build` فعلاً.
**الأثر:** سقوط الشاشة/التطبيق بلا `try/catch`.
**الإصلاح:** لا `Get.put` في `build`/حقل `State` — `Binding lazyPut` + `Get.find` في الشاشات (أو `isRegistered ? find : put`)؛ واحذفه من `MainWrapper.build`.
**كيف تتحقق:** تنقل بين تبويبات `MainWrapper` الأربعة + بدل اللغة/الثيم → قبل الإصلاح استثناء، بعده لا شيء. وبعدها `grep Get.put` في `presentation/views` → صفر (عدا `putAsync` في `main.dart`).

### [C-4] مفتاح خرائط حقيقي مُسرّب في التوزيعة
**الموقع:** `android/local.properties:6` + `android/app/google-services.json` + `android/app/src/main/AndroidManifest.xml:44-46` — تحققت يدوياً
**ما يحدث:** `MAPS_API_KEY=AIzaSyDzJ-hQCytfNeFiL5Zv9CI9OdeBqvp-dEw` تُحقن عبر `${MAPS_API_KEY}`؛ و`.gitignore:1-45` لا يستبعد `local.properties` ولا `google-services.json`؛ والجذر فيه `files.zip` و`libdelivery.zip`.
**السيناريو:** أي مشاركة مجلد/أرشيف تسرّب المفتاح → فواتير Maps باسمك.
**الأثر:** سرقة حصة وفواتير.
**الإصلاح:** دوّر المفتاح فوراً، قيده (package + API subset)، أضف الملفين لـ `.gitignore`، واحقنهما عبر CI secrets فقط.
**كيف تتحقق:** `Select-String MAPS_API_KEY local.properties` بلا قيمة حقيقية؛ بناء release من متغير بيئة.

### [C-5] التوكن plain في GetStorage بلا expiry ولا refresh — جلسات ميتة تبدو حية
**الموقع:** `lib/data/api_client/dio_client.dart:30-31` + `lib/features/auth/presentation/controllers/auth_controller.dart:800` + `:226` + `:405-409`
**ما يحدث:** `storage.read('token')` ملف JSON غير مشفر؛ `isLoggedIn() => read("token") != null` (أي string)؛ لا فك `exp` ولا refresh؛ `401 → logout` في `fetchDriverData` فقط.
**السيناريو:** توكن منتهٍ → `isLoggedIn==true` والسوكيت يحاول بتوكن ميت حتى `unauthorized` (`socket_service:156-181`) بينما المحفظة/السجل تفشل بصمت.
**الأثر:** سرقة توكن من جهاز مروت + جلسة شبح.
**الإصلاح:** `flutter_secure_storage` + migration يمسح القديم، فك `exp` عند الإقلاع، وinterceptor مركزي `401 → refresh/logout`.
**كيف تتحقق:** التوكن لا يظهر plain في ملفات التطبيق؛ توكن منتهٍ → توجه للـ login لا بقاء "متصلاً".

### [C-6] iOS بلا أي مفتاح موقع — الاتصال معطل كلياً على iPhone
**الموقع:** `ios/Runner/Info.plist:1-53` (كاملاً: فقط `NSPhotoLibraryUsageDescription` و`MapsApiKey`) مقابل `lib/data/services/location_service.dart:196-209` (تعليق "إلزامي: `UIBackgroundModes:location`") و`:167-171`
**ما يحدث:** لا `NSLocationWhenInUseUsageDescription` ولا `AlwaysAndWhenInUse` ولا `UIBackgroundModes` رغم اعتماد `ensurePermission/start` عليها.
**السيناريو:** سائق iPhone يضغط "متصل" → `ensurePermission` يفشل → `start()=false` → `waiting_gps_fix` للأبد. تحققت يدوياً من الملف.
**الأثر:** ميزة الاتصال ميتة على iOS بالكامل.
**الإصلاح:** أضف المفاتيح الثلاثة + `location`، واختبر على جهاز حقيقي، ووثق في `SETUP.md`.
**كيف تتحقق:** المفاتيح موجودة؛ زر الاتصال يمنح `granted` على iPhone.

### [C-7] فشل المحفظة/السجل صامت — خطأ الشبكة يُعرض كـ "رصيد 0"
**الموقع:** `lib/features/wallet/presentation/controllers/wallet_controller.dart:50-62` + `:65-91`، `lib/features/orders/presentation/controllers/orders_history_controller.dart:28-55`، `past_order_details_controller.dart:11-23`
**ما يحدث:** كل `catch` → `log` فقط؛ لا `error` observable؛ الواجهة تعرض `0.00`/فارغ عند الفشل.
**السيناريو:** نفق/تغطية سيئة → المحفظة `0.00` → ذعر "سُحب رصيدي" وتذاكر كاذبة؛ وتوكن منتهٍ يعرض أصفاراً بدل خروج (جلسة شبح مع C-5/H-6).
**الإصلاح:** `RxnString error` تميز مهلة/انقطاع/401/500 + بانر مع retry + عدم الكتابة فوق بيانات ناجحة قديمة (اعرضها + شارة "قديمة").
**كيف تتحقق:** وضع طيران → رسالة + retry لا `0.00`؛ عودة الشبكة → تمتلئ.

### [C-8] `DateTime.parse` غير محمي داخل `build` — سجل واحد فاسد يسقط المالية
**الموقع:** `lib/features/wallet/presentation/views/financial_transactions_screen.dart:613-614`، `cash_collection_screen.dart:391-392` + `:442-443`، `past_order_details_screen.dart:526-529` (يحمي `null` فقط لا التالف)
**ما يحدث:** استثناء داخل `build` يسقط القائمة كلها. عنصر `createdAt: null/""/رقمي` (وارد عند drift الباك) → شاشة بيضاء/كراش أحمر. النمط الآمن موجود فعلاً في `orders_history_screen:25-28` و`order_details:848-855` — وحّد عليه.
**الإصلاح:**
```dart
String _fmt(dynamic raw) {
  final d = raw == null ? null : DateTime.tryParse(raw.toString());
  return d == null ? "—" : DateFormat('MMM d, h:mm a').format(d);
}
```
**كيف تتحقق:** عنصر mock بـ `createdAt: null` و`"bad"` → قبل الإصلاح كراش، بعده `—`.

---

## 🟠 مشاكل عالية

### [H-1] تأكيد الاستلام يقبل أي رقم + بلا حارس ضغط مزدوج + QR وهمي
**الموقع:** `lib/features/orders/presentation/views/pickup_confirmation_screen.dart:31-47` + `:415-431`
**ما يحدث:** الفحص الوحيد "غير فارغ" — لا مقارنة مع `orderData['orderNumber']`؛ وضع QR يتخطى الفحص ولا يقرأ شيئاً (رسم متحرك)؛ ولا `_isSubmitting` (بعكس `new_order_controller:65-66` و`proof:62-63`).
**السيناريو:** رقم خاطئ/طلب آخر → `startDelivery` + انتقال للخريطة → استلام وتحصيل على طلب خاطئ؛ ونقرة مزدوجة → حدثان + شاشتا خريطة مكدستان.
**الإصلاح:** قارن `entered != expected → snackbar`؛ امنع متابعة QR دون مسح فعلي؛ وانسخ نمط `_isSubmitting` لزر التأكيد.
**كيف تتحقق:** رقم عشوائي → يُرفض حالياً يُقبل؛ ضغط مزدوج → emit واحد و`Get.to` واحدة.

### [H-2] كشف الكاش حساس لحالة الأحرف فيعكس الشارات
**الموقع:** `orders_history_screen.dart:262` + `financial_transactions_screen.dart:495`: `(order['paymentMethod'] ?? 'Cash') == 'Cash'`
**ما يحدث:** الباك يرسل حروفاً صغيرة (الدليل: افتراضي `"cash"` في `order_details:155` + اختبارات `'cash'/'card'`) → كل صف كاش حقيقي `isCash==false` → شارة "أونلاين" → السائق يظن لا تحصيل. يتفاعل مع C-1/C-2.
**الإصلاح:** `(order['paymentMethod']?.toString().toLowerCase() ?? 'cash') == 'cash'`.
**كيف تتحقق:** طلب `'cash'` يظهر حالياً بشارة online في الشاشتين.

### [H-3] استخراج `orderId` غير موحد — فشل صامت للاستلام/التسليم
**الموقع:** `new_order_request_screen.dart:70-76` (4 مفاتيح) مقابل `order_details:37` (`_id/id`) و`pickup:33` و`proof:64` (`_id` فقط) و`orders_history:267` (`_id` فقط)
**ما يحدث:** `proof:64` مع `{'orderId':'x'}` → `""` ثم `return` بلا سناكبار — زر ميت.
**الإصلاح:** دالة مركزية `extractOrderId` في كل الشاشات + رسالة خطأ بدل الصمت.
**كيف تتحقق:** مرر `{'orderId':'x'}` لشاشتي الاستلام/الإثبات → لا استجابة ولا سبب حالياً.

### [H-4] casts هشة على الأرقام والإحداثيات
**الموقع:** `orders_history_controller.dart:43-48` (`as num`)، `wallet_controller:88` (`as num?`)، `home_screen.dart:416-417` + `:902-903` (`as double?` على GeoJSON)
**ما يحدث:** `int` ليس `double` في Dart؛ `earnings: "12000"` أو إحداثي `[36,33]` يرمي `TypeError` داخل `Obx` → رقم قديم مضلل (يبتلعه catch في C-7) أو سقوط `HomeScreen`. `GeoUtils._validated:57-58` يتجنبها بـ `num.tryParse` لكن هذه السطور لا تستخدمه.
**الإصلاح:** وحّد على `num.tryParse('${...}') ?? 0` و`_num(dynamic v) => (v is num ? v : num.tryParse('$v'))?.toDouble()`.
**كيف تتحقق:** وحدة بـ `earnings: "10000"` ومطعم بإحداثي `int` → يفشل حالياً.

### [H-5] مستمع حالة يدوي يموت بعد إعادة إنشاء السوكيت + لا إعادة تأكيد online
**الموقع:** `order_details_screen.dart:48-51` (`.socket?.on("order:statusUpdated")`) مقابل `socket_service.dart:479-484` (`_teardownSocket` يعدم الكائن) + `:139-154` (`_onReconnected` يعيد الموقع فقط) + القناة الصحيحة `:33-37` (`orderStatusStream` كما في `proof:47`)
**ما يحدث:** المعالج على الكائن القديم يضيع بعد `connect()`؛ وإعادة الاتصال لا ترسل `goOnline` ولا `fetchDriverData` (يعتمد على `AppLifecycle` عند العودة من الخلفية فقط) → مؤشر أخضر كاذب بلا طلبات.
**الإصلاح:** اشترك في `orderStatusStream` مع فلتر `orderId`؛ وفي `_onReconnected` إذا `isOnline` أعد `goOnline()` + `fetchDriverData()` مع debounce.
**كيف تتحقق:** افتح التفاصيل → افصل/أعد الشبكة → ابث `statusUpdated` → الشارة لا تتحدث حالياً؛ وافصل 60s مقدمةً → لا `currentStatus` دون تصغير التطبيق.

### [H-6] لا retry ولا 401 مركزي في Dio — الأرصدة القديمة تُقرأ كأنها حالية
**الموقع:** `lib/data/api_client/dio_client.dart:28-44` (`onError → next` فقط؛ `connect/receive 40s` بلا `sendTimeout`) — تحققت يدوياً؛ مقابل `auth_controller:405-411` (المعالجة الوحيدة)
**ما يحدث:** إقلاع Render البارد/شبكة متقطعة → بيانات قديمة بلا رسالة ولا retry.
**الإصلاح:** interceptor: retry مرة للأخطاء الشبكية/`5xx` + `401 → logout` موحد (بتجاهل طلب login نفسه) + نتيجة خطأ تعرضها الواجهات.
**كيف تتحقق:** اقطع الشبكة في المحفظة → خطأ + retry؛ `401` من أي شاشة → خروج للـ login.

### [H-7] الـ OTP يعود في جسم الاستجابة ويُملأ تلقائياً + زر الإعادة ميت
**الموقع:** `auth_controller.dart:250-254` (`arguments {"otp": response.data['otp']}`) + `otp_screen.dart:28-33` (`_autoFillOtp`) + `:210-211` (`onPressed: () {}`) + `forgot_password:67-68` و`auth_controller:621-623`
**ما يحدث:** اعتراض الاستجابة يكشف الرمز؛ الملء التلقائي يلغي قيمة SMS؛ العالق بلا رمز لا يملك إعادة عاملة.
**الإصلاح (باك + عميل):** أوقف إرجاع `otp` إنتاجياً؛ احذف `_autoFillOtp`؛ فعّل الإعادة عبر endpoint مع `retryAfterSeconds` (`forgot:78-80`).
**كيف تتحقق:** استجابة `loginwithphone` بلا `otp`؛ زر الإعادة يطلب رمزاً ويحترم cooldown.

### [H-8] `async void` ضائعة وسباق تنقل (دخول/splash)
**الموقع:** `auth_controller.dart:778` (`void logout() async`) + `:799` (`void _handleLoginSuccess`) + `:215-223` (`onInit` ينادي 4 جلبات بلا await) + `notification_service.dart:120` + `splash_screen.dart:40-62` (`Future.delayed` غير قابل للإلغاء + تنقل بعد dispose)
**ما يحدث:** لا انتظار ولا التقاط خطأ؛ `_handleLoginSuccess` قد يوجه لـ `/blocked` بينما `login()` يوجه لوجهة أخرى → وميض/مسار خاطئ؛ وسplash قد ينفذ `connect/fetch/offAllNamed` من شاشة ميتة.
**الإصلاح:** `Future<void>` + `await` في النداءات؛ `Timer` قابل للإلغاء في `splash dispose` + فحص `mounted`؛ فعّل `unawaited_futures` lint.
**كيف تتحقق:** دخول بحساب `pending/blocked` → تنقل مزدوج حالياً؛ اخرج قبل 3s من الإقلاع → لا تنقل بعد التدمير.

### [H-9] حفظ الاسم يفشل بصمت تام (لا catch + نداء ناري)
**الموقع:** `auth_controller.dart:584-594` (`try/finally` بلا `catch` — بعكس `changePassword:597-610` التي تملك `handleError`) + `settings_screen.dart:554-555` (`onSave` بلا await)
**ما يحدث:** فشل شبكة → استثناء غير ممسوك في `VoidCallback` → الحوار مفتوح بلا رسالة ولا يعرف هل حُفظ.
**الإصلاح:** `on DioException → handleError` كالأخت + مؤشر تحميل ومنع إغلاق مزدوج.
**كيف تتحقق:** اقطع الشبكة → احفظ → snackbar وبقاء الحوار (حالياً صمت).

### [H-10] العملة: مركزية موجودة لكن 4 شاشات تتجاوزها + حساب تسوية داخل view
**الموقع:** المركزي `auth_controller.dart:127-136` (`currencySymbol`)؛ التجاوز `home_screen:687` + `cash_collection:110,119,226,402,469,474` + `wallet_screen:230,295,370,380,450,500,581,702` + `payment_collection:120,122,132,226` (`"ل.س"` صلبة)؛ التكرار `new_order:42-51` + `order_details:76-84` (switch محلي)؛ منطق في view `cash_collection:21-39` (`_computeTotalSettled` يجمع `totalPrice` الخام بينما التسوية عن الصافي)
**ما يحدث:** سائق DE/US يرى نفس المبلغ بعملتين في شاشتين؛ وتغيير قواعد العملة يتطلب 6 ملفات.
**الإصلاح:** احذف كل `"ل.س"` لصالح `currencySymbol` (`grep` → صفر)؛ انقل `_computeTotalSettled` لـ `WalletController` كـ getter مختبر؛ احذف `_getCurrency` المكررة.
**كيف تتحقق:** حساب `country=='DE'` → المحفظة ما تزال ليرة حالياً؛ غيّر الدولة في اختبار `currencySymbol`.

---

## 🟡 مشاكل متوسطة (مختصرة)

### [M-1] `TextEditingController` بلا `dispose` — تسريب متكرر
`pickup_confirmation_screen.dart:22,27-28` (لا dispose في 432 سطراً)؛ `settings_screen:473-475` + `:540` (3+1 داخل حوارات)؛ `auth_controller:38-44` (7 متحكمات، `onClose:943-946` يوقف Timer فقط). المرجع السليم `otp:47-55`/`forgot:31-35`/`reset:52-58`. الإصلاح: `dispose` + إغلاق متحكمات الحوار عند `Get.back`. التحقق: 20 فتح/إغلاق → تحذير `never disposed` حالياً.

### [M-2] تهيئة تحجب الإقلاع و`getToken` معلق بلا timeout
`main.dart:60-65` (`await Get.putAsync(LocationService.init)` → `getLastKnownPosition` بلا timeout في `location_service:68-71`)؛ `notification_service:113-118` (`await getToken()` بلا timeout عند كل دخول) + `:24-25` (نتيجة `requestPermission` مهملة). الفريق أجل Firebase لما بعد أول إطار (`main:35-40,94-120` — سليم) لكن هذين بلا حماية. الإصلاح: `.timeout(3s/10s)` + `try/catch` ومعالجة `denied/provisional`. التحقق: محاكاة تأخير GMS 10s → تأخر أول إطار/تعليق دخول حالياً.

### [M-3] رفض الموقع الدائم مسدود بلا زر إعدادات
`location_service:94-117` (`deniedForever → false`) + `home_screen:242-261` (snackbar فقط؛ لا `openAppSettings/openLocationSettings` في الكود). الإصلاح: زر "فتح الإعدادات"/"تفعيل GPS" حسب الحالة. التحقق: ارفض دائماً → كل "متصل" تفشل للأبد حالياً.

### [M-4] شبكة وتسليم: رابط صلب + `cleartext` + بلا خلفية أندرويد
`dio_client:12` (`https://nomnow-o4ba.onrender.com/` — مصدر واحد سليم الاشتقاق `socket:26-27` لكن بلا env)؛ `AndroidManifest:11` (`usesCleartextTraffic="true"`)؛ `AndroidManifest:2-6` (بلا `ACCESS_BACKGROUND_LOCATION` رغم `location_service:185-192` foreground). الإصلاح: `--dart-define`/env + `false` + `networkSecurityConfig` + طلب تدريجي للخلفية. التحقق: بناء staging دون لمس كود؛ `http://` يُرفض؛ `driver:updateLocation` يستمر 5 دقائق خلفية.

### [M-5] تحقق إدخال ناقص
`settings:513-521` (كلمة بلا سياسة حتى فارغة تُرسل)؛ `:543-556` (اسم `>2` فقط بلا حد أعلى)؛ `auth_controller:181-212` (صور: `lookupMimeType` من الامتداد فقط + حد 5MB وضغط 1600px/70% سليمان). الإصلاح: حد أدنى 8 للكلمة + 60 للاسم + فحص magic bytes. التحقق: كلمة حرف واحد وملف نصي `.jpg` يجتازان حالياً.

### [M-6] أداء: `Obx` واسع + ثقيل في `build` + صور كاملة الدقة
`home:371-410` (`Obx` يلف `GoogleMap` كاملاً + markers كل نبضة موقع)؛ `settings:37-230` (`Obx` يلف الشاشة كلها)؛ `financial:613` + `cash:391,442` (`DateFormat` جديد لكل صف)؛ `notifications:121-129` (`now()` لكل عنصر)؛ صور `settings:864-872` (80px تعرض الأصل) + `order_details:546-548` (64px) + `sign_up_form:159-161`. الإصلاح: تضييق `Obx` + `static final DateFormat` + `ResizeImage(width:160)` + حساب المسافات خارج `build`/debounce. التحقق: DevTools Performance/Memory قبل/بعد قيادة وهمية.

### [M-7] `logout` يمحو التفضيلات + كلمة المرور تبقى في الذاكرة
`auth_controller:778-797` (`_storage.erase()` يمحو token وlang وثيم وإشعارات لا تُزامن `notification_store:60-68`)؛ `clearLoginForm` في logout فقط (`:794`) لا بعد `_handleLoginSuccess:799-812`. الإصلاح: `remove(token/driverId/isLoggedIn)` فقط + مسح `loginPasswordController` فور النجاح. التحقق: خروج → اللغة/الثيم باقية والتوكن ممسوح؛ دخول → حقل الكلمة فارغ.

### [M-8] تايم-لاين أخضر دائم + حالة تقبل التراجع
`past_order_details:512-521` (الكل `isDone=true` + زمن القبول مُختلق من `createdAt`)؛ `order_details:40-47` (أي حدث يكتب فوق بلا ترتيب)؛ `proof:47-48` (أي `delivered` يخرجك دون مطابقة `orderId`). طلب `cancelled` يعرض "تم التوصيل" أخضر. الإصلاح: اشتقاق `isDone` من `orderStatus` + `"—"` للغائب + حراسة انتقالات + مطابقة `orderId`. التحقق: اعرض `cancelled` → أخضر كامل حالياً.

---

## 🔵 تحسينات منخفضة الأولوية
- **[L-1]** اسم المطعم بأقرب إحداثية بلا عتبة (`new_order_request_screen:97-129`، خاصة `:111-123`) — بعيد 50كم يُعرض بثقة. أضف عتبة 1–2كم وشارة "غير مؤكد".
- **[L-2]** لوق PII مطول + FCM بعد الخروج (`notification_service:162-168` كل حمولة FCM + `socket:427` كل عرض طلب بهواتف/عناوين `order_details:575-588`؛ `onTokenRefresh:30-32` يبقى بعد logout). اخفض لـ IDs في release (`kReleaseMode`) وألغِ الاشتراك عند الخروج. لا توكن يُطبع (سليم).
- **[L-3]** لا موديلات إطلاقاً — كل العقود `Map` خام (`driverData={}.obs:48`؛ `order_details:116,143-153`؛ `new_order:21-25`؛ 5 نسخ `_money`). خطأ إملائي = `null` صامت (حدث فعلاً: `idImage` في `auth:73-77`). يكفي `OrderSummary/WalletSummary/DriverProfile.fromJson` + `earningOf/money` واحدة.
- **[L-4]** `Get.context!` + حوارات مكدسة + `setState` في `initState` (`app_pages:44`؛ `active_order_pop_guard:43-48`؛ `delivery_map:120-138`؛ `_refreshMyLocation:87-96` بلا `mounted`). أضف حارس `null` + `isDialogOpen` + إسناد مباشر.
- **[L-5]** كود ميت مؤكد: `CashCollectionController` (4 أسطر بلا أي `Get.put/find`/استيراد — الشاشة تستخدم `WalletController:43` → احذف الملف)؛ ومسار `PaymentCollectionScreen` (C-2). **تصحيح:** `ProofOfDeliveryScreen` ليست ميتة (`delivery_map:335-337`)؛ `flutter_local_notifications` مستخدمة (`notification_service:3,14,27,48,63`)؛ لا `SettlementController` حالياً.

---

## ملاحظات تحتاج تأكيدك (من الباك/المنتج — ليست findings)
- خطأ إملائي `api/driver/dirver-info` (`auth:396`): هل المسار الحقيقي `driver-info`؟ كل إقلاع يعتمد عليه.
- أسماء أحداث السوكيت حرفياً (`driver:goOnline/goOffline/updateLocation`, `order:driverResponse/startDelivery/delivered` + المستمعات الـ 11) وenums (`pending/accepted/preparing/ready/picked_up/on_the_way/delivered/cancelled` + `online/busy/offline` + `approved/pending/rejected/blocked`) — حرف واحد = ميزة ميتة بصمت.
- شكل الأخطاء: هل الباك يرسل `code` (FILE_TOO_LARGE/INVALID_FILE_TYPE/DOCUMENTS_REQUIRED/ACCOUNT_* كما يفترض `auth:552-581,860-887`) و`message` و`retryAfterSeconds` عند 429؟ التعليق نفسه يشكك (`:863-864`).
- دلالات `active-order` (يفلتر `picked_up/on_the_way` فقط `auth:733-735`؟) و`totalSettled` محلي (خام `totalPrice`) مقابل `pendingSettlement/cashHeldForSettlement` من الباك (صافي؟) ومفتاح الصافي (`netEffect` مقابل `netEffectOnBalance`) وعتبة الحد (`>=` في `wallet:95-96` مقابل `>`؟) وقيم `country` الحقيقية (`DE/US` مقابل `SY/syria/germany` بأي حالة؟).
- ملكية الموارد: هل `orders/:id` و`startDelivery/delivered` تُرفض لغير السائق المُسند؟ العميل لا يتحقق (`auth:704-755`، `socket:426-443`). وهل `logout` يُبطل ربط `fcmToken` وإلا استمرت إشعارات الحساب السابق؟
- تواريخ UTC أم محلية؟ لا `toLocal()` في `lib/`؛ وفلتر `yyyy-MM-dd` محلي (`orders_history:63`) قد يقلب اليوم بين سوريا وبرلين. وعتبة `limitUsagePercent` هل تصل نصاً (`wallet:88` يرمي)؟
- ضرائب US (`_shouldShowTax` تعرض DE فقط `order_details:86-89` — مقصود؟) و`usesCleartextTraffic` وحقن `MAPS_API_KEY` والتوقيع مقصودة للنهائي؟ وحدود brute-force لـ login/OTP في الباك (CORS/rate-limit لا تُفحص من الموبايل)؟
- هل إزالة مسار الدفع مقصودة (يعيش داخل `order_details` الآن) أم مؤجلة؟ وهل `/payment-collection` داكنة دائماً قصداً (`payment_collection:19-23` تتجاهل `isDark`)؟ وهل الباك يقبل بديل `verificationId` حتى لا يعبر `otp` طبقة التنقل؟

## ما فُحص وكان سليماً
- حساب المسافات Haversine + تحقق GeoJSON + رفض (0,0) (`geo_utils:18-70` + استعمالات صحيحة الاتجاه `new_order:197-204`، `delivery_map:134`، `order_details:93`)؛ وأولوية الأجر (`driverEarning ?? originalDeliveryFee ?? deliveryFee`) باختباراتها الثمانية؛ و`_money` العرضية (`tryParse`)؛ وقفل القبول/الرفض (`new_order_controller:65-118` + فحص `isConnected` قبل emit `socket:455-469`)؛ وزر "تم التسليم" (`_isSubmitting` + انتظار تأكيد `delivered` `proof:46-83`)؛ ومفتاح online (انتظار `currentStatus` 3s + fallback HTTP + قفل + مؤشر degraded `home:220-240,62-66`).
- الإقلاع لا يُحجب بـ Firebase/FCM (بعد أول إطار + timeouts `main:94-120`)؛ ومستمعو السوكيت مرة واحدة (`socket:98-101` + guard `:73-76`)؛ وتنظيف سوكيت/موقع عند الخروج (`auth:782-787`)؛ و`mounted` في المسارات الحرجة (`home:191,194,208`، `delivery_map:56,75,81`، `forgot:64`، `reset:87,134`، `order_details:58`)؛ ولا `FutureBuilder` داخل `build` (صفر)؛ وقوائم `builder` (`notifications:72`، `orders_history:135`)؛ وصلاحيات الموقع (`location:94-117` + رسائل `home:242-261`)؛ وحارسا `PopScope` غير مكدسين (`app_pages:108-111`).
- لا Dio/GetStorage مباشر في الشاشات (في main/core/data/المتحكمات فقط)؛ والمستمع العام يُزال في dispose (`order_details:66-74`)؛ وعنوان السوكيت مشتق من `DioClient` (`socket:24-27`)؛ ولا `TODO/FIXME/localhost`/بيانات وهمية؛ وحد الرفع 5MB + ضغط 1600px/70% + تطبيع هاتف SY/DE في login/forgot + throttle موقع 6s + heartbeat 30s + سجل إشعارات dedupe/سقف 50؛ ولا deep links معلنة (لا سطح هجوم) وإشعار FCM يوقظ السوكيت فقط (`notification:156-160` — آمن).

## خطة إصلاح مقترحة بالترتيب
1. **[C-4]** دوّر مفتاح الخرائط وقيده — دقائق وتنقذ الفوترة.
2. **[C-1] + [C-2]** أصلح بوابة الدفع (بطاقة ≠ كاش + تحصيل قبل تسليم) — توقف النزيف المالي.
3. **[C-5] + [C-7] + [H-6]** أمان الجلسة (secure storage + expiry + 401 مركزي + حالة خطأ مرئية) — تنهي "الأصفار الكاذبة والجلسات الشبح".
4. **[C-3]** وحّد حقن GetX (`find` لا `put` في views) — يوقف الكراش الأكثر تكراراً.
5. **[C-6]** مفاتيح iOS — تعيد iPhone للخدمة.
6. **[C-8] + [H-4]** حصّن التحليلات (`tryParse` + `—`) — الشاشات المالية لا تسقط أبداً.
7. **[H-1] + [H-2] + [H-3]** تحقق الاستلام + حالة الأحرف + `extractOrderId` موحد.
8. **[H-5]** أصلح السوكيت (stream + إعادة `goOnline`) ثم **[H-7]** الـ OTP (أوقف إرجاعه + فعّل الإعادة).
9. **[H-8] + [H-9] + [H-10]** سباق التنقل + حفظ الاسم + العملة المركزية.
10. **[M-1 → M-8]** ثم **[L-1 → L-5]** دين الأداء/المعمارية تدريجياً، مع اختبارات للمسارات الحرجة (401/logout، فشل محفظة، عملة، `totalSettled`، reconnect) قبل أي تسليم عميل.
