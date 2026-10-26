import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/geo_models.dart';
import 'package:tawrid_app/repositories/geo_repository.dart';
import 'package:tawrid_app/repositories/warehouse_service_area_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// تُعرَض مباشرةً بعد نجاح تسجيل المستودع: يختار المستودع المحافظات/المدن
// التي يُوصّل إليها. المحافظات والمدن تُجلَب بالكامل من الخادم
// (GeoRepository) — إضافة منطقة جديدة مستقبلاً لا تحتاج أي تعديل هنا.
class WhServiceAreasPage extends ConsumerStatefulWidget {
  const WhServiceAreasPage({super.key});

  @override
  ConsumerState<WhServiceAreasPage> createState() => _WhServiceAreasPageState();
}

class _WhServiceAreasPageState extends ConsumerState<WhServiceAreasPage> {
  List<Governorate>? _governorates;
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final geo = ref.read(geoRepositoryProvider);
      final areasRepo = ref.read(warehouseServiceAreaRepositoryProvider);
      final governorates = await geo.getGovernorates();
      final existing = await areasRepo.getMyServiceAreas();
      setState(() {
        _governorates = governorates;
        _selected
          ..clear()
          ..addAll(existing);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  // null = بعض مدن المحافظة محدَّدة (حالة متوسّطة)، true = كلّها، false = لا شيء.
  bool? _governorateState(Governorate g) {
    if (g.cities.isEmpty) return false;
    final count = g.cities.where((c) => _selected.contains(c.id)).length;
    if (count == 0) return false;
    if (count == g.cities.length) return true;
    return null;
  }

  void _toggleGovernorate(Governorate g) {
    final current = _governorateState(g);
    setState(() {
      final selectAll = current != true; // عند false أو null → حدِّد الكل
      for (final c in g.cities) {
        if (selectAll) {
          _selected.add(c.id);
        } else {
          _selected.remove(c.id);
        }
      }
    });
  }

  void _toggleCity(String cityId, bool value) {
    setState(() {
      if (value) {
        _selected.add(cityId);
      } else {
        _selected.remove(cityId);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(warehouseServiceAreaRepositoryProvider)
          .setServiceAreas(_selected.toList());
      if (mounted) context.go(TRoutes.whHome);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final heroGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.28)!],
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'مناطق التخديم',
                      style: context.text.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اختر المحافظات والمدن التي يوصّل إليها مستودعك — يمكنك تعديلها لاحقاً',
                      style: context.text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                // Material (لا Container+BoxDecoration) حتى يكون أقرب سلف
                // Material لـ CheckboxListTile — وإلا تُرسَم خلفية القائمة
                // فوق تأثيرات الضغط (ink splashes) وتُخفيها بالكامل.
                child: Material(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final governorates = _governorates!;
    if (governorates.isEmpty) {
      return const EmptyState(
        message: 'لا توجد محافظات متاحة حالياً',
        icon: Icons.map_outlined,
      );
    }

    final cs = context.colors;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: governorates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final g = governorates[index];
              final selectedCount = g.cities
                  .where((c) => _selected.contains(c.id))
                  .length;
              return ExpansionTile(
                leading: Checkbox(
                  tristate: true,
                  value: _governorateState(g),
                  activeColor: cs.primary,
                  onChanged: (_) => _toggleGovernorate(g),
                ),
                title: Text(
                  g.name,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '$selectedCount من ${g.cities.length} مدينة محدَّدة',
                  style: context.text.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                children: g.cities
                    .map(
                      (c) => CheckboxListTile(
                        value: _selected.contains(c.id),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: cs.primary,
                        title: Text(c.name, style: context.text.bodyMedium),
                        onChanged: (v) => _toggleCity(c.id, v ?? false),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_selected.length} مدينة محدَّدة',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'حفظ ومتابعة',
                icon: Icons.check_circle_outline,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _saving ? null : () => context.go(TRoutes.whHome),
                child: const Text('تخطي الآن — يمكنك التعديل لاحقاً'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
