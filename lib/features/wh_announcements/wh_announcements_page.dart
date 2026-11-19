import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/announcement_models.dart';
import 'package:tawrid_app/repositories/announcement_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

class WhAnnouncementsPage extends ConsumerStatefulWidget {
  const WhAnnouncementsPage({super.key});

  @override
  ConsumerState<WhAnnouncementsPage> createState() => _WhAnnouncementsPageState();
}

class _WhAnnouncementsPageState extends ConsumerState<WhAnnouncementsPage> {
  List<WarehouseAnnouncement>? _items;
  bool _loading = true;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(announcementRepositoryProvider).getMyAnnouncements();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e);
        _loading = false;
      });
    }
  }

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _CreateAnnouncementSheet(onCreated: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'الإعلانات'),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: AppIcon(AppIcons.plus, size: 20, color: context.colors.onPrimary),
        label: const Text('إعلان جديد'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row);
    if (_error != null) return ErrorState.of(_error!, onRetry: _load);

    final items = _items ?? [];
    if (items.isEmpty) {
      return const UiEmpty(
        appIcon: AppIcons.tag,
        message: 'لا إعلانات بعد\nأنشئ أوّل إعلان خصم لصيدلياتك',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _AnnouncementCard(item: items[i]),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});
  final WarehouseAnnouncement item;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final expired = item.validUntil.isBefore(DateTime.now());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.title,
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              StatusBadge(
                label: expired ? 'منتهي' : (item.isActive ? 'نشط' : 'غير نشط'),
                tone: expired
                    ? StatusTone.neutral
                    : (item.isActive ? StatusTone.success : StatusTone.neutral),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.discountLabel,
            style: context.text.bodyMedium?.copyWith(color: cs.primary),
          ),
          if (item.body != null && item.body!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.body!,
                style: context.text.bodySmall?.copyWith(color: tk.hint),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Text(
            'صالح حتى: ${formatSmartTimestamp(item.validUntil)}',
            style: context.text.labelSmall?.copyWith(color: tk.hint),
          ),
        ],
      ),
    );
  }
}

class _CreateAnnouncementSheet extends ConsumerStatefulWidget {
  const _CreateAnnouncementSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateAnnouncementSheet> createState() =>
      _CreateAnnouncementSheetState();
}

class _CreateAnnouncementSheetState
    extends ConsumerState<_CreateAnnouncementSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final discountText = _discountCtrl.text.trim();
    if (title.isEmpty || discountText.isEmpty) {
      AppSnackbar.error(context, 'يُرجى ملء العنوان ونسبة الخصم');
      return;
    }
    final discount = double.tryParse(discountText);
    if (discount == null || discount <= 0 || discount > 100) {
      AppSnackbar.error(context, 'نسبة الخصم يجب أن تكون بين 1 و100');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(announcementRepositoryProvider).createAnnouncement(
            title: title,
            body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
            discountValue: discount,
            validUntil: _validUntil,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.x3l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('إعلان جديد', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _titleCtrl,
              label: 'عنوان الإعلان',
              hint: 'مثال: خصم نهاية الشهر',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تفاصيل (اختياري)',
                hintText: 'وصف إضافي للإعلان',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _discountCtrl,
              label: 'نسبة الخصم ٪',
              hint: 'مثال: 5',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    AppIcon(AppIcons.calendar, size: 18, color: tk.hint),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'صالح حتى: ${_validUntil.year}-'
                        '${_validUntil.month.toString().padLeft(2, '0')}-'
                        '${_validUntil.day.toString().padLeft(2, '0')}',
                        style: context.text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'نشر الإعلان',
              loading: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
