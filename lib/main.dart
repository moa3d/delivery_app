import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_core/firebase_core.dart';

// الاستيرادات الخاصة بالهيكل الجديد
import 'core/localization/message.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_controller.dart';
import 'routes/app_pages.dart';
import 'core/bindings/initial_binding.dart';
import 'data/services/location_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/notification_store.dart';

void main() async {
  // التأكد من تهيئة أدوات Flutter قبل أي عملية أخرى
  WidgetsFlutterBinding.ensureInitialized();

  // إعدادات شريط النظام (Status Bar) والتحكم في الشفافية لتحسين المظهر البصري
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
  ));

  // تم تعطيل Edge-to-Edge لأنه يتعارض مع أزرار النظام في Android و iOS
  // if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
  //   SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // }

  // ملاحظة v3.0 (إصلاح الشاشة السوداء على أجهزة بلا Google Mobile Services):
  // تهيئة Firebase/FCM نُقلت إلى ما بعد runApp (انظر MyApp._initFirebaseInBackground).
  // السبب: على أجهزة مثل Huawei الحديثة (بلا GMS كاملة)، كان
  // FirebaseMessaging.getToken() قد يعلّق للأبد — وبما أنه كان await قبل
  // runApp، تتوقف main قبل رسم أول إطار → شاشة سوداء. المحاكي يعمل لأنه
  // يحوي GMS. الحل: لا نحجب الإقلاع بأي عملية تعتمد على GMS.

  // تهيئة مخزن البيانات المحلي (GetStorage) — سريعة ولا تعتمد على GMS.
  try {
    await GetStorage.init();
  } catch (e) {
    debugPrint('⚠️ GetStorage init failed: $e');
  }

  // سجل الإشعارات المحلي — يعتمد على GetStorage فقط (لا على Firebase)،
  // فيُسجَّل هنا كي تعمل شاشة الإشعارات حتى على جهاز بلا GMS.
  try {
    Get.put(NotificationStore().load(), permanent: true);
  } catch (e) {
    debugPrint('⚠️ NotificationStore init failed: $e');
  }

  // خدمة الموقع المركزية — تُسجَّل قبل runApp لأن AuthController يعتمد عليها
  // فور إنشائه في InitialBinding. معزولة: فشل صلاحيات/خدمة الموقع يجب ألا
  // يمنع الإقلاع.
  try {
    await Get.putAsync(() => LocationService().init(), permanent: true);
  } catch (e, s) {
    debugPrint('⚠️ LocationService init failed — continuing: $e');
    debugPrintStack(stackTrace: s);
  }

  final box = GetStorage();

  // متحكم الوضع الليلي/النهاري — دائم ويقرأ الاختيار المحفوظ من GetStorage.
  // يُسجَّل هنا (بعد تهيئة التخزين وقبل runApp) ليعمل من أول إطار.
  Get.put(ThemeController(), permanent: true);

  // حقن المتحكمات الأساسية في ذاكرة التطبيق بشكل دائم يتم الآن عبر InitialBinding في GetMaterialApp
  // إدارة خدمة السوكيت للربط مع الخادم في حال وجود توكن مسبق تتم برمجياً داخل onInit للمتحكمات

  // تحديد اللغة المختارة من المستخدم أو استخدام لغة الجهاز الافتراضية
  String? savedLang = box.read('lang');
  Locale initialLocale = savedLang != null
      ? Locale(savedLang)
      : (Get.deviceLocale ?? const Locale('en'));

  runApp(MyApp(initialLocale: initialLocale));
}

class MyApp extends StatefulWidget {
  final Locale initialLocale;

  const MyApp({super.key, required this.initialLocale});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // تهيئة Firebase/FCM بعد رسم أول إطار — غير محجوبة للواجهة.
    // بهذا تفتح الشاشة فوراً، ثم تُهيَّأ الإشعارات في الخلفية. لو تعذّرت
    // (جهاز بلا GMS مثل Huawei)، يبقى التطبيق يعمل كاملاً بلا إشعارات.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFirebaseInBackground();
    });
  }

  Future<void> _initFirebaseInBackground() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      // timeout إضافي: على جهاز بلا GMS قد لا يرمي getToken استثناءً بل
      // يعلّق؛ الـ timeout يضمن عدم تعليق هذه المهمة الخلفية للأبد.
      await Firebase.initializeApp()
          .timeout(const Duration(seconds: 10));
      await Get.putAsync(() => NotificationService().init())
          .timeout(const Duration(seconds: 15));
      debugPrint('✅ Firebase/Notifications initialized');
    } catch (e, s) {
      debugPrint('⚠️ Firebase/Notifications unavailable — app continues without: $e');
      debugPrintStack(stackTrace: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obx يُعيد بناء GetMaterialApp عند تغيير الوضع من الإعدادات فوراً
    final themeController = Get.find<ThemeController>();
    return Obx(
      () => GetMaterialApp(
        // إعدادات العنوان واللغة
        title: 'NUMNOW Courier',
        debugShowCheckedModeBanner: false,
        translations: Messages(),
        locale: widget.initialLocale,
        fallbackLocale: const Locale('en'),

        // إعدادات الثيم — الوضع يتبع اختيار المستخدم المحفوظ
        // (system افتراضياً عند أول تشغيل) بدل الالتزام بالنظام فقط
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.themeMode.value,

        // حقن التبعيات الأولية (Professional Binding)
        initialBinding: InitialBinding(),

        // إدارة المسارات من الملف المنفصل
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,

        // غلاف عام للتطبيق للتحكم في الأبعاد والمنطقة الآمنة (SafeArea)
        builder: (context, child) {
          return Scaffold(
            // منع لوحة المفاتيح من إفساد تصميم الشاشة عند ظهورها
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              top: false,
              // السماح للمحتوى بالوصول لأعلى الشاشة خلف شريط الحالة
              bottom: true,
              // حماية أزرار التحكم السفلية من التداخل مع نظام التشغيل
              child: child!,
            ),
          );
        },
      ),
    );
  }
}
