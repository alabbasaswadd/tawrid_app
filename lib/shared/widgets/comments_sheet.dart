import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// ورقة تعليقات عامة — تُعاد استخدامها لأي مصدر تعليقات (عرض بيع، طلب تسعير،
// إعلان) عبر تمرير دالّتَي التحميل والإضافة فقط.
// تدعم الردود المتسلسلة (parentId): كل تعليق يظهر ردوده منسابةً تحته.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    required this.loadComments,
    required this.addComment,
    super.key,
  });

  final Future<List<OfferComment>> Function() loadComments;
  final Future<void> Function(String content, {String? parentId}) addComment;

  static Future<void> show(
    BuildContext context, {
    required Future<List<OfferComment>> Function() loadComments,
    required Future<void> Function(String content, {String? parentId}) addComment,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CommentsSheet(loadComments: loadComments, addComment: addComment),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<OfferComment>? _comments;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _replyToId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.loadComments();
      setState(() {
        _comments = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  void _setReplyTo(OfferComment c) {
    setState(() {
      _replyToId = c.id;
      _replyToName = c.authorName.isNotEmpty ? c.authorName : 'تعليق';
    });
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final parentId = _replyToId;

    setState(() => _sending = true);
    try {
      await widget.addComment(text, parentId: parentId);
      _controller.clear();
      _clearReply();
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('التعليقات', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(child: _buildList(scrollController)),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  if (_replyToName != null)
                    _ReplyIndicator(
                      name: _replyToName!,
                      onDismiss: _clearReply,
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: _replyToName != null
                                ? 'الرد على $_replyToName…'
                                : 'أضف تعليقاً...',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton(
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.send, color: context.colors.primary),
                        onPressed: _sending ? null : _send,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(ScrollController scrollController) {
    if (_loading) {
      return const AppListSkeleton(variant: SkeletonVariant.row, count: 4);
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final comments = _comments ?? [];
    if (comments.isEmpty) {
      return const EmptyState(message: 'لا توجد تعليقات بعد', icon: Icons.comment_outlined);
    }

    final roots = comments.where((c) => c.parentId == null).toList();
    final repliesByParent = <String, List<OfferComment>>{};
    for (final c in comments) {
      if (c.parentId != null) {
        repliesByParent.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    final rootIds = roots.map((c) => c.id).toSet();
    final orphaned = comments
        .where((c) => c.parentId != null && !rootIds.contains(c.parentId))
        .toList();

    final tiles = <Widget>[];
    for (final root in roots) {
      tiles.add(_CommentTile(comment: root, onReply: _setReplyTo));
      for (final reply in repliesByParent[root.id] ?? []) {
        tiles.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: _CommentTile(comment: reply, onReply: _setReplyTo),
          ),
        );
      }
      tiles.add(const SizedBox(height: AppSpacing.xs));
    }
    for (final c in orphaned) {
      tiles.add(_CommentTile(comment: c, onReply: _setReplyTo));
      tiles.add(const SizedBox(height: AppSpacing.xs));
    }

    return ListView(controller: scrollController, children: tiles);
  }
}

class _ReplyIndicator extends StatelessWidget {
  const _ReplyIndicator({required this.name, required this.onDismiss});
  final String name;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final cs = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tk.brandSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'الرد على: $name',
              style: context.text.labelSmall?.copyWith(color: cs.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: AppIcon(AppIcons.x, size: 16, color: tk.hint),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onReply});
  final OfferComment comment;
  final void Function(OfferComment) onReply;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final isWarehouse = comment.authorType == CommentAuthorType.warehouse;

    return AppCard(
      color: isWarehouse ? tk.brandSurface : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isWarehouse ? Icons.warehouse_outlined : Icons.local_pharmacy_outlined,
                size: 14,
                color: isWarehouse ? cs.primary : tk.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  comment.authorName.isNotEmpty
                      ? (isWarehouse
                          ? comment.authorName
                          : 'صيدلية: ${comment.authorName}')
                      : (isWarehouse ? 'المستودع' : 'الصيدلية'),
                  style: context.text.titleSmall?.copyWith(
                    color: isWarehouse ? cs.primary : tk.success,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatSmartTimestamp(comment.createdOn),
                style: context.text.labelSmall?.copyWith(color: tk.hint),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(comment.content, style: context.text.bodySmall),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => onReply(comment),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'رد',
                style: context.text.labelSmall?.copyWith(color: cs.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
