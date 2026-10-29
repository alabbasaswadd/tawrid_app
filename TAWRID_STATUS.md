# توريد — حالة المشروع وسجل القرارات

> **آخر تحديث:** 2026-10-25  
> **المنصة:** Flutter 3.x / Dart 3.x — Material 3 — Riverpod — GoRouter  
> **الهدف:** منصة توريد دوائي بين المستودعات والصيدليات (سوق سوري)

---

## 1. البنية المعمارية (Architecture Decisions)

### State Management
- **Riverpod** فقط: `AsyncNotifier` للجلسات، `Provider<Repository>` للخدمات.
- لا `ChangeNotifier`، لا `Bloc`، لا `setState` خارج نطاق الـ Widget.

### Navigation
- **GoRouter** مع `redirect` مبني على حالة الجلسة.
- Shell مزدوج: `PhShell` (5 تبويبات) + `WhShell` (5 تبويبات).
- المسارات العلوية (Create Offer، Catalog، Service Areas) تعلو فوق الـ Shell بدون شريط تنقل.

### Theming
- **TawridTokens** (ThemeExtension) للألوان الدلالية الإضافية: `context.tokens.success/warning/hint/...`
- **ColorScheme** للألوان الأساسية: `context.colors.primary/surface/error/...`
- **TextTheme** للخطوط: `context.text.titleLarge/bodyMedium/...`
- خط Cairo Variable مُعيَّن مركزياً في `AppTypography` — لا `GoogleFonts.cairo()` في الصفحات.

### Component System (shared/ui/)
| المكوّن | الاستخدام |
|---------|-----------|
| `AppButton` | كل أزرار الإجراءات الرئيسية (filled, tonal, outline, text, danger) |
| `AppTextField` | كل حقول الإدخال — التسمية فوق الحقل + hint داخله |
| `AppCard` | بطاقات المحتوى العام |
| `AppSectionHeader` | عناوين الأقسام مع إجراء اختياري |
| `AppSegmentedToggle` | أزرار التبديل المجزأة |
| `LoadingState / ErrorState / EmptyState` | حالات عرض البيانات |
| `StatusBadge` | شارات الحالة |
| `CenteredContent` | تمركز المحتوى على الشاشات الكبيرة |

### Component System (shared/widgets/)
| المكوّن | الاستخدام |
|---------|-----------|
| `MedicineListTile` | بطاقة الدواء موحّدة (شريط لوني + باج الشكل الصيدلاني) |
| `GovernorateCity Selector` | قائمتا محافظة/مدينة متتاليتان |
| `MultiRegionPicker` | اختيار متعدد للمناطق في نماذج العروض |
| `SalesOfferPostCard` | بطاقة عرض البيع في الفيد |
| `SalesOfferDetailSheet` | ورقة تفاصيل العرض (Modal) |
| `CommentsSheet` | ورقة التعليقات |
| `AppSnackbar` | إشعارات نجاح/خطأ (static methods) |
| `BarcodeScanner` | مسح الباركود بالكاميرا |

---

## 2. ما تم إنجازه ✅

### المصادقة والجلسات
- [x] تسجيل دخول الصيدلية (`PhLoginPage`) — AppTextField + AppButton + gradient ديناميكي
- [x] تسجيل الصيدلية (`PhRegisterPage`) — 6 حقول + محافظة/مدينة
- [x] تسجيل دخول المستودع (`WhLoginPage`) — اسم مستخدم أو بريد
- [x] تسجيل المستودع (`WhRegisterPage`) — خطوتان: بيانات المستودع + بيانات المدير
- [x] مناطق التخديم (`WhServiceAreasPage`) — اختيار محافظات/مدن بعد التسجيل مباشرة
- [x] جلسة الصيدلية (`pharmacySessionProvider`) — AsyncNotifier + SecureStorage
- [x] جلسة المستودع (`warehouseSessionProvider`) — AsyncNotifier + SecureStorage
- [x] إعادة توجيه تلقائي عند انتهاء الجلسة (401 → clear session)

