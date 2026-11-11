import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// منتقي الكمية (Figma: منتقي كمية): − | القيمة | + — أزرار ٣٦×٤٠ على سطح
// العلامة الفاتح، والقيمة في الوسط بعرض ٤٨.
//
// بتمرير [onValueChanged] تصير القيمة قابلة للكتابة مباشرةً: كمية مثل ٢٤٠
// لا تُبلَغ بالضغط ٢٤٠ مرة. الشكل لا يتغيّر — الحقل بنفس عرض النص وطرازه.
class QuantityStepper extends StatefulWidget {
  const QuantityStepper({
    required this.value,
    this.onIncrement,
    this.onDecrement,
    this.onValueChanged,
    this.enabled = true,
    super.key,
  });

  final String value;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  /// يُفعّل الكتابة المباشرة. يُستدعى عند تثبيت القيمة (إرسال أو فقد التركيز)
  /// لا عند كل ضغطة حرف — كل نداء هنا رحلة شبكة.
  final ValueChanged<int>? onValueChanged;

  final bool enabled;

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(QuantityStepper old) {
    super.didUpdateWidget(old);
    // القيمة الموثوقة تأتي من الخادم بعد كل تعديل. لا نكتب فوق ما يطبعه
    // المستخدم الآن، فالمزامنة تتم وهو غير مركّز على الحقل فقط.
    if (widget.value != old.value && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    // نصّ فارغ أو غير رقمي ليس قراراً بالحذف — نعيد القيمة الأخيرة الصحيحة.
    if (parsed == null) {
      _controller.text = widget.value;
      return;
    }
    if (parsed.toString() == widget.value) return;
    widget.onValueChanged?.call(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final editable = widget.onValueChanged != null && widget.enabled;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // ترتيب ثابت بصرياً: − يسار، + يمين (كما في التصميم).
        textDirection: TextDirection.ltr,
        children: [
          _StepButton(
            symbol: '−',
            onTap: widget.enabled ? widget.onDecrement : null,
          ),
          SizedBox(
            width: 48,
            height: 40,
            child: editable
                ? Center(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: context.text.titleMedium,
                      onSubmitted: (_) => _commit(),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      widget.value,
                      textAlign: TextAlign.center,
                      style: context.text.titleMedium,
                    ),
                  ),
          ),
          _StepButton(
            symbol: '+',
            onTap: widget.enabled ? widget.onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.symbol, required this.onTap});

  final String symbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return Material(
      color: t.brandSurfaceSubtle,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 40,
          child: Center(
            child: Text(
              symbol,
              style: context.text.labelLarge?.copyWith(color: cs.primary),
            ),
          ),
        ),
      ),
    );
  }
}
