import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/warehouse_medicine_models.dart';
import 'package:tawrid_app/repositories/warehouse_medicine_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// أدوية مستودعي (Figma: المستودع / أدوية مستودعي).
//
// قائمة تعريفية لا مخزون: الأسعار والكميات تُحدَّد داخل كل عرض بيع، وما
// هنا هو «أي أصناف يتعامل بها مستودعي» ليُبنى منها العرض.
class WhMedicinesPage extends ConsumerStatefulWidget {
  const WhMedicinesPage({super.key});

  @override
  ConsumerState<WhMedicinesPage> createState() => _WhMedicinesPageState();
}

class _WhMedicinesPageState extends ConsumerState<WhMedicinesPage> {
  List<WarehouseMedicine>? _items;
  bool _loading = true;
  String? _error;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(warehouseMedicineRepositoryProvider)
          .getMine(search: _query, limit: 50);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    // نصف ثانية: كتابة اسم دواء عربي لا تستحق رحلة شبكة لكل حرف.
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _query = v);
      _load(silent: true);
    });
  }

  Future<void> _remove(WarehouseMedicine m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة من أدويتي'),
        content: Text(
            'سيُزال «${m.displayName}» من قائمة أدوية مستودعك. لا يؤثر ذلك '
            'في العروض المنشورة التي تضمّه.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(warehouseMedicineRepositoryProvider).remove(m.id);
      if (!mounted) return;
      AppSnackbar.success(context, 'أُزيل الدواء من قائمتك');
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  // الماسح حقيقي (mobile_scanner): يُعيد الرمز نصاً فنمرّره إلى البحث
  // نفسه — الباركود مجرّد طريقة أسرع لكتابة ما يُبحث عنه.
  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    // لا حقل نصّي مرتبط — يُمرَّر الرمز مباشرة إلى البحث.
    _onSearchChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أدوية مستودعي'),
        actions: [
          // زر الكتالوج العام: حدٌّ بلون العلامة — ثانوي لا رئيسي.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Material(
              color: Colors.transparent,
              shape: StadiumBorder(side: BorderSide(color: cs.primary)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () async {
                  await context.push(TRoutes.whMedicineCatalog);
                  if (mounted) await _load(silent: true);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('الكتالوج العام',
                          style: context.text.bodySmall
                              ?.copyWith(color: cs.primary)),
                      const SizedBox(width: 6),
                      AppIcon(AppIcons.package, size: 15, color: cs.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final tk = context.tokens;
    final items = _items ?? const <WarehouseMedicine>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.xs, AppSpacing.page, 0),
          child: AppSearchBar(
            hint: 'ابحث في أصناف المخزون…',
            onChanged: _onSearchChanged,
            onScanTap: _scanBarcode,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _loading
                  ? 'جارٍ التحميل…'
                  : '${items.length} ${items.length == 1 ? 'دواء' : 'دواءً'} في مستودعك',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
          ),
        ),

        Expanded(child: _buildList(items)),
      ],
    );
  }

  Widget _buildList(List<WarehouseMedicine> items) {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.x3l),
          EmptyState(
            icon: Icons.medication_outlined,
            message: _query.trim().isNotEmpty
                ? 'لا دواء يطابق بحثك في أدويتك'
                : 'لا أدوية بعد — أضفها من «الكتالوج العام» لتبني عليها عروضك',
          ),
        ],
      );
    }

    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, 0, AppSpacing.page, AppSpacing.x3l),
      children: [
        for (final m in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _MedicineCard(medicine: m, onRemove: () => _remove(m)),
          ),
        const SizedBox(height: AppSpacing.xs),
        // توضيح ما تعنيه القائمة فعلاً — ليست مخزوناً بكميات وأسعار.
        Text(
          'أدوية مستودعك بيانات تعريفية من الكتالوج الوطني تُبنى عليها عروضك. '
          'الأسعار والكميات تُحدَّد داخل كل عرض بيع.',
          style: context.text.labelSmall?.copyWith(color: tk.hint),
        ),
      ],
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine, required this.onRemove});

  final WarehouseMedicine medicine;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final m = medicine;

    final spec = [
      if (m.genericName.isNotEmpty) m.genericName,
      m.dosageForm.label,
      if (m.manufacturerName.isNotEmpty) m.manufacturerName,
    ].join(' · ');

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.displayName,
                    style: context.text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(spec,
                    style: context.text.bodySmall?.copyWith(color: tk.hint),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (m.sakoCode.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('كود ساكو: ${m.sakoCode}',
                      style: context.text.labelSmall?.copyWith(color: tk.hint)),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton.icon(
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 16, color: cs.error),
            label: Text('إزالة', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }
}
