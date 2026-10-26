import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/tender_models.dart';
import 'package:tawrid_app/repositories/tender_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

/// مسوّدة تسعير صنف واحد — ثلاثة حقول وملاحظة.
class _ItemDraft {
  _ItemDraft(this.item)
      : unitPrice = TextEditingController(),
        bonusPercentage = TextEditingController(),
        extraBonus = TextEditingController(),
        notes = TextEditingController();

  final TenderItem item;
  final TextEditingController unitPrice;
  final TextEditingController bonusPercentage;
  final TextEditingController extraBonus;
  final TextEditingController notes;

  bool get isPriced =>
      unitPrice.text.trim().isNotEmpty ||
      bonusPercentage.text.trim().isNotEmpty ||
      extraBonus.text.trim().isNotEmpty;

  void dispose() {
    unitPrice.dispose();
    bonusPercentage.dispose();
    extraBonus.dispose();
    notes.dispose();
  }

  Map<String, dynamic> toPayload() => {
        'tenderItemId': item.id,
        'unitPrice': double.tryParse(unitPrice.text.trim()),
        'bonusPercentage': double.tryParse(bonusPercentage.text.trim()),
        'extraBonus': double.tryParse(extraBonus.text.trim()),
        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
      };
}

// تقديم عرض سعر (Figma: المستودع / تقديم عرض سعر).
//
// لا يرى المستودع هنا — ولا في أي مكان — شيئاً عن عروض منافسيه: الخادم
// لا يُرجعها أصلاً قبل انتهاء المهلة.
class WhSubmitTenderOfferPage extends ConsumerStatefulWidget {
  const WhSubmitTenderOfferPage({required this.tenderId, super.key});
  final String tenderId;

  @override
  ConsumerState<WhSubmitTenderOfferPage> createState() =>
      _WhSubmitTenderOfferPageState();
}

