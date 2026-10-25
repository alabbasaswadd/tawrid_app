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
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/medicine_list_tile.dart';

// أدوية المستودع — مرجعٌ فقط (أيّ أدوية يتعامل بها المستودع)، بلا ربط
// مخزون/كميات (قرار نطاق مقصود حالياً). تُغذّي قائمة اختيار الأدوية عند
// إنشاء عرض بيع. بحث فوري + عدّاد علوي لتصفّح أسرع عند كِبر القائمة.
class WhMedicinesPage extends ConsumerStatefulWidget {
  const WhMedicinesPage({super.key});

  @override
  ConsumerState<WhMedicinesPage> createState() => _WhMedicinesPageState();
}

class _WhMedicinesPageState extends ConsumerState<WhMedicinesPage> {
  final _search = TextEditingController();
  List<WarehouseMedicine>? _medicines;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(warehouseMedicineRepositoryProvider).getMine();
      setState(() {
        _medicines = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _openCatalog() async {
    await context.push(TRoutes.whMedicineCatalog);
    _load();
  }

  Future<void> _confirmRemove(WarehouseMedicine m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف دواء',
            style: Theme.of(ctx).textTheme.titleMedium),
        content: Text('إزالة "${m.displayName}" من قائمة أدوية مستودعك؟',
            style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(warehouseMedicineRepositoryProvider).remove(m.id);
      if (mounted) _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  List<WarehouseMedicine> get _filtered {
    final list = _medicines ?? [];
    final q = _search.text.trim();
    if (q.isEmpty) return list;
    return list
        .where((m) =>
            m.displayName.contains(q) ||
            m.genericName.contains(q) ||
            m.manufacturerName.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('أدويتي'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCatalog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة دواء'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث في أدويتك...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: [
                  Text('${_filtered.length} من ${_medicines?.length ?? 0} دواء',
                      style: context.text.bodySmall
                          ?.copyWith(color: tk.hint)),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final all = _medicines ?? [];
    if (all.isEmpty) {
      return const EmptyState(
        message:
            'لا توجد أدوية في مستودعك بعد\nاضغط "إضافة دواء" للاختيار من الكاتالوج',
        icon: Icons.medication_outlined,
      );
    }

    final medicines = _filtered;
    if (medicines.isEmpty) {
      return const EmptyState(
          message: 'لا نتائج مطابقة للبحث',
          icon: Icons.search_off_outlined);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 88),
        itemCount: medicines.length,
        itemBuilder: (context, index) {
          final m = medicines[index];
          return MedicineListTile(
            displayName: m.displayName,
            genericName: m.genericName,
            manufacturerName: m.manufacturerName,
            dosageForm: m.dosageForm,
            strength: m.strength,
            trailing: IconButton(
              icon: Icon(Icons.delete_outline,
                  color: context.colors.error),
              onPressed: () => _confirmRemove(m),
            ),
          );
        },
      ),
    );
  }
}
