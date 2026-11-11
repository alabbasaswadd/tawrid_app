# قواعد مشروع توريد (tawrid_app)

## القاعدة الذهبية: التقيد بنظام التصميم — لا مكونات جديدة إلا للضرورة

مصدر الحقيقة للتصميم هو ملف Figma «توريد | TAWREED» (fileKey: `WCqmsZnJzP07waVsNSgsZk`)
ومكتبة المكونات المنفذة منه في هذا المشروع. **قبل بناء أي واجهة:**

1. **ابحث أولاً في `lib/shared/ui/ui.dart`** — غالباً المكوّن موجود:
   - ذرّات: `AppIcon` · `AppButton` · `AppTextField` · `StatusBadge` · `BonusBadge` ·
     `AppFilterChip` · `QuantityStepper` · `AppCheckbox`
   - مركّبات: `AppSearchBar` · `AppCard` · `AppSectionHeader` · `SummaryCounter`
   - بطاقات: `OfferCard` · `OrderCard` · `OfferItemRow` (عرض/تحرير/اختيار) ·
     `WarehouseOfferCard` · `TenderCard` (طلب تسعير)
   - اختيار المناطق: `GovernorateRow` · `CityRow`
   - هيكل: `WelcomeTopBar` · `InnerTopBar` · `AppBottomNav`
   - حالات: `UiLoading` · `UiEmpty` · `UiError` · `OfferCardSkeleton`
2. **لا تخترع مكوناً جديداً** إذا أمكن تركيب الشاشة من الموجود — ولو تطلب ذلك
   تمرير بارامترات إضافية لمكوّن قائم فهذا أفضل من مكوّن جديد.
3. **عند الضرورة القصوى فقط**: اسحب مواصفات المكوّن من Figma (get_design_context)،
   ابنه في `lib/shared/ui/`، صدّره من `ui.dart`، وأضف عينة له في معرض
   `/dev/gallery` (`lib/features/dev_gallery/design_gallery_page.dart`).

## الألوان والخطوط والمقاسات — من الثيم فقط

- **ممنوع** أي `Color(0x...)` أو حجم خط صلب في الشاشات.
- الألوان: `context.colors` (ColorScheme) و`context.tokens` (TawridTokens —
  أسطح الحالات والذهبي وأسطح العلامة والظلال `cardShadow`/`navShadow`).
- النصوص: `context.text` (Tajawal بتدرّج Figma: 22/18/16/15/14/12/11) +
  `context.priceStyle` / `context.priceBrandStyle` لطراز «سعر وأرقام».
- المسافات: `AppSpacing` (xs 4 · sm 8 · md 12 · lg 16 · xl 20 · x2l 24 · x3l 32،
  هامش الصفحة `AppSpacing.page` = 20). الزوايا: `AppRadius` (sm 8 · md 12 · lg 16 · full).
- الأيقونات: `AppIcon(AppIcons.xxx)` حصراً (SVG من Figma في `assets/icons/`) —
  لا `Icons.*` من Material في الواجهات الجديدة.

## اصطلاحات RTL (مثبتة من لقطات Figma)

- التطبيق RTL بالكامل؛ «بداية القراءة» = اليمين.
- الشارات (نقطة الحالة/هدية البونص/إغلاق الشريحة): الأيقونة في بداية القراءة (يمين النص).
- أزرار الإجراء داخل البطاقات (مثل «إضافة للطلبية +»): الأيقونة في نهاية القراءة (يسار النص).
- روابط التفاصيل: شيفرون `chevronForwardRtl` يسار النص.

## عام

- كل مكوّن يجب أن يعمل في الوضعين الفاتح والداكن (اقرأ من الثيم، لا قيم صلبة).
- المصطلح المعتمد حالياً في Figma: «طلب تسعير» بدل «مناقصة».
- بعد أي تعديل: `flutter analyze` نظيف قبل الاعتبار منجزاً.