### صفحات الصيدلية
- [x] الصفحة الرئيسية (`PhHomePage`) — بطاقة ترحيب + بحث سريع + أحدث النشاطات
- [x] بحث الأدوية (`PhMedicineSearchPage`) — بحث فوري + تفاصيل الدواء
- [x] تصفّح العروض (`PhOffersPage`) — فيد عروض المستودعات حسب المنطقة + تفاصيل + تعليقات
- [x] طلبيات التوريد (`PhOrdersPage`) — تبويبات (جارية/مكتملة/ملغاة) + تفاصيل + مسار الحالة + إلغاء + توليد فاتورة
- [x] طلبات التسعير (`PhTendersPage`) — تبويبات (مفتوحة/بانتظار الترسية/منتهية) + إنشاء طلب بأصناف ومهلة + إلغاء + مقارنة عروض الأسعار والترسية
- [x] المستودعات المتاحة (`PhWarehousesPage`) — قائمة نشطة + بحث محلي
- [x] ملف مستودع (`PhWarehouseProfilePage`) — بياناته + مدن خدمته + عروضه المتاحة لك
- [x] الإشعارات + إعداداتها (`NotificationsPage` / `NotificationSettingsPage`)
- [x] المزيد (`PhMorePage`) — قائمة الخدمات + تسجيل الخروج

### صفحات المستودع
- [x] الصفحة الرئيسية (`WhHomePage`) — إحصائيات + عروضي + طلبات تسعير مفتوحة
- [x] أدويتي (`WhMedicinesPage`) — قائمة + بحث فوري + حذف
- [x] كتالوج الأدوية (`WhMedicineCatalogPage`) — اختيار من الكتالوج العام
- [x] إنشاء عرض بيع (`WhCreateOfferPage`) — نوع العرض + أصناف + مناطق + بونص
- [x] عروضي (`WhOffersPage`) — إدارة عروض البيع
- [x] الطلبيات الواردة (`WhOrdersPage`) — قائمة + تفاصيل + تحديث الحالة
- [x] عروض أسعاري (`WhTendersPage`) — قائمة عروض أسعار المستودع على طلبات التسعير
- [x] التقدّم بعرض سعر (`WhSubmitTenderOfferPage`) — نموذج سعر/بونص لكل صنف
- [x] الملف الشخصي (`WhProfilePage`) — بيانات المستودع + تعديل مناطق التخديم
- [x] موظّفو المستودع (`WhUsersPage`) — للمدير فقط: إضافة/تعديل/إيقاف/كلمة مرور
- [x] الإشعارات + إعداداتها (نفس شاشتَي الصيدلية بعلم `isWarehouse`)
- [x] المزيد (`WhMorePage`)

### البنية التقنية
- [x] نظام الثيم المركزي (Light/Dark) مع TawridTokens
- [x] نظام المكوّنات الموحّد (`shared/ui/` + `shared/widgets/`)
- [x] API Client مع Dio + AuthInterceptor (pharmacy vs warehouse)
- [x] 10 مستودعات بيانات (repositories) جاهزة
- [x] نماذج البيانات الكاملة (11 ملف)
- [x] إدارة مناطق التخديم الجغرافية

---

## 3. التنظيف الذي تم (2026-10-25) 🧹

### المشكلة التي أُصلحت
**خطأ مرئي:** صفحة تسجيل الدخول كانت تستخدم `labelText` (تسمية عائمة) بدلاً من `AppTextField` الذي يعرض التسمية فوق الحقل بوضوح. كذلك كانت تستخدم `TawridButton` المهمل و`GoogleFonts.cairo()` مباشرة.

