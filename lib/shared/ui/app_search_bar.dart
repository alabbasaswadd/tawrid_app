import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// شريط البحث الموحد (Figma: شريط بحث): ارتفاع ٤٨، أيقونة البحث في بداية
// القراءة، وزرّ المسح (X) يظهر حين يوجد نصّ، والباركود في الطرف المقابل
// حين يكون الحقل فارغاً.
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    this.controller,
    this.hint = 'ابحث…',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onScanTap,
    this.onClearTap,
    this.readOnly = false,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  // لفتح شاشة بحث مخصصة عند الضغط (مع readOnly).
  final VoidCallback? onTap;
  final VoidCallback? onScanTap;
  // يُظهر زرّ X حين يكون الحقل غير فارغ؛ اضغطه لتفريغ البحث.
  final VoidCallback? onClearTap;
  final bool readOnly;
  final bool autofocus;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _ctrl;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _hasText = _ctrl.text.isNotEmpty;
    _ctrl.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(AppSearchBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _ctrl.removeListener(_onControllerChange);
      _ctrl = widget.controller ?? TextEditingController();
      _hasText = _ctrl.text.isNotEmpty;
      _ctrl.addListener(_onControllerChange);
    }
  }

  void _onControllerChange() {
    final has = _ctrl.text.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChange);
    // نتخلص من المتحكّم فقط إن أنشأناه نحن — لا نُتلف الخارجي.
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.search, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              onTap: widget.onTap,
              readOnly: widget.readOnly,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              style: context.text.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: widget.hint,
                hintStyle: context.text.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (_hasText && widget.onClearTap != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: widget.onClearTap,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
            ),
          ] else if (!_hasText && widget.onScanTap != null) ...[
            const SizedBox(width: 10),
            InkWell(
              onTap: widget.onScanTap,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AppIcon(AppIcons.scanBarcode, size: 20, color: cs.primary),
            ),
          ],
        ],
      ),
    );
  }
}
