// سُلّم المسافات — مطابق لـ Figma (الهوية · المسافات):
// xs ٤ · sm ٨ · md ١٢ · lg ١٦ · xl ٢٠ · x2l ٢٤ · x3l ٣٢
abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double x2l = 24.0;
  static const double x3l = 32.0;

  // خارج سُلّم Figma — للفراغات الكبيرة جداً (قيمة قديمة مُبقاة).
  static const double xxl = 48.0;

  // هامش الصفحة الأفقي الموحّد في كل الشاشات (Figma: 20).
  static const double page = xl;

  // أنصاف أقطار قديمة — تُفضَّل AppRadius الجديدة.
  static const double cardRadius = AppRadius.lg;
  static const double chipRadius = AppRadius.full;
  static const double buttonRadius = AppRadius.md;
  static const double inputRadius = AppRadius.md;
}

// الزوايا — مطابقة لـ Figma (الهوية · الزوايا): sm ٨ · md ١٢ · lg ١٦ · full دائري
abstract final class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double full = 999.0;
}