### ما تم تغييره
| الملف | التغيير |
|-------|---------|
| `auth/login_page.dart` | `TextFormField` → `AppTextField`، `TawridButton` → `AppButton`، gradient ديناميكي، `cs.surface` |
| `auth/register_page.dart` | نفس التغييرات + إزالة `_obscurePass/Confirm` (تتولاها `AppTextField` داخلياً) |
| `wh_auth/wh_register_page.dart` | نفس التغييرات + `_StepIndicator` يستخدم `Theme.of(context)` |
| `wh_auth/wh_service_areas_page.dart` | `TawridButton` → `AppButton`، ألوان theme-aware |
| `wh_offers/wh_create_offer_page.dart` | `TawridButton` → `AppButton`، `TawridColors.success/error` → tokens |
| `wh_tenders/wh_submit_tender_offer_page.dart` | `TawridButton` → `AppButton`، `GoogleFonts` → `textTheme` |
| `wh_orders/wh_orders_page.dart` | `TawridColors.surface/border` → `cs.surface/outline`، `GoogleFonts` → `context.text` |
| `wh_tenders/wh_tenders_page.dart` | نفس التغييرات |
| `ph_more/ph_more_page.dart` | `TawridColors.warning/info` → `context.tokens.*`، `GoogleFonts` → `context.text` |
| `wh_medicines/wh_medicines_page.dart` | `TawridColors.error` → `context.colors.error`، `GoogleFonts` → `context.text` |
| `ph_orders/ph_orders_page.dart` | `GoogleFonts` + `TawridColors.hint` → theme tokens |
| `ph_tenders/ph_tenders_page.dart` | نفس التغييرات |
| `splash/splash_page.dart` | `TawridColors.brandGradient` → gradient ديناميكي من `cs.primary` |
| `shared/widgets/tawrid_button.dart` | **محذوف** — `AppButton` هو البديل الوحيد الآن |

### القواعد الثابتة بعد التنظيف
- ✅ `AppTextField` فقط لحقول الإدخال (لا `TextFormField` مع `labelText` في الصفحات)
- ✅ `AppButton` فقط للأزرار الرئيسية (لا `TawridButton` — محذوف)
- ✅ `context.text.*` للنصوص (لا `GoogleFonts.cairo()` في الصفحات)
- ✅ `context.colors.*` / `context.tokens.*` للألوان (لا `TawridColors.surface/background/hint` في الصفحات)
- ✅ `TawridColors.statusX` مقبول فقط للألوان الدلالية للحالات (pending/completed/etc.)

---

## 3.5 مزامنة مع الباك إند (2026-10-26) 🔗

الباك إند أُعيدت فيه تسمية «المناقصات» إلى **طلبات التسعير** وحُذف **نوع
العرض**، فانكسر التطبيق صامتاً. ما أُصلح:

| الكسر | الأثر قبل الإصلاح | الإصلاح |
|---|---|---|
| مسارات `/tenders/*` | **404 على كل شاشات المناقصات** (القائمة، التفاصيل، الإنشاء، الإلغاء، الترسية، وعروض المستودع) | `/quotation-requests/*` + `select-quotation` + `my-quotations` + `{id}/quotations` |
| `offerType` في `SalesOfferSummary/Detail` | **تعطُّل شاشة العروض كلها** (`null is not int` لأن الحقل حُذف من الخادم) | حُذف من النماذج والواجهات، وحُذف `SalesOfferType` |
| مفاتيح JSON لطلب التسعير | قيم مفقودة وتعطُّل عند القراءة | `tenderNumber→requestNumber` · `offerCount→quotationCount` · `tenderItemId→quotationRequestItemId` · `offerType→quotationType` · `offersVisible→quotationsVisible` · `offers→quotations` |
| جسم تقديم عرض السعر | 400 من الـvalidator | `quotationType` + `quotationRequestItemId` |
| شروط الدفع مشروطة بنوع «مبيع» | تختفي عن عروض لها شروط دفع فعلية | تُعرض متى وُجدت قيمة |

**قاعدة للمستقبل:** أي إعادة تسمية في الباك إند تستلزم مراجعة
`api_endpoints.dart` **و** ملف النموذج المقابل في `lib/models/` معاً —
تصحيح المسار وحده لا يكفي لأن مفاتيح JSON تتغيّر معه.

---

## 3.6 شاشتا الصيدلي المُفعَّلتان + توحيد المصطلح (2026-10-26) 🩺

`PhOrdersPage` و`PhTendersPage` كانتا placeholder — الـrepositories كانت
جاهزة والخادم يدعم كل شيء، فكان الصيدلي يرى تطبيقاً نصف ميت. ما بُني:

- **`PhOrdersPage`** — تبويبات جارية/مكتملة/ملغاة (التجميع محلي لأن الخادم
  يفلتر بحالة واحدة فقط)، بطاقة طلبية، ورقة تفاصيل فيها الأصناف وملاحظاتك
  ومسار الحالة، إلغاء في «بانتظار التأكيد» فقط، وتوليد فاتورة من طلبية
  مكتملة لم تُولَّد فاتورتها.
