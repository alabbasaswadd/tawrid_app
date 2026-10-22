import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/medicine_catalog_models.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/repositories/warehouse_medicine_repository.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/medicine_list_tile.dart';

// تصفّح/بحث مكتبة الأدوية المركزية (الكاتالوج العام) وإضافة ما يُريده
// المستودع إلى قائمته (lib/features/wh_medicines/wh_medicines_page.dart) —
// بلا ربط مخزون.
class WhMedicineCatalogPage extends ConsumerStatefulWidget {
  const WhMedicineCatalogPage({super.key});

  @override
  ConsumerState<WhMedicineCatalogPage> createState() => _WhMedicineCatalogPageState();
}

class _WhMedicineCatalogPageState extends ConsumerState<WhMedicineCatalogPage> {
  final _searchController = TextEditingController();
  List<MedicineCatalogItem>? _results;
  Set<String> _addedCatalogIds = {};
  final Set<String> _addingNow = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mine = await ref.read(warehouseMedicineRepositoryProvider).getMine();
      _addedCatalogIds = mine.map((m) => m.catalogItemId).toSet();
      await _search();
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _searchController.text.trim();
      final list = await ref
          .read(medicineCatalogRepositoryProvider)
          .search(name: query.isEmpty ? null : query);
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _add(MedicineCatalogItem item) async {
    setState(() => _addingNow.add(item.id));
    try {
      await ref.read(warehouseMedicineRepositoryProvider).add(item.id);
      if (mounted) {
        setState(() {
          _addedCatalogIds.add(item.id);
          _addingNow.remove(item.id);
        });
        AppSnackbar.success(context, 'تمت إضافة ${item.displayName} إلى مستودعك');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addingNow.remove(item.id));
        AppSnackbar.error(context, ApiException.from(e).message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختيار من الكاتالوج')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم التجاري أو العلمي أو الباركود...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _search);

    final results = _results ?? [];
    if (results.isEmpty) {
      return const EmptyState(message: 'لا توجد نتائج', icon: Icons.search_off_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        final added = _addedCatalogIds.contains(item.id);
        final adding = _addingNow.contains(item.id);

        return MedicineListTile(
          displayName: item.displayName,
          genericName: item.genericName,
          manufacturerName: item.manufacturerName,
          dosageForm: item.dosageForm,
          strength: item.strength,
          trailing: added
              ? const Icon(Icons.check_circle, color: TawridColors.success)
              : adding
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: TawridColors.warehouse),
                      onPressed: () => _add(item),
                    ),
        );
      },
    );
  }
}
