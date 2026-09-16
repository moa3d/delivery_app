# إعدادات مطلوبة بعد التعديل — تطبيق السائق

> **لا توجد حزم جديدة.** كل التعديلات تعتمد على `geolocator` و `get` و `get_storage`
> و `google_maps_flutter` الموجودة أصلاً في المشروع. المطلوب فقط إعدادات المنصّات
> الأصلية: التتبّع في الخلفية يحتاج صلاحيات وخدمة نظام، والخريطة تحتاج مفتاح API.

---

## 1) أندرويد

### `android/app/src/main/AndroidManifest.xml`

أضف الصلاحيات التالية **قبل** وسم `<application>`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- مطلوبة لاستمرار التتبّع بعد تصغير التطبيق -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- لعرض الإشعار الدائم على أندرويد 13+ -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

أضف أيضاً في وسم `<application>`:
```xml
android:enableOnBackInvokedCallback="true"
```
وهي ضرورية ليعمل `PopScope` (الخروج ب confirmation) على أندرويد 14+.

خدمة `GeolocatorLocationService` تُدمج تلقائياً من مانيفست الحزمة. إذا ظهر خطأ
`Missing foregroundServiceType` عند البناء لـ API 34+، أضف داخل `<application>`:

```xml
<service
    android:name="com.baseflow.geolocator.GeolocatorLocationService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="location"
    tools:node="merge" />
```

مع إضافة `xmlns:tools="http://schemas.android.com/tools"` في وسم `<manifest>`.

### `android/app/build.gradle`

```gradle
android {
    compileSdk 35
    defaultConfig {
        minSdk 21
        targetSdk 35
    }
}
```

### توقيع الإصدار

البناء يقرأ مفتاح التوقيع من `android/key.properties` (غير متعقَّب في git). عند غياب
الملف — أو نقص أحد حقوله الأربعة أو ضياع ملف المفتاح — يعود الإصدار إلى مفاتيح
debug تلقائياً، فيبقى `flutter run --release` يعمل عند كل مطوّر، **لكن حزمة موقَّعة
بـdebug لا تُقبل على Google Play**.

التجهيز مرة واحدة:

```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties   # ثم املأ القيم
```

للتحقّق أن الإصدار صار يلتقط المفتاح:

```bash
cd android && ./gradlew :app:signingReport
```

يجب أن يظهر تحت `Variant: release` السطر `Config: release` لا `Config: debug`.

> **⚠️ ضياع الـkeystore أو كلمة مروره = استحالة تحديث التطبيق على Google Play
> نهائياً.** احتفظ بنسخة احتياطية خارج المشروع وخارج git.

### ملاحظة مهمة حول صلاحية "طوال الوقت"

التصميم الحالي يستخدم **صلاحية "أثناء الاستخدام" (While in use) + Foreground Service**،
وهذا كافٍ تماماً لاستمرار التتبّع بعد تصغير التطبيق أو إطفاء الشاشة، ويتجنّب
مراجعة Google Play الخاصة بصلاحية `ACCESS_BACKGROUND_LOCATION` (التي تتطلّب
نموذج إفصاح وتستغرق أسابيع). لا تطلب `ACCESS_BACKGROUND_LOCATION` إلا إذا احتجت
التتبّع مع التطبيق مقتول تماماً — وهو ليس مطلوباً هنا.

---

## 2) iOS

### `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج موقعك لإرسال طلبات التوصيل القريبة منك وتمكين تتبّع الطلب.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>نحتاج موقعك أثناء العمل حتى تصلك الطلبات ويستطيع الزبون تتبّع طلبه.</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

### Xcode

`Runner` ← **Signing & Capabilities** ← `+ Capability` ← **Background Modes** ←
فعّل ✅ **Location updates**.

> **⚠️ تحذير iOS حرج:** بدون هذه الخطوة سيرمي iOS استثناءً Objective-C غير قابل
> لالتقاطه في Dart عند تفعيل `allowBackgroundLocationUpdates: true` داخل
> `LocationService`. التطبيق سيسقط فوراً بدون رسالة خطأ واضحة.

---

> مفتاح الخريطة على iOS ليس هنا — راجع القسم 3 أدناه.

---

## 3) مفاتيح خرائط غوغل

المفتاح لا يُكتب داخل الكود على أي من المنصّتين، بل يُحقن من ملف محلي:

| المنصّة | الملف | مسار الحقن |
|---|---|---|
| أندرويد | `android/local.properties` → `MAPS_API_KEY=...` | `app/build.gradle.kts` يقرأه ويضعه في `manifestPlaceholders` → `${MAPS_API_KEY}` في `AndroidManifest.xml` |
| iOS | `ios/Flutter/Maps.xcconfig` → `MAPS_API_KEY = ...` | `Info.plist` (`MapsApiKey = $(MAPS_API_KEY)`) → `AppDelegate.swift` يمرّره إلى `GMSServices.provideAPIKey` |

