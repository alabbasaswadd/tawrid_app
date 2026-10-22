import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// ورقة تعليقات عامة — تُعاد استخدامها لأي مصدر تعليقات (عرض بيع، مناقصة،
// إعلان) عبر تمرير دالّتَي التحميل والإضافة فقط.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    required this.loadComments,
    required this.addComment,
    super.key,
  });

  final Future<List<OfferComment>> Function() loadComments;
  final Future<OfferComment> Function(String content) addComment;

  static Future<void> show(
    BuildContext context, {
    required Future<List<OfferComment>> Function() loadComments,
    required Future<OfferComment> Function(String content) addComment,
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
  List<OfferComment>? _comments;
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final comment = await widget.addComment(text);
      setState(() {
        _comments = [...(_comments ?? []), comment];
        _controller.clear();
      });
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'أضف تعليقاً...'),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: TawridColors.warehouse),
                      onPressed: _sending ? null : _send,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(ScrollController scrollController) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final comments = _comments ?? [];
    if (comments.isEmpty) {
      return const EmptyState(message: 'لا توجد تعليقات بعد', icon: Icons.comment_outlined);
    }

    return ListView.separated(
      controller: scrollController,
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final c = comments[index];
        return Align(
          alignment: c.authorType.name == 'warehouse' ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: TawridColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.authorName,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 2),
                Text(c.content, style: GoogleFonts.cairo(fontSize: 13)),
                const SizedBox(height: 2),
                Text(formatSmartTimestamp(c.createdOn),
                    style: GoogleFonts.cairo(fontSize: 10, color: TawridColors.hint)),
              ],
            ),
          ),
        );
      },
    );
  }
}
