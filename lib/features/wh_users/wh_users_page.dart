import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/warehouse_user_models.dart';
import 'package:tawrid_app/repositories/warehouse_user_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// إدارة موظّفي المستودع — للمدير فقط (الخادم يفرضها بسياسة Warehouse.Admin،
// والمدخل في «المزيد» مخفيّ عن الموظّف فلا يصطدم بـ403).
//
// القائمة تشمل الموقوفين عمداً: الإيقاف ليس حذفاً، والمدير يحتاج رؤيتهم
// ليُعيد تفعيلهم.
class WhUsersPage extends ConsumerStatefulWidget {
  const WhUsersPage({super.key});

  @override
  ConsumerState<WhUsersPage> createState() => _WhUsersPageState();
}

class _WhUsersPageState extends ConsumerState<WhUsersPage> {
  List<WarehouseUser>? _users;
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  /// معرّف المستخدم الحالي — لتمييز «أنت» ولمنع إيقاف النفس قبل الرحلة.
  String? get _myId => switch (ref.read(warehouseSessionProvider).value) {
        WarehouseSessionAuthenticated(:final warehouseUserId) => warehouseUserId,
        _ => null,
      };

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
      final list = await ref.read(warehouseUserRepositoryProvider).getUsers();
      if (!mounted) return;
      setState(() {
        _users = list;
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

  int get _activeAdmins => (_users ?? const <WarehouseUser>[])
      .where((u) => u.isActive && u.role == WarehouseUserRole.admin)
      .length;

  // حارسا الخادم ينعكسان هنا نصّاً قبل الرحلة: لا إيقاف للنفس، ولا إيقاف
  // لآخر مدير فعّال — وإلا بقي المستودع بلا من يملك إعادة التفعيل.
  String? _blockReasonForDeactivate(WarehouseUser u) {
    if (u.id == _myId) return 'لا يمكنك إيقاف حسابك بنفسك';
    if (u.role == WarehouseUserRole.admin && _activeAdmins <= 1) {
      return 'لا يمكن إيقاف آخر مدير فعّال في المستودع';
    }
    return null;
  }

  Future<void> _toggleActive(WarehouseUser u) async {
    if (u.isActive) {
      final blocked = _blockReasonForDeactivate(u);
      if (blocked != null) {
        AppSnackbar.error(context, blocked);
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('إيقاف الموظّف'),
          content: Text(
              'سيفقد «${u.fullName}» الوصول فوراً، ويبقى حسابه قائماً فيمكن '
              'إعادة تفعيله لاحقاً.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.colors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إيقاف'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy.add(u.id));
    try {
      await ref.read(warehouseUserRepositoryProvider).setActive(u.id, !u.isActive);
      if (!mounted) return;
      AppSnackbar.success(context, u.isActive ? 'أُوقف الموظّف' : 'أُعيد تفعيل الموظّف');
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _UserFormSheet(),
    );
    if (created == true) await _load();
  }

  Future<void> _edit(WarehouseUser u) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _UserFormSheet(
        existing: u,
        isSelf: u.id == _myId,
        // الخادم يشترط `IsActive` في حارس «آخر مدير»، فمدير موقوف يُخفَّض
        // بلا اعتراض — ولا داعي لقفل الخيار عليه.
        isLastActiveAdmin:
            u.role == WarehouseUserRole.admin && u.isActive && _activeAdmins <= 1,
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _resetPassword(WarehouseUser u) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعيين كلمة مرور'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('كلمة مرور جديدة لـ «${u.fullName}».',
                  style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller,
                hint: '٦ أحرف على الأقل',
                obscure: true,
                autofocus: true,
                validator: (v) => (v == null || v.length < 6)
                    ? 'كلمة المرور يجب ألا تقل عن ٦ أحرف'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'تنبيه: جلسة الموظّف الحالية تبقى صالحة بعد التغيير — لقطع '
                'وصوله فوراً أوقف حسابه.',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ctx.tokens.hint),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
            },
            child: const Text('تعيين'),
          ),
        ],
      ),
    );

    final password = controller.text;
    controller.dispose();
    if (confirmed != true) return;

    setState(() => _busy.add(u.id));
    try {
      await ref.read(warehouseUserRepositoryProvider).resetPassword(u.id, password);
      if (mounted) AppSnackbar.success(context, 'عُيِّنت كلمة المرور');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('موظّفو المستودع'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('موظّف جديد'),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final users = _users ?? const <WarehouseUser>[];
    if (users.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: AppSpacing.x3l),
          EmptyState(
            icon: Icons.group_outlined,
            message: 'لا موظّفين بعد — أضف حساباً لكل موظّف ليعمل باسمه',
          ),
        ],
      );
    }

    // الفعّالون أولاً، ثم الموقوفون في ذيل القائمة.
    final sorted = [...users]..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.fullName.compareTo(b.fullName);
      });

    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.md, AppSpacing.page, 88),
      children: [
        for (final u in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _UserCard(
              user: u,
              isSelf: u.id == _myId,
              busy: _busy.contains(u.id),
              onEdit: () => _edit(u),
              onToggleActive: () => _toggleActive(u),
              onResetPassword: () => _resetPassword(u),
            ),
          ),

        // قواعد الخادم مكتوبة حيث تُطبَّق (Figma) — المدير يقرؤها قبل أن
        // يصطدم برفضٍ، ويفهم لماذا لا يوجد زرّ حذف أصلاً.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: tk.warningSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: tk.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'لا يمكنك إيقاف حسابك بنفسك، ولا ترك المستودع بلا مدير '
                  'مفعّل واحد. والموظّف يُوقَف ولا يُحذف لأن معرّفه مرجع في '
                  'سجلّ حالات الطلبيات. الإيقاف يقطع جلسته فوراً.',
                  style: context.text.bodySmall?.copyWith(color: tk.warning),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.busy,
    required this.onEdit,
    required this.onToggleActive,
    required this.onResetPassword,
  });

  final WarehouseUser user;
  final bool isSelf;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSelf ? '${user.fullName} (أنت)' : user.fullName,
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // اسم المستخدم هو ما يدخل به الموظّف فعلاً — أهمّ من
                    // بريده في شاشة إدارة الحسابات.
                    Text('اسم المستخدم: ${user.userName}',
                        style: context.text.bodySmall?.copyWith(color: tk.hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: user.role.label,
                tone: user.role == WarehouseUserRole.admin
                    ? StatusTone.brand
                    : StatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: cs.outline),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              TextButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('تعديل'),
              ),
              TextButton(
                onPressed: busy ? null : onResetPassword,
                child: const Text('كلمة المرور'),
              ),
              const Spacer(),
              Text(user.isActive ? 'مفعّل' : 'موقوف',
                  style: context.text.bodySmall?.copyWith(color: tk.hint)),
              const SizedBox(width: AppSpacing.xs),
              // مفتاح لا زرّ نصّي: الحالة ثنائية ومرئية في وضع المفتاح
              // نفسه، فلا يحتاج المدير قراءة نصّ ليعرف من يعمل.
              if (busy)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                Switch(
                  value: user.isActive,
                  onChanged: (_) => onToggleActive(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── إضافة/تعديل موظّف ────────────────────────────────────────────────
// نموذج واحد للحالتين: الإضافة تطلب اسم مستخدم وبريداً وكلمة مرور، أما
// التعديل فالخادم لا يقبل تغييرها — فتُعرض للقراءة فقط بدل إخفائها.
class _UserFormSheet extends ConsumerStatefulWidget {
  const _UserFormSheet({
    this.existing,
    this.isSelf = false,
    this.isLastActiveAdmin = false,
  });

  final WarehouseUser? existing;
  final bool isSelf;
  final bool isLastActiveAdmin;

  @override
  ConsumerState<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends ConsumerState<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.existing?.firstName);
  late final _lastName = TextEditingController(text: widget.existing?.lastName);
  late final _userName = TextEditingController(text: widget.existing?.userName);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _shamCash =
      TextEditingController(text: widget.existing?.shamCashAccount);
  final _password = TextEditingController();
  late WarehouseUserRole _role = widget.existing?.role ?? WarehouseUserRole.staff;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  // خفض رتبة آخر مدير فعّال يرفضه الخادم — نُقفل الخيار بدل تركه يفشل.
  bool get _roleLocked => _isEdit && widget.isLastActiveAdmin;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _userName.dispose();
    _email.dispose();
    _phone.dispose();
    _shamCash.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(warehouseUserRepositoryProvider);
      final sham = _shamCash.text.trim();

      if (_isEdit) {
        await repo.updateUser(
          widget.existing!.id,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
          shamCashAccount: sham,
          role: _roleLocked ? null : _role,
        );
      } else {
        await repo.createUser(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          userName: _userName.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
          role: _role,
          shamCashAccount: sham.isEmpty ? null : sham,
        );
      }

      if (mounted) {
        AppSnackbar.success(context, _isEdit ? 'حُفظت التعديلات' : 'أُضيف الموظّف');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      // SingleChildScrollView لا ListView: الأخيرة تُزيل الحقول الخارجة عن
      // الشاشة فيتخطّاها `validate()` ويُرجع true على نموذج ناقص.
      builder: (_, controller) => Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.x3l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(_isEdit ? 'تعديل موظّف' : 'موظّف جديد',
                style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _isEdit
                  ? 'اسم المستخدم والبريد لا يُعدّلان بعد الإنشاء.'
                  : 'لكل موظّف حساب دخول مستقلّ باسمه.',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _firstName,
                    label: 'الاسم الأول',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'الاسم الأول مطلوب'
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _lastName,
                    label: 'الاسم الأخير',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'الاسم الأخير مطلوب'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _userName,
              label: 'اسم المستخدم',
              hint: 'يُستخدم لتسجيل الدخول',
              enabled: !_isEdit,
              validator: (v) {
                if (_isEdit) return null;
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'اسم المستخدم مطلوب';
                if (s.length < 3) return 'اسم المستخدم يجب ألا يقل عن ٣ أحرف';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _email,
              label: 'البريد الإلكتروني',
              keyboardType: TextInputType.emailAddress,
              enabled: !_isEdit,
              validator: (v) {
                if (_isEdit) return null;
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'البريد الإلكتروني مطلوب';
                if (!s.contains('@') || !s.contains('.')) {
                  return 'صيغة البريد الإلكتروني غير صحيحة';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _phone,
              label: 'رقم الهاتف',
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'رقم الهاتف مطلوب' : null,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _password,
                label: 'كلمة المرور',
                hint: '٦ أحرف على الأقل',
                obscure: true,
                validator: (v) => (v == null || v.length < 6)
                    ? 'كلمة المرور يجب ألا تقل عن ٦ أحرف'
                    : null,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _shamCash,
              label: 'حساب شام كاش (اختياري)',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('الدور', style: context.text.labelMedium),
            const SizedBox(height: 6),
            RadioGroup<WarehouseUserRole>(
              groupValue: _role,
              // `RadioGroup.onChanged` إلزامي، فالتعطيل يكون على البطاقات
              // نفسها (`enabled`) لا بتمرير null هنا.
              onChanged: (v) {
                if (_roleLocked || v == null) return;
                setState(() => _role = v);
              },
              child: Column(
                children: [
                  for (final r in WarehouseUserRole.values)
                    RadioListTile<WarehouseUserRole>(
                      value: r,
                      enabled: !_roleLocked,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.label),
                      subtitle: Text(
                        r == WarehouseUserRole.admin
                            ? 'صلاحيات كاملة، بما فيها إدارة الموظّفين'
                            : 'يعمل في المستودع بلا إدارة للموظّفين',
                        style: context.text.bodySmall?.copyWith(color: tk.hint),
                      ),
                    ),
                ],
              ),
            ),
            if (_roleLocked)
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: tk.hint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('آخر مدير فعّال — لا يمكن خفض رتبته',
                        style: context.text.labelSmall?.copyWith(color: tk.hint)),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _isEdit ? 'حفظ التعديلات' : 'إضافة الموظّف',
              loading: _saving,
              onPressed: _saving ? null : _submit,
            ),
            ],
          ),
        ),
      ),
    );
  }
}
