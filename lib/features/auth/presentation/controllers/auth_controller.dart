import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:io';
import 'package:dio/dio.dart' as dio_instance;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../../../../data/api_client/dio_client.dart';
import '../../../../data/services/notification_service.dart';
import '../../../../data/services/location_service.dart';
import '../../../../data/services/socket_service.dart';
import 'package:delivery_app/routes/app_routes.dart';
import 'package:delivery_app/features/orders/presentation/views/delivery_map_screen.dart';

/// نتيجة خطوة من فلو إعادة تعيين كلمة المرور (v4.3). الشاشة تحتاج أكثر من
/// رسالة: هل نجحت الخطوة، وكم ثانية تبقّت قبل السماح بإعادة الإرسال.
class PasswordResetResult {
  final bool success;
  final String? message;
  final int? retryAfterSeconds;

  const PasswordResetResult({
    required this.success,
    this.message,
    this.retryAfterSeconds,
  });
}

/// المتحكم المركزي لإدارة عمليات التوثيق وبيانات السائق والملف الشخصي
class AuthController extends GetxController {
  final _storage = GetStorage();
  final _api = DioClient().instance;
  final _picker = ImagePicker();

  // حقول التحكم في النصوص للواجهات
  final loginPhoneController = TextEditingController();
  final loginPasswordController = TextEditingController();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final plateController = TextEditingController();
  final passwordController = TextEditingController();

  // متغيرات الحالة والبيانات التفاعلية
  final isLoading = false.obs;
  final driverData = {}.obs;
  final totalDeliveries = 0.obs;
  final selectedVehicle = RxnString();
  final selectedCity = RxnString();
  final nearbyRestaurants = <Map<String, dynamic>>[].obs;

  /// مصدر الحقيقة الوحيد لحالة الاتصال (online/busy = true).
  /// تُكتب فقط من السيرفر: fetchDriverData + driver:currentStatus.
  /// الشاشات تعرض فقط — ممنوع الكتابة المتفائلة محلياً.
  final isOnline = false.obs;

  /// true حتى يكتمل أول fetchDriverData — خلالها المؤشر رمادي (غير مؤكد)
  /// بدل عرض كاش GetStorage قديم أخضر كاذب.
  final isStatusSyncing = true.obs;

  /// قفل يمنع تبديلين متسابقين أثناء انتظار تأكيد السيرفر.
  final isTogglingStatus = false.obs;

  /// يوحّد قاعدة online/busy في مكان واحد. بلا كاش محلي عمداً: لا أحد
  /// يقرأه، وكتابته كانت تُسقط الاختبارات بخطأ من طابور GetStorage.
  void applyServerAvailability(String? availability) {
    final online = availability == 'online' || availability == 'busy';
    if (isOnline.value != online) isOnline.value = online;
  }

  /// مستندات السائق مفهرسة بـ `type` القادم من الباك.
  ///
  /// الباك (`getDriverInfo` / `updateDriverInfo`) يُرجع مصفوفة `documents`
  /// وحدها — لا يوجد في أي رد حقول مسطّحة مثل `idImage`، لذا كانت الواجهة
  /// تقرأ `null` دائماً وتُظهر كل المستندات ناقصة إلى الأبد.
  final documents = <String, Map<String, dynamic>>{}.obs;

  /// اسم حقل الرفع (multipart) ← قيمة `type` المقابلة في الباك
  static const Map<String, String> docTypeByField = {
    'idImage': 'id',
    'drivingLicenseImage': 'driving_license',
    'vehicleRegistrationImage': 'vehicle_registration',
  };

  /// يُعيد بناء خريطة المستندات من مصفوفة `documents` القادمة من السيرفر
  void _syncDocuments(dynamic raw) {
    if (raw is! List) return;
    final next = <String, Map<String, dynamic>>{};
    for (final doc in raw) {
      if (doc is! Map) continue;
      final type = doc['type']?.toString();
      if (type == null || type.isEmpty) continue;
      next[type] = Map<String, dynamic>.from(doc);
    }
    documents
      ..clear()
      ..addAll(next)
      ..refresh();
  }

  Map<String, dynamic>? _documentFor(String fieldName) =>
      documents[docTypeByField[fieldName]];

  /// هل رُفع هذا المستند فعلياً (وله صورة على السيرفر)؟
  bool hasDocument(String fieldName) {
    final url = _documentFor(fieldName)?['image']?['url'];
    return url is String && url.isNotEmpty;
  }

