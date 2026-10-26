import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/repositories/notification_repository.dart';

// زر الجرس في الشريط العلوي مع شارة غير المقروء. العدّاد يُقرأ من مزوّد
// مستقلّ تُبطله شاشة الإشعارات بعد القراءة، فلا حاجة لتمرير العدد يدوياً.
// فشل جلب العدّاد لا يُظهر خطأً: الجرس يبقى بلا شارة — عدد غير متاح ليس
// سبباً لإزعاج المستخدم في شاشة أخرى.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({required this.isWarehouse, super.key});

  final bool isWarehouse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
            .watch(isWarehouse ? whUnreadCountProvider : phUnreadCountProvider)
            .value ??
        0;

    return IconButton(
      tooltip: 'الإشعارات',
      onPressed: () => context.push(
          isWarehouse ? TRoutes.whNotifications : TRoutes.phNotifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (count > 0)
            PositionedDirectional(
              end: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: context.tokens.danger,
                  borderRadius: BorderRadius.circular(999),
                  // حدّ بلون الشريط حتى تنفصل الشارة عن الأيقونة تحتها
                  border: Border.all(color: context.colors.surface, width: 1.5),
                ),
                child: Text(
                  count > 99 ? '٩٩+' : '$count',
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