**كلا الملفين غير متعقَّبين في git** — كل مطوّر ينشئهما محلياً. وعند غيابهما لا ينكسر
البناء ولا يسقط التطبيق: الخريطة وحدها تظهر رمادية فارغة **بلا أي رسالة خطأ**، وهذا
أول ما يجب فحصه عند "الخريطة لا تعمل عندي".

> **⚠️ مفتاح منفصل لكل منصّة — إلزامي.** مفتاح Google Cloud يقبل **نوع تقييد تطبيقات
> واحداً فقط**: إمّا "Android apps" وإمّا "iOS apps"، لا الاثنين معاً. فالمفتاح المشترك
> إمّا مقيَّد بأندرويد فتظهر خريطة iOS رمادية، وإمّا غير مقيَّد فيكون مكشوفاً لمن
> يستخرجه من الحزمة.

الإعداد المطلوب في Google Cloud Console لكل مفتاح:

| | مفتاح أندرويد | مفتاح iOS |
|---|---|---|
| التقييد | Android apps: `com.nomnow.driver` + بصمة SHA-1 | iOS apps: bundle ID `com.nomnow.driver` |
| الـAPI المفعَّل | Maps SDK for Android | **Maps SDK for iOS** |

نسيان تفعيل *Maps SDK for iOS* تحديداً هو السبب الأشيع لخريطة رمادية على iOS رغم
صحّة المفتاح.

---

## 4) أول بناء على ماك

الملفات المولّدة على ويندوز (`ios/Flutter/Generated.xcconfig` و `.dart_tool/` و
`build/`) تحمل مسارات `C:\flutter\...`، و `ios/Podfile` يقرأ `FLUTTER_ROOT` منها
حرفياً. لذلك بعد نقل المشروع إلى ماك، ابدأ بالتنظيف وإلا فشل `pod install` برسالة
`FLUTTER_ROOT not found`:

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace   # الـworkspace لا الـxcodeproj
```

- لا يوجد `Podfile.lock` في المشروع بعد — أول `pod install` هو الذي ينشئه.
- **التوقيع:** `Runner` ← Signing & Capabilities ← اختر **Team**. لا يوجد
  `DEVELOPMENT_TEAM` محفوظ في المشروع؛ المحاكي يعمل بدونه، الجهاز الحقيقي لا.
- **لا تخفّض** `platform :ios, '15.0'` في `Podfile` ولا
  `IPHONEOS_DEPLOYMENT_TARGET = 15.0` — القيمتان متطابقتان عمداً، و
  `google_maps_flutter` و Firebase 15 يتطلّبانهما.

---

## 5) الإشعارات على iOS — غير مكتملة بعد

`firebase_core` و `firebase_messaging` مضافتان، وأندرويد يعمل عبر
`android/app/google-services.json` الموجود. أما iOS فينقصه ثلاثة أشياء:

1. تسجيل تطبيق iOS بالـbundle ID `com.nomnow.driver` في مشروع Firebase
   `nomnow-c1fc3`، وتنزيل `GoogleService-Info.plist` إلى `ios/Runner/`
   **وإضافته إلى هدف Runner من داخل Xcode** — نسخه إلى المجلد وحده لا يكفي، لن
   يُحزَم مع التطبيق.
2. مفتاح APNs (‎.p8) من Apple Developer، مرفوعاً في Firebase ←
   Project Settings ← Cloud Messaging. بدونه لا يصل أي إشعار على iOS مهما كان
   الكود صحيحاً.
3. Xcode: `+ Capability` ← **Push Notifications**.

`Firebase.initializeApp()` في `main.dart` محاط بـ`try/catch` مع مهلة، فغياب هذه
الإعدادات **لا يُسقط التطبيق ولا يؤخّر إقلاعه** — الإشعارات وحدها تبقى معطّلة.

---

## 6) تحقّق سريع بعد التطبيق

| السيناريو | النتيجة المتوقّعة |
|---|---|
| تفعيل مفتاح "متصل" | يظهر إشعار دائم "تطبيق NUMNOW قيد العمل" |
| تصغير التطبيق أثناء الاتصال | الإشعار يبقى، والموقع يستمر بالوصول للسيرفر |
| الانتقال لتبويب المحفظة | التتبّع لا يتوقّف (كان يتوقّف سابقاً) |
| تفعيل "متصل" وGPS مطفأ | رسالة "يُرجى تشغيل خدمة الموقع" ولا يتم الانتقال إلى online |
| قبول طلب في الثانية الأخيرة | لا يُرسل "rejected" بعد القبول |
| قفل الجهاز 10 دقائق ثم فتحه | يُعاد اتصال السوكيت تلقائياً وتُجلب حالة الطلب النشط |
| فتح شاشة الخريطة أثناء التوصيل | تيّار GPS واحد فقط (لا تيّاران) |
| فتح شاشة الخريطة (أندرويد و iOS) | تظهر الخريطة بتفاصيلها، لا مساحة رمادية فارغة |
| تشغيل iOS بلا `Maps.xcconfig` | التطبيق يعمل كاملاً والخريطة وحدها فارغة (لا سقوط) |
