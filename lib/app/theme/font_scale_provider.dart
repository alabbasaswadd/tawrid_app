import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFontScaleKey = 'font_scale';

enum FontScaleLevel {
  small(0.85, 'صغير'),
  normal(1.0, 'عادي'),
  large(1.1, 'كبير'),
  larger(1.2, 'أكبر');

  const FontScaleLevel(this.factor, this.label);
  final double factor;
  final String label;
}

class FontScaleController extends Notifier<FontScaleLevel> {
  @override
  FontScaleLevel build() {
    _load();
    return FontScaleLevel.normal;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kFontScaleKey);
    if (v == null) return;
    state = FontScaleLevel.values.firstWhere(
      (l) => l.name == v,
      orElse: () => FontScaleLevel.normal,
    );
  }

  Future<void> setLevel(FontScaleLevel level) async {
    state = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFontScaleKey, level.name);
  }
}

final fontScaleProvider = NotifierProvider<FontScaleController, FontScaleLevel>(
  FontScaleController.new,
);
