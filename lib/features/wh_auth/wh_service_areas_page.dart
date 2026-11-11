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

// مناطق التغطية (Figma: المستودع / مناطق التغطية).
//
// تُعرَض بعد تسجيل المستودع ومن الإعدادات معاً. المحافظات والمدن تُجلَب
// كاملةً من الخادم، فإضافة منطقة جديدة مستقبلاً لا تحتاج تعديلاً هنا.
class WhServiceAreasPage extends ConsumerStatefulWidget {
  const WhServiceAreasPage({super.key});

  @override
  ConsumerState<WhServiceAreasPage> createState() => _WhServiceAreasPageState();
}

class _WhServiceAreasPageState extends ConsumerState<WhServiceAreasPage> {
  List<Governorate>? _governorates;
  final Set<String> _selected = {};

  /// المحافظات المفتوحة — الكل مطويّ بدءاً: أربع عشرة محافظة مفتوحة
  /// تجعل الشاشة جداراً من المدن.
  final Set<String> _expanded = {};
  String _query = '';

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
      if (!mounted) return;
      setState(() {
        _governorates = governorates;
        _selected
          ..clear()
          ..addAll(existing);
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
      final selectAll = current != true; // عند false أو null: حدِّد الكل
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
      if (!mounted) return;
      AppSnackbar.success(context, 'حُفظت مناطق التغطية');
      context.go(TRoutes.whHome);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// المحافظات المطابقة للبحث — بالاسم أو باسم أي مدينة فيها.
  List<Governorate> get _visible {
    final all = _governorates ?? const <Governorate>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((g) =>
            g.name.toLowerCase().contains(q) ||
            g.cities.any((c) => c.name.toLowerCase().contains(q)))
        .toList();
  }

  /// شرائح ما اختير: «محافظة · مدينة»، وتُختصر إلى «كل المدن» للمحافظة
  /// المكتملة بدل سرد عشر مدن في عشر شرائح.
  List<(String label, String cityId)> get _selectedChips {
    final out = <(String, String)>[];
    for (final g in _governorates ?? const <Governorate>[]) {
      final picked = g.cities.where((c) => _selected.contains(c.id)).toList();
      if (picked.isEmpty) continue;
      if (picked.length == g.cities.length) {
        out.add(('${g.name} · كل المدن', picked.first.id));
      } else {
        for (final c in picked) {
          out.add(('${g.name} · ${c.name}', c.id));
        }
      }
    }
    return out;
  }

  void _removeChip(String cityId) {
    final all = _governorates ?? const <Governorate>[];
    final match = all.where((g) => g.cities.any((c) => c.id == cityId));
    if (match.isEmpty) return;
    final g = match.first;

    // شريحة «كل المدن» تحمل معرّف أول مدينة، فإزالتها تُفرغ المحافظة كلها.
    final whole =
        g.cities.isNotEmpty && g.cities.every((c) => _selected.contains(c.id));

    setState(() {
      if (whole) {
        for (final c in g.cities) {
          _selected.remove(c.id);
        }
      } else {
        _selected.remove(cityId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'مناطق التغطية'),
      body: _buildBody(),
      bottomNavigationBar: _loading || _error != null ? null : _buildSaveBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final tk = context.tokens;
    final cs = context.colors;
    final chips = _selectedChips;
    final govCount = (_governorates ?? const <Governorate>[])
        .where((g) => g.cities.any((c) => _selected.contains(c.id)))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.x3l),
      children: [
        Text(
          'عدّل نطاق توزيعك: أضف محافظات ومدناً أو أزلها، ثم احفظ التعديلات. '
          'تنعكس التغييرات على ظهور عروضك فوراً.',
          style: context.text.bodySmall?.copyWith(color: tk.hint),
        ),
        const SizedBox(height: AppSpacing.md),

        AppSearchBar(
          hint: 'ابحث عن محافظة أو مدينة…',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          children: [
            Expanded(
              child: Text(
                'المناطق المختارة: ${_selected.length} '
                '${_selected.length == 1 ? 'مدينة' : 'مدن'} في '
                '$govCount ${govCount == 1 ? 'محافظة' : 'محافظات'}',
                style: context.text.bodySmall?.copyWith(color: tk.hint),
              ),
            ),
            if (_selected.isNotEmpty)
              TextButton(
                onPressed: () => setState(_selected.clear),
                style: TextButton.styleFrom(foregroundColor: cs.error),
                child: const Text('مسح الكل'),
              ),
          ],
        ),

        if (chips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (label, cityId) in chips)
                AppFilterChip(
                  label: label,
                  onRemoved: () => _removeChip(cityId),
                ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        if (_visible.isEmpty)
          const EmptyState(
            icon: Icons.place_outlined,
            message: 'لا محافظة أو مدينة تطابق بحثك',
          )
        else
          for (final g in _visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _GovernorateCard(
                governorate: g,
                selected: _selected,
                // البحث يفتح المطابِقة تلقائياً لتظهر المدينة المقصودة.
                expanded: _expanded.contains(g.id) || _query.trim().isNotEmpty,
                state: switch (_governorateState(g)) {
                  true => AppCheckState.all,
                  false => AppCheckState.none,
                  _ => AppCheckState.partial,
                },
                onToggleExpanded: () => setState(() {
                  if (!_expanded.remove(g.id)) _expanded.add(g.id);
                }),
                onToggleAll: () => _toggleGovernorate(g),
                onToggleCity: _toggleCity,
              ),
            ),
      ],
    );
  }

  Widget _buildSaveBar() {
    final cs = context.colors;
    final tk = context.tokens;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline)),
          boxShadow: tk.navShadow,
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
        child: AppButton(
          label: 'حفظ التعديلات',
          loading: _saving,
          // الحفظ بلا مناطق مسموح عمداً: مستودع بلا مناطق يُعدّ خادماً
          // للجميع في الخادم، وهو اختيار مشروع لا خطأ.
          onPressed: _saving ? null : _save,
        ),
      ),
    );
  }
}

