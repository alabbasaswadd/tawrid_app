import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/repositories/geo_repository.dart';
import 'package:tawrid_app/shared/widgets/governorate_city_selector.dart';

// مُنتقي مناطق مستهدفة متعددة لعرض البيع — عرض واحد قد يستهدف أكثر من
// محافظة وأكثر من مدينة، فيُعرض كقائمة رقاقات (chips) قابلة للحذف، مع
// زر "إضافة منطقة" يفتح ورقة سفلية لاختيار محافظة (ومدينة اختيارية).
class MultiRegionPicker extends StatelessWidget {
  const MultiRegionPicker({
    required this.regions,
    required this.onChanged,
    super.key,
  });

  final List<TargetRegion> regions;
  final ValueChanged<List<TargetRegion>> onChanged;

  Future<void> _addRegion(BuildContext context) async {
    final picked = await showModalBottomSheet<TargetRegion>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddRegionSheet(),
    );
    if (picked == null) return;

    final exists = regions.any((r) => r.governorate == picked.governorate && r.city == picked.city);
    if (exists) return;
    onChanged([...regions, picked]);
  }

  void _removeAt(int index) {
    final next = [...regions]..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < regions.length; i++)
              Chip(
                label: Text(regions[i].label, style: GoogleFonts.cairo(fontSize: 12.5)),
                avatar: const Icon(Icons.location_on_outlined, size: 16, color: TawridColors.warehouse),
                onDeleted: () => _removeAt(i),
                backgroundColor: TawridColors.warehouse.withValues(alpha: 0.08),
                side: BorderSide(color: TawridColors.warehouse.withValues(alpha: 0.2)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: TawridColors.warehouse),
              label: Text('إضافة منطقة',
                  style: GoogleFonts.cairo(fontSize: 12.5, color: TawridColors.warehouse)),
              onPressed: () => _addRegion(context),
            ),
          ],
        ),
        if (regions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('أضف محافظة ومدينة واحدة على الأقل',
                style: GoogleFonts.cairo(fontSize: 11.5, color: TawridColors.hint)),
          ),
      ],
    );
  }
}

class _AddRegionSheet extends ConsumerStatefulWidget {
  const _AddRegionSheet();

  @override
  ConsumerState<_AddRegionSheet> createState() => _AddRegionSheetState();
}

class _AddRegionSheetState extends ConsumerState<_AddRegionSheet> {
  String? _governorateId;
  String? _cityId;

  @override
  Widget build(BuildContext context) {
    final governorates = ref.watch(governoratesProvider).value ?? [];

    String? governorateName;
    String? cityName;
    for (final g in governorates) {
      if (g.id == _governorateId) {
        governorateName = g.name;
        for (final c in g.cities) {
          if (c.id == _cityId) cityName = c.name;
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('إضافة منطقة مستهدفة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('اختر محافظة، والمدينة اختيارية (بلا مدينة = كل مدن المحافظة)',
              style: GoogleFonts.cairo(fontSize: 12, color: TawridColors.hint)),
          const SizedBox(height: AppSpacing.md),
          GovernorateCitySelector(
            governorateId: _governorateId,
            cityId: _cityId,
            onGovernorateChanged: (v) => setState(() {
              _governorateId = v;
              _cityId = null;
            }),
            onCityChanged: (v) => setState(() => _cityId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: governorateName == null
                ? null
                : () => Navigator.pop(
                      context,
                      TargetRegion(governorate: governorateName!, city: cityName),
                    ),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