- **`PhTendersPage`** — تبويبات مفتوحة/بانتظار الترسية/منتهية. «بانتظار
  الترسية» مبنية على `isExpired` لا على رمز الحالة وحده، لأن الخادم لا
  يُغلق الطلب تلقائياً عند انتهاء المهلة. إنشاء طلب (عنوان، وصف، مهلة
  بتاريخ **ووقت**، أصناف بكمية ووحدة وملاحظة)، إلغاء وهو مفتوح، ومقارنة
  عروض الأسعار مع إجمالي تقديري لكل عرض (سعر الوحدة × الكمية المطلوبة)
  وزر اعتماد مع ملاحظة للمستودع.

قيود الخادم المنعكسة حرفياً في الواجهة — لا نعرض زراً يرفضه الخادم:

| القاعدة في الخادم | انعكاسها |
|---|---|
| `QuotationsVisible = UtcNow >= ExpiresAt` | تفاصيل العروض مخفية قبل المهلة، ويبقى **العدد** ظاهراً |
| الترسية ترفض قبل انتهاء المهلة وبعد الترسية/الإلغاء | زر «اعتماد» يظهر فقط عند `offersVisible && status ∉ {awarded, cancelled}` |
| الإلغاء مسموح وهو `Open` فقط | زر الإلغاء مشروط بالحالة نفسها |
| `ExpiresAt > UtcNow` في الـvalidator | منتقي تاريخ **ووقت** + تحقّق محلي قبل الإرسال (منتقي تاريخ وحده يرسل منتصف الليل = ماضٍ) |

**توحيد المصطلح:** حُذفت كلمة «مناقصة» من كل نصوص الواجهة (صفر تطابُق في
`lib/`). التبويب السفلي صار «التسعير» في التطبيقين، و«عروضي على المناقصات»
صارت «عروض أسعاري». أسماء الملفات والأصناف (`*Tender*`) بقيت كما هي عمداً
حتى لا تُعاد تسمية الشجرة كلها دفعةً واحدة. وشُدِّد `AppBottomNav` بـ
`maxLines: 1 + ellipsis` فلا تُفيض أي تسمية مستقبلية الشريط.

---

## 3.7 الإشعارات (2026-10-26) 🔔

الخادم كان مكتملاً (صندوق مُرقَّم، عدّاد غير المقروء، تعليم مفرد/كلّي،
كتالوج إعدادات، تسجيل أجهزة) والتصميم جاهزاً في Figma — ولم يكن في
التطبيق **ولا ملف واحد** يقابلها، وزرّا الجرس في الرئيسيتين كان
`onPressed: () {}` فارغاً. ما بُني:

| الملف | الدور |
|---|---|
| `models/notification_models.dart` | `AppNotification` + `NotificationSetting` + `NotificationType` |
| `repositories/notification_repository.dart` | الصندوق والإعدادات + مزوّدا عدّاد غير المقروء |
| `features/notifications/notifications_page.dart` | الصندوق: الكل/غير المقروء، تعليم كمقروء، تعليم الكل، فتح الشاشة المقصودة |
| `features/notifications/notification_settings_page.dart` | مفتاح لكل نوع، والمقفلة تُعرض مقفلة |
| `shared/widgets/notification_bell.dart` | جرس الشريط العلوي + شارة العدد |

قرارات تستحقّ التذكّر:

- **شاشة واحدة للجهتين** بعلم `isWarehouse`. بادئة المسار (`/warehouse/`)
  هي نفسها ما يجعل `_AuthInterceptor` يرسل توكن المستودع — فلا شيء آخر
  يحتاج إلى تفريق.
- **القائمة تأتي من كتالوج الخادم** (`NotificationTypeCatalog`): العنوان
  والوصف وهل النوع قابل للتعطيل. نوع جديد في الخادم يظهر في شاشة الإعدادات
  **بلا تحديث للتطبيق**. لذلك لا تُبنى القائمة من `enum` في العميل.
- **النوع المجهول لا يُسقط الصندوق**: `NotificationType.unknown` يحتفظ
  بالرقم الأصلي ويُعرض بنصّه القادم من الخادم.
- **التعليم كمقروء تفاؤلي**: يُطبَّق محلياً فوراً، وفشل الشبكة يُعيد
  الحالة السابقة.
