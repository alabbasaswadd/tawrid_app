import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';
import 'package:tawrid_app/repositories/ph_listing_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

// محادثة الحجز بين صيدليتين.
// الرسائل تُحذف تلقائياً من الخادم بعد 6 ساعات من إرسالها.
// تُحمَّل عند الفتح وتُحدَّث كل 15 ثانية (polling بسيط بدل WebSocket).
class PhListingChatPage extends ConsumerStatefulWidget {
  const PhListingChatPage({
    required this.listingId,
    required this.bookingId,
    super.key,
  });

  final String listingId;
  final String bookingId;

  @override
  ConsumerState<PhListingChatPage> createState() => _PhListingChatPageState();
}

class _PhListingChatPageState extends ConsumerState<PhListingChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<PhListingMessage> _messages = const [];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadSilent());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msgs = await ref.read(phListingRepositoryProvider).getMessages(
            widget.listingId,
            widget.bookingId,
          );
      if (!mounted) return;
      setState(() {
        _messages = msgs;
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

  Future<void> _loadSilent() async {
    try {
      final msgs = await ref.read(phListingRepositoryProvider).getMessages(
            widget.listingId,
            widget.bookingId,
          );
      if (!mounted) return;
      final hadNew = msgs.length > _messages.length;
      setState(() => _messages = msgs);
      if (hadNew) _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _send() async {
    final content = _msgCtrl.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      final msg = await ref
          .read(phListingRepositoryProvider)
          .sendMessage(widget.listingId, widget.bookingId, content);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _msgCtrl.text = content;
      });
    }
  }

  void _scrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Scaffold(
      appBar: const InnerTopBar(title: 'المحادثة'),
      body: Column(
        children: [
          // ── إشعار الحذف التلقائي ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            color: tk.warningSurface,
            child: Row(
              children: [
                AppIcon(AppIcons.clock, size: 14, color: tk.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'تُحذف الرسائل تلقائياً بعد ٦ ساعات من إرسالها.',
                    style: context.text.labelSmall
                        ?.copyWith(color: tk.warning),
                  ),
                ),
              ],
            ),
          ),

          // ── قائمة الرسائل ────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: context.text.bodySmall
                                    ?.copyWith(color: tk.danger)),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              label: 'إعادة المحاولة',
                              variant: AppButtonVariant.tonal,
                              onPressed: _load,
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'لا رسائل بعد — ابدأ المحادثة',
                              style: context.text.bodySmall
                                  ?.copyWith(color: tk.hint),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.sm,
                              AppSpacing.md,
                              AppSpacing.sm,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) =>
                                _MessageBubble(message: _messages[i]),
                          ),
          ),

          // ── حقل الكتابة ───────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm +
                  MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: tk.navShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      hintStyle: context.text.bodySmall
                          ?.copyWith(color: tk.hint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SendButton(onTap: _send, loading: _sending),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── فقاعة رسالة واحدة ────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final PhListingMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final m = message;

    final isMe = m.isMine;
    final bubbleColor = isMe ? cs.primary : tk.surfaceAlt;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;
    // RTL: start = يمين، end = يسار — رسائلي تظهر يميناً، رسائل الطرف الآخر يساراً.
    final align = isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final radius = BorderRadius.only(
      topRight: const Radius.circular(AppRadius.lg),
      topLeft: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(isMe ? AppRadius.lg : AppRadius.sm),
      bottomRight: Radius.circular(isMe ? AppRadius.sm : AppRadius.lg),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                m.senderName,
                style:
                    context.text.labelSmall?.copyWith(color: tk.hint),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
            ),
            child: Text(
              m.content,
              style: context.text.bodyMedium?.copyWith(color: textColor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _timeLabel(m.sentAt),
            style: context.text.labelSmall?.copyWith(color: tk.hint),
          ),
        ],
      ),
    );
  }

  static String _timeLabel(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 6) return 'منذ ${diff.inHours} س';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

// ── زر الإرسال المدوّر ───────────────────────────────────────────────────────
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, required this.loading});
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.onPrimary),
                )
              : Icon(Icons.send_rounded, color: cs.onPrimary, size: 20),
        ),
      ),
    );
  }
}
