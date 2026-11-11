import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/medicine_catalog_models.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/medicine_list_tile.dart';

// البحث عن تفاصيل الأدوية (نشرة الأسعار) — بحث أونلاين حيّ + ترقيم صفحات +
// مسح باركود، مع عرض تفاصيل الدواء عند الضغط عليه.
class PhMedicineSearchPage extends ConsumerStatefulWidget {
  const PhMedicineSearchPage({super.key});

  @override
  ConsumerState<PhMedicineSearchPage> createState() => _PhMedicineSearchPageState();
}

class _PhMedicineSearchPageState extends ConsumerState<PhMedicineSearchPage> {
  static const int _pageSize = 30;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  final List<MedicineCatalogItem> _results = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _runSearch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(reset: true));
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _runSearch({required bool reset}) async {
    final query = _searchController.text.trim();
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _offset = 0;
        _hasMore = true;
      });
    }
    try {
      final list = await ref.read(medicineCatalogRepositoryProvider).search(
            name: query.isEmpty ? null : query,
            limit: _pageSize,
            offset: reset ? 0 : _offset,
          );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _results
            ..clear()
            ..addAll(list);
        } else {
          _results.addAll(list);
        }
        _offset = _results.length;
        _hasMore = list.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    await _runSearch(reset: false);
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty) return;
    _searchController.text = code;
    _runSearch(reset: true);
  }

  void _showDetails(MedicineCatalogItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MedicineDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('البحث عن دواء')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _runSearch(reset: true),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الباركود (أونلاين)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Container(
                  margin: const EdgeInsetsDirectional.only(end: 6),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.qr_code_scanner, color: context.colors.primary),
                    tooltip: 'مسح باركود',
                    onPressed: _scanBarcode,
                  ),
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
    if (_error != null) return ErrorState(message: _error!, onRetry: () => _runSearch(reset: true));
    if (_results.isEmpty) {
      return const EmptyState(message: 'لا توجد نتائج', icon: Icons.search_off_outlined);
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final item = _results[index];
        return MedicineListTile(
          displayName: item.displayName,
          genericName: item.genericName,
          manufacturerName: item.manufacturerName,
          dosageForm: item.dosageForm,
          strength: item.strength,
          trailing: IconButton(
            icon: Icon(Icons.info_outline, color: context.colors.primary),
            tooltip: 'التفاصيل',
            onPressed: () => _showDetails(item),
          ),
        );
      },
    );
  }
}

class _MedicineDetailSheet extends StatelessWidget {
  const _MedicineDetailSheet({required this.item});
  final MedicineCatalogItem item;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(color: cs.outline, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(item.displayName, style: context.text.titleLarge),
            if (item.foreignName.isNotEmpty)
              Text(item.foreignName, style: context.text.bodySmall),
            const SizedBox(height: AppSpacing.md),
            _row(context, 'الاسم العلمي', item.genericName),
            _row(context, 'الشركة', item.manufacturerName),
            _row(context, 'الشكل الدوائي',
                item.strength > 0 ? '${item.dosageForm.label} ${item.strength}' : item.dosageForm.label),
            if (item.barcode.isNotEmpty) _row(context, 'الباركود', item.barcode),
            if (item.sakoCode.isNotEmpty) _row(context, 'رمز ساكو', item.sakoCode),
            const Divider(height: AppSpacing.lg),
            _priceRow(context, 'سعر الصيدلي', item.pricePharmacist, item.currency),
            _priceRow(context, 'سعر الجمهور', item.pricePublic, item.currency),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: context.text.bodySmall)),
          Expanded(child: Text(value, style: context.text.bodyMedium)),
        ],
      ),
    );
  }

  Widget _priceRow(BuildContext context, String label, double value, String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: context.text.bodySmall)),
          Text('${value.toStringAsFixed(0)} $currency',
              style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
        ],
      ),
    );
  }
}
