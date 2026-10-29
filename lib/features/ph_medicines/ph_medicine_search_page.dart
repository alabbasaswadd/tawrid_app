import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/offer_summary_card.dart';

// فلتر سريع في صفحة البحث عن عروض الأسعار.
enum _OfferFilter {
  all('الكل'),
  bonus('عروض البونص'),
  expiringSoon('ينتهي قريباً');

  const _OfferFilter(this.label);
  final String label;
}

// البحث في عروض الأسعار (Figma: الصيدلي / البحث عن دواء).
//
// تعرض هذه الشاشة العروض المتاحة مباشرةً (لا الكتالوج العام)، مع بحث حيّ
// وفلاتر سريعة وترتيب.
class PhMedicineSearchPage extends ConsumerStatefulWidget {
  const PhMedicineSearchPage({super.key});

  @override
  ConsumerState<PhMedicineSearchPage> createState() =>
      _PhMedicineSearchPageState();
}

class _PhMedicineSearchPageState extends ConsumerState<PhMedicineSearchPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<SalesOfferSummary> _results = const [];
  bool _loading = true;
  String? _error;

  _OfferFilter _filter = _OfferFilter.all;
  OfferSort _sort = OfferSort.newest;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _runSearch());
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(salesOfferRepositoryProvider).getAvailableOffers(
            search: query.isEmpty ? null : query,
            hasBonus: _filter == _OfferFilter.bonus ? true : null,
            expiringWithinDays: _filter == _OfferFilter.expiringSoon ? 7 : null,
            sort: _sort,
            limit: 40,
          );
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

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    _searchController.text = code;
    _runSearch();
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SortSheet(
        current: _sort,
        onSelect: (s) {
          setState(() => _sort = s);
          _runSearch();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InnerTopBar(
        title: 'البحث في العروض',
        trailing: IconButton(
          icon: AppIcon(AppIcons.sliders, size: 20,
              color: context.colors.onSurface),
          tooltip: 'الترتيب',
          onPressed: _showSortSheet,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.xs, AppSpacing.page, 0),
            child: AppSearchBar(
              controller: _searchController,
              hint: 'ابحث بالاسم أو المادة الفعالة…',
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _runSearch(),
              onScanTap: _scanBarcode,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: _OfferFilter.values.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) {
                final f = _OfferFilter.values[i];
                return AppFilterChip(
                  label: f.label,
                  selected: _filter == f,
                  onTap: () {
                    setState(() => _filter = f);
                    _runSearch();
                  },
                );
              },
            ),
          ),
          if (!_loading && _error == null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.sm, AppSpacing.page, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_results.length} ${_results.length == 1 ? 'عرض' : 'عروض'}',
                      style: context.text.bodySmall
                          ?.copyWith(color: context.tokens.hint),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showSortSheet,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ترتيب: ${_sort.label}',
                          style: context.text.bodySmall?.copyWith(
                              color: context.colors.primary),
                        ),
                        const SizedBox(width: 4),
                        AppIcon(AppIcons.chevronDown,
                            size: 14, color: context.colors.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton();
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _runSearch);
    }
    if (_results.isEmpty) {
      return UiEmpty(
        message: 'لا عروض مطابقة',
        description: _searchController.text.trim().isNotEmpty
            ? 'جرّب تعديل كلمات البحث أو إزالة الفلتر'
            : 'لا توجد عروض متاحة حالياً في منطقتك',
        appIcon: AppIcons.tag,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, 0, AppSpacing.page, AppSpacing.x3l),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) {
        final offer = _results[i];
        return OfferSummaryCard(
          offer: offer,
          // السلّة على مستوى الصنف لا العرض: إضافة عرض كاملاً بلا اختيار
          // أصنافه وكمياتها لا معنى لها، فالزرّ يقود إلى التفاصيل حيث
          // تُختار الأصناف وتُضاف بأسعارها المجمَّدة.
          onAdd: () => context.push(TRoutes.phOfferDetail(offer.id)),
          onDetails: () => context.push(TRoutes.phOfferDetail(offer.id)),
        );
      },
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current, required this.onSelect});
  final OfferSort current;
  final ValueChanged<OfferSort> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text('ترتيب النتائج', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.md),
            for (final s in OfferSort.values)
              ListTile(
                dense: true,
                title: Text(s.label),
                trailing: current == s
                    ? Icon(Icons.check, color: context.colors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelect(s);
                },
              ),
          ],
        ),
      ),
    );
  }
}
