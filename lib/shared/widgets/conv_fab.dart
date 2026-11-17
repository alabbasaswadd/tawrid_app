import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/repositories/conversation_repository.dart';

// زر الدردشة العائم — يظهر في كل شاشات القشرة ويحمل شارة بعدد الرسائل
// غير المقروءة. مستقل بـ ConsumerWidget حتى لا تتجدّد القشرة كلها عند
// تغيّر العدد.
class ConvFab extends ConsumerWidget {
  const ConvFab({required this.isWarehouse, required this.onTap, super.key});

  final bool isWarehouse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = isWarehouse
        ? ref.watch(whUnreadConversationsProvider).value ?? 0
        : ref.watch(phUnreadConversationsProvider).value ?? 0;

    final cs = context.colors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          heroTag: isWarehouse ? 'wh_conv_fab' : 'ph_conv_fab',
          onPressed: onTap,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 3,
          child: const Icon(Icons.chat_bubble_outline),
        ),
        if (unread > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: TextStyle(
                  color: cs.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
