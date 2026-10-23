import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/repositories/warehouse_service_area_repository.dart';

// مُنتقي مناطق مستهدفة متعددة لعرض البيع — يعرض المناطق المختارة كرقاقات
// مقروءة، ويفتح ورقة اختيار تعرض **مناطق خدمة المستودع فقط** (لا كل سوريا)
// مجمّعة حسب المحافظة مع تحديد متعدد.
class MultiRegionPicker extends StatelessWidget {
  const MultiRegionPicker({
    required this.regions,
    required this.onChanged,
    super.key,
  });

  final List<TargetRegion> regions;
  final ValueChanged<List<TargetRegion>> onChanged;

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<List<TargetRegion>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SelectRegionsSheet(initial: regions),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (regions.isEmpty)
          InkWell(
            onTap: () => _openSheet(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md, horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TawridColors.warehouse.withValues(alpha: 0.35)),
                color: TawridColors.warehouse.withValues(alpha: 0.04),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_location_alt_outlined,
                      color: TawridColors.warehouse, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('اختر مناطق الاستهداف من مناطق خدمتك',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13, color: TawridColors.warehouse, fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_left, color: TawridColors.warehouse),
                ],
              ),
            ),
          )
        else ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < regions.length; i++)
                Chip(
                  label: Text(regions[i].label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5)),
                  avatar: const Icon(Icons.location_on,
                      size: 16, color: TawridColors.warehouse),
                  onDeleted: () {
                    final next = [...regions]..removeAt(i);
                    onChanged(next);
                  },
                  backgroundColor: TawridColors.warehouse.withValues(alpha: 0.08),
                  side: BorderSide(color: TawridColors.warehouse.withValues(alpha: 0.2)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: () => _openSheet(context),
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: Text('تعديل المناطق (${regions.length})',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5)),
            style: TextButton.styleFrom(
              foregroundColor: TawridColors.warehouse,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectRegionsSheet extends ConsumerStatefulWidget {
  const _SelectRegionsSheet({required this.initial});
  final List<TargetRegion> initial;

  @override
  ConsumerState<_SelectRegionsSheet> createState() => _SelectRegionsSheetState();
}

class _SelectRegionsSheetState extends ConsumerState<_SelectRegionsSheet> {
  late List<TargetRegion> _sel;

  @override
  void initState() {
    super.initState();
    _sel = [...widget.initial];
  }

  bool _isCity(String gov, String city) =>
      _sel.any((r) => r.governorate == gov && r.city == city);
  bool _isWhole(String gov) =>
      _sel.any((r) => r.governorate == gov && (r.city == null || r.city!.isEmpty));

  void _toggleCity(String gov, String city) {
    setState(() {
      if (_isCity(gov, city)) {
        _sel.removeWhere((r) => r.governorate == gov && r.city == city);
      } else {
        // اختيار مدينة محددة يلغي اختيار «كل المحافظة»
        _sel.removeWhere((r) => r.governorate == gov && (r.city == null || r.city!.isEmpty));
        _sel.add(TargetRegion(governorate: gov, city: city));
      }
    });
  }

  void _toggleWhole(String gov) {
    setState(() {
      if (_isWhole(gov)) {
        _sel.removeWhere((r) => r.governorate == gov && (r.city == null || r.city!.isEmpty));
      } else {
        // «كل المحافظة» يلغي اختيار المدن المفردة لنفس المحافظة
        _sel.removeWhere((r) => r.governorate == gov);
        _sel.add(TargetRegion(governorate: gov, city: null));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(myServiceGovernoratesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42, height: 4,
              decoration: BoxDecoration(
                color: Colors.black12, borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اختر مناطق الاستهداف',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('من مناطق خدمة مستودعك فقط',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: TawridColors.hint)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: areas.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('تعذّر تحميل مناطق الخدمة',
                        style: GoogleFonts.ibmPlexSansArabic(color: TawridColors.hint)),
                  ),
                ),
                data: (govs) {
                  if (govs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_outlined, size: 42, color: TawridColors.hint),
                            const SizedBox(height: AppSpacing.sm),
                            Text('لم تُحدَّد مناطق خدمة لمستودعك بعد',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('حدِّد مناطق التغطية من: المستودع ← مناطق الخدمة',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: TawridColors.hint)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
                    itemCount: govs.length,
                    separatorBuilder: (_, i) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final g = govs[i];
                      final whole = _isWhole(g.name);
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                          color: Colors.grey.withValues(alpha: 0.03),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_city_outlined,
                                    size: 18, color: TawridColors.warehouse),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(g.name,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 14, fontWeight: FontWeight.w700)),
                                ),
                                FilterChip(
                                  label: Text('كل المحافظة',
                                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5)),
                                  selected: whole,
                                  onSelected: (_) => _toggleWhole(g.name),
                                  selectedColor: TawridColors.warehouse.withValues(alpha: 0.15),
                                  checkmarkColor: TawridColors.warehouse,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                for (final c in g.cities)
                                  FilterChip(
                                    label: Text(c.name,
                                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5)),
                                    selected: whole || _isCity(g.name, c.name),
                                    onSelected:
                                        whole ? null : (_) => _toggleCity(g.name, c.name),
                                    selectedColor:
                                        TawridColors.warehouse.withValues(alpha: 0.15),
                                    checkmarkColor: TawridColors.warehouse,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    Text('${_sel.length} منطقة مختارة',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: TawridColors.hint)),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, _sel),
                      child: const Text('تطبيق'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
