import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';
import 'package:tawrid_app/repositories/ph_listing_repository.dart';
import 'package:tawrid_app/repositories/pharmacy_profile_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

// إنشاء إعلان جديد «صيدلي إلى صيدلي».
// المحافظة والمدينة تُملأ تلقائياً من ملف الصيدلية (قابلة للتعديل).
class PhCreateListingPage extends ConsumerStatefulWidget {
  const PhCreateListingPage({super.key});

  @override
  ConsumerState<PhCreateListingPage> createState() =>
      _PhCreateListingPageState();
}

class _PhCreateListingPageState extends ConsumerState<PhCreateListingPage> {
  final _formKey = GlobalKey<FormState>();

  final _medicineCtrl = TextEditingController();
  final _genericCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _govCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  PhListingReason _reason = PhListingReason.slowMoving;
  DateTime? _expiryDate;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _prefillRegion();
  }

  Future<void> _prefillRegion() async {
    try {
      final me = await ref.read(pharmacyProfileRepositoryProvider).getMe();
      if (!mounted) return;
      _govCtrl.text = me.governorate;
      _cityCtrl.text = me.city;
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _medicineCtrl, _genericCtrl, _manufacturerCtrl, _quantityCtrl,
      _priceCtrl, _notesCtrl, _govCtrl, _cityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: const Locale('ar'),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_reason == PhListingReason.nearExpiry && _expiryDate == null) {
      setState(() => _submitError = 'يرجى تحديد تاريخ انتهاء الصلاحية');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final req = CreatePhListingRequest(
        medicineName: _medicineCtrl.text.trim(),
        genericName: _genericCtrl.text.trim().isEmpty
            ? null
            : _genericCtrl.text.trim(),
        manufacturer: _manufacturerCtrl.text.trim().isEmpty
            ? null
            : _manufacturerCtrl.text.trim(),
        quantity: int.parse(_quantityCtrl.text.trim()),
        pricePerUnit: double.parse(_priceCtrl.text.trim()),
        expiryDate: _expiryDate,
        reason: _reason,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        governorate: _govCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
      );

      await ref.read(phListingRepositoryProvider).createListing(req);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = ApiException.from(e).message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;

    return Scaffold(
      appBar: const InnerTopBar(title: 'إعلان جديد'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.x3l,
          ),
          children: [
            // ── معلومات الدواء ─────────────────────────────────────────────
            _SectionLabel(label: 'معلومات الدواء'),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _medicineCtrl,
              label: 'اسم الدواء *',
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _genericCtrl,
              label: 'الاسم الجنيسي (اختياري)',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _manufacturerCtrl,
              label: 'الشركة المصنّعة (اختياري)',
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── الكمية والسعر ──────────────────────────────────────────────
            _SectionLabel(label: 'الكمية والسعر'),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    label: 'الكمية (وحدة) *',
                    child: TextFormField(
                      controller: _quantityCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (int.tryParse(v.trim()) == null ||
                            int.parse(v.trim()) < 1) {
                          return 'رقم صحيح > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _LabeledField(
                    label: 'السعر (ل.س/الوحدة) *',
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]')),
                      ],
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (double.tryParse(v.trim()) == null ||
                            double.parse(v.trim()) <= 0) {
                          return 'سعر صحيح > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── سبب البيع ──────────────────────────────────────────────────
            _SectionLabel(label: 'سبب البيع *'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final r in PhListingReason.values)
                  AppFilterChip(
                    label: r.label,
                    selected: _reason == r,
                    onTap: () => setState(() => _reason = r),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── تاريخ انتهاء الصلاحية ──────────────────────────────────────
            _SectionLabel(
              label: _reason == PhListingReason.nearExpiry
                  ? 'تاريخ انتهاء الصلاحية *'
                  : 'تاريخ انتهاء الصلاحية (اختياري)',
            ),
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: _pickExpiry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _expiryDate == null
                        ? context.colors.outline
                        : context.colors.primary,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: context.colors.surface,
                ),
                child: Row(
                  children: [
                    AppIcon(AppIcons.calendar,
                        size: 18, color: context.colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _expiryDate == null
                            ? 'اضغط لتحديد التاريخ'
                            : 'ينتهي: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                        style: context.text.bodyMedium?.copyWith(
                          color: _expiryDate == null
                              ? tk.hint
                              : context.colors.primary,
                        ),
                      ),
                    ),
                    if (_expiryDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _expiryDate = null),
                        child: AppIcon(AppIcons.x, size: 16, color: tk.hint),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── المنطقة ───────────────────────────────────────────────────
            _SectionLabel(label: 'المنطقة'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'تُملأ تلقائياً من ملف صيدليتك — عدّلها إن لزم.',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _govCtrl,
                    label: 'المحافظة *',
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _cityCtrl,
                    label: 'المدينة *',
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── ملاحظات ───────────────────────────────────────────────────
            _SectionLabel(label: 'ملاحظات (اختياري)'),
            const SizedBox(height: AppSpacing.sm),
            _LabeledField(
              label: 'أي معلومات إضافية تفيد المشتري',
              child: TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                minLines: 2,
                keyboardType: TextInputType.multiline,
              ),
            ),

            const SizedBox(height: AppSpacing.x2l),

            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  _submitError!,
                  style: context.text.bodySmall
                      ?.copyWith(color: tk.danger),
                ),
              ),

            AppButton(
              label: 'نشر الإعلان',
              onPressed: _submitting ? null : _submit,
              loading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: context.text.titleSmall
            ?.copyWith(color: context.colors.onSurface),
      );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 2),
          child: Text(label, style: context.text.labelMedium),
        ),
        child,
      ],
    );
  }
}