class _WhSubmitTenderOfferPageState
    extends ConsumerState<WhSubmitTenderOfferPage> {
  TenderDetail? _request;
  final List<_ItemDraft> _drafts = [];
  final _notes = TextEditingController();
  TenderOfferType _type = TenderOfferType.mixed;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await ref
          .read(tenderRepositoryProvider)
          .getTenderDetailsForWarehouse(widget.tenderId);
      if (!mounted) return;
      setState(() {
        _request = t;
        for (final d in _drafts) {
          d.dispose();
        }
        _drafts
          ..clear()
          ..addAll(t.items.map(_ItemDraft.new));
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

  bool get _showPrice =>
      _type == TenderOfferType.priceBased || _type == TenderOfferType.mixed;
  bool get _showBonus =>
      _type == TenderOfferType.bonusBased || _type == TenderOfferType.mixed;

  Future<void> _submit({required bool asDraft}) async {
    final priced = _drafts.where((d) => d.isPriced).toList();

    // المسودة تُحفظ ناقصة عمداً، أمّا الإرسال فيحتاج صنفاً مسعَّراً واحداً
    // على الأقل — عرضٌ فارغ لا معنى له عند الصيدلية.
    if (!asDraft && priced.isEmpty) {
      AppSnackbar.error(context, 'سعّر صنفاً واحداً على الأقل قبل الإرسال');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(tenderRepositoryProvider).submitOffer(
            tenderId: widget.tenderId,
            offerType: _type.code,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            items: priced.map((d) => d.toPayload()).toList(),
            asDraft: asDraft,
          );
      if (!mounted) return;
      AppSnackbar.success(
          context,
          asDraft
              ? 'حُفظت المسودة — لا تصل الصيدلية حتى ترسلها'
              : 'أُرسل عرض السعر');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'تقديم عرض سعر'),
      body: _buildBody(),
      bottomNavigationBar: _request == null ? null : _buildActions(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final t = _request!;
    final tk = context.tokens;
    final area = [t.tenantGovernorate, t.tenantCity]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' — ');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس الطلب على سطح باهت — سياق لا بطاقة قرار.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: tk.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: context.text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  [
                    '${t.items.length} ${t.items.length == 1 ? 'صنف' : 'أصناف'}',
                    if (area.isNotEmpty) 'من $area',
                    'يُغلق ${formatSmartTimestamp(t.expiresAt)}',
                  ].join(' · '),
                  style: context.text.bodySmall?.copyWith(color: tk.goldStrong),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          Text('نوع عرض السعر', style: context.text.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          // الشرائح تتحكّم بأي الحقول تظهر: لا معنى لحقل سعر في عرض بونص.
          Row(
            children: [
              for (final ty in TenderOfferType.values)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: AppFilterChip(
                    label: switch (ty) {
                      TenderOfferType.priceBased => 'بالسعر',
                      TenderOfferType.bonusBased => 'بالبونص',
                      TenderOfferType.mixed => 'مختلط',
                    },
                    selected: _type == ty,
                    onTap: () => setState(() => _type = ty),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'بالسعر: تُسعّر الأصناف · بالبونص: تمنح نسبة بونص · مختلط: الاثنان معاً.',
            style: context.text.labelSmall?.copyWith(color: tk.hint),
          ),

          const SizedBox(height: AppSpacing.lg),
          Text('تسعير الأصناف المطلوبة', style: context.text.titleLarge),
          const SizedBox(height: AppSpacing.sm),

          for (final d in _drafts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ItemCard(
                draft: d,
                showPrice: _showPrice,
                showBonus: _showBonus,
                onChanged: () => setState(() {}),
              ),
            ),

          const SizedBox(height: AppSpacing.sm),
          Text('ملاحظات على عرضك (اختياري)', style: context.text.labelMedium),
          const SizedBox(height: 6),
          AppTextField(
            controller: _notes,
            hint: 'التسليم خلال ٤٨ ساعة من قبولكم العرض، والأسعار سارية ما دام '
                'طلب التسعير مفتوحاً.',
          ),

          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: tk.goldSurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: tk.gold),
            ),
            child: Text(
              'يبقى عرضك مخفياً عن الصيدلية وعن بقية المستودعات حتى انتهاء '
              'المهلة، ويمكنك تعديله ما دام الطلب مفتوحاً.',
              style: context.text.bodySmall?.copyWith(color: tk.goldStrong),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final cs = context.colors;
    final tk = context.tokens;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline)),
          boxShadow: tk.navShadow,
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: AppButton(
                label: 'إرسال عرض السعر',
                loading: _saving,
                onPressed: _saving ? null : () => _submit(asDraft: false),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'حفظ مسودة',
                variant: AppButtonVariant.outline,
                onPressed: _saving ? null : () => _submit(asDraft: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// بطاقة تسعير صنف (Figma): الاسم والمطلوب، ثم الحقول الثلاثة في صفّ،
// ثم ملاحظة الصنف.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.draft,
    required this.showPrice,
    required this.showBonus,
    required this.onChanged,
  });

  final _ItemDraft draft;
  final bool showPrice;
  final bool showBonus;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final item = draft.item;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.medicineName, style: context.text.titleSmall),
          const SizedBox(height: 2),
          Text(
            'المطلوب: ${item.quantity.toStringAsFixed(0)} ${item.unit}'
            '${item.notes != null && item.notes!.isNotEmpty ? ' · ${item.notes}' : ''}',
            style: context.text.bodySmall?.copyWith(color: tk.hint),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showPrice)
                Expanded(
                  child: AppTextField(
                    controller: draft.unitPrice,
                    label: 'سعر الوحدة',
                    hint: 'ل.س',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              if (showPrice && showBonus) const SizedBox(width: AppSpacing.sm),
              if (showBonus) ...[
                Expanded(
                  child: AppTextField(
                    controller: draft.bonusPercentage,
                    label: 'نسبة البونص',
                    hint: '٪',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: draft.extraBonus,
                    label: 'بونص إضافي',
                    hint: 'عبوة',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: draft.notes,
            hint: 'ملاحظة على الصنف — مثال: متوفر بالكامل، تسليم خلال ٤٨ ساعة',
          ),
        ],
      ),
    );
  }
}
