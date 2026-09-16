# تقرير: مشاكل رفع وثائق السائق في الباك وخطة إصلاحها

- **التاريخ:** 2026-09-11
- **النطاق:** `backendNUMNOW`: مسارات `POST /api/driver/register` و`PATCH /api/driver/update-info` و`GET /api/driver/dirver-info`
- **الأعراض عند السائقين:** الوثيقة «لا تُرفع»، أو تظهر رسالة `Server error`، أو تبقى الوثائق «ناقصة» والحساب قيد المراجعة إلى الأبد.

> ## ✅ الحالة: نُفِّذت B1 إلى B7 بتاريخ 2026-09-12
> راجعنا كود `backendNUMNOW` بعد ردّ فريق الباك وأكّدنا كل بند في مكانه:
> B1 (`driver.controller.js:533-544`)، B2 (`driver.routes.js:33` و`getDriverInfo:418`)،
> B3 (`middleware/upload.js` بحد 5MB و`upload.safe`)، B4 (`:560-563`)، B5 (`:501-549`)،
> B6 (`:20, 173-179`)، B7 (`:63-73`). **شكراً لكم.**
>
> من جهة التطبيق: حذفنا الحل المؤقت لـ B2 (`update-info` بجسم فارغ) فلم يعد يُستدعى،
> ورفعنا الحد المحلي إلى 5MB، وصار منطق الأخطاء يعتمد على `code` لا على نص الرسالة.
>
> **بقي بند واحد جديد ظهر أثناء المراجعة: B8 في نهاية هذا الملف.**

---

## الملخص

| # | الخطورة | الملف | ما يراه السائق |
|---|---|---|---|
| B1 | 🔴 حرج | `controllers/driver.controller.js:468-478` | رفع وثيقة لم تُرفع وقت التسجيل يُرفض دائماً: `id document not found` |
| B2 | 🟠 عالٍ | `routes/driver.routes.js:26` | السائق قيد المراجعة لا يستطيع قراءة حالة وثائقه ولا سبب رفضها |
| B3 | 🟠 عالٍ | `middleware/upload.js` + `server.js:103` | صورة أكبر من 2MB أو ملف ليس صورة ← `500 Server error` (وفي التسجيل يفشل الحساب كله) |
| B4 | 🟡 متوسط | `controllers/driver.controller.js:450-457, 480-488` | الصورة القديمة تُحذف قبل نجاح رفع الجديدة ← روابط مكسورة عند الأدمن |
| B5 | 🟡 متوسط | `controllers/driver.controller.js:508-513` | عدة وثائق في طلب واحد ← `headers already sent` وصور يتيمة |
| B6 | 🔵 منخفض | `controllers/driver.controller.js:83-129` | فشل التسجيل بعد الرفع يترك صوراً يتيمة على Cloudinary |
| B7 | ⚪ سياسة | `register` مقابل `admin.controller.js:1354` | التسجيل يقبل 0 وثائق، والاعتماد يشترط 3 |

**ترتيب التنفيذ المقترح:**
1. **B2** (سطر واحد).
2. **B1 + B4 + B5** (إعادة كتابة جزء واحد من `updateDriverInfo`، الكود جاهز أدناه).
3. **B3**.
4. **B6**.
5. **B7**.

**تنظيف البيانات بعد نشر B1:** هذا الاستعلام يحدد السائقين العالقين حالياً:

```js
db.drivers.find(
  { status: "pending", $expr: { $lt: [{ $size: "$documents" }, 3] } },
  { name: 1, phone: 1, "documents.type": 1, createdAt: 1 }
)
```

للتجارب أدناه:

```bash
BASE=https://nomnow-o4ba.onrender.com
TOKEN=<توكن سائق حالته pending>
```

---

## B1 — 🔴 لا يمكن إضافة وثيقة غير موجودة مسبقاً

### المشكلة
`updateDocument` داخل `updateDriverInfo` **يستبدل** وثيقة موجودة فقط:

