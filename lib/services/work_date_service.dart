import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// مسئول ذخیره و خواندن «تاریخ کاری» انتخاب‌شده (شمسی).
/// این تاریخ تا وقتی کاربر عوضش نکند ثابت می‌ماند؛ نام پوشه‌ی روز
/// (مثلاً «14050503») از همین مقدار ساخته می‌شود.
class WorkDateService {

  static const String _yearKey = 'work_date_year';
  static const String _monthKey = 'work_date_month';
  static const String _dayKey = 'work_date_day';

  /// تاریخ ذخیره‌شده را برمی‌گرداند. اگر چیزی ذخیره نشده باشد
  /// (اولین اجرای برنامه)، تاریخ امروز را برمی‌گرداند.
  static Future<Jalali> getWorkDate() async {

    final prefs = await SharedPreferences.getInstance();

    final year = prefs.getInt(_yearKey);
    final month = prefs.getInt(_monthKey);
    final day = prefs.getInt(_dayKey);

    if (year == null || month == null || day == null) {
      return Jalali.now();
    }

    return Jalali(year, month, day);

  }

  /// تاریخ جدید را ذخیره می‌کند.
  static Future<void> setWorkDate(Jalali date) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_yearKey, date.year);
    await prefs.setInt(_monthKey, date.month);
    await prefs.setInt(_dayKey, date.day);

  }

  /// نام پوشه‌ی روز را می‌سازد. مثلاً برای 1405/05/03 → "14050503"
  /// (سال ۴ رقمی، ماه و روز هرکدام ۲ رقمی، پشت سر هم).
  static String folderNameFor(Jalali date) {

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year$month$day';

  }

}
