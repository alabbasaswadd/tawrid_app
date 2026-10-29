import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// زر السلّة (Figma: زر السلة) — أيقونة دائرية ٤٠×٤٠ وشارة عدّ في طرفها
// العلوي عند وجود أصناف. يُستخدم في الشريط العلوي للرئيسية وبحث الأسعار.
class CartButton extends StatelessWidget {
  const CartButton({required this.count, this.onTap, super.key});

  /// عدد أصناف السلّة — صفر يُخفي الشارة ولا يُخفي الزر.
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: cs.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: AppIcon(
                  AppIcons.shoppingCart,
                  size: 20,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ),
        if (count > 0)
          PositionedDirectional(
            // الشارة في بداية القراءة أعلى الأيقونة — كما في لقطة Figma.
            start: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: count > 9 ? BorderRadius.circular(9) : null,
              ),
              child: Center(
                child: Text(
                  count > 99 ? '٩٩+' : '$count',
                  style: context.text.labelSmall?.copyWith(
                    color: cs.onPrimary,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
