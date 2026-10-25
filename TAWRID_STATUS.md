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
- [x] طلبيات التوريد (`PhOrdersPage`) — skeleton (جاهز للتطوير)
- [x] المناقصات (`PhTendersPage`) — skeleton (جاهز للتطوير)
- [x] المزيد (`PhMorePage`) — قائمة الخدمات + تسجيل الخروج

### صفحات المستودع
- [x] الصفحة الرئيسية (`WhHomePage`) — إحصائيات + عروضي + مناقصات مفتوحة
- [x] أدويتي (`WhMedicinesPage`) — قائمة + بحث فوري + حذف
- [x] كتالوج الأدوية (`WhMedicineCatalogPage`) — اختيار من الكتالوج العام
- [x] إنشاء عرض بيع (`WhCreateOfferPage`) — نوع العرض + أصناف + مناطق + بونص
- [x] عروضي (`WhOffersPage`) — إدارة عروض البيع
- [x] الطلبيات الواردة (`WhOrdersPage`) — قائمة + تفاصيل + تحديث الحالة
- [x] عروضي على المناقصات (`WhTendersPage`) — قائمة عروض المستودع على المناقصات
- [x] التقدّم بعرض على مناقصة (`WhSubmitTenderOfferPage`) — نموذج سعر/بونص لكل صنف
- [x] الملف الشخصي (`WhProfilePage`) — بيانات المستودع + تعديل مناطق التخديم
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

## 4. الأخطاء والمشاكل المعروفة 🐛

| الخطأ | الموقع | الأولوية | الحالة |
|-------|--------|----------|--------|
| `PhOrdersPage` placeholder فارغة — لا منطق فعلي | `ph_orders_page.dart` | عالية | مفتوح |
| `PhTendersPage` placeholder فارغة | `ph_tenders_page.dart` | عالية | مفتوح |
| الملف الشخصي للصيدلية (`PhMorePage`) — "الملف الشخصي" و"الإعدادات" لا تنتقل | `ph_more_page.dart` | متوسطة | مفتوح |
| `PhListingsPage` غير مُنفَّذة (placeholder) | `router.dart` - `_PlaceholderPage` | متوسطة | مفتوح |
| `WhListingsPage` غير مُنفَّذة | نفسه | متوسطة | مفتوح |
| `WhMorePage` قد تحتاج تطوير | `wh_more_page.dart` | منخفضة | مراجعة |

---

## 5. الأولويات القادمة 📋

### Phase 1: إكمال صفحات الصيدلية (عاجل)
- [ ] **`PhOrdersPage`** — ربط `supplyOrderRepository.getPharmacyOrders()` + قائمة حقيقية + تفاصيل
- [ ] **`PhTendersPage`** — ربط `tenderRepository.getPharmacyTenders()` + إنشاء مناقصة جديدة + إدارة العروض المُقدَّمة
- [ ] **`PhListingsPage`** — إعلانات الصيدليات عن الأدوية للبيع

### Phase 2: الملفات الشخصية
- [ ] **`PhProfilePage`** — بيانات الصيدلية + تعديل البريد/كلمة المرور
- [ ] **`WhMorePage`** — استكمال القائمة

### Phase 3: الميزات المتقدمة
- [ ] **إشعارات FCM** — للعروض الجديدة والطلبيات
- [ ] **`PharmacyListing`** — الصيدلي يُعلن عن أدوية للبيع
- [ ] **فاتورة الشراء** — توليد وعرض الفاتورة عند اكتمال الطلبية
- [ ] **Dark Mode تام** — الفحص النهائي بعد اكتمال الترحيل

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
