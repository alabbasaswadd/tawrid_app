import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/realtime/conversation_hub.dart';
import 'package:tawrid_app/models/conversation_models.dart';
import 'package:tawrid_app/repositories/conversation_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

class ConversationChatPage extends ConsumerStatefulWidget {
  const ConversationChatPage({
    required this.conversationId,
    required this.title,
    required this.isWarehouse,
    super.key,
  });

  final String conversationId;
  final String title;
  final bool isWarehouse;

  @override
  ConsumerState<ConversationChatPage> createState() =>
      _ConversationChatPageState();
}

class _ConversationChatPageState extends ConsumerState<ConversationChatPage> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ConversationMessage>? _messages;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  StreamSubscription<IncomingMessage>? _liveSub;
  StreamSubscription<void>? _reconnectSub;

  ConversationRepository get _repo => widget.isWarehouse
      ? ref.read(whConversationRepositoryProvider)
      : ref.read(phConversationRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
    _listenLive();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _reconnectSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // البثّ الفوري يُلحق الرسائل الواردة بلا إعادة جلب. وإن انقطع الاتصال
  // ثم عاد، نُعيد الجلب كاملاً بدل محاولة تعويض ما فات أثناء الانقطاع.
  void _listenLive() {
    final hub = ref.read(conversationHubProvider);

    _liveSub = hub.messages.listen((event) {
      if (event.conversationId != widget.conversationId) return;
      _appendLive(event.message);
    });

    _reconnectSub = hub.onReconnected.listen((_) => _load());
  }

  void _appendLive(ConversationMessage message) {
    if (!mounted) return;

    final current = _messages ?? const <ConversationMessage>[];
    // الرسالة التي أرسلتُها تصل أيضاً عبر القناة (لتظهر على بقية أجهزتي)،
    // وقد تكون مضافة محلياً من ردّ الإرسال — المعرّف يمنع ازدواجها.
    if (current.any((m) => m.id == message.id)) return;

    setState(() => _messages = [...current, message]);
    _scrollToBottom();

    // وصلت ونحن داخل المحادثة ⇒ قُرئت. بلا هذا يبقى العدّاد منتفخاً.
    if (!message.isFromMe) {
      _repo.markRead(widget.conversationId).ignore();
    }
    invalidateUnreadConversations(ref, isWarehouse: widget.isWarehouse);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msgs = await _repo.getMessages(widget.conversationId);
      // تعليم كمقروء فور فتح المحادثة
      _repo.markRead(widget.conversationId).ignore();
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
      invalidateUnreadConversations(ref, isWarehouse: widget.isWarehouse);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _textCtrl.clear();
    try {
      final msg =
          await _repo.sendMessage(widget.conversationId, text);
      if (!mounted) return;
      // الخادم يبثّ الرسالة قبل أن يردّ على هذا الطلب، فقد تكون وصلت عبر
      // القناة أولاً — المعرّف يحسم الأمر بدل أن تظهر مرّتين.
      final current = _messages ?? const <ConversationMessage>[];
      if (!current.any((m) => m.id == msg.id)) {
        setState(() => _messages = [...current, msg]);
      }
      _scrollToBottom();
      invalidateUnreadConversations(ref, isWarehouse: widget.isWarehouse);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: InnerTopBar(title: widget.title),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm + bottomPad,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
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
                        borderSide:
                            BorderSide(color: cs.primary, width: 1.5),
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
  }

  Widget _buildMessages() {
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
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: msgs.length,
      itemBuilder: (_, i) => _MessageBubble(message: msgs[i]),
    );
  }
}

// ── فقاعة رسالة ──────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ConversationMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final isMe = message.isFromMe;

    final bubbleColor =
        isMe ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;
    final timeColor =
        isMe ? cs.onPrimary.withValues(alpha: 0.7) : tk.hint;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topRight: const Radius.circular(16),
            topLeft: const Radius.circular(16),
            bottomRight:
                isMe ? Radius.zero : const Radius.circular(16),
            bottomLeft:
                isMe ? const Radius.circular(16) : Radius.zero,
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
                  message.senderName,
                  style: context.text.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              message.content,
              style:
                  context.text.bodyMedium?.copyWith(color: textColor),
            ),
            const SizedBox(height: 2),
            Text(
              formatSmartTimestamp(message.createdAt),
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
