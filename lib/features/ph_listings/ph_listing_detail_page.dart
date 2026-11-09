import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';
import 'package:tawrid_app/repositories/ph_listing_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// تفاصيل الإعلان + نقاشه العلني.
//
// لا حجزَ ولا محادثة خاصة: الصيادلة يعلّقون تحت الإعلان باسم صيدلياتهم،
// وصاحب الإعلان يردّ في المكان نفسه. السؤال الذي يخطر لعشرة يُجاب مرة
// واحدة أمامهم جميعاً، والإعلان لا يُقفَل على أول من طلبه.
class PhListingDetailPage extends ConsumerStatefulWidget {
  const PhListingDetailPage({required this.listingId, super.key});
  final String listingId;

  @override
  ConsumerState<PhListingDetailPage> createState() =>
      _PhListingDetailPageState();
}

class _PhListingDetailPageState extends ConsumerState<PhListingDetailPage> {
  PhListingSummary? _listing;
  List<PhListingComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _actionError;

  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  PhListingComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(phListingRepositoryProvider);
      final listing = await repo.getListing(widget.listingId);
      final comments = await repo.getComments(widget.listingId);
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _comments = comments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  String get _myTenantId {
    final session = ref.read(pharmacySessionProvider).value;
    return session is SessionAuthenticated ? (session.tenantId ?? '') : '';
  }

  bool _isOwner(PhListingSummary listing) =>
      _myTenantId.isNotEmpty && _myTenantId == listing.pharmacyId;