- **`PUT settings` دمج لا استبدال** (تحقّقنا من الـHandler) — فإرسال مفتاح
  واحد آمن، ويُرجع القائمة كاملةً فنعرض الحالة النهائية بلا طلب ثانٍ.
- **فشل عدّاد الشارة صامت**: الجرس بلا شارة بدل رسالة خطأ في شاشة أخرى.

**ما يزال ناقصاً — التنبيه الفوري (Push):** الخادم يوفّر
`POST/DELETE/GET auth/devices`، لكن تسجيل الجهاز يحتاج رمز FCM، أي
`firebase_messaging` + مشروع Firebase + `google-services.json`. لا شيء من
ذلك موجود في `pubspec.yaml` ولا يمكن توليده هنا — **يحتاج بيانات اعتماد
من المالك**. حتى ذلك الحين الصندوق والإعدادات تعملان كاملتين، والمفاتيح
تُحفظ فعلياً استعداداً للتنبيه الفوري.

---

## 3.8 موظّفو المستودع + ملف المستودع العام (2026-10-26) 👥

ثلاث شاشات جديدة، وثلاثة أزرار ميتة (`onTap: () {}`) صارت حيّة.

| الملف | الدور |
|---|---|
| `features/wh_users/wh_users_page.dart` | موظّفو المستودع: قائمة، إضافة، تعديل، إيقاف/تفعيل، تعيين كلمة مرور |
| `features/ph_warehouses/ph_warehouses_page.dart` | المستودعات النشطة + بحث محلي |
| `features/ph_warehouses/ph_warehouse_profile_page.dart` | ملف مستودع: بياناته، مدن خدمته، وعروضه المتاحة لهذه الصيدلية |
| `models/warehouse_user_models.dart` · `repositories/warehouse_user_repository.dart` | عقد `warehouse/users` |
| `models/warehouse_models.dart` (`WarehouseProfile`) | عقد `GET /supply-warehouses/{id}` |

قرارات تستحقّ التذكّر:

- **الدور يُقرأ من `GET /warehouse/auth/me` لا من الجلسة.** الجلسة لا تخزّن
  الدور، والأهمّ: قد يغيّره مدير آخر بعد تسجيل الدخول فيبقى التوكن قديماً.
  المزوّد الجديد `warehouseMeProvider` هو المصدر.
- **مدخل «موظّفو المستودع» مخفيّ عن الموظّف** لأن الخادم يفرض سياسة
  `Warehouse.Admin` — إظهاره يعني إرسال الموظّف إلى 403. وريثما يصل الدور
  يبقى مخفياً: الإخفاء أسلم من وميض مدخل ثم اختفائه.
- **حارسا الخادم منعكسان في الواجهة نصّاً قبل الرحلة:** لا إيقاف للنفس،
  ولا إيقاف/خفض رتبة لآخر مدير فعّال (وإلا بقي المستودع بلا من يملك إعادة
  التفعيل). خيار الدور يُقفل بدل أن يُترك ليفشل.
- **التعديل لا يمسّ اسم المستخدم والبريد** — الخادم لا يقبلهما في
  `UpdateWarehouseUser`، فيُعرضان للقراءة بدل إخفائهما.
- **القائمة تشمل الموقوفين** عمداً: الإيقاف ليس حذفاً، والمدير يحتاج رؤيتهم
  ليُعيد تفعيلهم. الفعّالون أولاً ثم الموقوفون.
- **تنبيه مكتوب في شاشة كلمة المرور:** تغييرها لا يُبطل توكن الموظّف القائم
  (لا إبطال للتوكن في المشروع) — لقطع وصوله فوراً يجب إيقاف حسابه.
- **عروض المستودع في ملفه تمرّ بفلتر التغطية** (`GET /offers?warehouseId=`)،
  فما يظهر هو ما يحقّ لهذه الصيدلية رؤيته لا كل عروضه. وحين يختلف العدّاد
  عن القائمة نقول ذلك صراحةً: «لديه N عرض لكن لا شيء منها يستهدف منطقتك»
  بدل «لا عروض».