```js
// driver.controller.js:471-478 (الحالي)
const document = driver.documents.find((doc) => doc.type === type);
if (!document) {
  res.status(400).json({
    message: m.info.documentNotFound.replace("{{type}}", type),
  });
  return false;
}
```

في المقابل، `register` يسمح بالتسجيل بلا أي وثيقة (`documents: []`)، و`approveDriver` يرفض أي سائق عنده أقل من 3 وثائق.

### الأثر
أي سائق سجّل دون وثيقة واحدة على الأقل يبقى `pending` **إلى الأبد**:
- لا يستطيع إضافة الوثيقة الناقصة من التطبيق.
- الأدمن لا يستطيع اعتماده.
- لا يوجد مسار آخر لإضافة وثيقة.

### إعادة الإنتاج
```bash
# سائق مسجَّل بلا idImage، وبعد تسجيل الدخول والتحقق من OTP:
curl -X PATCH "$BASE/api/driver/update-info" \
  -H "Authorization: Bearer $TOKEN" \
  -F idImage=@id.jpg
# ← 400 {"message":"id document not found"}
```

### الإصلاح
الكود في القسم «الكود المشترك لـ B1 + B4 + B5» أدناه: إذا لم توجد الوثيقة **تُضاف** بحالة `pending`.

---

## B2 — 🟠 `dirver-info` يرفض السائق `pending`

### المشكلة
```js
// routes/driver.routes.js:26
router.get("/dirver-info", auth, driverController.getDriverInfo);
```
`auth` يُرجع `403 "Your account is under review..."` لكل سائق `pending` (`driverauth.middleware.js:29-32`).

### الأثر
السائق قيد المراجعة هو **الوحيد** الذي يحتاج رؤية حالة كل وثيقة (`documents[].status`) وسبب الرفض (`rejectionReason`)، ولا يستطيع قراءتها أبداً:
- تظهر كل وثائقه «ناقصة».
- لا يعرف لماذا رُفضت وثيقته.
- يعيد رفع وثائق صحيحة بلا داعٍ.

### إعادة الإنتاج
```bash
curl "$BASE/api/driver/dirver-info" -H "Authorization: Bearer $TOKEN"
# ← 403 {"message":"Your account is under review. Please wait for approval."}
```

### الإصلاح (سطر واحد)
```js
// routes/driver.routes.js
const { auth, authAllowPending } = require("../middleware/driverauth.middleware");

router.get("/dirver-info", authAllowPending, driverController.getDriverInfo);
```
`authAllowPending` موجود أصلاً ويرفض `blocked` و`rejected`. التطبيق يتعامل مسبقاً مع `status: "pending"` في رد 200، فلا يحتاج أي تعديل.

**مقترح إضافي:** إضافة `reasonForSuspension` إلى `.select(...)` في `getDriverInfo` (السطر 384)، لأن شاشة الحظر في التطبيق لا تستطيع عرض السبب.

---

## B3 — 🟠 أخطاء multer تصل كـ `500 Server error`

### المشكلة
- `middleware/upload.js` يرفض الملف عبر `cb(new Error(...))` أو `limits.fileSize` (2MB).
- multer يمرّر الخطأ إلى `next(err)`، فيصل إلى المعالج العام في `server.js:103` الذي يُرجع دائماً:

```json
500 { "message": "Server error", "error": "File too large" }
```

### الأثر
- السائق يرى «Server error» دون أن يعرف أن السبب حجم الصورة.
- في **التسجيل**، صورة واحدة أكبر من 2MB تُفشل إنشاء الحساب كله.
- التطبيق يكتب للسائق «PNG, JPG (الحد الأقصى 5 ميجا)» بينما السيرفر يرفض ما فوق 2MB. صور كاميرات الهواتف الحديثة ولقطات الشاشة PNG تتجاوز 2MB بسهولة.

### إعادة الإنتاج
```bash
curl -X PATCH "$BASE/api/driver/update-info" -H "Authorization: Bearer $TOKEN" -F idImage=@photo_3mb.jpg
# ← 500 {"message":"Server error","error":"File too large"}

curl -X PATCH "$BASE/api/driver/update-info" -H "Authorization: Bearer $TOKEN" -F idImage=@file.pdf
# ← 500 {"message":"Server error","error":"Only image files are allowed!"}
```

