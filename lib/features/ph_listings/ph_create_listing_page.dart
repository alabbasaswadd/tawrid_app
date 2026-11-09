import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/medicine_catalog_models.dart';
import 'package:tawrid_app/models/pharmacy_auth_models.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/repositories/ph_listing_repository.dart';
import 'package:tawrid_app/repositories/pharmacy_profile_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// إنشاء إعلان جديد «صيدلي إلى صيدلي».
//
// الدواء يُختار من الكتالوج لا يُكتب: الاسم المكتوب بخطّ اليد لا يطابقه بحث
// صيدليٍّ آخر، فيضيع الإعلان. وللدواء خارج الكتالوج مخرجٌ صريح بإدخال يدوي.
//
// المنطقة ليست حقلاً: تُؤخذ من ملف صيدلية المعلِن ضمنياً — الإعلان محلّي
// بطبيعته، وتركها قابلة للتعديل يسمح بإعلانٍ في مدينة لا يملك فيها شيئاً.
class PhCreateListingPage extends ConsumerStatefulWidget {
  const PhCreateListingPage({super.key});

  @override
  ConsumerState<PhCreateListingPage> createState() =>
      _PhCreateListingPageState();
}

class _PhCreateListingPageState extends ConsumerState<PhCreateListingPage> {
  final _formKey = GlobalKey<FormState>();

  final _medicineCtrl = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  PhListingReason _reason = PhListingReason.slowMoving;
  DateTime? _expiryDate;
  bool _submitting = false;
  String? _submitError;

  /// الصنف المختار من الكتالوج — null يعني إدخالاً يدوياً أو لا اختيار بعد.
  MedicineCatalogItem? _picked;

  /// مخرج الدواء غير المفهرس: يكشف حقل الاسم الحرّ.
  bool _manualEntry = false;

