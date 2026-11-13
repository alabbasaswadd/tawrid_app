import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// ورقة دردشة مباشرة بين الصيدلية والمستودع على طلبية بعينها.
// الرسائل تُعرض كفقاعات: الصيدلية على اليمين (بداية القراءة)،
// المستودع على اليسار. لا ردود متسلسلة — الواجهة بسيطة ومباشرة.
class OrderChatSheet extends StatefulWidget {
  const OrderChatSheet({
    required this.warehouseName,
    required this.loadMessages,
    required this.sendMessage,
    super.key,
  });

  final String warehouseName;
  final Future<List<OrderComment>> Function() loadMessages;
  final Future<void> Function(String content) sendMessage;

  static Future<void> show(
    BuildContext context, {
    required String warehouseName,
    required Future<List<OrderComment>> Function() loadMessages,
    required Future<void> Function(String content) sendMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => OrderChatSheet(
        warehouseName: warehouseName,
        loadMessages: loadMessages,
        sendMessage: sendMessage,
      ),
    );
  }

  @override
  State<OrderChatSheet> createState() => _OrderChatSheetState();
}

class _OrderChatSheetState extends State<OrderChatSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scrollCtrl = ScrollController();

  List<OrderComment>? _messages;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msgs = await widget.loadMessages();
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await widget.sendMessage(text);
      _ctrl.clear();
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, _) {
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── رأس الورقة ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xs),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outline,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          AppIcon(AppIcons.warehouse, size: 18, color: cs.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              widget.warehouseName,
                              style: context.text.titleSmall
                                  ?.copyWith(color: cs.primary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── قائمة الرسائل ────────────────────────────────────────
                Expanded(child: _buildMessages()),

                const Divider(height: 1),

                // ── حقل الإدخال ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.sm,
                    AppSpacing.sm, AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          textDirection: TextDirection.rtl,
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالة...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Material(
                        color: cs.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _sending ? null : _send,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: _sending
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.onPrimary,
                                      ),
                                    )
                                  : Icon(Icons.send_rounded,
                                      size: 18, color: cs.onPrimary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row, count: 4);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final msgs = _messages ?? [];
    if (msgs.isEmpty) {
      return const EmptyState(
        message: 'ابدأ المحادثة مع المستودع',
        icon: Icons.chat_bubble_outline,
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: msgs.length,
      itemBuilder: (_, i) => _ChatBubble(comment: msgs[i]),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.comment});
  final OrderComment comment;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final isMe = !comment.isWarehouse; // الصيدلية هي المستخدم الحالي

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: AppIcon(AppIcons.warehouse, size: 14, color: cs.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? cs.primary : tk.brandSurface,
                    borderRadius: BorderRadius.only(
                      topRight: const Radius.circular(AppRadius.lg),
                      topLeft: const Radius.circular(AppRadius.lg),
                      bottomRight: isMe
                          ? const Radius.circular(4.0)
                          : const Radius.circular(AppRadius.lg),
                      bottomLeft: isMe
                          ? const Radius.circular(AppRadius.lg)
                          : const Radius.circular(4.0),
                    ),
                  ),
                  child: Text(
                    comment.content,
                    style: context.text.bodySmall?.copyWith(
                      color: isMe ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatSmartTimestamp(comment.createdOn),
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.hint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: AppSpacing.xs),
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: AppIcon(AppIcons.user, size: 14, color: cs.primary),
            ),
          ],
        ],
      ),
    );
  }
}