### الإصلاح
**1) `middleware/upload.js`:** الملف متوافق مع كل الاستخدامات الحالية (`upload.single` / `upload.fields` تبقى كما هي).

```js
const multer = require("multer");
const { getMessages } = require("../utils/messages");

const MAX_FILE_SIZE_MB = 5;

const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith("image/")) return cb(null, true);
  const err = new Error("Only image files are allowed!");
  err.code = "INVALID_FILE_TYPE";
  err.field = file.fieldname;
  cb(err, false);
};

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FILE_SIZE_MB * 1024 * 1024 },
  fileFilter,
});

// يغلّف أي middleware من multer ويحوّل أخطاءه إلى 400/413 مترجمة بدل 500
upload.safe = (middleware) => (req, res, next) =>
  middleware(req, res, (err) => {
    if (!err) return next();
    const m = getMessages(req).upload;

    if (err.code === "LIMIT_FILE_SIZE") {
      return res.status(413).json({
        code: "FILE_TOO_LARGE",
        field: err.field,
        message: m.fileTooLarge.replace("{{max}}", MAX_FILE_SIZE_MB),
      });
    }
    if (err.code === "INVALID_FILE_TYPE") {
      return res.status(400).json({
        code: "INVALID_FILE_TYPE",
        field: err.field,
        message: m.invalidFileType,
      });
    }
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ code: err.code, field: err.field, message: m.invalidUpload });
    }
    next(err);
  });

module.exports = upload;
```

**2) `routes/driver.routes.js`:** نفس التعديل على `/register` و`/update-info`.

```js
const driverDocFields = upload.fields([
  { name: "driverImage", maxCount: 1 },
  { name: "idImage", maxCount: 1 },
  { name: "drivingLicenseImage", maxCount: 1 },
  { name: "vehicleRegistrationImage", maxCount: 1 },
]);

router.post("/register", upload.safe(driverDocFields), driverController.register);
router.patch("/update-info", authAllowPending, upload.safe(driverDocFields), driverController.updateDriverInfo);
```

**3) `utils/messages.js`:** بجانب كتل `translations.xx.driver`.

```js
translations.en.upload = {
  fileTooLarge: "Image is too large. Maximum size is {{max}} MB",
  invalidFileType: "Only image files are allowed",
  invalidUpload: "Invalid file upload",
};
translations.ar.upload = {
  fileTooLarge: "حجم الصورة كبير. الحد الأقصى {{max}} ميجابايت",
  invalidFileType: "يُسمح بملفات الصور فقط",
  invalidUpload: "ملف مرفوع غير صالح",
};
translations.de.upload = {
  fileTooLarge: "Bild ist zu groß. Maximal {{max}} MB",
  invalidFileType: "Nur Bilddateien sind erlaubt",
  invalidUpload: "Ungültiger Datei-Upload",
};
```

> **طلب:** إضافة حقل `code` ثابت في ردود الأخطاء (مثل `FILE_TOO_LARGE`) حتى لا يعتمد التطبيق على مطابقة نص الرسالة المترجمة.

---

## B4 — 🟡 حذف الصورة القديمة قبل نجاح الجديدة

### المشكلة
الترتيب الحالي في `updateDriverInfo`، سواء للصورة الشخصية (450-457) أو للوثائق (480-488):

```
cloudinary.destroy(old)  →  uploadBuffer(new)  →  driver.save()
```

إذا فشل رفع Cloudinary (انقطاع أو timeout) أو فشل `save`، تبقى قاعدة البيانات تشير إلى `public_id` **محذوف**.

### الأثر
- يرى الأدمن صورة مكسورة.
- قد يوافق على وثيقة لم يرها، أو يرفضها ظلماً.
- السائق لا يعلم أن وثيقته أصبحت فارغة.

### الإصلاح
الترتيب الصحيح: `upload(new)` ثم `save()` ثم `destroy(old)` (best-effort). الكود مدمج في القسم المشترك أدناه.

