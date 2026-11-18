import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/notifications/message_notifications.dart';
import 'package:tawrid_app/core/notifications/push_service.dart';
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
    this.otherPartyId,
    this.otherPartyType,
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

  /// هوية الطرف الآخر — تجعل اسمه في الرأس مدخلاً إلى ملفه.
  /// تغيب حين تُفتح المحادثة من إشعار، فالإشعار يحمل الاسم لا المعرّف.
  final String? otherPartyId;
  final String? otherPartyType;

  @override
  ConsumerState<ConversationChatPage> createState() =>
      _ConversationChatPageState();
}

class _ConversationChatPageState extends ConsumerState<ConversationChatPage> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  /// تركيز حقل الكتابة — يُعاد طلبه بعد كل إرسال.
  ///
  /// زرّ الإرسال يسحب التركيز إليه، وزرّ «إرسال» في لوحة المفاتيح يُغلقها
  /// بعد onSubmitted. وكلاهما يقطع تتابع الكتابة: من يُرسل رسالة غالباً
  /// يُرسل تاليتها.
  final _inputFocus = FocusNode();
  List<ConversationMessage>? _messages;
  bool _loading = true;
  String? _error;

  StreamSubscription<IncomingMessage>? _liveSub;
  StreamSubscription<void>? _reconnectSub;

  /// حجم الدفعة — ما يملأ شاشتين تقريباً، فلا يُطلب التالي فور الفتح.
  static const _pageSize = 25;

  /// مُهلة تجميع «تعليم كمقروء».
  ///
  /// كان يُرسَل عند كل رسالة واردة: محادثة نشطة بعشر رسائل عشرة طلبات
  /// تقول الشيء نفسه. الطلب واحد يشمل ما وصل خلال المهلة.
  Timer? _markReadTimer;
  static const _markReadDelay = Duration(seconds: 2);

  /// هل بقي أقدم مما حُمّل؟ دفعةٌ أقصر من المطلوب تعني أننا بلغنا البداية.
  bool _hasOlder = true;
  bool _loadingOlder = false;

  /// هل ابتعد القارئ عن الأسفل بما يكفي ليُعرض زرّ العودة؟
  bool _showJumpToBottom = false;

  /// الرسالة التي يجري الردّ عليها — تُعرَض فوق حقل الكتابة.
  ConversationMessage? _replyingTo;

  ConversationRepository get _repo => widget.isWarehouse
      ? ref.read(whConversationRepositoryProvider)
      : ref.read(phConversationRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _textCtrl.text = widget.draft ?? '';

    // المحادثة أمام المستخدم: لا إشعار لرسائلها، ويُمحى ما تراكم منها في
    // شريط النظام — إشعارٌ برسالة يراها بعينه إزعاجٌ لا خدمة.
    ref.read(pushServiceProvider).setOpenConversation(widget.conversationId);
    MessageNotifications.clear(widget.conversationId).ignore();

    _scrollCtrl.addListener(_onScroll);
    _load();
    _listenLive();
  }

  // قرب القمة لا عندها: التحميل يبدأ قبل أن يصطدم المستخدم بالحافة،
  // فلا يرى فراغاً ينتظره.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;

    final position = _scrollCtrl.position;

    // ارتفاع شاشة كامل تقريباً: أقلّ منه والقارئ ما زال قرب الأحدث،
    // فالزرّ يحجب رسالةً بلا داعٍ.
    final far = position.maxScrollExtent - position.pixels > 600;
    if (far != _showJumpToBottom) setState(() => _showJumpToBottom = far);

    if (position.pixels <= 200) _loadOlder();
  }

  /// يجلب الدفعة الأسبق ويُقدّمها، مع تثبيت موضع القراءة.
  ///
  /// بلا التثبيت تقفز الشاشة: إضافة رسائل فوق المعروض تدفعه للأسفل بقدر
  /// ارتفاعها، فيفقد المستخدم السطر الذي كان يقرأه.
  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasOlder) return;

    final current = _messages;
    if (current == null || current.isEmpty) return;

    setState(() => _loadingOlder = true);
    final before = current.first.createdAt;
    final extentBefore = _scrollCtrl.position.maxScrollExtent;

    try {
      final older = await _repo.getMessages(
        widget.conversationId,
        before: before,
        take: _pageSize,
      );
      if (!mounted) return;

      setState(() {
        _hasOlder = older.length == _pageSize;
        if (older.isNotEmpty) _messages = [...older, ...current];
        _loadingOlder = false;
      });

      if (older.isEmpty) return;

      // بعد الرسم: الارتفاع الجديد لا يُعرف قبل أن تُبنى الفقاعات.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollCtrl.hasClients) return;
        final grew = _scrollCtrl.position.maxScrollExtent - extentBefore;
        if (grew > 0) _scrollCtrl.jumpTo(_scrollCtrl.position.pixels + grew);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOlder = false);
      AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  @override
  void dispose() {
    ref.read(pushServiceProvider).setOpenConversation(null);
    _liveSub?.cancel();
    _reconnectSub?.cancel();
    _markReadTimer?.cancel();
    _inputFocus.dispose();
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
    // وصلت مرّتين (القناة وردّ الإرسال) — المعرّف يحسمها.
    if (current.any((m) => m.id == message.id)) return;

    // رسالتي تعود إليّ عبر القناة لتظهر على بقية أجهزتي، وفقاعتها
    // المحلّية ما زالت معلَّقة هنا. تُستبدل في مكانها لا تُضاف تحتها:
    // الإضافة كانت تُظهرها مرّتين لجزء من ثانية ثم تُحذف إحداهما —
    // وهو الارتعاش الذي يُرى «اختفت ثم ظهرت».
    final pendingIndex = _indexOfPendingLike(current, message);
    if (pendingIndex != -1) {
      final next = [...current]..[pendingIndex] = message;
      setState(() => _messages = next);
      return;
    }

    setState(() => _messages = [...current, message]);
    _scrollToBottom();

    // وصلت ونحن داخل المحادثة ⇒ قُرئت. بلا هذا يبقى العدّاد منتفخاً.
    //
    // والإنقاص محلّي بواحد: العدّاد زاد بواحد لتوّه من الحدث نفسه، فلا
    // داعي لسؤال الخادم عن رقمٍ نعرفه.
    if (!message.isFromMe) {
      _scheduleMarkRead();
      reduceUnreadConversations(
        ref,
        isWarehouse: widget.isWarehouse,
        readCount: 1,
      );
    }
  }

  /// يبدأ الردّ على رسالة — من السحب عليها.
  void _startReply(ConversationMessage message) {
    setState(() => _replyingTo = message);
    _inputFocus.requestFocus();
  }

  /// ينسخ نصّ الرسالة — من الضغط المطوّل.
  ///
  /// مباشرةً بلا ورقة خيارات: بقي إجراءٌ واحد بعد أن انتقل الردّ إلى
  /// السحب، وورقةٌ بخيار واحد خطوةٌ زائدة.
  Future<void> _copyMessage(ConversationMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (mounted) AppSnackbar.success(context, 'نُسخ النصّ');
  }

  void _scheduleMarkRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(_markReadDelay, () {
      if (!mounted) return;
      _repo.markRead(widget.conversationId).ignore();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msgs = await _repo.getMessages(
        widget.conversationId,
        take: _pageSize,
      );
      // تعليم كمقروء فور فتح المحادثة
      _repo.markRead(widget.conversationId).ignore();
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        // دفعةٌ أقصر من المطلوبة تعني أن المحادثة كلها هنا.
        _hasOlder = msgs.length == _pageSize;
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
  /// بلا قفل للزرّ ولا دوّارة: كل إرسال مستقلّ بنفسه، فيكتب المستخدم
  /// رسالتين متتابعتين كما يفعل في أي تطبيق مراسلة. حال كل رسالة
  /// مكتوبة على فقاعتها لا على الزرّ.
  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final replyTo = _replyingTo;
    _textCtrl.clear();

    // التركيز يُستردّ فوراً لا بعد ردّ الخادم: الإرسال لا ينتظره أصلاً،
    // وتأخيرُ التركيز يُغلق لوحة المفاتيح لجزء من ثانية ثم يفتحها.
    _inputFocus.requestFocus();

    setState(
      () => _messages = [
        ...(_messages ?? const []),
        ConversationMessage.optimistic(
          localId: localId,
          content: text,
          senderName: '',
          replyTo: replyTo == null
              ? null
              : ReplyPreview(
                  id: replyTo.id,
                  senderName: replyTo.senderName,
                  content: replyTo.content,
                ),
        ),
      ],
    );
    // يُلغى فور الإرسال لا بعد التأكيد: الشريط باقياً بعد الضغط يوهم
    // أن الردّ لم يُرسَل.
    if (replyTo != null) setState(() => _replyingTo = null);
    _scrollToBottom();

    try {
      final sent = await _deliver(text, replyToId: replyTo?.id);
      if (!mounted) return;
      _confirm(localId, sent);
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
    }
  }

  /// يُعيد إرسال رسالة فشلت — بنصّها كما هو.
  ///
  /// بلا هذا كانت الفقاعة الفاشلة طريقاً مسدوداً: تقول «لم تُرسَل» ولا
  /// تقبل شيئاً، فيُعيد المستخدم كتابتها من الصفر.
  Future<void> _retry(ConversationMessage failed) async {
    setState(
      () => _messages = _messages
          ?.map(
            (m) => m.id == failed.id
                ? m.copyWith(pending: true, failed: false)
                : m,
          )
          .toList(),
    );

    try {
      final sent = await _deliver(
        failed.content,
        replyToId: failed.replyTo?.id,
      );
      if (!mounted) return;
      _confirm(failed.id, sent);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _messages = _messages
            ?.map(
              (m) => m.id == failed.id
                  ? m.copyWith(pending: false, failed: true)
                  : m,
            )
            .toList(),
      );
      AppSnackbar.error(context, ApiException.from(e).message);
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
  Future<ConversationMessage> _deliver(String text, {String? replyToId}) async {
    final hub = ref.read(conversationHubProvider);

    if (hub.canSend) {
      try {
        return await hub.sendMessage(
          widget.conversationId,
          text,
          replyToMessageId: replyToId,
        );
      } catch (_) {
        // يسقط إلى REST أدناه.
      }
    }

    return _repo.sendMessage(
      widget.conversationId,
      text,
      replyToMessageId: replyToId,
    );
  }

  /// يُثبّت الفقاعة المحلّية بنسختها المؤكَّدة — في موضعها نفسه.
  ///
  /// الاستبدال في المكان لا حذفٌ ثم إضافة: الثاني يُحرّك القائمة ويُرى
  /// قفزة. وإن كان البثّ قد ثبّتها قبل عودة الردّ، تُحذف المحلّية فقط.
  void _confirm(String localId, ConversationMessage confirmed) {
    final current = _messages ?? const <ConversationMessage>[];
    final index = current.indexWhere((m) => m.id == localId);
    if (index == -1) return;

    final alreadyConfirmed = current.any((m) => m.id == confirmed.id);

    setState(() {
      final next = [...current];
      if (alreadyConfirmed) {
        next.removeAt(index);
      } else {
        next[index] = confirmed;
      }
      _messages = next;
    });
  }

  /// موضع فقاعة معلَّقة تُقابل رسالةً عائدة من الخادم.
  ///
  /// المطابقة بالنصّ لأن المعرّف المحلّي لا يعرفه الخادم. ويُبحث من
  /// الآخر: رسالتان متطابقتان نصّاً تُثبَّت أحدثُهما المعلَّقة أولاً.
  static int _indexOfPendingLike(
    List<ConversationMessage> messages,
    ConversationMessage incoming,
  ) {
    if (!incoming.isFromMe) return -1;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.pending && m.content == incoming.content) return i;
    }
    return -1;
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

    // ملف المستودع متاح للصيدلية وحدها — لا شاشة مقابلة تعرض صيدلية
    // للمستودع، فالعنوان يبقى نصّاً عنده.
    final opensProfile =
        !widget.isWarehouse &&
        widget.otherPartyType == 'warehouse' &&
        (widget.otherPartyId?.isNotEmpty ?? false);

    return Scaffold(
      appBar: InnerTopBar(
        title: widget.title,
        subtitle: switch (widget.otherPartyType) {
          'warehouse' => 'مستودع',
          'pharmacy' => 'صيدلية',
          _ => null,
        },
        onTitleTap: opensProfile
            ? () =>
                  context.push(TRoutes.phWarehouseProfile(widget.otherPartyId!))
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildMessages()),
                // يظهر حين يبتعد القارئ — ومع الترقيم صار الابتعاد أعمق،
                // فالعودة بالسحب وحدها تُرهق.
                if (_showJumpToBottom)
                  PositionedDirectional(
                    end: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: _JumpToBottomButton(onTap: _scrollToBottom),
                  ),
              ],
            ),
          ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingTo case final replying?)
                  _ReplyComposerBar(
                    message: replying,
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        focusNode: _inputFocus,
                        textInputAction: TextInputAction.send,
                        // لوحة المفاتيح تبقى بعد الإرسال: onSubmitted يُغلقها
                        // افتراضياً، وطلب التركيز داخل _send يُبقيها.
                        onSubmitted: (_) => _send(),
                        // رسالة طويلة تلتفّ فينمو الحقل إلى خمسة أسطر ثم
                        // يُمرَّر داخله بدل أن يبتلع الشاشة.
                        //
                        // بلا keyboardType: multiline عمداً — يُحوّل مفتاح
                        // الإدخال إلى سطر جديد فيُفقد زرّ الإرسال من اللوحة.
                        minLines: 1,
                        maxLines: 5,
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
                            borderSide: BorderSide(
                              color: cs.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // الزرّ لا يُقفَل ولا يحمل دوّارة: حال كل رسالة مكتوبة على
                    // فقاعتها. وقفلُه كان يمنع كتابة رسالة ثانية قبل وصول
                    // الأولى — وهو ما لا يفعله أي تطبيق مراسلة.
                    IconButton.filled(
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

    final rows = _withDateSeparators(msgs);

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      // عنصر إضافي في الأعلى حين يجري جلب الأسبق.
      itemCount: rows.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (_, i) {
        if (_loadingOlder && i == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final row = rows[i - (_loadingOlder ? 1 : 0)];
        return switch (row) {
          _DateRow(:final day) => _DateSeparator(day: day),
          _MessageRow(:final message) => _MessageBubble(
            message: message,
            onRetry: message.failed ? () => _retry(message) : null,
            // المعلَّقة لا رَدَّ عليها: لا معرّف لها في الخادم بعد.
            onReply: message.pending || message.failed
                ? null
                : () => _startReply(message),
            onLongPress: () => _copyMessage(message),
          ),
        };
      },
    );
  }

  /// يُدخل فاصل تاريخ قبل أول رسالة من كل يوم.
  ///
  /// بلا الفواصل تبدو مئة رسالة خيطاً واحداً متصلاً: الوقت على الفقاعة
  /// يقول الساعة ولا يقول أيّ يوم، فرسالة أمس ورسالة اليوم سواء.
  static List<_ChatRow> _withDateSeparators(List<ConversationMessage> msgs) {
    final rows = <_ChatRow>[];
    DateTime? lastDay;

    for (final m in msgs) {
      final day = DateTime(
        m.createdAt.year,
        m.createdAt.month,
        m.createdAt.day,
      );
      if (lastDay == null || day != lastDay) {
        rows.add(_DateRow(day));
        lastDay = day;
      }
      rows.add(_MessageRow(m));
    }

    return rows;
  }
}

// ── صفوف القائمة ─────────────────────────────────────────────────────────
sealed class _ChatRow {
  const _ChatRow();
}

class _DateRow extends _ChatRow {
  const _DateRow(this.day);
  final DateTime day;
}

class _MessageRow extends _ChatRow {
  const _MessageRow(this.message);
  final ConversationMessage message;
}

// فاصل يوم: «اليوم» و«أمس» بالاسم، وما قبلهما بالتاريخ — الاسم أسرع
// قراءةً، والتاريخ أدقّ حين يبعد اليوم.
class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.day});

  final DateTime day;

  static const _months = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff < 7) return _weekday(day.weekday);

    // السنة تُذكر لما تجاوزها فقط — ذكرها دائماً حشو.
    final base = '${day.day} ${_months[day.month - 1]}';
    return day.year == now.year ? base : '$base ${day.year}';
  }

  static String _weekday(int w) => switch (w) {
    DateTime.saturday => 'السبت',
    DateTime.sunday => 'الأحد',
    DateTime.monday => 'الاثنين',
    DateTime.tuesday => 'الثلاثاء',
    DateTime.wednesday => 'الأربعاء',
    DateTime.thursday => 'الخميس',
    _ => 'الجمعة',
  };

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            _label(),
            style: context.text.labelSmall?.copyWith(color: tk.hint),
          ),
        ),
      ),
    );
  }
}

