import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/location/location_service.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

/// حقل التقاط الموقع عند إنشاء الحساب — للصيدلية والمستودع معاً.
///
/// الإذن يُطلب عند الضغط لا عند فتح الشاشة: نافذة إذن تظهر قبل أن يفهم
/// المستخدم لماذا تُطلب تُرفض عادةً، ورفضها الدائم يُغلق الباب.
class LocationField extends StatefulWidget {
  const LocationField({
    required this.latitude,
    required this.longitude,
    required this.onCaptured,
    this.label = 'موقع الصيدلية',
    this.hint = 'مطلوب — يُستخدم لتحديد المستودعات التي تخدم موقعك',
    super.key,
  });

  final double? latitude;
  final double? longitude;
  final void Function(double latitude, double longitude) onCaptured;
  final String label;
  final String hint;

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  bool _busy = false;

  Future<void> _capture() async {
    setState(() => _busy = true);
    final result = await locationService.capture();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case LocationCaptured(:final latitude, :final longitude):
        widget.onCaptured(latitude, longitude);
        if (mounted) AppSnackbar.success(context, 'تم تحديد الموقع بنجاح');
      case LocationFailed(:final message, :final openSettings, :final openLocationSettings):
        if (openLocationSettings && mounted) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('خدمة الموقع مغلقة'),
              content: const Text('يجب تفعيل GPS لتحديد الموقع. هل تريد فتح إعدادات الموقع؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('فتح الإعدادات'),
                ),
              ],
            ),
          );
          if (ok == true) await locationService.openLocationSettings();
        } else {
          if (mounted) AppSnackbar.error(context, message);
          if (openSettings) await locationService.openAppSettings();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final captured = widget.latitude != null && widget.longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 2),
          child: Row(
            children: [
              Text(widget.label, style: context.text.labelMedium),
              Text(' *', style: context.text.labelMedium?.copyWith(color: cs.error)),
            ],
          ),
        ),
        AppCard(
          onTap: _busy ? null : _capture,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          // حدّ أخضر عند النجاح: إشارة بصرية أن الشرط استُوفي.
          color: captured ? tk.brandSurface : null,
          child: Row(
            children: [
              if (_busy)
                const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(
                  captured ? Icons.check_circle : Icons.my_location,
                  size: 20,
                  color: captured ? tk.success : cs.primary,
                ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _busy
                          ? 'جارٍ تحديد الموقع…'
                          : captured
                              ? 'تم تحديد الموقع'
                              : 'تحديد الموقع الحالي',
                      style: context.text.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      captured
                          // الإحداثيات تُعرض ليتحقّق المستخدم أنها ليست صفراً
                          // أو موقعاً خاطئاً قبل أن يُنشئ الحساب.
                          ? '${widget.latitude!.toStringAsFixed(5)}, '
                              '${widget.longitude!.toStringAsFixed(5)}'
                          : widget.hint,
                      style: context.text.labelSmall?.copyWith(color: tk.hint),
                    ),
                  ],
                ),
              ),
              if (captured)
                TextButton(
                  onPressed: _busy ? null : _capture,
                  child: const Text('تحديث'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
