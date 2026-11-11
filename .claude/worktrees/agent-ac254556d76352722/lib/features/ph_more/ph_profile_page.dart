import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/pharmacy_auth_models.dart';
import 'package:tawrid_app/repositories/pharmacy_profile_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// الملف الشخصي للصيدلية: عرض البيانات وتعديل ما يقبله الخادم.
class PhProfilePage extends ConsumerStatefulWidget {
  const PhProfilePage({super.key});

  @override
  ConsumerState<PhProfilePage> createState() => _PhProfilePageState();
}

class _PhProfilePageState extends ConsumerState<PhProfilePage> {
  PharmacyMe? _me;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  String? _error;

  final _phone = TextEditingController();
  final _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await ref.read(pharmacyProfileRepositoryProvider).getMe();
      if (!mounted) return;
      setState(() {
        _me = me;
        _phone.text = me.phone;
        _address.text = me.address;
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch(
        ApiEndpoints.phUpdateProfile,
        data: {
          'phone': _phone.text.trim(),
          'address': _address.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      AppSnackbar.success(context, 'تم حفظ بيانات الصيدلية');
      await _load();
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
      bottomNavigationBar: (_editing && !_loading)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppButton(
                  label: 'حفظ التغييرات',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
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
    final cs = context.colors;
    final tk = context.tokens;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.28)!],
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // بطاقة الهوية
        Container(
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
                    child: const Icon(Icons.local_pharmacy_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me.pharmacyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleLarge?.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(me.areaLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85))),
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
                    _InfoRow(icon: Icons.email_outlined, text: me.email),
                    _InfoRow(icon: Icons.phone_outlined, text: me.phone.isNotEmpty ? me.phone : '—'),
                    _InfoRow(icon: Icons.place_outlined, text: me.address.isNotEmpty ? me.address : '—'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'البيانات القابلة للتعديل',
          icon: Icons.edit_outlined,
          subtitle: _editing ? 'عدّل الحقول التي تريد تغييرها' : 'اضغط تعديل في الأعلى للبدء',
        ),
        const SizedBox(height: AppSpacing.sm),

        AppCard(
          child: Column(
            children: [
              AppTextField(
                controller: _phone,
                label: 'رقم الهاتف',
                hint: '09xxxxxxxx',
                keyboardType: TextInputType.phone,
                enabled: _editing,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _address,
                label: 'العنوان',
                hint: 'الشارع، أقرب معلم…',
                enabled: _editing,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'معلومات الحساب',
          subtitle: 'تُحدَّث تلقائياً بعد الموافقة — لا يمكن تعديلها يدوياً',
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              _ReadOnlyField(label: 'اسم الصيدلية', value: me.pharmacyName),
              Divider(height: 1, color: cs.outline),
              _ReadOnlyField(label: 'البريد الإلكتروني', value: me.email),
              Divider(height: 1, color: cs.outline),
              _ReadOnlyField(label: 'المحافظة', value: me.governorate),
              Divider(height: 1, color: cs.outline),
              _ReadOnlyField(label: 'المدينة', value: me.city),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Text('توريد — منصة التوريد الدوائي',
              style: context.text.labelSmall?.copyWith(color: tk.hint)),
        ),
      ],
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
            child: Text(label,
                style: context.text.bodySmall?.copyWith(color: tk.hint)),
          ),
          Text(value.isNotEmpty ? value : '—',
              style: context.text.bodyMedium),
        ],
      ),
    );
  }
}