**أُضيف للبنية التحتية:** `ApiClient.patch` (لم يكن موجوداً، و
`PATCH users/{id}/active` يحتاجه)، و`OfferSort` في `enums.dart`، وتوسيع
`getAvailableOffers` بكل معاملات التصفية التي يدعمها الخادم (`search`,
`warehouseId`, `hasBonus`, `expiringWithinDays`, `minUnitPrice`,
`maxUnitPrice`, `dosageForm`, `sort`) — كلها اختيارية وغيابها يعيد السلوك
السابق حرفياً، فلم تنكسر مواضع الاستدعاء القائمة.

---

## 4. الأخطاء والمشاكل المعروفة 🐛

| الخطأ | الموقع | الأولوية | الحالة |
|-------|--------|----------|--------|
| ~~`PhOrdersPage` placeholder فارغة~~ | `ph_orders_page.dart` | — | **مُنجز 2026-10-26** |
| ~~`PhTendersPage` placeholder فارغة~~ | `ph_tenders_page.dart` | — | **مُنجز 2026-10-26** |
| ~~الإشعارات غائبة كلياً عن التطبيق~~ (الصندوق والإعدادات) | `features/notifications/` | — | **مُنجز 2026-10-26** |
| التنبيه الفوري (Push/FCM) غير مُفعَّل | `pubspec.yaml` | عالية | **محجوب** — يحتاج مشروع Firebase و`google-services.json` من المالك |
| زر «الملف الشخصي» للصيدلية ميت (`onTap: () {}`) | `ph_more_page.dart` | متوسطة | مفتوح |
| زر «التقارير» للمستودع ميت (`onTap: () {}`) | `wh_more_page.dart` | منخفضة | مفتوح |
| `PhListingsPage` غير مُنفَّذة (placeholder) | `router.dart` - `_PlaceholderPage` | — | **مؤجَّل** (بيع الفائض مرحلة لاحقة) |
| `WhListingsPage` غير مُنفَّذة | نفسه | — | **مؤجَّل** (نفس السبب) |

---

## 5. الأولويات القادمة 📋

### Phase 1: إكمال صفحات الصيدلية (عاجل)
- [x] **`PhOrdersPage`** — قائمة حقيقية + تفاصيل + إلغاء + فاتورة *(2026-10-26)*
- [x] **`PhTendersPage`** — إنشاء طلب تسعير + إلغاء + مقارنة عروض الأسعار والترسية *(2026-10-26)*

### Phase 2: الإشعارات
- [x] صندوق الإشعارات + شارة العدد غير المقروء *(2026-10-26)*
- [x] تعليم كمقروء (مفرد/الكل) *(2026-10-26)*
- [x] إعدادات الإشعارات — تُبنى من كتالوج الخادم *(2026-10-26)*
- [ ] **تسجيل جهاز FCM** — محجوب على مشروع Firebase و`google-services.json`

### Phase 3: المستودع والملفات الشخصية
- [x] **موظّفو المستودع** — قائمة/إضافة/تعديل/إيقاف/كلمة مرور *(2026-10-26)*
- [x] **ملف المستودع العام** — `GET /supply-warehouses/{id}` + قائمة المستودعات *(2026-10-26)*
- [ ] **`PhProfilePage`** — بيانات الصيدلية + تعديل البريد/كلمة المرور (زر «الملف الشخصي» ما يزال ميتاً)
- [ ] **تقارير المستودع** — زر «التقارير» في `WhMorePage` ما يزال ميتاً

### Phase 4: استثمار قدرات الخادم الجديدة
- [x] طبقة المستودع (`getAvailableOffers`) تقبل كل معاملات التصفية *(2026-10-26)*
- [ ] **واجهة** تصفية/ترتيب في `PhOffersPage` (البحث فيها ما يزال محلياً بينما الخادم يدعم `search`)
- [ ] `?search=` في أدوية المستودع
- [ ] التقاط الموقع عند إنشاء الحساب (الحقول موجودة في الخادم — الميزة شكلية حالياً)

### Phase 5: البحث المقارن والسلّة *(2026-10-29)*
- [x] **`PhPriceSearchPage`** — بحث الأسعار: أصناف العروض + التسعير المباشر
      في قائمة واحدة، مع لوحة فلاتر (المصدر/الترتيب) وشارة عدد الفلاتر
