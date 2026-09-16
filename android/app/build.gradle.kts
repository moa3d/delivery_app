import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // 👈 أضف هذا السطر
    id("dev.flutter.flutter-gradle-plugin")
}

// توقيع الإصدار — يُقرأ من android/key.properties (غير متعقَّب في git).
// عند غياب الملف أو نقص أحد حقوله أو ضياع ملف المفتاح، يبقى الإصدار موقَّعاً
// بمفاتيح debug كما كان، فلا ينكسر `flutter run --release` عند من لا يملك
// المفتاح — لكن حزمة موقَّعة بـdebug لا تُقبل على Google Play.
val keystoreProperties = Properties().apply {
    val propsFile = rootProject.file("key.properties")
    if (propsFile.exists()) propsFile.inputStream().use { load(it) }
}

val hasKeystoreFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keystoreProperties.getProperty(it).isNullOrBlank() }

val releaseStoreFile = keystoreProperties.getProperty("storeFile")
    ?.let { rootProject.file(it) }
    ?.takeIf { hasKeystoreFields && it.exists() }

android {
    namespace = "com.nomnow.driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true // إضافة هذا السطر
        sourceCompatibility = JavaVersion.VERSION_17 // تأكد أنها 1.8 أو أحدث
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nomnow.driver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // مفتاح خرائط غوغل يُقرأ من local.properties (غير متعقَّب في git)
        // بدل كتابته داخل AndroidManifest المرفوع مع الكود.
        // البناء لا يفشل عند غيابه — تظهر الخريطة فارغة فقط.
        val mapsApiKey: String = Properties().apply {
            val propsFile = rootProject.file("local.properties")
            if (propsFile.exists()) propsFile.inputStream().use { load(it) }
        }.getProperty("MAPS_API_KEY") ?: ""
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