  /// `missing` | `pending` | `approved` | `rejected`
  String documentStatus(String fieldName) {
    if (!hasDocument(fieldName)) return 'missing';
    final status = _documentFor(fieldName)?['status']?.toString();
    return (status == null || status.isEmpty) ? 'pending' : status;
  }

  /// سبب الرفض الذي كتبه الأدمن — يظهر فقط عند الرفض
  String? documentRejectionReason(String fieldName) {
    if (documentStatus(fieldName) != 'rejected') return null;
    final reason = _documentFor(fieldName)?['rejectionReason']?.toString();
    return (reason == null || reason.isEmpty) ? null : reason;
  }

  /// رمز عملة السائق حسب بلده — يمنع تثبيت "ل.س" على شاشات السائق الألماني
  String get currencySymbol {
    switch (driverData['country']?.toString()) {
      case 'DE':
        return 'currency_eur'.tr;
      case 'US':
        return 'currency_usd'.tr;
      default:
        return 'currency_syp'.tr;
    }
  }

  /// كل المستندات مرفوعة وغير مرفوضة — لا شيء ينتظر تدخّل السائق
  bool get allDocumentsSubmitted => docTypeByField.keys.every(
      (f) => hasDocument(f) && documentStatus(f) != 'rejected');

  /// يطابق التحقق في driver.controller.js حرفياً
  static final _syPhone = RegExp(r'^\+963[9][0-9]{8}$');
  static final _dePhone = RegExp(r'^\+49[1-9][0-9]{9,13}$');

  /// يُرجع الرقم منظّماً إن كان صالحاً، وإلا null
  String? validatePhone(String raw) {
    var p = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (!p.startsWith('+')) return null;
    if (_syPhone.hasMatch(p) || _dePhone.hasMatch(p)) return p;
    return null;
  }

  // ملفات الوثائق والصورة الشخصية
  final profileImage = Rxn<File>();
  final idCardFile = Rxn<File>();
  final licenseFile = Rxn<File>();
  final registrationFile = Rxn<File>();

  // ── الرفع ─────────────────────────────────────────────────────
  /// حد multer في الباك (`middleware/upload.js`) — رُفع إلى 5MB في v2.0
  static const _maxUploadBytes = 5 * 1024 * 1024;

  /// المهلة العامة (40 ث) لا تكفي لإقلاع Render البارد + الرفع إلى Cloudinary
  static const _uploadTimeout = Duration(seconds: 90);

  final _uploadOptions = dio_instance.Options(
    sendTimeout: _uploadTimeout,
    receiveTimeout: _uploadTimeout,
  );

  /// حقل المستند الجاري رفعه (`idImage`...) بعد اختيار الصورة — للمؤشر في الواجهة
  final uploadingField = RxnString();

  /// يمنع فتح المعرض مرتين أو رفعين متزامنين (يُضبط قبل فتح المعرض)
  bool _uploadInProgress = false;