---

## B5 — 🟡 `Promise.all` مع ردّ مبكر داخل `updateDocument`

### المشكلة
```js
// driver.controller.js:508-513 (الحالي)
const results = await Promise.all([
  updateDocument("id", "idImage"),
  updateDocument("driving_license", "drivingLicenseImage"),
  updateDocument("vehicle_registration", "vehicleRegistrationImage"),
]);
if (results.includes(false)) return;
```
- كل استدعاء لا يجد وثيقته يُرسل `res.status(400).json(...)`، فإذا نقصت وثيقتان يُرسل الرد مرتين (`ERR_HTTP_HEADERS_SENT`).
- الاستدعاءات الناجحة تكون قد حذفت القديمة ورفعت الجديدة، ثم يتوقف التنفيذ قبل `driver.save()`. النتيجة: صور يتيمة وروابط مكسورة معاً.

### الإصلاح
يُحل ضمن القسم المشترك أدناه: لا ردّ داخل الحلقة، والرفع أولاً، والتنظيف عند أي فشل.

---

## الكود المشترك لـ B1 + B4 + B5 (`updateDriverInfo`)

يستبدل كل ما بين تعليق `2️⃣ تحديث صورة السائق الشخصية` (السطر 445) و`await driver.save();` (السطر 515). قسم تحديث المركبة والرد النهائي يبقيان كما هما.

```js
    // =========================
    // 2️⃣ رفع الصور الجديدة أولاً (الشخصية + الوثائق)
    // =========================
    const DOC_FIELDS = [
      ["id", "idImage"],
      ["driving_license", "drivingLicenseImage"],
      ["vehicle_registration", "vehicleRegistrationImage"],
    ];

    const jobs = [];
    if (req.files?.driverImage) {
      jobs.push({ kind: "driverImage", file: req.files.driverImage[0] });
    }
    for (const [type, field] of DOC_FIELDS) {
      if (req.files?.[field]) {
        jobs.push({ kind: "document", type, file: req.files[field][0] });
      }
    }

    const settled = await Promise.allSettled(
      jobs.map((job) => uploadBuffer(job.file.buffer, "drivers")),
    );
    const newPublicIds = settled
      .filter((s) => s.status === "fulfilled")
      .map((s) => s.value.public_id);

    const failedUpload = settled.find((s) => s.status === "rejected");
    if (failedUpload) {
      // لا نترك صوراً يتيمة، ولا نلمس الصور القديمة
      await Promise.allSettled(newPublicIds.map((id) => cloudinary.uploader.destroy(id)));
      throw failedUpload.reason;
    }

    // =========================
    // 3️⃣ تطبيق الصور — إضافة الوثيقة إن لم تكن موجودة (B1)
    // =========================
    const oldPublicIds = [];

    jobs.forEach((job, i) => {
      const r = settled[i].value;
      const image = { url: r.secure_url, public_id: r.public_id };

      if (job.kind === "driverImage") {
        if (driver.driverImage?.public_id) oldPublicIds.push(driver.driverImage.public_id);
        driver.driverImage = image;
        return;
      }

      const document = driver.documents.find((doc) => doc.type === job.type);
      if (document) {
        if (document.image?.public_id) oldPublicIds.push(document.image.public_id);
        document.image = image;
        document.status = "pending";
        document.rejectionReason = undefined;
        document.verifiedAt = undefined;
        document.verifiedBy = undefined;
      } else {
        driver.documents.push({ type: job.type, image, status: "pending" });
      }

      // أي وثيقة جديدة تعيد الحساب إلى المراجعة
      driver.isDocumentsVerified = false;
      driver.status = "pending";
    });

    try {
      await driver.save();
    } catch (err) {
      await Promise.allSettled(newPublicIds.map((id) => cloudinary.uploader.destroy(id)));
      throw err;
    }

    // حذف القديمة بعد نجاح الحفظ فقط (B4) — فشلها لا يُفشل الطلب
    Promise.allSettled(oldPublicIds.map((id) => cloudinary.uploader.destroy(id)));
```

