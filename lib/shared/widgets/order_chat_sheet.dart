import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// ورقة محادثة مباشرة على طلبية بعينها — تعمل من منظور الصيدلية والمستودع.
//
// عند isWarehouseView = true  : رسائل المستودع على اليسار (أنا)، الصيدلية على اليمين.
// عند isWarehouseView = false : رسائل الصيدلية على اليمين (أنا)، المستودع على اليسار.
class OrderChatSheet extends StatefulWidget {
  const OrderChatSheet({
    required this.counterpartyName,
    required this.loadMessages,
    required this.sendMessage,
    this.isWarehouseView = false,
    super.key,
  });

  /// اسم الطرف الآخر في المحادثة (اسم الصيدلية من منظور المستودع، أو اسم المستودع من منظور الصيدلية).
  final String counterpartyName;

  /// true عند فتح الورقة من جانب المستودع.
  final bool isWarehouseView;

  final Future<List<OrderComment>> Function() loadMessages;
  final Future<void> Function(String content) sendMessage;

  static Future<void> show(
    BuildContext context, {
    required String counterpartyName,
    required Future<List<OrderComment>> Function() loadMessages,
    required Future<void> Function(String content) sendMessage,
    bool isWarehouseView = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => OrderChatSheet(
        counterpartyName: counterpartyName,
        loadMessages: loadMessages,
        sendMessage: sendMessage,
        isWarehouseView: isWarehouseView,
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
                          AppIcon(
                            widget.isWarehouseView ? AppIcons.user : AppIcons.warehouse,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              widget.counterpartyName.isNotEmpty
                                  ? widget.counterpartyName
                                  : (widget.isWarehouseView ? 'الصيدلية' : 'المستودع'),
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
      return EmptyState(
        message: widget.isWarehouseView
            ? 'ابدأ المحادثة مع الصيدلية'
            : 'ابدأ المحادثة مع المستودع',
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
      itemBuilder: (_, i) => _ChatBubble(
        comment: msgs[i],
        isWarehouseView: widget.isWarehouseView,
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.comment, required this.isWarehouseView});

  final OrderComment comment;

  /// true = نحن المستودع: رسائل المستودع على اليسار، الصيدلية على اليمين.
  final bool isWarehouseView;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    // isMe = true عندما تكون الرسالة من الطرف الذي يشاهد الشاشة.
    final isMe = isWarehouseView ? comment.isWarehouse : !comment.isWarehouse;
    final showName = !isMe && comment.authorName.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: AppIcon(
                isWarehouseView ? AppIcons.warehouse : AppIcons.user,
                size: 14,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      comment.authorName,
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.hint,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? tk.brandSurface : cs.primary,
                    borderRadius: BorderRadius.only(
                      topRight: const Radius.circular(AppRadius.lg),
                      topLeft: const Radius.circular(AppRadius.lg),
                      bottomLeft: isMe
                          ? const Radius.circular(4.0)
                          : const Radius.circular(AppRadius.lg),
                      bottomRight: isMe
                          ? const Radius.circular(AppRadius.lg)
                          : const Radius.circular(4.0),
                    ),
                  ),
                  child: Text(
                    comment.content,
                    style: context.text.bodySmall?.copyWith(
                      color: isMe ? cs.onSurface : cs.onPrimary,
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
          if (!isMe) ...[
            const SizedBox(width: AppSpacing.xs),
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: AppIcon(
                isWarehouseView ? AppIcons.user : AppIcons.warehouse,
                size: 14,
                color: cs.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
