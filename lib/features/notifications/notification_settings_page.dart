import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/notification_models.dart';
import 'package:tawrid_app/repositories/notification_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// إعدادات الإشعارات — القائمة كلها تأتي من كتالوج الخادم (النوع والعنوان
// والوصف وهل هو قابل للتعطيل)، فالتطبيق لا يعرف الأنواع مسبقاً ونوع جديد
// في الخادم يظهر هنا بلا تحديث للتطبيق.
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({required this.isWarehouse, super.key});

  final bool isWarehouse;

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  List<NotificationSetting>? _settings;
  bool _loading = true;
  String? _error;
  final Set<int> _saving = {};

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
      final list =
          await notificationRepositoryOf(ref, widget.isWarehouse).getSettings();
      if (!mounted) return;
      setState(() {
        _settings = list;
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

  // الخادم يدمج التغييرات ولا يستبدل القائمة، فإرسال مفتاح واحد آمن،
  // ويُرجع القائمة كاملةً بعد التعديل فنعرض حالته النهائية بلا طلب ثانٍ.
  Future<void> _toggle(NotificationSetting s, bool value) async {
    setState(() => _saving.add(s.typeCode));
    try {
      final updated = await notificationRepositoryOf(ref, widget.isWarehouse)
          .updateSettings({s.typeCode: value});
      if (!mounted) return;
      setState(() => _settings = updated);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving.remove(s.typeCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الإشعارات')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final settings = _settings ?? const <NotificationSetting>[];
    if (settings.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: AppSpacing.x3l),
          EmptyState(
            icon: Icons.tune,
            message: 'لا أنواع إشعارات متاحة لهذا الحساب',
          ),
        ],
      );
    }

    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.x3l),
      children: [
        Text(
          'هذه المفاتيح تتحكّم بالتنبيه الفوري فقط — كل إشعار يُحفظ في الصندوق '
          'مهما كانت حالة مفتاحه.',
          style: context.text.bodySmall?.copyWith(color: tk.hint),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final s in settings)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label.isEmpty ? s.code : s.label,
                            style: context.text.titleSmall),
                        if (s.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(s.description,
                              style:
                                  context.text.bodySmall?.copyWith(color: tk.hint)),
                        ],
                        if (!s.configurable) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(Icons.lock_outline, size: 13, color: tk.hint),
                              const SizedBox(width: 4),
                              Text('إشعار نظام — لا يمكن تعطيله',
                                  style: context.text.labelSmall
                                      ?.copyWith(color: tk.hint)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (_saving.contains(s.typeCode))
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: s.pushEnabled,
                      onChanged:
                          s.configurable ? (v) => _toggle(s, v) : null,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