بعد هذا التعديل يصبح `m.info.documentNotFound` غير مستخدم ويمكن حذفه.

---

## B6 — 🔵 صور يتيمة عند فشل `register`

### المشكلة
- في `register` (السطور 83-129) تُرفع كل الصور إلى Cloudinary **قبل** `driver.save()`.
- `Promise.all` يُرفض عند أول فشل بينما بقية الرفعات مستمرة، وأي فشل لاحق (validation أو `save`) يترك الصور بلا مالك.

### الإصلاح
```js
exports.register = async (req, res) => {
  const uploadedIds = []; // خارج try ليصل إليها catch
  try {
    // ... نفس التحققات الحالية ...

    const track = (r) => {
      uploadedIds.push(r.public_id);
      return r;
    };

    // في كل مهمة: uploadBuffer(...).then(track).then((r) => { ... })

    const settled = await Promise.allSettled(uploadTasks);
    const failed = settled.find((s) => s.status === "rejected");
    if (failed) throw failed.reason;

    await driver.save();
    // ... نفس الرد الحالي ...
  } catch (err) {
    await Promise.allSettled(uploadedIds.map((id) => cloudinary.uploader.destroy(id)));
    console.error(err);
    res.status(500).json({ message: err.message });
  }
};
```

---

## B7 — ⚪ سياسة: التسجيل بلا وثائق

- `register` يقبل 0 وثائق، و`approveDriver` يشترط 3.
- **المقترح:** إلزام الوثائق الثلاث عند التسجيل، مع الإبقاء على إصلاح B1 للسائقين الحاليين وللاستبدال لاحقاً.

```js
// في register بعد التحقق من الحقول النصية، وقبل Driver.findOne
const requiredDocs = ["idImage", "drivingLicenseImage", "vehicleRegistrationImage"];
if (requiredDocs.some((f) => !req.files?.[f])) {
  return res.status(400).json({
    code: "DOCUMENTS_REQUIRED",
    message: m.auth.documentsRequired, // يُضاف في messages.js بالعربية والإنجليزية والألمانية
  });
}
```

---

## ما يفعله التطبيق حالياً (للتنسيق)

تعديلات يُجريها فريق الفرونت بالتوازي، ولا تُغني عن إصلاحات الباك:

- ضغط الصور قبل الرفع (أقصى بُعد 1600px) وفحص الحجم محلياً.
- إلزام الوثائق الثلاث في شاشة التسجيل (يمنع سائقين عالقين جدداً حتى نشر B1).
- رسائل واضحة لأخطاء 413 و400 وانتهاء المهلة.
- **حل مؤقت لـ B2:** عندما يُرجع `dirver-info` 403 لسائق `pending`، يستدعي التطبيق `PATCH /api/driver/update-info` بجسم فارغ `{}` ليقرأ `documents` و`status` من الرد.
  **يُرجى عدم تغيير سلوك `update-info` مع الجسم الفارغ** (يجب أن يبقى 200 بلا أي تعديل) إلى أن يُنشر B2، وسنحذف هذا الحل بعدها.

> **معروف ومُبلَّغ سابقاً:** قرارات الأدمن (مراجعة وثيقة، اعتماد، حظر) لا تبثّ أي حدث إلى namespace `/driver` (`admin.controller.js:1305-1327` وما بعدها)، لذلك يعتمد التطبيق على الاستطلاع كل 45 ثانية.

---

## اختبارات القبول بعد النشر

