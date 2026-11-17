import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/conversation_models.dart';
import 'package:tawrid_app/repositories/conversation_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({required this.isWarehouse, super.key});

  final bool isWarehouse;

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  List<Conversation> _conversations = const [];
  bool _loading = true;
  String? _error;

  ConversationRepository get _repo => widget.isWarehouse
      ? ref.read(whConversationRepositoryProvider)
      : ref.read(phConversationRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final convs = await _repo.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = convs;
        _loading = false;
      });
      invalidateUnreadConversations(ref, isWarehouse: widget.isWarehouse);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'المحادثات'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppListSkeleton(variant: SkeletonVariant.row, count: 7);
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_conversations.isEmpty) {
      return const EmptyState(
        message: 'لا توجد محادثات بعد',
        icon: Icons.chat_bubble_outline,
      );
    }

    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
      itemBuilder: (_, i) {
        final conv = _conversations[i];
        return _ConversationTile(
          conversation: conv,
          onTap: () => context.push(
            widget.isWarehouse
                ? TRoutes.whConversationDetail(conv.id, conv.otherPartyName)
                : TRoutes.phConversationDetail(conv.id, conv.otherPartyName),
          ),
        );
      },
    );
  }
}

// ── صف المحادثة ──────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    final isWh = conversation.otherPartyType == 'warehouse';
    final avatarColor = isWh ? cs.primary : cs.secondary;
    final initial = conversation.otherPartyName.isNotEmpty
        ? conversation.otherPartyName[0]
        : '؟';
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.xs,
      ),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: avatarColor.withValues(alpha: 0.14),
            child: Text(
              initial,
              style: context.text.titleMedium?.copyWith(color: avatarColor),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
              child: Icon(
                isWh
                    ? Icons.warehouse_outlined
                    : Icons.local_pharmacy_outlined,
                size: 8,
                color: cs.onPrimary,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        conversation.otherPartyName,
        style: context.text.titleSmall?.copyWith(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: conversation.lastMessageText != null
          ? Text(
              conversation.lastMessageText!,
              style: context.text.bodySmall?.copyWith(
                color: hasUnread ? cs.onSurface : tk.hint,
                fontWeight: hasUnread ? FontWeight.w500 : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatSmartTimestamp(conversation.updatedAt),
            style: context.text.labelSmall?.copyWith(
              color: hasUnread ? cs.primary : tk.hint,
            ),
          ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : '${conversation.unreadCount}',
                style: context.text.labelSmall?.copyWith(
                  color: cs.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