// بطاقة محافظة قابلة للطيّ (Figma): صف المحافظة بمربع ثلاثي الحالة، ثم
// صفوف المدن، ثم رابط «اختيار كل مدن …».
class _GovernorateCard extends StatelessWidget {
  const _GovernorateCard({
    required this.governorate,
    required this.selected,
    required this.expanded,
    required this.state,
    required this.onToggleExpanded,
    required this.onToggleAll,
    required this.onToggleCity,
  });

  final Governorate governorate;
  final Set<String> selected;
  final bool expanded;
  final AppCheckState state;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleAll;
  final void Function(String cityId, bool value) onToggleCity;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final g = governorate;
    final picked = g.cities.where((c) => selected.contains(c.id)).length;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // حدّ بلون العلامة حين يكون في المحافظة اختيار — تمييز بصري يُغني
        // عن قراءة كل بطاقة لمعرفة أين اختار.
        border: Border.all(
            color: state == AppCheckState.none ? cs.outline : cs.primary),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Column(
        children: [
          GovernorateRow(
            name: g.name,
            selection: state,
            countLabel: switch (state) {
              AppCheckState.all => 'كل المدن',
              AppCheckState.partial => '$picked من ${g.cities.length}',
              AppCheckState.none => null,
            },
            expanded: expanded,
            onTap: onToggleExpanded,
            onCheckboxTap: onToggleAll,
          ),
          if (expanded) ...[
            Divider(height: 1, color: cs.outline),
            for (final c in g.cities)
              CityRow(
                name: c.name,
                selected: selected.contains(c.id),
                onTap: () => onToggleCity(c.id, !selected.contains(c.id)),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onToggleAll,
                child: Text(
                  state == AppCheckState.all
                      ? 'إلغاء كل مدن ${g.name}'
                      : 'اختيار كل مدن ${g.name} (${g.cities.length})',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
