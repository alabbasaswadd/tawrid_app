# خطة توحيد تصميم تطبيق توريد (Design System)

هدف: روح واحدة · تصميم موحّد ومتجاوب · دعم الدارك مود · مركز واحد للحقيقة · طابع هادئ رصين يليق بجمهور مثقّف.

## 1) التشخيص (أرقام فعلية وقت الكتابة)
- يوجد ثيم مركزي (`app_theme.dart`, Material 3, Cairo, `TawridColors`) لكن الشاشات تتجاوزه.
- `GoogleFonts.cairo` يدوياً داخل الشاشات: **29 ملف / 132 استدعاء**.
- `Colors.white` يدوياً: **57 مرة** · شفافيات `withValues(alpha:)`: **47 مرة**.
- ألوان `TawridColors` ثابتة (const) غير مشتقّة من `ColorScheme` ⇒ لا يمكن دعم الدارك مود بها.
- هويّتان متضاربتان: بنفسجي المستودع (16 ملف) + أخضر/تركواز.
- لا `darkTheme` ولا `ThemeMode` ولا حفظ تفضيل.

## 2) روح التصميم
- لون أساسي واحد هادئ (accent منخفض التشبّع)؛ تمييز المستودع/الصيدلية بلمسة خفيفة لا بتدرّج كامل.
- أسطح مسطّحة + حدود 1px + ظلال خفيفة جداً بدل كثرة التدرّجات (تدرّج واحد لشاشة الدخول فقط).
- طيف محايد دافئ، طباعة منضبطة (وزنان–ثلاثة)، زوايا موحّدة (12/16).

## 3) المعمارية المركزية
```
lib/app/theme/
├─ tokens.dart            ← القيم الخام (ألوان light/dark، ظلال، مدد الحركة)
├─ app_tokens_ext.dart    ← ThemeExtension<TawridTokens> (دلالات خارج ColorScheme) + context.tokens
├─ app_typography.dart    ← مقياس نصّي واحد (يبني textTheme من ColorScheme)
├─ app_theme.dart         ← light + dark من نفس الدلالات
├─ theme_mode_provider.dart ← ThemeMode عبر Riverpod + حفظ في shared_preferences
└─ app_colors.dart        ← LEGACY (يُهجَر تدريجياً إلى TawridTokens/ColorScheme)
```
- النصوص عبر `textTheme` فقط؛ الألوان عبر `ColorScheme`/`context.tokens` — لا ثوابت لونية في الشاشات.

## 4) الطباعة
- مصدر واحد؛ تُمنع `GoogleFonts.cairo` في الشاشات.
- قرار: Cairo (الحالي) أم IBM Plex Sans Arabic / Tajawal (أرصن). (المرحلة 0 تُبقي Cairo كمتغيّر واحد يسهل تبديله.)

## 5) الدارك مود
- `AppTheme.dark` من نفس الدلالات + `ThemeMode` (نظام/فاتح/داكن) + حفظ التفضيل + مفتاح تبديل.

## 6) مكتبة مكوّنات (`lib/shared/ui/`)
`AppScaffold` · `AppCard` · `AppButton` · `AppTextField` · `StatusChip` · `SectionHeader` · `AppListTile` · حالات Loading/Empty/Error — كلها من الثيم.

## 7) التجاوب
نقاط كسر + `maxContentWidth` + حشوات متكيّفة عبر LayoutBuilder.

## 8) الحالات الدلالية
توحيد خرائط enum→لون/نص في مكان واحد يتكيّف مع الوضعين ويغذّي `StatusChip`.

## 9) خطة التنفيذ المرحلية
- **المرحلة 0 — الأساس (غير كاسر):** tokens + ThemeExtension + light/dark + typography + themeMode plumbing. الشاشات تبقى على اللون الحالي حتى الهجرة.
- **المرحلة 1 — المكوّنات.**
- **المرحلة 2 — الهجرة شاشة‑بشاشة** (إزالة GoogleFonts/Colors.white).
- **المرحلة 3 — تفعيل الدارك مود الكامل + التجاوب.**
- **المرحلة 4 — حارس lint** يمنع `GoogleFonts.`/`Colors.white`/`Color(0x` في `lib/features`.

## 10) قرارات مطلوبة
1. الخط. 2. اللون الأساسي وإلغاء البنفسجي؟ 3. الدارك الافتراضي = النظام؟ 4. تخطيط لوحي حقيقي أم توسيط؟

## 11) التقدير
~5–8 أيام عمل.

---
### حالة المرحلة 0 (قيد التنفيذ)
افتراضات مؤقتة (قابلة للتغيير): الخط Cairo · لون أساسي تركواز‑أخضر مغبّر · المستودع نيلي هادئ بدل البنفسجي · `themeMode` الافتراضي = فاتح (يُحوّل إلى «النظام» بعد اكتمال الهجرة لتفادي شاشات نصف‑داكنة).
