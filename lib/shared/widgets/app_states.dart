import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';

// حالات موحّدة متكيّفة مع الثيم (فاتح/داكن). أسماء الأصناف ثابتة حتى لا تتغيّر
// مواضع الاستدعاء عبر التطبيق.

// مؤشّر التحميل الموحّد: شعار توريد نابض + «جارٍ التحميل».
//
// تعريف واحد تستعمله كل الشاشات، فتغييره هنا يغيّرها جميعاً. النبض بطيء
// ولطيف (١٢٠٠ مللي ذهاباً وإياباً) — حركة تقول «يعمل» بلا أن تخطف
// الانتباه عن المحتوى القادم.
class LoadingState extends StatefulWidget {
  const LoadingState({this.message = 'جارٍ التحميل…', super.key});

  /// نصّ بديل حين يكون سبب الانتظار معروفاً: «جارٍ تجهيز الملف…».
  final String message;

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            // لا يختفي تماماً: من ٠٫٤٥ إلى ١ يبقي الشعار حاضراً وهو ينبض.
            opacity: Tween<double>(begin: 0.45, end: 1).animate(curve),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
              child: Image.asset(
                'assets/images/logo.png',
                width: 36,
                fit: BoxFit.fitWidth,
                // غياب الأصل لا يجوز أن يُسقط كل شاشة تُحمِّل.
                errorBuilder: (_, _, _) => Icon(
                    Icons.local_pharmacy_outlined,
                    size: 48,
                    color: context.colors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(widget.message,
              style: context.text.bodySmall?.copyWith(color: tk.hint)),
        ],
      ),
    );
  }
}

/// حالة العطل — تُميّز انقطاع الشبكة من عطل الخادم من الطلب المرفوض.
///
/// التمييز ليس زينة: الثلاثة تحتاج من المستخدم أفعالاً مختلفة. انقطاع
/// الشبكة يُصلحه هو، وعطل الخادم ينتظره، والطلب المرفوض يحتاج تعديل ما
/// أدخل. وعرضها بوجهٍ واحد يُحمّله ذنب عطلٍ ليس ذنبه، أو يدفعه لتكرار
/// محاولةٍ لن تنجح.
///
/// والعطلان العابران (شبكة/خادم) يُعرضان بحلقةٍ نابضة: حركةٌ تقول «الأمر
/// مؤقّت» قبل أن تُقرأ كلمة. والمرفوض ساكنٌ — سكونه يقول إن شيئاً لن
/// يتغيّر ما لم يتغيّر الطلب.
class ErrorState extends StatelessWidget {
  /// نصٌّ جاهز — لعطلٍ لا استثناء وراءه (تحقّق محلّي مثلاً).
  const ErrorState({required String message, this.onRetry, super.key})
      : error = message;

  /// الاستثناء نفسه — يحمل صنفه، فتُختار الصورة والنصّ منه.
  const ErrorState.of(this.error, {this.onRetry, super.key});

  /// [ApiException] أو نصّ.
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    final kind = error is ApiException
        ? (error as ApiException).kind
        : ApiErrorKind.request;
    final message =
        error is ApiException ? (error as ApiException).message : '$error';

    final (icon, title, tone, hint) = switch (kind) {
      ApiErrorKind.network => (
          Icons.wifi_off_rounded,
          'لا اتصال بالإنترنت',
          tk.warning,
          'تحقّق من الشبكة ثم أعد المحاولة',
        ),
      ApiErrorKind.server => (
          Icons.cloud_off_rounded,
          'الخدمة غير متاحة مؤقّتاً',
          cs.error,
          'العطل عندنا لا عندك — أعد المحاولة بعد قليل',
        ),
      ApiErrorKind.request => (
          Icons.error_outline,
          null,
          cs.error,
          null,
        ),
    };

    final transient = kind != ApiErrorKind.request;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ErrorGlyph(icon: icon, tone: tone, pulsing: transient),
            const SizedBox(height: AppSpacing.md),
            if (title != null) ...[
              Text(title, textAlign: TextAlign.center, style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              // للعطل العابر عنوانٌ يكفي، والتفصيل تحته أهدأ. وللمرفوض
              // الرسالةُ هي كل ما يملكه المستخدم فتُعرض بحجمها الكامل.
              transient ? (hint ?? message) : message,
              textAlign: TextAlign.center,
              style: transient
                  ? context.text.bodySmall?.copyWith(color: tk.hint)
                  : context.text.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// أيقونة العطل، وحولها حلقةٌ تتمدّد وتخفت حين يكون العطل عابراً.
class _ErrorGlyph extends StatefulWidget {
  const _ErrorGlyph({
    required this.icon,
    required this.tone,
    required this.pulsing,
  });

  final IconData icon;
  final Color tone;
  final bool pulsing;

  @override
  State<_ErrorGlyph> createState() => _ErrorGlyphState();
}

class _ErrorGlyphState extends State<_ErrorGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disc = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: widget.tone.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(widget.icon, color: widget.tone, size: 44),
    );

    if (!widget.pulsing) return disc;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_controller.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            // الحلقة تتمدّد إلى ١٫٦ وتتلاشى — موجةٌ واحدة تتكرّر، لا دوران
            // يوحي بأن شيئاً يُحمَّل الآن.
            Transform.scale(
              scale: 1 + (t * 0.6),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.tone.withValues(alpha: 0.35 * (1 - t)),
                    width: 2,
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: disc,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon ?? Icons.inbox_outlined, size: 60, color: context.tokens.hint),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
            ],
          ),
        ),
      );
}

class AppSnackbar {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    final bg = isError ? context.colors.error : context.tokens.success;
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: context.text.bodyMedium?.copyWith(color: Colors.white)),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  static void success(BuildContext context, String message) => show(context, message);
  static void error(BuildContext context, String message) => show(context, message, isError: true);
}