- [x] **`PhCartPage`** — السلّة مجمَّعة حسب المستودع، لكل مجموعة إجمالها
      وتنبيه حدّها الأدنى وزر إتمامها المستقلّ
- [x] **السلّة على الخادم** (`/tawrid-api/cart`) لا محلياً: تتبع الحساب لا
      الجهاز، والتجميع والإجماليات وحالة الحدّ الأدنى كلها منه — فلا حساب
      محلّي يفترق عنه. والأسعار تُشتقّ في الخادم من المصدر، فالإضافة ترسل
      مرجع الصنف وكميته فقط
- [x] **`CartButton`** — زر السلّة بشارة العدّ في الشريط العلوي (رئيسية
      الصيدلي + بحث الأسعار)
- [x] **تسعير أدوية المستودع** — سعر اختياري لكل صنف
      (`PATCH /warehouse/medicines/{id}/price`)؛ الصنف بلا سعر يبقى في
      «أدويتي» ولا يظهر في البحث المقارن
- [x] **`WhOrderSettingsPage`** — الحدّ الأدنى للطلبية الواحدة، إعداد بائع
      يضبطه كل مستودع لنفسه (`GET`/`PUT /warehouse/settings`)
- [ ] **ترتيب «الأقرب»** يتطلّب موقعاً مسجَّلاً للصيدلية — مرتبط ببند
      «التقاط الموقع عند إنشاء الحساب» أعلاه، والخادم يردّ برسالة صريحة
      حتى يُنفَّذ

### مؤجَّل بقرار المالك
- بيع الفائض (`PharmacyListing` / `PhListingsPage` / `WhListingsPage`)
- إعلانات/أخبار المنصّة
- كميات ودفعات المخزون

---

## 6. نقاط بنية تحتاج انتباهاً ⚠️

### `TawridColors` (app_colors.dart)
- الملف محتفَظ به لأن:
  - ألوان الحالات الدلالية (`statusPending/Completed/...`) لا تزال مستخدمة
  - `pharmacyGradient`/`brandGradient` مُعرَّفة كـ const للاستخدام المحدود
- **لا يُنبغي** استخدام `TawridColors.background/surface/border/hint/textSecondary` في صفحات جديدة — استخدم `context.colors.*` أو `context.tokens.*`

### `LoadingState / ErrorState / EmptyState`
- مُعرَّفة في `shared/ui/ui_states.dart` (مُصدَّرة من `shared/ui/ui.dart`)
- بعض الصفحات تستوردها من `shared/widgets/app_states.dart` (يُعيد تصديرها أيضاً)
- للتوحيد: استخدم `shared/ui/ui.dart` فقط في الصفحات الجديدة

### الحقول الكثيفة `isDense: true`
- الحقول الكثيفة داخل البطاقات (مثل `wh_create_offer_page.dart`) تبقى كـ raw `TextFormField` عن قصد — لا تُحوَّل لـ `AppTextField` لأنها في سياق بصري مختلف (بطاقات صغيرة).

---

## 7. المستودعات المرتبطة

| المستودع | الموقع | التقنية |
|----------|--------|---------|
| Backend API | `C:\Users\alabbas\Desktop\tawrid\tawrid.api` | ASP.NET Core 9, PostgreSQL, Clean Architecture + CQRS |
| Frontend (هذا المشروع) | `C:\Users\alabbas\Desktop\tawrid\tawrid_app` | Flutter, Material 3, Arabic RTL |
| خطة التوريد التفصيلية | `C:\Users\alabbas\Desktop\tawrid\tawrid.api\SUPPLY_CHAIN_PLAN.md` | — |

---

## 8. كيفية استخدام هذا الملف

- **عند إضافة ميزة جديدة:** أضفها في قسم "ما تم إنجازه" ✅
- **عند اكتشاف خطأ:** أضفه في قسم "الأخطاء والمشاكل المعروفة" 🐛
- **عند اتخاذ قرار معماري:** وثّقه في قسم "البنية المعمارية" أو "نقاط بنية تحتاج انتباهاً"
- **عند إكمال مرحلة:** حرّك العناصر من "الأولويات القادمة" إلى "ما تم إنجازه"
- **آخر تحديث:** عدّل التاريخ في أعلى الملف عند كل تحديث مهم