  Future<void> _pickFromCatalog() async {
    final item = await showModalBottomSheet<MedicineCatalogItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CatalogPickerSheet(),
    );
    if (item == null || !mounted) return;
    setState(() {
      _picked = item;
      _manualEntry = false;
      _medicineCtrl.text = item.displayName;
      _manufacturerCtrl.text = item.manufacturerName;
    });
  }

  void _clearPicked() {
    setState(() {
      _picked = null;
      _medicineCtrl.clear();
      _manufacturerCtrl.clear();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _medicineCtrl, _manufacturerCtrl, _quantityCtrl,
      _priceCtrl, _notesCtrl,
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
    if (_medicineCtrl.text.trim().isEmpty) {
      setState(() => _submitError = 'اختر الدواء من الكتالوج أو أدخل اسمه');
      return;
    }
    if (_reason == PhListingReason.nearExpiry && _expiryDate == null) {
      setState(() => _submitError = 'يرجى تحديد تاريخ انتهاء الصلاحية');
      return;
    }
    // المنطقة تُؤخذ من ملف الصيدلية — بلا ملف لا إعلان، فإرسال منطقة
    // فارغة يُنشئ إعلاناً لا يراه أحد في بحث المنطقة.
    final me = ref.read(pharmacyMeProvider).value;
    if (me == null || me.governorate.trim().isEmpty) {
      setState(() => _submitError =
          'تعذّرت قراءة منطقة صيدليتك — حدّث الصفحة ثم أعد المحاولة');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final req = CreatePhListingRequest(
        medicineName: _medicineCtrl.text.trim(),
        manufacturer: _manufacturerCtrl.text.trim().isEmpty
            ? null
            : _manufacturerCtrl.text.trim(),
        quantity: int.parse(_quantityCtrl.text.trim()),
        pricePerUnit: double.parse(_priceCtrl.text.trim()),
        expiryDate: _expiryDate,
        reason: _reason,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        governorate: me.governorate.trim(),
        city: me.city.trim(),
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
            _MedicinePickerField(
              picked: _picked,
              onPick: _pickFromCatalog,
              onClear: _clearPicked,
            ),

            // مخرج الدواء غير المفهرس — لا يُعرض ما دام هناك صنف مختار.
            if (_picked == null) ...[
              const SizedBox(height: AppSpacing.sm),
              if (!_manualEntry)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setState(() => _manualEntry = true),
                    child: Text(
                      'الدواء غير موجود في الكتالوج؟ أدخل اسمه يدوياً',
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.primary),
                    ),
                  ),
                )
              else
                AppTextField(
                  controller: _medicineCtrl,
                  label: 'اسم الدواء *',
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
            ],

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
                    label:
                        'السعر (${currencySymbol(ref.watch(pharmacyMeProvider).value?.pricingCurrency ?? 'SYP')}/الوحدة) *',
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
            const SizedBox(height: AppSpacing.sm),
            _RegionRow(me: ref.watch(pharmacyMeProvider)),

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
            const SizedBox(height: AppSpacing.sm),
            Text(
              'ينتهي الإعلان تلقائياً بعد 3 أيام في حال عدم وجود استجابة، '
              'أو عند الاتفاق بين الطرفين.',
              style: context.text.bodySmall?.copyWith(color: context.tokens.hint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── حقل اختيار الدواء من الكتالوج ───────────────────────────────────────
class _MedicinePickerField extends StatelessWidget {
  const _MedicinePickerField({
    required this.picked,
    required this.onPick,
    required this.onClear,
  });

  final MedicineCatalogItem? picked;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final item = picked;

    return Material(
      color: item == null ? cs.surface : tk.brandSurfaceSubtle,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: item == null ? cs.outline : cs.primary,
              width: item == null ? 1 : 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item == null ? tk.brandSurface : cs.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: AppIcon(
                    AppIcons.pill,
                    size: 18,
                    color: item == null ? cs.primary : cs.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: item == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('اختر الدواء من الكتالوج *',
                              style: context.text.bodyMedium),
                          const SizedBox(height: 2),
                          Text(
                            'ابحث بالاسم التجاري أو الجنيسي أو الباركود',
                            style: context.text.labelSmall
                                ?.copyWith(color: tk.hint),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.displayName,
                            style: context.text.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitleOf(item),
                            style: context.text.labelSmall
                                ?.copyWith(color: tk.hint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (item == null)
                AppIcon(AppIcons.chevronForwardRtl, size: 16, color: cs.primary)
              else
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: AppIcon(AppIcons.x, size: 16, color: cs.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «الجنيسي · الشركة» — وبلا شركة الجنيسي وحده، فلا تبقى نقطة معلّقة.
String _subtitleOf(MedicineCatalogItem m) => m.manufacturerName.isEmpty
    ? m.genericName
    : '${m.genericName} · ${m.manufacturerName}';

// ── ورقة البحث في الكتالوج ──────────────────────────────────────────────
class _CatalogPickerSheet extends ConsumerStatefulWidget {
  const _CatalogPickerSheet();

  @override
  ConsumerState<_CatalogPickerSheet> createState() =>
      _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends ConsumerState<_CatalogPickerSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<MedicineCatalogItem> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty || !mounted) return;

    // الباركود يُنفَّذ فوراً لا بعد مهلة الكتابة: ليس حرفاً يُتبَع بآخر.
    _debounce?.cancel();
    _searchCtrl.text = code;
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    // أربعة أعشار الثانية: كتابة اسم دواء لا تستحق رحلة شبكة لكل حرف.
    _debounce = Timer(const Duration(milliseconds: 400), _run);
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _searchCtrl.text.trim();
      final list = await ref
          .read(medicineCatalogRepositoryProvider)
          .search(name: q.isEmpty ? null : q, limit: 30);
      if (!mounted) return;
      setState(() {
        _results = list;
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

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('اختيار الدواء', style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: AppSearchBar(
                controller: _searchCtrl,
                hint: 'ابحث بالاسم التجاري أو الجنيسي أو الباركود',
                onChanged: _onChanged,
                onSubmitted: (_) => _run(),
                // التلميح كان يَعِد بالباركود بلا وسيلةٍ لإدخاله إلا طبعه
                // رقماً رقماً. والماسح هو نفسه المستعمَل في بقية شاشات
                // البحث — نفس المكوّن ونفس السلوك.
                onScanTap: _scanBarcode,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: _loading
                  ? const AppListSkeleton(variant: SkeletonVariant.row)
                  : _error != null
                      ? ErrorState(message: _error!, onRetry: _run)
                      : _results.isEmpty
                          ? const UiEmpty(
                              appIcon: AppIcons.pill,
                              message: 'لا دواء يطابق بحثك',
                              description: 'جرّب اسماً آخر، أو أغلق هذه '
                                  'النافذة وأدخل الاسم يدوياً.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.page,
                                0,
                                AppSpacing.page,
                                AppSpacing.xl,
                              ),
                              itemCount: _results.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (_, i) {
                                final m = _results[i];
                                return AppCard(
                                  onTap: () => Navigator.pop(context, m),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: tk.brandSurface,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  AppRadius.sm),
                                        ),
                                        child: Center(
                                          child: AppIcon(AppIcons.pill,
                                              size: 18, color: cs.primary),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.displayName,
                                              style: context.text.bodyMedium,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _subtitleOf(m),
                                              style: context.text.labelSmall
                                                  ?.copyWith(color: tk.hint),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── المنطقة (عرض فقط) ───────────────────────────────────────────────────
// تُؤخذ من ملف صيدلية المعلِن ولا تُحرَّر: الإعلان محلّي، ومنطقته منطقة
// صاحبه لا خياراً يُكتب.
class _RegionRow extends StatelessWidget {
  const _RegionRow({required this.me});

  final AsyncValue<PharmacyMe> me;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    final (String text, bool pending) = switch (me) {
      AsyncData(:final value) when value.governorate.isNotEmpty => (
          value.city.isEmpty
              ? value.governorate
              : '${value.city}، ${value.governorate}',
          false,
        ),
      AsyncError() => ('تعذّرت قراءة منطقة صيدليتك', true),
      _ => ('جارٍ قراءة منطقة صيدليتك…', true),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tk.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          AppIcon(
            AppIcons.mapPin,
            size: 18,
            color: pending ? tk.hint : cs.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: context.text.bodyMedium?.copyWith(
                    color: pending ? tk.hint : cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'تُؤخذ من ملف صيدليتك ولا تُعدَّل هنا',
                  style: context.text.labelSmall?.copyWith(color: tk.hint),
                ),
              ],
            ),
          ),
        ],
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
