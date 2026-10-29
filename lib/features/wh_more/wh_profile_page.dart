import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/geo_models.dart';
import 'package:tawrid_app/models/warehouse_auth_models.dart';
import 'package:tawrid_app/repositories/geo_repository.dart';
import 'package:tawrid_app/repositories/warehouse_profile_repository.dart';
import 'package:tawrid_app/repositories/warehouse_service_area_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// الملف الشخصي للمستودع: بطاقة بيانات + محرّر مناطق التغطية (قابل للتعديل والحفظ).
class WhProfilePage extends ConsumerStatefulWidget {
  const WhProfilePage({super.key});

  @override
  ConsumerState<WhProfilePage> createState() => _WhProfilePageState();
}

class _WhProfilePageState extends ConsumerState<WhProfilePage> {
  WarehouseMe? _me;
  List<Governorate> _governorates = [];
  final Set<String> _selected = {};
  Set<String> _savedSelection = {};

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
      final results = await Future.wait([
        ref.read(warehouseProfileRepositoryProvider).getMe(),
        ref.read(geoRepositoryProvider).getGovernorates(),
        ref.read(warehouseServiceAreaRepositoryProvider).getMyServiceAreas(),
      ]);
      final me = results[0] as WarehouseMe;
      final govs = results[1] as List<Governorate>;
      final areas = (results[2] as List<String>).toSet();
      setState(() {
        _me = me;
        _governorates = govs;
        _selected
          ..clear()
          ..addAll(areas);
        _savedSelection = {...areas};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  bool get _dirty =>
      _selected.length != _savedSelection.length || !_selected.containsAll(_savedSelection);

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
      final selectAll = current != true;
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
      await ref.read(warehouseServiceAreaRepositoryProvider).setServiceAreas(_selected.toList());
      if (!mounted) return;
      setState(() {
        _savedSelection = {..._selected};
        _saving = false;
      });
      AppSnackbar.success(context, 'تم حفظ مناطق التغطية');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackbar.error(context, ApiException.from(e).message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: _buildBody(),
      bottomNavigationBar: (_me != null && _dirty)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppButton(
                  label: 'حفظ مناطق التغطية (${_selected.length})',
                  icon: Icons.save_outlined,
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final me = _me!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _ProfileHeader(me: me),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'مناطق التغطية',
          icon: Icons.map_outlined,
          subtitle: 'اختر المحافظات والمدن التي يوصّل إليها مستودعك',
          trailing: Text('${_selected.length} مدينة', style: context.text.bodySmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_governorates.isEmpty)
          const EmptyState(message: 'لا توجد محافظات متاحة حالياً', icon: Icons.map_outlined)
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _governorates.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _GovernorateTile(
                    governorate: _governorates[i],
                    selected: _selected,
                    triState: _governorateState(_governorates[i]),
                    onToggleGovernorate: () => _toggleGovernorate(_governorates[i]),
                    onToggleCity: _toggleCity,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.me});
  final WarehouseMe me;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final location = [me.governorate, me.city].where((e) => e.isNotEmpty).join(' - ');
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.28)!],
    );
    final onHero = Colors.white;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.warehouse_outlined, color: onHero, size: 28),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.warehouseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge?.copyWith(color: onHero)),
                    const SizedBox(height: 2),
                    Text('رمز: ${me.warehouseCode}${location.isNotEmpty ? ' · $location' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: onHero.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _InfoRow(icon: Icons.person_outline, text: '${me.firstName} ${me.lastName} (${me.userName})'),
                _InfoRow(icon: Icons.badge_outlined, text: me.role.label),
                if (me.phone.isNotEmpty) _InfoRow(icon: Icons.phone_outlined, text: me.phone),
                if (me.email.isNotEmpty) _InfoRow(icon: Icons.email_outlined, text: me.email),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _GovernorateTile extends StatelessWidget {
  const _GovernorateTile({
    required this.governorate,
    required this.selected,
    required this.triState,
    required this.onToggleGovernorate,
    required this.onToggleCity,
  });

  final Governorate governorate;
  final Set<String> selected;
  final bool? triState;
  final VoidCallback onToggleGovernorate;
  final void Function(String cityId, bool value) onToggleCity;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final selectedCount = governorate.cities.where((c) => selected.contains(c.id)).length;
    return ExpansionTile(
      leading: Checkbox(
        tristate: true,
        value: triState,
        activeColor: cs.primary,
        onChanged: (_) => onToggleGovernorate(),
      ),
      title: Text(governorate.name, style: context.text.titleSmall),
      subtitle: Text('$selectedCount من ${governorate.cities.length} مدينة محدَّدة',
          style: context.text.bodySmall),
      childrenPadding: const EdgeInsets.only(right: AppSpacing.md),
      children: governorate.cities
          .map((c) => CheckboxListTile(
                value: selected.contains(c.id),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: cs.primary,
                dense: true,
                title: Text(c.name, style: context.text.bodyMedium),
                onChanged: (v) => onToggleCity(c.id, v ?? false),
              ))
          .toList(),
    );
  }
}
