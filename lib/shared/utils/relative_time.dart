// صياغة زمنية بأسلوب منشورات فيسبوك: "الآن"، "منذ N دقيقة"، "اليوم، HH:mm"،
// "الأمس، HH:mm"، ثم تاريخ كامل للأقدم. التاريخ لا يُعرَض كرقم خام إن كان
// اليوم — تحديداً كما طُلب.
String formatSmartTimestamp(DateTime dateTime) {
  final dt = dateTime.isUtc ? dateTime.toLocal() : dateTime;
  final now = DateTime.now();
  final diff = now.difference(dt);
  final time = _formatTime(dt);

  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) {
    return 'منذ ${diff.inMinutes} ${diff.inMinutes == 1 ? "دقيقة" : "دقائق"}';
  }
  if (_isSameDay(dt, now)) return 'اليوم، $time';

  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(dt, yesterday)) return 'الأمس، $time';

  if (diff.inDays < 7) {
    return 'منذ ${diff.inDays} ${diff.inDays == 1 ? "يوم" : "أيام"}';
  }

  final y = dt.year.toString();
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y/$m/$d، $time';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'ص' : 'م';
  return '$hour12:$minute $period';
}
