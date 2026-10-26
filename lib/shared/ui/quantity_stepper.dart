import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// منتقي الكمية (Figma: منتقي كمية): − | القيمة | + — أزرار ٣٦×٤٠ على سطح
// العلامة الفاتح، والقيمة في الوسط بعرض ٤٨.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.value,
    this.onIncrement,
    this.onDecrement,
    super.key,
  });

  final String value;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // ترتيب ثابت بصرياً: − يسار، + يمين (كما في التصميم).
        textDirection: TextDirection.ltr,
        children: [
          _StepButton(symbol: '−', onTap: onDecrement),
          SizedBox(
            width: 48,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
          ),
          _StepButton(symbol: '+', onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.symbol, required this.onTap});

  final String symbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return Material(
      color: t.brandSurfaceSubtle,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 40,
          child: Center(
            child: Text(
              symbol,
              style: context.text.labelLarge?.copyWith(color: cs.primary),
            ),
          ),
        ),
      ),
    );
  }
}
