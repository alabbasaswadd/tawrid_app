import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// الشريط العلوي الترحيبي (Figma: شريط علوي/ترحيب) — تحية + اسم الجهة في
// بداية القراءة، وزر إشعارات دائري في الطرف المقابل مع نقطة غير المقروء.
class WelcomeTopBar extends StatelessWidget implements PreferredSizeWidget {
  const WelcomeTopBar({
    required this.greeting,
    required this.name,
    this.onNotificationsTap,
    this.hasUnread = false,
    this.actions = const [],
    super.key,
  });

  final String greeting;
  final String name;
  final VoidCallback? onNotificationsTap;
  final bool hasUnread;

  /// إجراءات تسبق زرّ الإشعارات (بحث الأسعار والسلّة في رئيسية الصيدلي).
  final List<Widget> actions;

  /// سطرا الشريط بمقياس الخط الافتراضي: «نص مساعد» ١٢/١٨ فوق «عنوان قسم»
  /// ١٨/٢٦ = ٤٤، وحشوٌ رأسي ١٢ من الطرفين — مجموعها ٦٨ كما في Figma.
  static const double _contentHeight = 18 + 26;
  static const double _verticalPadding = AppSpacing.md;

  // الارتفاع يتبع تكبير خطّ النظام. تثبيته على ٦٨ كان يعني صفر هامش عند
  // المقياس الافتراضي، فأي تكبير — ومنه إعداد حجم الخط في المتصفح —
  // يُفيض السطرين. والحشوة لا تكبر: النصّ وحده هو ما يكبر.
  @override
  Size get preferredSize {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    final scaler = view == null
        ? TextScaler.noScaling
        : MediaQueryData.fromView(view).textScaler;
    return Size.fromHeight(scaler.scale(_contentHeight) + _verticalPadding * 2);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return SafeArea(
      bottom: false,
      // سقفٌ للتكبير: فوق ١٫٦ لا يتّسع السطر الواحد للاسم مهما فعلنا،
      // والشريط عنصر هيكلٍ ثابت الارتفاع لا نصّ مقروء طويلاً.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: _verticalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // خطّ الدفاع الثاني: إن لم يتّسع السطران معاً — لأن مقياس
                    // الخط في شجرة الودجت يخالف مقياس المنصّة — تُسقَط التحية
                    // ويبقى الاسم. سطرٌ ناقص أهون من شريط أحمر مشطوب.
                    final scaler = MediaQuery.textScalerOf(context);
                    final fits =
                        scaler.scale(_contentHeight) <= constraints.maxHeight;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (fits)
                          Text(
                            greeting,
                            style: context.text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        // اسم صيدلية طويل يلتفّ سطرين فيفيض الشريط ارتفاعاً.
                        Text(
                          name,
                          style: context.text.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
              ),
              for (final action in actions) ...[
                action,
                const SizedBox(width: AppSpacing.sm),
              ],
              Stack(
                children: [
                  Material(
                    color: cs.surface,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onNotificationsTap,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: AppIcon(
                            AppIcons.bell,
                            size: 20,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasUnread)
                    PositionedDirectional(
                      end: 2,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: t.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// الشريط العلوي للشاشات الداخلية (Figma: شريط علوي/داخلي) —
// زر رجوع دائري في بداية القراءة وعنوان في الوسط وموازن في الطرف الآخر.
class InnerTopBar extends StatelessWidget implements PreferredSizeWidget {
  const InnerTopBar({
    required this.title,
    this.onBack,
    this.trailing,
    this.showBack = true,
    super.key,
  });

  final String title;

  // الافتراضي: Navigator.maybePop.
  final VoidCallback? onBack;

  // عنصر اختياري مكان الموازن (مثل زر إجراء).
  final Widget? trailing;

  // يُخفي زرّ الرجوع — لشاشةٍ لا مخرج منها إلا بإتمامها (إعادة تعيين كلمة
  // المرور الإجبارية). زرٌّ معطَّل يبقى دائرةً فارغة تُقرأ عطلاً، وإخفاؤه
  // أصدق. ويُستبدَل بموازنٍ بنفس عرضه فيبقى العنوان في وسطه.
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 10,
        ),
        child: Row(
          children: [
            if (showBack)
              Material(
                color: cs.surface,
                shape: CircleBorder(side: BorderSide(color: cs.outline)),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: AppIcon(
                        AppIcons.chevronBackRtl,
                        size: 20,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 40, height: 40),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 40, height: 40, child: trailing),
          ],
        ),
      ),
    );
  }
}
