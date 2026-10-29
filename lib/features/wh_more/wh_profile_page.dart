import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
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
  bool _editing = false;
  bool _saving = false;
  bool _savingProfile = false;
  String? _error;

  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
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
        _phone.text = me.phone;
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

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await ref.read(apiClientProvider).patch(
        ApiEndpoints.whUpdateProfile,
        data: {'phone': _phone.text.trim()},
      );
      if (!mounted) return;
      setState(() {
        _editing = false;
        _savingProfile = false;
      });
      AppSnackbar.success(context, 'تم حفظ البيانات');
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _savingProfile = false);
        AppSnackbar.error(context, ApiException.from(e).message);
      }
    }
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
    Widget? bottomBar;
    if (_editing && !_loading) {
      bottomBar = SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButton(
            label: 'حفظ البيانات',
            loading: _savingProfile,
            onPressed: _savingProfile ? null : _saveProfile,
          ),
        ),
      );
    } else if (_me != null && _dirty) {
      bottomBar = SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButton(
            label: 'حفظ مناطق التغطية (${_selected.length})',
            icon: Icons.save_outlined,
            loading: _saving,
            onPressed: _save,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          if (!_loading && _me != null)
            TextButton.icon(
              onPressed: () => setState(() => _editing = !_editing),
              icon: Icon(_editing ? Icons.close : Icons.edit_outlined, size: 18),
              label: Text(_editing ? 'إلغاء' : 'تعديل'),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: bottomBar,
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final me = _me!;
    final cs = context.colors;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _ProfileHeader(me: me),
        const SizedBox(height: AppSpacing.lg),

        AppSectionHeader(
          title: 'البيانات القابلة للتعديل',
          icon: Icons.edit_outlined,
          subtitle: _editing ? 'عدّل الحقول التي تريد تغييرها' : 'اضغط تعديل في الأعلى للبدء',
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: AppTextField(
            controller: _phone,
            label: 'رقم الهاتف',
            hint: '09xxxxxxxx',
            keyboardType: TextInputType.phone,
            enabled: _editing,
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'معلومات الحساب',
          subtitle: 'لا يمكن تعديلها يدوياً',
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              _ReadOnlyField(label: 'اسم المستودع', value: me.warehouseName),
              Divider(height: 1, color: cs.outline),
              _ReadOnlyField(label: 'رمز المستودع', value: me.warehouseCode),
              Divider(height: 1, color: cs.outline),
              _ReadOnlyField(label: 'البريد الإلكتروني', value: me.email),
              Divider(height: 1, color: cs.outline),
              _ReadOnlyField(label: 'المحافظة', value: me.governorate),
              Divider(height: 1, color: cs.outline),
              _ReadOnlyField(label: 'المدينة', value: me.city),
            ],
          ),
        ),

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

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: context.text.bodySmall?.copyWith(color: tk.hint)),
          ),
          Text(value.isNotEmpty ? value : '—', style: context.text.bodyMedium),
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