// ── فقاعة رسالة ──────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onRetry,
    this.onReply,
    this.onLongPress,
  });

  final ConversationMessage message;

  /// يُمرَّر للفقاعة الفاشلة وحدها — الضغط يُعيد إرسالها.
  final VoidCallback? onRetry;

  /// السحب يبدأ الردّ — للمؤكَّدة وحدها.
  final VoidCallback? onReply;

  /// الضغط المطوّل ينسخ النصّ.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final isMe = message.isFromMe;

    final bubbleColor = isMe ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;
    final timeColor = isMe ? cs.onPrimary.withValues(alpha: 0.7) : tk.hint;

    final bubble = Container(
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
          if (message.replyTo case final quoted?) ...[
            _QuotedMessage(reply: quoted, onMine: isMe),
            const SizedBox(height: 6),
          ],
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
                AppIcon(AppIcons.clock, size: 11, color: timeColor),
                const SizedBox(width: 3),
              ] else if (message.failed) ...[
                AppIcon(AppIcons.alertTriangle, size: 11, color: tk.danger),
                const SizedBox(width: 3),
              ],
              Text(
                message.failed
                    ? 'لم تُرسَل — اضغط للإعادة'
                    : formatSmartTimestamp(message.createdAt),
                style: context.text.labelSmall?.copyWith(
                  color: message.failed ? tk.danger : timeColor,
                ),
              ),
              // علامتا الإيصال على رسائلي وحدها: علامةٌ على رسالة الآخر
              // تقول «قرأتُها» — وهو يعرف ذلك ولا ينتظر إخباري به.
              if (isMe && !message.pending && !message.failed) ...[
                const SizedBox(width: 4),
                _ReadTicks(read: message.isReadByOther, color: timeColor),
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      // الفقاعة الفاشلة وحدها تستجيب للضغط: جعلُ كل فقاعة قابلة للضغط
      // بلا فعلٍ يُربك — أثرُ ضغطٍ لا يتبعه شيء.
      child: _SwipeToReply(
        enabled: onReply != null,
        messageKey: message.id,
        onReply: onReply,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onRetry,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: bubble,
          ),
        ),
      ),
    );
  }
}