  /// يختار صورة مضغوطة (أقصى بُعد 1600px) ويرفض ما يتجاوز حد السيرفر.
  /// `requestFullMetadata: false` يمنع طلب صلاحية مكتبة الصور على iOS.
  Future<XFile?> pickUploadImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 70,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    if (await image.length() > _maxUploadBytes) {
      _showWarning("alert".tr, "file_too_large".tr);
      return null;
    }
    return image;
  }

  /// جزء multipart بنوع صريح — Dio يستنتج النوع من الامتداد فقط، والملف
  /// بلا امتداد يُرسل `application/octet-stream` فيرفضه fileFilter في multer.
  Future<dio_instance.MultipartFile> _imagePart(String path) {
    final mime = lookupMimeType(path);
    if (mime != null && mime.startsWith('image/')) {
      return dio_instance.MultipartFile.fromFile(
        path,
        contentType: dio_instance.DioMediaType.parse(mime),
      );
    }
    return dio_instance.MultipartFile.fromFile(
      path,
      filename: 'upload.jpg',
      contentType: dio_instance.DioMediaType('image', 'jpeg'),
    );
  }

  @override
  void onInit() {
    super.onInit();
    if (isLoggedIn()) {
      fetchDriverData();
      fetchTotalDeliveries();
      updateFCMTokenOnServer();
      fetchActiveOrderOnStartup();
    }
  }

  /// التحقق من وجود توكن فعال في المخزن المحلي
  bool isLoggedIn() => _storage.read("token") != null;

  /// تنفيذ عملية تسجيل الدخول
  Future<void> login() async {
    if (loginPhoneController.text
        .trim()
        .isEmpty || loginPasswordController.text.isEmpty) {
      _showWarning("alert".tr, "enter_required_data".tr);
      return;
    }

    final normalizedPhone = validatePhone(loginPhoneController.text);
    if (normalizedPhone == null) {
      _showWarning("alert".tr, "invalid_phone_format".tr);
      return;
    }

    try {
      isLoading.value = true;
      final response = await _api.post("api/driver/loginwithphone", data: {
        "phone": normalizedPhone,
        "password": loginPasswordController.text,
      });
      if (response.statusCode == 200) {
        if (response.data['requiresVerification'] ?? false) {
          Get.toNamed('/otp', arguments: {
            "phone": loginPhoneController.text,
            "otp": response.data['otp']
          });
        } else {
          _handleLoginSuccess(response.data);
        }
      }
    } on dio_instance.DioException catch (e) {
      handleError(e);
    } catch (e) {
      _showWarning("alert".tr, "${"error".tr}: ${e.toString()}");
    } finally {
      isLoading.value = false;
    }
  }

  /// تسجيل حساب جديد ورفع الوثائق. يُرجع true عند إنشاء الحساب فعلاً.
  Future<bool> register() async {
    if (fullNameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        plateController.text.trim().isEmpty) {
      _showWarning("alert".tr, "enter_all_data".tr);
      return false;
    }

    final normalizedPhone = validatePhone(phoneController.text);
    if (normalizedPhone == null) {
      _showWarning("alert".tr, "invalid_phone_format".tr);
      return false;
    }

    // الوثائق الثلاث إلزامية في الباك أيضاً (B7)، ونفحصها هنا كي لا
    // يُرسل السائق نموذجاً كاملاً بالصور ثم يُرفض — راجع
    // docs/backend_documents_upload_report2.md
    if (idCardFile.value == null ||
        licenseFile.value == null ||
        registrationFile.value == null) {
      _showWarning("alert".tr, "docs_required".tr);
      return false;
    }

    try {
      isLoading.value = true;
      dio_instance.FormData formData = dio_instance.FormData.fromMap({
        "name": fullNameController.text.trim(),
        "phone": normalizedPhone,
        "email": emailController.text.trim(),
        "password": passwordController.text,
        "vehicletype": (selectedVehicle.value ?? "car").toLowerCase(),
        "vehicleplate": plateController.text.trim(),
        "zone": selectedCity.value ?? "General",
      });

      if (profileImage.value != null) {
        formData.files.add(MapEntry(
          "driverImage",
          await _imagePart(profileImage.value!.path),
        ));
      }
      formData.files.addAll([
        MapEntry("idImage", await _imagePart(idCardFile.value!.path)),
        MapEntry("drivingLicenseImage", await _imagePart(licenseFile.value!.path)),
        MapEntry(
          "vehicleRegistrationImage",
          await _imagePart(registrationFile.value!.path),
        ),
      ]);

      final response = await _api.post("api/driver/register",
          data: formData, options: _uploadOptions);
      if (response.statusCode == 201 || response.statusCode == 200) {
        clearRegistrationForm();
        // يدخل السائق بالرقم نفسه بلا إعادة كتابته
        loginPhoneController.text = normalizedPhone;
        _showAccountCreatedDialog();
        return true;
      }
      _showWarning("alert".tr, "unexpected_error".tr);
      return false;
    } on dio_instance.DioException catch (e) {
      _handleUploadError(e);
      return false;
    } catch (e) {
      _showWarning("alert".tr, "${"error".tr}: ${e.toString()}");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// حوار يشرح الخطوة التالية ويبقى ظاهراً حتى يقرأه السائق. الـsnackbar
  /// وحدها لم تكن تكفي: `Get.back()` التي كانت تليها تُغلق أي snackbar
  /// مفتوح وترجع فوراً (GetX 4.7)، فكانت رسالة النجاح تختفي في لحظتها.
  void _showAccountCreatedDialog() {
    Get.defaultDialog(
      title: "account_created".tr,
      middleText: "account_created_next".tr,
      textConfirm: "go_to_login".tr,
      confirmTextColor: Colors.white,
      onConfirm: () => Get.back(),
    );
  }

  /// تفريغ نموذج التسجيل بعد نجاحه وعند تسجيل الخروج. المتحكم مُسجَّل
  /// `permanent`، فبلا هذا التفريغ تبقى بيانات السائق وصور وثائقه في
  /// الحقول طوال عمر التطبيق ويراها من يسجّل بعده على الجهاز نفسه.
  void clearRegistrationForm() {
    fullNameController.clear();
    phoneController.clear();
    emailController.clear();
    passwordController.clear();
    plateController.clear();
    selectedVehicle.value = null;
    selectedCity.value = null;
    profileImage.value = null;
    idCardFile.value = null;
    licenseFile.value = null;
    registrationFile.value = null;
  }

  void clearLoginForm() {
    loginPhoneController.clear();
    loginPasswordController.clear();
  }

  /// التحقق من رمز OTP
  Future<void> verifyOTP(String phone, String otp) async {
    try {
      isLoading.value = true;
      final response = await _api.post(
          "api/driver/verifyphone", data: {"phone": phone, "otp": otp});
      if (response.statusCode == 200) _handleLoginSuccess(response.data);
    } on dio_instance.DioException catch (e) {
      handleError(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// جلب بيانات السائق وفحص حالته الأمنية
  Future<void> fetchDriverData() async {
    try {
      final response = await _api.get("api/driver/dirver-info");
      if (response.statusCode == 200 && response.data['driver'] != null) {
        driverData.assignAll(response.data['driver']);
        applyServerAvailability(
            response.data['driver']['availability']?.toString());
        _syncDocuments(response.data['driver']['documents']);
        _checkStatus();
        _syncLocationMode();
      }
    } on dio_instance.DioException catch (e) {
      if (e.response?.statusCode == 401) {
        logout();
        return;
      } else {
        handleError(e);
      }
    } finally {
      // أول مزامنة اكتملت (نجاحاً أو فشلاً) — نخرج من حالة "غير مؤكد".
      // عند الفشل تبقى isOnline على آخر قيمة مؤكدة بدل كاش قديم.
      if (isStatusSyncing.value) isStatusSyncing.value = false;
    }
  }

  void _checkStatus() {
    // قيم status المعتمدة في الباك إند: approved / pending / rejected / blocked
    String status = driverData['status'] ?? 'approved';
    final route = Get.currentRoute;
    if (status == 'blocked') {
      // الاستطلاع يستدعي هذه الدالة كل 45 ثانية — بلا هذا الشرط كانت
      // offAllNamed تُعيد بناء الشاشة نفسها دورياً وتُصفّر حالتها.
      if (route != '/blocked') Get.offAllNamed('/blocked');
    } else if (status == 'rejected') {
      logout(); // حساب مرفوض — إخراج السائق (مطابق لمنطق handleError)
    } else if (status == 'pending') {
      if (route != '/documents-completion') {
        Get.offAllNamed('/documents-completion');
      }
    } else if (route == '/login' || route == '/splash') {
      Get.offAllNamed('/main-navigation');
    } else if (route == '/documents-completion' || route == '/blocked') {
      // اعتُمد الحساب بينما السائق واقف على شاشة محجوزة
      _onAccountUnblocked();
    }
  }

  /// انتقال الحساب من محجوز إلى معتمد أثناء الاستطلاع
  void _onAccountUnblocked() {
    stopStatusPolling();
    // إعادة الاتصال ضرورية: connect() وحدها لا تكفي لو كان السوكيت قد
    // رُفض سابقاً بـ unauthorized، لأن _authRejected يوقف إعادة المحاولة.
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().connect();
    }
    fetchTotalDeliveries();
    // كل محاولات إرسال توكن FCM أثناء المراجعة رُفضت بـ403 (مسار
    // fcm-token محمي بـ auth)، ولا يُحفظ التوكن محلياً إلا بعد نجاح
    // الإرسال — فبلا هذه المحاولة لا تصل إشعارات الطلبات حتى إعادة
    // تشغيل التطبيق.
    updateFCMTokenOnServer();
    Get.offAllNamed('/main-navigation');
  }

  /// يضبط وضع خدمة الموقع حسب حالة السائق الحقيقية القادمة من السيرفر.
  /// نطلب الصلاحية فقط للحسابات المعتمدة كي لا نُزعج حساباً قيد المراجعة.
  void _syncLocationMode() {
    if (!Get.isRegistered<LocationService>()) return;
    if ((driverData['status']?.toString() ?? 'approved') != 'approved') return;

    // لا نطلب الصلاحية أثناء السبلاش — نافذة الصلاحية ستظهر فوق السبلاش
    // وتُشوّش على الإقلاع. التتبّع يبدأ عند تفعيل "متصل" في HomeScreen.
    if (Get.currentRoute == '/splash') return;

    final availability = driverData['availability']?.toString();
    final shouldPush = availability == 'online' || availability == 'busy';
    Get.find<LocationService>().start(pushToServer: shouldPush);
  }

  /// يُزامن رد update-info: `documents` كاملة + الحالة، لأن الباك يُعيد
  /// الحساب إلى `pending` بعد أي رفع مستند.
  void _applyDriverUpdate(dynamic driver) {
    if (driver is! Map) return;
    _syncDocuments(driver['documents']);
    for (final key in const ['status', 'isDocumentsVerified']) {
      if (driver[key] != null) driverData[key] = driver[key];
    }
    driverData.refresh();
  }

  /// رفع مستند (بطاقة هوية / رخصة / تسجيل سيارة). يُرجع true عند النجاح فقط.
  Future<bool> uploadDocument(String fieldName) async {
    if (_uploadInProgress) return false;
    _uploadInProgress = true;

    // الاستطلاع قد يُعيد بناء الشاشة في منتصف الرفع — نوقفه مؤقتاً
    final wasPolling = _statusPollTimer?.isActive ?? false;
    stopStatusPolling();

    try {
      final image = await pickUploadImage();
      if (image == null) return false;

      uploadingField.value = fieldName;
      isLoading.value = true;
      final formData = dio_instance.FormData();
      formData.files.add(MapEntry(fieldName, await _imagePart(image.path)));
      final response = await _api.patch("api/driver/update-info",
          data: formData, options: _uploadOptions);
      if (response.statusCode != 200) return false;

      _applyDriverUpdate(response.data['driver']);
      Get.snackbar("success".tr, "document_uploaded".tr);
      return true;
    } on dio_instance.DioException catch (e) {
      _handleUploadError(e);
      return false;
    } catch (e) {
      _showWarning("alert".tr, "${"error".tr}: ${e.toString()}");
      return false;
    } finally {
      _uploadInProgress = false;
      uploadingField.value = null;
      isLoading.value = false;
      if (wasPolling) startStatusPolling();
    }
  }

  /// تحديث صورة الملف الشخصي
  Future<void> updateProfileImage() async {
    if (_uploadInProgress) return;
    _uploadInProgress = true;
    try {
      final image = await pickUploadImage();
      if (image == null) return;
      isLoading.value = true;
      dio_instance.FormData formData = dio_instance.FormData();
      formData.files.add(
          MapEntry("driverImage", await _imagePart(image.path)));
      final response = await _api.patch("api/driver/update-info",
          data: formData, options: _uploadOptions);
      if (response.statusCode == 200) {
        driverData['driverImage'] = response.data['driver']['driverImage'];
        driverData.refresh();
      }
    } on dio_instance.DioException catch (e) {
      _handleUploadError(e);
    } catch (e) {
      _showWarning("alert".tr, "${"error".tr}: ${e.toString()}");
    } finally {
      _uploadInProgress = false;
      isLoading.value = false;
    }
  }

  /// أخطاء الرفع برسائل مفهومة. نعتمد على `code` الثابت الذي يُرجعه
  /// `upload.safe` في الباك لا على نص الرسالة، لأنها مترجمة حسب
  /// `Accept-Language` وقابلة للتغيير.
  void _handleUploadError(dio_instance.DioException e) {
    final res = e.response;
    if (res == null) {
      // انتهاء المهلة أو انقطاع الشبكة أثناء الرفع
      _showWarning("alert".tr, "upload_timeout".tr);
      return;
    }

    final data = res.data;
    final code = data is Map ? data['code']?.toString() : null;
    final message = data is Map ? (data['message']?.toString() ?? '') : '';

    if (code == 'FILE_TOO_LARGE' || res.statusCode == 413) {
      _showWarning("alert".tr, "file_too_large".tr);
      return;
    }
    if (code == 'INVALID_FILE_TYPE') {
      _showWarning("alert".tr, "invalid_image_type".tr);
      return;
    }
    if (code == 'DOCUMENTS_REQUIRED') {
      _showWarning("alert".tr, "docs_required".tr);
      return;
    }
    if (res.statusCode == 500 && message == 'Server error') {
      _showWarning("alert".tr, "upload_failed".tr);
      return;
    }
    handleError(e);
  }

  /// تحديث بيانات الملف الشخصي العامة
  Future<void> updateDriverProfile(Map<String, dynamic> data) async {
    try {
      isLoading.value = true;
      await _api.patch("api/driver/update-info", data: data);
      driverData.addAll(data);
      driverData.refresh();
      Get.back();
    } finally {
      isLoading.value = false;
    }
  }

  /// تغيير كلمة المرور
  Future<void> changePassword(String current, String next) async {
    try {
      isLoading.value = true;
      await _api.patch("api/driver/change-password",
          data: {"currentPassword": current, "newPassword": next});
      Get.back();
      Get.snackbar("success".tr, "password_changed".tr);
    } on dio_instance.DioException catch (e) {
      handleError(e);
    }
    finally {
      isLoading.value = false;
    }
  }

  /// v4.3 — طلب رمز إعادة التعيين عبر SMS بالهاتف حصراً (لم يعد بالإيميل،
  /// حتى لو كان للسائق بريد مسجَّل). الرقم يُرسل مطبَّعاً كما في تسجيل الدخول.
  Future<PasswordResetResult> forgotPassword(String phone) async {
    try {
      isLoading.value = true;
      final res =
          await _api.post("api/driver/forgot-password", data: {"phone": phone});
      final data = res.data;
      return PasswordResetResult(
        success: true,
        // مرحلة اختبار: الرمز يأتي ضمن نص الرسالة مؤقتاً — الشاشة تعرضه كما هو
        message: data is Map ? data['message']?.toString() : null,
      );
    } on dio_instance.DioException catch (e) {
      return _passwordResetError(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// v4.3 — تأكيد الرمز وتعيين كلمة المرور بخطوة واحدة. لم يعد هناك `:token`
  /// في المسار: الحقول الأربعة كلها في الـbody.
  Future<PasswordResetResult> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      isLoading.value = true;
      final res = await _api.post("api/driver/reset-password", data: {
        "phone": phone,
        "otp": otp,
        "newPassword": newPassword,
        "confirmPassword": confirmPassword,
      });
      final data = res.data;
      return PasswordResetResult(
        success: true,
        message: data is Map ? data['message']?.toString() : null,
      );
    } on dio_instance.DioException catch (e) {
      return _passwordResetError(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// أخطاء فلو إعادة التعيين تُعالَج هنا لا عبر [handleError]: السائق غير
  /// مسجَّل دخول في هذا الفلو، فتوجيهه إلى /blocked أو استدعاء logout() عند
  /// 403 بلا معنى — وشاشة /blocked تتوقع بيانات سائق محمَّلة أصلاً. نكتفي
  /// برسالة الباك المترجَمة حسب لغة الطلب، وبـ retryAfterSeconds عند 429.
  PasswordResetResult _passwordResetError(dio_instance.DioException e) {
    final data = e.response?.data;
    final message = data is Map ? data['message']?.toString() : null;
    return PasswordResetResult(
      success: false,
      message: (message != null && message.trim().isNotEmpty)
          ? message
          : "connection_error".tr,
      retryAfterSeconds: e.response?.statusCode == 429 && data is Map
          ? int.tryParse('${data['retryAfterSeconds']}')
          : null,
    );
  }

  /// جلب إحصائيات التوصيلات
  Future<void> fetchTotalDeliveries() async {
    try {
      final res = await _api.get("api/driver/orders-history");
      if (res.statusCode == 200) {
        totalDeliveries.value = res.data['totalOrdersCount'] ?? 0;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// الشاشات التي لا يجوز مقاطعة السائق أثناء وجوده فيها
  static const _busyRoutes = {
    '/new-order',
    '/details-order',
    '/pick-up-confirmation',
    '/delivery-map',
  };

  /// معرّف آخر طلب تم الانتقال إليه تلقائياً — لمنع إعادة الانتقال
  /// عند كل عودة من الخلفية لنفس الطلب.
  String? _lastNavigatedOrderId;

  /// HTTP fallback: جلب الطلب النشط عند الإقلاع وعند العودة من الخلفية
  /// (بديل لـ Socket لأن الباك أند لا يدعم حدث order:getActiveOrder).
  Future<void> fetchActiveOrderOnStartup() async {
    try {
      final res = await _api.get("api/driver/active-order");
      if (res.statusCode != 200 || res.data['hasActiveOrder'] != true) return;

      final order = res.data['order'];
      if (order == null) return;

      // لا نُعيد بناء الشاشة إن كان السائق فيها أصلاً — كان هذا يُخرجه
      // من شاشة تأكيد الاستلام أو الخريطة عند كل عودة من الخلفية.
      if (_busyRoutes.contains(Get.currentRoute)) return;

      // لا نُعيد الانتقال إذا كنا نهنا بالفعل لهذا الطلب
      final orderId = order['_id']?.toString() ?? order['orderId']?.toString();
      if (orderId != null && orderId == _lastNavigatedOrderId) return;
      _lastNavigatedOrderId = orderId;

      // التفرّع حسب حالة الطلب الفعلية على السيرفر — وليس دائماً لشاشة
      // التفاصيل. قبل هذا التعديل كانت كل استعادة (بعد رجوع، تعطّل، أو
      // إعادة تشغيل) تُعيد السائق إلى /details-order بغضّ النظر عن
      // الحالة الحقيقية، فيرى لحالة on_the_way زر "تأكيد الاستلام" رغم
      // أن هذه الخطوة منتهية فعلياً — والباك اند يرفضها بـ order:error
      // (mustBePickedUp) بلا أي طريق بديل من تلك الشاشة إلى الخريطة.
      //
      // ملاحظة تنفيذية: DeliveryMapScreen تقرأ البيانات حصراً من
      // widget.orderData (بلا fallback لـ Get.arguments)، وGetPage الخاص
      // بـ deliveryMap لا يمرّر أي وسائط — لذا نستخدم هنا Get.offAll()
      // بالودجت مباشرة، لا Get.offAllNamed، لضمان وصول البيانات فعلياً.
      //
      // ملاحظة توافق v3.0: مسار active-order في الباك يفلتر على
      // ["picked_up","on_the_way"] فقط، فحالة delivered لا تصل هنا عملياً.
      // فرع delivered أدناه دفاعي بحت (توافق مستقبلي) لا يُنفَّذ في الوضع الحالي.
      final status = order['orderStatus']?.toString();
      switch (status) {
        case 'on_the_way':
          Get.offAll(() => DeliveryMapScreen(orderData: order));
          break;
        case 'delivered':
          // دفاعي: لو أعاد الباك يوماً هذه الحالة، لا نُبقي السائق عالقاً
          // في شاشة طلب منتهٍ — نعيده للرئيسية.
          Get.offAllNamed(AppRoutes.mainNavigation);
          break;
        case 'picked_up':
        default:
          // picked_up (الحالة الطبيعية بعد القبول)، وأي حالة غير متوقعة
          // تُعامَل بأمان بنفس مسار ما قبل هذا التصحيح.
          Get.offAllNamed(AppRoutes.detailsOrder, arguments: order);
      }
    } catch (e) {
      debugPrint("active-order fallback: $e");
    }
  }

  /// جلب المطاعم القريبة
  Future<void> fetchNearbyRestaurants() async {
    try {
      final res = await _api.get("api/driver/restaurants");
      if (res.statusCode == 200 && res.data['restaurants'] != null) {
        nearbyRestaurants.assignAll(
          List<Map<String, dynamic>>.from(res.data['restaurants']),
        );
      }
    } catch (e) {
      debugPrint("restaurants fetch error: $e");
    }
  }

  /// تغيير لغة التطبيق وحفظها
  void updateLanguage(String code) {
    Get.updateLocale(Locale(code));
    _storage.write('lang', code);
    Get.back();
  }

  void logout() async {
    try {
      await _api.post("api/driver/logout");
    } catch (_) {}
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().disconnect();
    }
    if (Get.isRegistered<LocationService>()) {
      await Get.find<LocationService>().stop();
    }
    _storage.erase();
    // تصفير مصدر الحقيقة حتى لا تتسرب حالة السائق السابق للحساب التالي.
    isOnline.value = false;
    isTogglingStatus.value = false;
    isStatusSyncing.value = false;
    suspensionReason.value = null;
    clearLoginForm();
    clearRegistrationForm();
    Get.offAllNamed('/login');
  }

  void _handleLoginSuccess(Map<String, dynamic> data) async {
    await _storage.write("token", data['token']);
    await _storage.write(
        "driverId", data['driver']['id'] ?? data['driver']['_id']);
    await _storage.write("isLoggedIn", true);
    // حساب جديد = حالة غير مؤكدة (رمادي) حتى يرد السيرفر — لا نورث أخضر قديماً.
    isOnline.value = false;
    isTogglingStatus.value = false;
    isStatusSyncing.value = true;
    Get.find<SocketService>().connect();
    fetchDriverData();
    fetchTotalDeliveries();
    updateFCMTokenOnServer();
  }

  // نفحص العربية والألمانية أيضاً لأن رسائل تسجيل الدخول مترجمة
  static const _blockedKeywords = ["blocked", "محظور", "حظر", "gesperrt"];
  static const _rejectedKeywords = ["rejected", "مرفوض", "رفض", "abgelehnt"];
  static const _pendingKeywords = [
    "review", "pending", "approval",
    "مراجعة", "انتظار", "überprüfung", "genehmigung"
  ];

  /// هل الخطأ 403 ورسالته تحتوي إحدى الكلمات؟
  bool _is403With(dynamic e, List<String> keywords) {
    if (e is! dio_instance.DioException || e.response?.statusCode != 403) {
      return false;
    }
    final responseData = e.response?.data;
    final msg = (responseData is Map
            ? (responseData['message'] ?? "").toString()
            : "")
        .toLowerCase();
    return keywords.any(msg.contains);
  }

  /// ينتقل إلى شاشة محجوزة ما لم يكن السائق فيها — الاستطلاع كل 45 ثانية
  /// يمرّ من هنا، وبلا الشرط كانت الشاشة تُعاد بناؤها وتُصفَّر حالتها.
  void _goToGuardedRoute(String route) {
    if (Get.currentRoute != route) Get.offAllNamed(route);
  }

  /// سبب الإيقاف الذي كتبه الأدمن. جسم ردّ الـ403 هو مصدره الوحيد، لأن
  /// السائق المحظور مرفوض من `dirver-info` ومن تسجيل الدخول معاً.
  /// يبقى null إلى أن يُنشر B8 في الباك.
  final suspensionReason = RxnString();

  /// `code` الثابت في جسم الخطأ — مستقل عن لغة الرسالة
  String? _errorCode(dynamic e) {
    if (e is! dio_instance.DioException) return null;
    final data = e.response?.data;
    return data is Map ? data['code']?.toString() : null;
  }

  void _captureSuspensionReason(dynamic e) {
    if (e is! dio_instance.DioException) return;
    final data = e.response?.data;
    final reason = data is Map ? data['reasonForSuspension']?.toString() : null;
    suspensionReason.value = (reason == null || reason.isEmpty) ? null : reason;
  }

  /// معالجة الأخطاء وتنفيذ سيناريوهات الحظر والرفض والانتظار (403)
  void handleError(dynamic e) {
    if (e is dio_instance.DioException && e.response?.statusCode == 403) {
      // `code` أولاً (B8)، ومطابقة النص المترجم تبقى سقوطاً آمناً ما دام
      // الباك المنشور لا يرسل `code` في ردود 403.
      final code = _errorCode(e);

      if (code == 'ACCOUNT_BLOCKED' ||
          (code == null && _is403With(e, _blockedKeywords))) {
        _captureSuspensionReason(e);
        _goToGuardedRoute('/blocked');
        return;
      }
      if (code == 'ACCOUNT_REJECTED' ||
          (code == null && _is403With(e, _rejectedKeywords))) {
        logout();
        return;
      }
      if (code == 'ACCOUNT_PENDING' ||
          (code == null && _is403With(e, _pendingKeywords))) {
        _goToGuardedRoute('/documents-completion');
        return;
      }

      // 403 غير معروف — في هذا الباكد لا يعني إلا منع وصول
      _goToGuardedRoute('/blocked');
      return;
    }

    String message = "connection_error".tr;
    if (e is dio_instance.DioException) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        message = responseData['message']?.toString() ?? message;
      }
    }
    _showWarning("alert".tr, message);
  }

  /// تحديث توكن FCM على السيرفر
  Future<void> updateFCMTokenOnServer() async {
    try {
      if (Get.isRegistered<NotificationService>()) {
        await Get.find<NotificationService>().fetchAndSendToken();
      }
    } catch (e) {
      debugPrint("FCM Error: $e");
    }
  }

  // ── استطلاع حالة الحساب ────────────────────────────────────────
  // الباك لا يبثّ أي حدث للسائق عند اعتماده أو حظره أو مراجعة مستنداته
  // (المكان الوحيد الذي يبثّ إلى namespace `/driver` هو عرض الطلبات)،
  // فالسائق كان يبقى عالقاً على شاشة المراجعة حتى يُعيد تشغيل التطبيق.
  // الاستطلاع يعمل على الشاشات المحجوزة فقط ويتوقف فور مغادرتها.
  Timer? _statusPollTimer;

  static const _statusPollInterval = Duration(seconds: 45);

  void startStatusPolling() {
    if (_statusPollTimer?.isActive ?? false) return;
    _statusPollTimer =
        Timer.periodic(_statusPollInterval, (_) => fetchDriverData());
  }

  void stopStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  /// فحص يدوي فوري (زر "تحقق الآن" وسحب-للتحديث)
  Future<void> refreshStatusNow() async {
    isCheckingStatus.value = true;
    try {
      await fetchDriverData();
    } finally {
      isCheckingStatus.value = false;
    }
  }

  final isCheckingStatus = false.obs;

  @override
  void onClose() {
    stopStatusPolling();
    super.onClose();
  }

  void _showWarning(String title, String msg) {
    Get.snackbar(
        title, msg, backgroundColor: Colors.redAccent, colorText: Colors.white);
  }
}
