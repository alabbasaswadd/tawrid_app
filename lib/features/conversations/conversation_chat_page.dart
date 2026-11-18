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
    this.draft,
    super.key,
  });

  final String conversationId;
  final String title;
  final bool isWarehouse;

  /// نصّ يُعبَّأ في حقل الكتابة عند الفتح ولا يُرسَل.
  ///
  /// لا يُرسَل تلقائياً عمداً: الرسالة تُنسَب إلى المستخدم، فلا يصحّ أن
  /// يُرسِل التطبيق باسمه شيئاً لم يقرأه. ويبقى تعديله أو حذفه بيده.
  final String? draft;

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
    _textCtrl.text = widget.draft ?? '';
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

  /// يُرسل الرسالة — والفقاعة تظهر قبل أن يُلمَس الخادم.
  ///
  /// الانتظار كان هو سبب البطء لا المنفذ: الفقاعة لم تكن تُرسَم إلا بعد
  /// عودة الردّ، فكل تأخير شبكة يُرى فراغاً. الآن تُرسَم فوراً بعلامة
  /// «قيد الإرسال»، ويستبدلها ردّ الخادم بالمؤكَّدة.
  ///
  /// والإرسال عبر القناة القائمة: لا مصافحة ولا ترويسات ولا تحليل توكن
  /// لكل سطر. وREST احتياطٌ لا بديل — حين تكون القناة مغلقة (شبكة
  /// متعثّرة، أو خادم بلا Hub) تصل الرسالة على كل حال.
  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ConversationMessage.optimistic(
      localId: localId,
      content: text,
      senderName: '',
    );

    _textCtrl.clear();
    setState(() {
      _messages = [...(_messages ?? const []), optimistic];
      _sending = true;
    });
    _scrollToBottom();

    try {
      final sent = await _deliver(text);
      if (!mounted) return;
      _replaceLocal(localId, sent);
      invalidateUnreadConversations(ref, isWarehouse: widget.isWarehouse);
    } catch (e) {
      if (!mounted) return;
      // الفقاعة تبقى معلَّمة بالفشل لا تُمحى: نصٌّ يختفي بعد الضغط يُقرأ
      // إرسالاً ناجحاً، وهو أسوأ من فشلٍ ظاهر.
      setState(
        () => _messages = _messages
            ?.map(
              (m) => m.id == localId
                  ? m.copyWith(pending: false, failed: true)
                  : m,
            )
            .toList(),
      );
      AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// يوصل الرسالة: القناة أولاً، وREST إن تعذّرت.
  ///
  /// السقوط يشمل فشل الاستدعاء لا انقطاع القناة وحده — قناةٌ مفتوحة إلى
  /// خادم لا يعرف الطريقة كانت تُضيع الرسالة بدل أن تُوصلها.
  ///
  /// وتكرار رسالة أهون من ضياعها: الأولى يراها المستخدم ويحذفها، والثانية
  /// لا يعرف بها أصلاً. ومع ذلك لا يتكرّر الاحتمال إلا مرة — الحالة
  /// الوحيدة المعروفة (طريقة معدومة) تُطفئ المسار بعدها.
  Future<ConversationMessage> _deliver(String text) async {
    final hub = ref.read(conversationHubProvider);

    if (hub.canSend) {
      try {
        return await hub.sendMessage(widget.conversationId, text);
      } catch (_) {
        // يسقط إلى REST أدناه.
      }
    }

    return _repo.sendMessage(widget.conversationId, text);
  }

  /// يستبدل الفقاعة المحلّية بالمؤكَّدة — أو يحذفها إن سبقها البثّ.
  void _replaceLocal(String localId, ConversationMessage confirmed) {
    final current = _messages ?? const <ConversationMessage>[];

    // القناة قد تكون أوصلت المؤكَّدة قبل عودة الردّ (الخادم يبثّ ثم يردّ)
    // — عندها تُحذف المحلّية فقط بدل أن تتضاعف.
    final alreadyThere = current.any((m) => m.id == confirmed.id);

    setState(
      () => _messages = [
        for (final m in current)
          if (m.id != localId) m else if (!alreadyThere) confirmed,
      ],
    );
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

    // الفقاعة المعلَّقة أبهت: الفرق يُقرأ قبل قراءة الأيقونة.
    final bubbleColor = isMe
        ? (message.pending ? cs.primary.withValues(alpha: 0.72) : cs.primary)
        : cs.surfaceContainerHighest;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;
    final timeColor = isMe ? cs.onPrimary.withValues(alpha: 0.7) : tk.hint;

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
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
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
              style: context.text.bodyMedium?.copyWith(color: textColor),
            ),
            const SizedBox(height: 2),
            // الوقت ومعه حال الرسالة: ساعةٌ ما دامت في الطريق، وعلامةُ
            // تنبيه إن لم تصل — فيُقرأ المصير من الفقاعة نفسها لا من
            // شريط عابر يختفي.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.pending) ...[
                  Icon(Icons.schedule, size: 11, color: timeColor),
                  const SizedBox(width: 3),
                ] else if (message.failed) ...[
                  Icon(Icons.error_outline, size: 11, color: tk.danger),
                  const SizedBox(width: 3),
                ],
                Text(
                  message.failed
                      ? 'لم تُرسَل'
                      : formatSmartTimestamp(message.createdAt),
                  style: context.text.labelSmall?.copyWith(
                    color: message.failed ? tk.danger : timeColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
