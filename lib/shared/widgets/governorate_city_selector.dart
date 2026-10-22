import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/models/geo_models.dart';
import 'package:tawrid_app/repositories/geo_repository.dart';

// زوج قوائم منسدلة (محافظة ← مدينة) تُحمَّل من الخادم (governoratesProvider)
// بدل الكتابة الحرّة — تغيير المحافظة يُصفّي قائمة المدن تلقائياً ويصفّر
// المدينة المختارة. يُستخدَم في تسجيل الصيدلي وتسجيل المستودع.
class GovernorateCitySelector extends ConsumerWidget {
  const GovernorateCitySelector({
    required this.governorateId,
    required this.cityId,
    required this.onGovernorateChanged,
    required this.onCityChanged,
    this.cityRequired = false,
    super.key,
  });

  final String? governorateId;
  final String? cityId;
  final ValueChanged<String?> onGovernorateChanged;
  final ValueChanged<String?> onCityChanged;
  final bool cityRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final governoratesAsync = ref.watch(governoratesProvider);

    return governoratesAsync.when(
      data: (governorates) {
        Governorate? selected;
        for (final g in governorates) {
          if (g.id == governorateId) {
            selected = g;
            break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: governorateId,
              decoration: const InputDecoration(
                labelText: 'المحافظة',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: governorates
                  .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
                  .toList(),
              onChanged: (v) {
                onGovernorateChanged(v);
                onCityChanged(null);
              },
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              // مفتاح مرتبط بالمحافظة لإعادة بناء القائمة عند تغييرها بدل
              // الاحتفاظ بقيمة قد لا تكون ضمن المدن الجديدة.
              key: ValueKey('city-selector-$governorateId'),
              initialValue: cityId,
              decoration: InputDecoration(
                labelText: cityRequired ? 'المدينة' : 'المدينة (اختياري)',
                prefixIcon: const Icon(Icons.location_city_outlined),
              ),
              items: (selected?.cities ?? const [])
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: selected == null ? null : onCityChanged,
              validator: cityRequired ? (v) => v == null ? 'مطلوب' : null : null,
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: CircularProgressIndicator(color: TawridColors.primary)),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          'تعذّر تحميل قائمة المحافظات، تحقّق من الاتصال',
          style: TextStyle(color: TawridColors.error, fontSize: 13),
        ),
      ),
    );
  }
}
