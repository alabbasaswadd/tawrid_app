import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/app/theme/font_scale_provider.dart';

// ورقة اختيار حجم الخط — تُعرض من صفحة «حسابي» للجانبين.
// كل خيار يُظهر نصّاً تجريبياً مقيَّساً بمستواه ليرى المستخدم الفرق قبل الاختيار.
void showFontScaleSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (_, innerRef, _) {
        final current = innerRef.watch(fontScaleProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.sm),
                  child: Text('حجم الخط', style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final level in FontScaleLevel.values)
                  _FontScaleTile(
                    level: level,
                    selected: current == level,
                    onTap: () {
                      innerRef.read(fontScaleProvider.notifier).setLevel(level);
                      Navigator.pop(ctx);
                    },
                  ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _FontScaleTile extends StatelessWidget {
  const _FontScaleTile({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final FontScaleLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page, vertical: AppSpacing.sm),
        child: Row(
          children: [
            // علامة التحديد
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? cs.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? cs.primary : cs.outline,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            // اسم المستوى
            Text(
              level.label,
              style: context.text.bodyMedium?.copyWith(
                color: selected ? cs.primary : null,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            // نص تجريبي بمقياس هذا المستوى تحديداً
            Expanded(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(level.factor),
                ),
                child: Text(
                  'أبجد هوّز ١٢٣',
                  style: context.text.bodySmall?.copyWith(color: tk.hint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
