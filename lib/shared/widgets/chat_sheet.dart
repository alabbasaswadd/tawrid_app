import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

/// ورقة دردشة عامة — واجهة رسائل بفقاعات تُعاد استخدامها لأي محادثة
/// (تعليقات على عرض، رسائل طلبية، ...).
///
/// [currentUserType]: 'warehouse' أو 'pharmacy' — يحدّد أيّ جانب "أنا".
class ChatSheet extends StatefulWidget {
  const ChatSheet({
    required this.title,
    required this.currentUserType,
    required this.loadMessages,
    required this.sendMessage,
    super.key,
  });

  final String title;
  final String currentUserType;
  final Future<List<OfferComment>> Function() loadMessages;
  final Future<OfferComment> Function(String content) sendMessage;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String currentUserType,
    required Future<List<OfferComment>> Function() loadMessages,
    required Future<OfferComment> Function(String content) sendMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChatSheet(
        title: title,
        currentUserType: currentUserType,
        loadMessages: loadMessages,
        sendMessage: sendMessage,
      ),
    );
  }

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<OfferComment>? _messages;
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.loadMessages();
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      final msg = await widget.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages = [...(_messages ?? []), msg];
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMe(OfferComment msg) {
    return msg.authorType ==
        (widget.currentUserType == 'warehouse'
            ? CommentAuthorType.warehouse
            : CommentAuthorType.pharmacy);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // ─── Header ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: context.text.titleMedium,
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              // ─── Message list ──────────────────────────────────────
              Expanded(child: _buildBody()),
              // ─── Input bar ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالة...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: cs.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _sending
                        ? const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton.filled(
                            icon: const Icon(Icons.send, size: 18),
                            onPressed: _send,
                            style: IconButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppListSkeleton(variant: SkeletonVariant.row, count: 5);
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final msgs = _messages ?? [];
    if (msgs.isEmpty) {
      return const EmptyState(
        message: 'لا توجد رسائل بعد\nابدأ المحادثة الآن',
        icon: Icons.chat_bubble_outline,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount: msgs.length,
      itemBuilder: (context, i) => _MessageBubble(
        message: msgs[i],
        isMe: _isMe(msgs[i]),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final OfferComment message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    final bubbleColor = isMe ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;
    final timeColor = isMe
        ? cs.onPrimary.withValues(alpha: 0.7)
        : tk.hint;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topRight: const Radius.circular(16),
            topLeft: const Radius.circular(16),
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.authorName,
                  style: context.text.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(message.content,
                style: context.text.bodyMedium?.copyWith(color: textColor)),
            const SizedBox(height: 2),
            Text(
              formatSmartTimestamp(message.createdOn),
              style: context.text.labelSmall?.copyWith(
                color: timeColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
