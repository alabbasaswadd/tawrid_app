import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/tender_models.dart';
import 'package:tawrid_app/repositories/tender_repository.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/tawrid_button.dart';

// التقدّم بعرض على مناقصة مفتوحة — يصل إليها المستودع من بطاقة المناقصة في
// الصفحة الرئيسية. لا يرى المستودع أي معلومة عن المنافسين هنا أو في أي
// مكان آخر.
class WhSubmitTenderOfferPage extends ConsumerStatefulWidget {
  const WhSubmitTenderOfferPage({required this.tenderId, super.key});
  final String tenderId;

  @override
  ConsumerState<WhSubmitTenderOfferPage> createState() => _WhSubmitTenderOfferPageState();
}

class _ItemDraft {
  _ItemDraft(this.item)
      : unitPrice = TextEditingController(),
        bonusPercentage = TextEditingController(),
        extraBonus = TextEditingController();

  final TenderItem item;
  final TextEditingController unitPrice;
  final TextEditingController bonusPercentage;
  final TextEditingController extraBonus;

  void dispose() {
    unitPrice.dispose();
    bonusPercentage.dispose();
    extraBonus.dispose();
  }
}

class _WhSubmitTenderOfferPageState extends ConsumerState<WhSubmitTenderOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();

  TenderDetail? _tender;
  bool _loading = true;
  String? _error;
  TenderOfferType _offerType = TenderOfferType.priceBased;
  List<_ItemDraft> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final d in _items) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tender =
          await ref.read(tenderRepositoryProvider).getTenderDetailsForWarehouse(widget.tenderId);
      setState(() {
        _tender = tender;
        _items = tender.items.map(_ItemDraft.new).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final items = _items
          .map((d) => {
                'tenderItemId': d.item.id,
                'unitPrice': d.unitPrice.text.trim().isEmpty ? null : double.tryParse(d.unitPrice.text),
                'bonusPercentage': d.bonusPercentage.text.trim().isEmpty
                    ? null
                    : double.tryParse(d.bonusPercentage.text),
                'extraBonus':
                    d.extraBonus.text.trim().isEmpty ? null : double.tryParse(d.extraBonus.text),
              })
          .toList();

      await ref.read(tenderRepositoryProvider).submitOffer(
            tenderId: widget.tenderId,
            offerType: _offerType.code,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            items: items,
          );

      if (mounted) {
        AppSnackbar.success(context, 'تم تقديم عرضك على المناقصة');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقدّم بعرض')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final tender = _tender!;
    final showPrice = _offerType == TenderOfferType.priceBased || _offerType == TenderOfferType.mixed;
    final showBonus = _offerType == TenderOfferType.bonusBased || _offerType == TenderOfferType.mixed;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        children: [
          Text(tender.title, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text('رقم المناقصة: ${tender.tenderNumber}',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: TawridColors.textSecondary)),
          if (tender.description != null && tender.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(tender.description!, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<TenderOfferType>(
            initialValue: _offerType,
            decoration: const InputDecoration(labelText: 'نوع العرض'),
            items: TenderOfferType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => _offerType = v ?? TenderOfferType.priceBased),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظات عامة (اختياري)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('الأصناف المطلوبة (${_items.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ..._items.map((draft) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(draft.item.medicineName,
                          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${draft.item.quantity} ${draft.item.unit}',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: TawridColors.textSecondary)),
                      if (draft.item.notes != null && draft.item.notes!.isNotEmpty)
                        Text(draft.item.notes!,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: TawridColors.textSecondary)),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          if (showPrice)
                            Expanded(
                              child: TextFormField(
                                controller: draft.unitPrice,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'سعر الوحدة', isDense: true),
                              ),
                            ),
                          if (showPrice && showBonus) const SizedBox(width: AppSpacing.xs),
                          if (showBonus)
                            Expanded(
                              child: TextFormField(
                                controller: draft.bonusPercentage,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'بونص %', isDense: true),
                              ),
                            ),
                          if (showBonus) const SizedBox(width: AppSpacing.xs),
                          if (showBonus)
                            Expanded(
                              child: TextFormField(
                                controller: draft.extraBonus,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'بونص إضافي (اختياري)', isDense: true),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: AppSpacing.lg),
          TawridButton(
            label: 'تقديم العرض',
            onPressed: _saving ? null : _submit,
            loading: _saving,
            gradient: TawridColors.warehouseGradient,
            icon: Icons.send_outlined,
          ),
        ],
      ),
    );
  }
}
