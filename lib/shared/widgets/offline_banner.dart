import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/connectivity_state.dart';

/// شريط «لا اتصال» فوق التطبيق كلّه.
///
/// معروضٌ مرّة واحدة في جذر الشجرة لا في كل شاشة: الانقطاع حالةُ تطبيقٍ
/// لا حالةُ صفحة، وتكراره في كل شاشة يعني نسيانه في بعضها.
///
/// وفوق المحتوى لا داخله — [Overlay] على ارتفاع شريط الحالة — كي لا
/// يُزيح الصفحةَ تحته فيقفز ما يقرؤه المستخدم كلما تذبذبت الشبكة.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: ServerReachability.unreachable,
            builder: (context, offline, _) => AnimatedSlide(
              // ينزلق لا يُومض: الظهور المفاجئ يُقرأ عطلاً في الواجهة،
              // والانزلاق يقول إن شيئاً طرأ الآن.
              offset: offline ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: offline ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const _Bar(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        color: tk.danger,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          MediaQuery.of(context).padding.top + AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'لا اتصال بالإنترنت',
              style: context.text.labelSmall?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
