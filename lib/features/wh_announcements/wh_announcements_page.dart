import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/warehouse_models.dart';
import 'package:tawrid_app/repositories/warehouse_announcement_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

class WhAnnouncementsPage extends ConsumerStatefulWidget {
  const WhAnnouncementsPage({super.key});

  @override
  ConsumerState<WhAnnouncementsPage> createState() => _WhAnnouncementsPageState();
}

class _WhAnnouncementsPageState extends ConsumerState<WhAnnouncementsPage> {
  List<WarehouseAnnouncement> _announcements = const [];
  bool _loading = true;
  String? _error;

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
      final list = await ref
          .read(warehouseAnnouncementRepositoryProvider)
          .getWarehouseAnnouncements();
      if (!mounted) return;
      setState(() {
        _announcements = list;
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

  void _openCreate() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateAnnouncementSheet(
        onCreated: () {
          Navigator.pop(context, true);
        },
      ),
    ).then((created) {
      if (created == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'إعلاناتي'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('إعلان جديد'),
      ),
      body: _loading
          ? const AppListSkeleton()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _announcements.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: AppSpacing.x3l),
                          EmptyState(
                            message:
                                'لا إعلانات بعد — أنشئ أول إعلان لصيدليات منطقتك',
                            icon: Icons.campaign_outlined,
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            AppSpacing.md,
                            AppSpacing.page,
                            AppSpacing.x3l + 80,
                          ),
                          itemCount: _announcements.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (_, i) =>
                              _AnnouncementCard(_announcements[i]),
                        ),
                ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard(this.announcement);
  final WarehouseAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final fmt = DateFormat('yyyy/MM/dd');
    final expired = announcement.validUntil.isBefore(DateTime.now());
    final inactive = !announcement.isActive || expired;
    final valueLabel = announcement.discountValue == announcement.discountValue.roundToDouble()
        ? announcement.discountValue.toInt().toString()
        : announcement.discountValue.toStringAsFixed(1);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(announcement.title, style: context.text.titleSmall),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: inactive ? 'منتهٍ' : 'ساري',
                tone: inactive ? StatusTone.neutral : StatusTone.success,
              ),
            ],
          ),
          if (announcement.body != null && announcement.body!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              announcement.body!,
              style: context.text.bodySmall?.copyWith(color: tk.hint),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.percent, size: 14, color: tk.gold),
              const SizedBox(width: 4),
              Text(
                'حسم $valueLabel% على إجمالي الفاتورة',
                style: context.text.labelMedium?.copyWith(color: tk.goldStrong),
              ),
              const Spacer(),
              Icon(Icons.calendar_today_outlined, size: 13, color: tk.hint),
              const SizedBox(width: 4),
              Text(
                'حتى ${fmt.format(announcement.validUntil)}',
                style: context.text.labelSmall?.copyWith(color: tk.hint),
              ),
            ],
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
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  DateTime? _validUntil;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _valueCtrl.addListener(_prefillTitle);
  }

  void _prefillTitle() {
    final v = double.tryParse(_valueCtrl.text.trim());
    if (v != null && v > 0) {
      final label = v == v.roundToDouble()
          ? v.toInt().toString()
          : v.toStringAsFixed(1);
      _titleCtrl.text = 'حسم $label% على إجمالي الفاتورة';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _validUntil = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_validUntil == null) {
      AppSnackbar.error(context, 'اختر تاريخ انتهاء الإعلان');
      return;
    }
    final v = double.tryParse(_valueCtrl.text.trim());
    if (v == null || v <= 0 || v > 100) {
      AppSnackbar.error(context, 'أدخل نسبة حسم صحيحة بين 0 و100');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(warehouseAnnouncementRepositoryProvider).createAnnouncement(
            title: _titleCtrl.text.trim(),
            body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
            discountType: 1,
            discountValue: v,
            validUntil: DateTime(
              _validUntil!.year,
              _validUntil!.month,
              _validUntil!.day,
              23,
              59,
              59,
            ),
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'تم نشر الإعلان وإشعار الصيدليات');
      widget.onCreated();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final fmt = DateFormat('yyyy/MM/dd');

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.lg,
          AppSpacing.page,
          AppSpacing.x3l,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('إعلان جديد', style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'سيصل الإعلان فوراً إلى صيدليات منطقتك كإشعار.',
                style: context.text.bodySmall?.copyWith(color: tk.hint),
              ),
              const SizedBox(height: AppSpacing.x2l),

              AppTextField(
                controller: _valueCtrl,
                label: 'نسبة الحسم %',
                hint: 'مثال: 2',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'أدخل نسبة الحسم';
                  final d = double.tryParse(v.trim());
                  if (d == null || d <= 0 || d > 100) return 'نسبة بين 0 و100';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _titleCtrl,
                label: 'عنوان الإعلان',
                hint: 'حسم 2% على إجمالي الفاتورة',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل عنواناً' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _bodyCtrl,
                label: 'تفاصيل إضافية (اختياري)',
                hint: 'ينطبق على جميع الأصناف خلال فترة العرض',
              ),
              const SizedBox(height: AppSpacing.md),

              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: AppTextField(
                    label: 'ساري حتى',
                    hint: 'اختر تاريخاً',
                    controller: TextEditingController(
                      text: _validUntil == null
                          ? ''
                          : fmt.format(_validUntil!),
                    ),
                    validator: (_) =>
                        _validUntil == null ? 'اختر تاريخ الانتهاء' : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),

              AppButton(
                label: 'نشر الإعلان',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