  Future<void> _addComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _actionError = null;
    });
    try {
      final added = await ref
          .read(phListingRepositoryProvider)
          .addComment(widget.listingId, content, parentId: _replyingTo?.id);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, added];
        _commentCtrl.clear();
        _sending = false;
        _replyingTo = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = ApiException.from(e).message;
        _sending = false;
      });
    }
  }

  void _startReply(PhListingComment comment) {
    setState(() => _replyingTo = comment);
    _commentFocus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyingTo = null);

  Future<void> _deleteComment(PhListingComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التعليق'),
        content: const Text('سيُحذف تعليقك من تحت هذا الإعلان.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _actionError = null);
    try {
      await ref
          .read(phListingRepositoryProvider)
          .deleteComment(widget.listingId, c.id);
      if (!mounted) return;
      setState(() => _comments =
          _comments.where((e) => e.id != c.id).toList(growable: false));
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = ApiException.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'تفاصيل الإعلان'),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final l = _listing!;
    final isOwner = _isOwner(l);
    final cs = context.colors;
    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.x3l,
      ),
      children: [
        // ── بطاقة المعلومات الكاملة ────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tk.brandSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Center(
                      child: AppIcon(AppIcons.pill, size: 24,
                          color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.medicineName, style: context.text.titleLarge),
                        if (l.manufacturer != null)
                          Text(l.manufacturer!,
                              style: context.text.bodySmall
                                  ?.copyWith(color: tk.hint)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 124),
                    child: StatusBadge(
                      label: l.reason.label,
                      tone: _reasonTone(l.reason),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(icon: AppIcons.package,
                  label: 'الكمية', value: '${l.quantity} وحدة'),
              _InfoRow(
                icon: AppIcons.tag,
                label: 'السعر',
                value: '${formatMoneyWith(l.pricePerUnit, l.currency)} / الوحدة',
                valueStyle: context.priceBrandStyle,
              ),
              _InfoRow(icon: AppIcons.mapPin,
                  label: 'المنطقة',
                  value: l.city.isEmpty
                      ? l.governorate
                      : '${l.city}، ${l.governorate}'),
              _InfoRow(icon: AppIcons.user,
                  label: 'الصيدلية', value: l.pharmacyName),
              if (l.expiryDate != null)
                _InfoRow(
                  icon: AppIcons.clock,
                  label: 'صلاحية الدواء',
                  value:
                      '${l.expiryDate!.day}/${l.expiryDate!.month}/${l.expiryDate!.year}',
                  valueColor: tk.warning,
                ),
              _InfoRow(
                icon: AppIcons.clock,
                label: 'انتهاء الإعلان',
                value: _listingExpiryLabel(l.listingExpiresAt, l.status),
                valueColor: l.isListingExpired
                    ? tk.danger
                    : l.status == PhListingStatus.booked
                        ? tk.hint
                        : tk.hint,
              ),
              if (l.notes != null && l.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('ملاحظات:',
                    style: context.text.labelMedium
                        ?.copyWith(color: tk.hint)),
                Text(l.notes!,
                    style: context.text.bodySmall
                        ?.copyWith(color: cs.onSurface)),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        if (_actionError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              _actionError!,
              style: context.text.bodySmall?.copyWith(color: tk.danger),
            ),
          ),

        // ── نقاش الإعلان ──────────────────────────────────────────────────
        // التعليقات علنية تحت الإعلان: كل صيدلية ترى ما سأله غيرها وجواب
        // المعلِن عليه، فلا يتكرّر السؤال نفسه في عشر محادثات خاصة.
        Row(
          children: [
            AppIcon(AppIcons.fileText, size: 18, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _comments.isEmpty
                    ? 'التعليقات'
                    : 'التعليقات (${_comments.length})',
                style: context.text.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        if (_comments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: tk.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              isOwner
                  ? 'لا تعليقات بعد — ستظهر هنا أسئلة الصيادلة عن إعلانك.'
                  : 'لا تعليقات بعد — كن أول من يسأل عن هذا الدواء.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
          )
        else
          ..._buildCommentTree(l),

        const SizedBox(height: AppSpacing.md),

        // صندوق الكتابة — متاح للمالك والمتصفّح معاً: المعلِن يردّ على
        // الأسئلة في مكانها لا في رسالة خاصة.
        _CommentComposer(
          controller: _commentCtrl,
          focusNode: _commentFocus,
          sending: _sending,
          replyingTo: _replyingTo,
          hint: isOwner
              ? 'ردّ على سؤال أو أضف توضيحاً…'
              : 'اسأل عن الدواء أو اعرض سعراً…',
          onSend: _addComment,
          onCancelReply: _cancelReply,
        ),
      ],
    );
  }

  /// يُرتّب التعليقات شجرياً: كل تعليق جذر يتبعه ردوده مُزاحة.
  List<Widget> _buildCommentTree(PhListingSummary l) {
    final Map<String, List<PhListingComment>> replyMap = {};
    final List<PhListingComment> roots = [];
    for (final c in _comments) {
      if (c.parentId == null) {
        roots.add(c);
      } else {
        replyMap.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    final widgets = <Widget>[];
    for (final root in roots) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: _CommentBubble(
          comment: root,
          isMine: root.authorId == _myTenantId,
          isListingOwner: root.authorId == l.pharmacyId,
          onDelete: root.authorId == _myTenantId
              ? () => _deleteComment(root)
              : null,
          onReply: () => _startReply(root),
        ),
      ));
      final replies = replyMap[root.id] ?? [];
      for (final reply in replies) {
        widgets.add(Padding(
          padding: const EdgeInsetsDirectional.only(
            bottom: AppSpacing.xs,
            start: AppSpacing.x2l,
          ),
          child: _CommentBubble(
            comment: reply,
            isMine: reply.authorId == _myTenantId,
            isListingOwner: reply.authorId == l.pharmacyId,
            isReply: true,
            onDelete: reply.authorId == _myTenantId
                ? () => _deleteComment(reply)
                : null,
            onReply: null,
          ),
        ));
      }
      widgets.add(const SizedBox(height: AppSpacing.xs));
    }
    return widgets;
  }

  static StatusTone _reasonTone(PhListingReason r) => switch (r) {
        PhListingReason.nearExpiry => StatusTone.warning,
        PhListingReason.slowMoving => StatusTone.neutral,
        PhListingReason.overstocked => StatusTone.info,
        PhListingReason.other => StatusTone.neutral,
      };

  static String _listingExpiryLabel(DateTime expiresAt, PhListingStatus status) {
    if (status == PhListingStatus.closed) return 'الإعلان مغلق';
    if (status == PhListingStatus.booked) return 'ينتهي عند الاتفاق بين الطرفين';
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'انتهى الإعلان';
    if (remaining.inDays == 0) return 'الإعلان ينتهي اليوم';
    if (remaining.inDays == 1) return 'يوم واحد متبقٍ للإعلان';
    return 'متبقٍ ${remaining.inDays} أيام للإعلان';
  }
}

// ── صف معلومة واحدة داخل AppCard ─────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
    this.valueColor,
  });

  final AppIcons icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          AppIcon(icon, size: 15, color: tk.hint),
          const SizedBox(width: AppSpacing.sm),
          Text('$label: ',
              style: context.text.bodySmall?.copyWith(color: tk.hint)),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  context.text.bodySmall?.copyWith(
                    color: valueColor ?? context.colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── فقاعة تعليق ──────────────────────────────────────────────────────────
// اسم الصيدلية ومدينتها أول ما يُقرأ: التعليق بلا صاحبٍ معروف لا يُبنى عليه
// قرار بيع. وتعليق صاحب الإعلان يُميَّز بشارة «صاحب الإعلان».
class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.comment,
    required this.isMine,
    required this.isListingOwner,
    this.isReply = false,
    this.onDelete,
    this.onReply,
  });

  final PhListingComment comment;
  final bool isMine;
  final bool isListingOwner;
  final bool isReply;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;

  String? get _locationLabel {
    final city = comment.authorCity;
    final gov = comment.authorGovernorate;
    if (city.isNotEmpty && gov.isNotEmpty) return '$city، $gov';
    if (city.isNotEmpty) return city;
    if (gov.isNotEmpty) return gov;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final c = comment;
    final location = _locationLabel;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isMine ? tk.brandSurfaceSubtle : cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isMine ? cs.primary : cs.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── رأس التعليق: أفاتار + بيانات الصيدلية + الوقت + حذف ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tk.brandSurface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(AppIcons.user, size: 16, color: cs.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isMine ? '${c.authorName} (أنت)' : c.authorName,
                            style: context.text.titleSmall
                                ?.copyWith(color: cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isListingOwner) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Flexible(
                            child: StatusBadge(
                              label: 'صاحب الإعلان',
                              tone: StatusTone.brand,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          AppIcon(AppIcons.mapPin,
                              size: 11, color: cs.onSurface),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              location,
                              style: context.text.labelSmall
                                  ?.copyWith(color: cs.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _timeAgo(c.createdOn),
                style: context.text.labelSmall?.copyWith(color: tk.hint),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: AppSpacing.xs),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: AppIcon(AppIcons.x, size: 13, color: tk.hint),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Text(c.content, style: context.text.bodyMedium),

          // ── زر «رد» — يظهر فقط على التعليقات الجذر ──
          if (onReply != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: InkWell(
                onTap: onReply,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  child: Text(
                    'رد',
                    style: context.text.labelSmall
                        ?.copyWith(color: cs.primary),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ── صندوق كتابة تعليق / رد ───────────────────────────────────────────────
class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.hint,
    required this.onSend,
    required this.onCancelReply,
    this.replyingTo,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;
  final PhListingComment? replyingTo;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final replying = replyingTo;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: replying != null ? cs.primary : cs.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط «رداً على» — يظهر فقط عند الرد على تعليق بعينه.
          if (replying != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .07),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.md - 1),
                  topRight: Radius.circular(AppRadius.md - 1),
                ),
              ),
              child: Row(
                children: [
                  AppIcon(AppIcons.chevronBackRtl,
                      size: 13, color: cs.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'رداً على ${replying.authorName}',
                      style: context.text.labelSmall
                          ?.copyWith(color: cs.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: onCancelReply,
                    borderRadius:
                        BorderRadius.circular(AppRadius.full),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: AppIcon(AppIcons.x,
                          size: 13, color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  enabled: !sending,
                  keyboardType: TextInputType.multiline,
                  style: context.text.bodyMedium,
                  decoration: InputDecoration(
                    hintText: replying != null
                        ? 'اكتب ردّك هنا…'
                        : hint,
                    hintStyle:
                        context.text.bodySmall?.copyWith(color: tk.hint),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    counterStyle:
                        context.text.labelSmall?.copyWith(color: tk.hint),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AppButton(
                    label: replying != null ? 'نشر الرد' : 'نشر التعليق',
                    compact: true,
                    fullWidth: false,
                    loading: sending,
                    onPressed: sending ? null : onSend,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