| # | الطلب | النتيجة المتوقعة |
|---|---|---|
| 1 | `GET dirver-info` لسائق `pending` | `200` ويحتوي `documents` |
| 2 | `PATCH update-info` مع `idImage` لسائق بلا وثيقة هوية | `200`، وتظهر `documents` بعنصر `type:"id", status:"pending"` |
| 3 | `PATCH update-info` مع وثيقة مرفوضة | `200`، الحالة `pending`، `rejectionReason` فارغ، والصورة القديمة محذوفة من Cloudinary |
| 4 | صورة 6MB | `413` مع `code:"FILE_TOO_LARGE"` ورسالة بلغة `Accept-Language` |
| 5 | ملف PDF | `400` مع `code:"INVALID_FILE_TYPE"` |
| 6 | 3 وثائق في طلب واحد لسائق بلا وثائق | `200`، و3 عناصر في `documents`، ولا يوجد `headers already sent` في السجل |
| 7 | محاكاة فشل Cloudinary (مفتاح خاطئ مؤقتاً) | `500`، والصورة القديمة ما زالت تعمل |
| 8 | `POST register` بلا وثائق (إن اعتُمد B7) | `400` مع `code:"DOCUMENTS_REQUIRED"` |

---

## B8 — 🟠 جديد (2026-09-12): سبب الحظر لا يصل إلى صاحبه

> ## ✅ B8 منفَّذ ومُتحقَّق منه (2026-09-12)
> وصلتنا النسخة المحدَّثة وراجعناها: `code` و`reasonForSuspension` موجودان في المواضع الخمسة —
> `auth` و`authAllowPending` في `driverauth.middleware.js:28-45, 76-87`، و`loginWithPhone:201`
> و`verifyPhone:268` و`forgotPassword:331`. ومفتاح `accountPending` مضاف بالإنكليزية والعربية والألمانية.
>
> من جهة التطبيق: `handleError` صار يميّز الحالات بـ`code` بدل نص الرسالة، وشاشة الحظر تعرض
> `reasonForSuspension` القادم في جسم الـ403. أبقينا مطابقة النص كسقوط احتياطي فقط لحين نشر
> هذه النسخة على `nomnow-o4ba.onrender.com` — **رجاءً أكّدوا لنا موعد النشر**.
>
> ملاحظتكم عن `rejected` مفهومة: لا مكان في المشروع يضبط هذه الحالة حالياً، والتطبيق يعالجها
> على أي حال (تسجيل خروج) فور ظهورها.

شكراً على إضافة `reasonForSuspension` إلى `getDriverInfo` ضمن B2، لكن السائق **المحظور** لا يستطيع الوصول إليه إطلاقاً:

- `GET /dirver-info` يمرّ على `authAllowPending`، وهو يرفض `blocked` بـ 403 (`driverauth.middleware.js:60-61`).
- `POST /loginwithphone` يرفض `blocked` بـ 403 قبل إصدار أي توكن (`driver.controller.js:165-166`).

فالحقل الوحيد الذي يشرح للسائق سبب إيقافه لا يمر بأي مسار يستطيع قراءته، وشاشة الحظر في التطبيق تعرض نصاً عاماً فقط.

### إعادة الإنتاج
```bash
# سائق حالته blocked وله reasonForSuspension في قاعدة البيانات
curl -X POST "$BASE/api/driver/loginwithphone" -H "Content-Type: application/json" \
  -d '{"phone":"+963912345678","password":"..."}'
# ← 403 {"message":"Your account has been blocked"}   ← بلا سبب

curl "$BASE/api/driver/dirver-info" -H "Authorization: Bearer $OLD_TOKEN"
# ← 403 {"message":"Your account has been blocked"}   ← بلا سبب
```

### الإصلاح المقترح
إدراج السبب و`code` ثابت في جسم ردّ الـ403 نفسه، في الموضعين (الميدلوير `auth` و`authAllowPending`، و`loginWithPhone`):

```js
if (user.status === "blocked") {
  return res.status(403).json({
    code: "ACCOUNT_BLOCKED",
    message: m.auth.accountBlocked,
    reasonForSuspension: user.reasonForSuspension || null,
  });
}
```

بمجرد توفّر الحقل سنعرضه في شاشة الحظر بدل النص العام. ويفيد `code` الثابت هنا أيضاً، لأن التطبيق يميّز حالياً بين
«محظور / مرفوض / قيد المراجعة» عبر البحث في نص الرسالة المترجمة — وهو أسلوب هشّ.
`ACCOUNT_REJECTED` و`ACCOUNT_PENDING` في مواضعهما المناظرة تُغنينا عنه نهائياً.