// زرّ العودة إلى آخر الرسائل.
class _JumpToBottomButton extends StatelessWidget {
  const _JumpToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Material(
      color: cs.surface,
      shape: CircleBorder(side: BorderSide(color: cs.outline)),
      elevation: 2,
      shadowColor: tk.hint,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AppIcon(AppIcons.chevronDown, size: 20, color: cs.onSurface),
          ),
        ),
      ),
    );
  }
}

// شريط الردّ فوق حقل الكتابة: يقول على ماذا تردّ، ويسمح بالتراجع.
class _ReplyComposerBar extends StatelessWidget {
  const _ReplyComposerBar({required this.message, required this.onCancel});

  final ConversationMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        // شريط لوني في بداية القراءة — نفس ما يميّز الاقتباس في الفقاعة،
        // فيُقرأ الاثنان شيئاً واحداً.
        border: BorderDirectional(
          start: BorderSide(color: cs.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ردّ على ${message.isFromMe ? 'رسالتك' : message.senderName}',
                  style: context.text.labelSmall?.copyWith(color: cs.primary),
                ),
                Text(
                  message.content,
                  style: context.text.bodySmall?.copyWith(color: tk.hint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: AppIcon(AppIcons.x, size: 16, color: tk.hint),
            onPressed: onCancel,
            tooltip: 'إلغاء الردّ',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// الاقتباس داخل الفقاعة: مقتطف الأصل فوق نصّ الردّ.
class _QuotedMessage extends StatelessWidget {
  const _QuotedMessage({required this.reply, required this.onMine});

  final ReplyPreview reply;

  /// فقاعتي داكنة وفقاعة الآخر فاتحة — والاقتباس يتبع أرضيّته لا لوناً
  /// ثابتاً، وإلا اختفى على إحداهما.
  final bool onMine;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    final accent = onMine ? cs.onPrimary : cs.primary;
    final faded = onMine ? cs.onPrimary.withValues(alpha: 0.75) : tk.hint;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: (onMine ? cs.onPrimary : cs.onSurface).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: BorderDirectional(start: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reply.senderName,
            style: context.text.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            reply.content,
            style: context.text.bodySmall?.copyWith(color: faded),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// علامتا الإيصال: واحدة لما وصل الخادم، واثنتان لما قرأه الطرف الآخر.
//
// المقروءة أوضح لوناً لا أكبر حجماً: تغيّر الحجم يُزحزح سطر الوقت كلّه
// كلّما تبدّلت الحالة.
class _ReadTicks extends StatelessWidget {
  const _ReadTicks({required this.read, required this.color});

  final bool read;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tint = read ? color : color.withValues(alpha: 0.6);

    return SizedBox(
      width: read ? 15 : 10,
      height: 11,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            child: AppIcon(AppIcons.check, size: 11, color: tint),
          ),
          if (read)
            Positioned(
              right: 5,
              child: AppIcon(AppIcons.check, size: 11, color: tint),
            ),
        ],
      ),
    );
  }
}

// السحب للردّ.
//
// Dismissible بـ confirmDismiss يُرجع false: يعطي الحركة والارتداد
// مجاناً ويمنع اختفاء الرسالة — فالسحب هنا إيماءةٌ لا حذف.
//
// والاتجاه startToEnd يتبع اتجاه القراءة: في واجهة عربية يعني السحب من
// اليمين، فتوافق الإيماءةُ الحسَّ لا تخالفه.
class _SwipeToReply extends StatelessWidget {
  const _SwipeToReply({
    required this.child,
    required this.enabled,
    required this.messageKey,
    this.onReply,
  });

  final Widget child;
  final bool enabled;
  final String messageKey;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final cs = context.colors;

    return Dismissible(
      key: ValueKey('swipe_$messageKey'),
      direction: DismissDirection.startToEnd,
      // ربع العرض: أقلّ منه تنطلق الإيماءة بأي لمسة مائلة أثناء التمرير.
      dismissThresholds: const {DismissDirection.startToEnd: 0.25},
      confirmDismiss: (_) async {
        onReply?.call();
        return false;
      },
      background: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.md),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Icon(Icons.reply, size: 18, color: cs.primary),
        ),
      ),
      child: child,
    );
  }
}
