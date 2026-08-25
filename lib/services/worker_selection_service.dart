import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'work_date_service.dart';

/// مسئول ذخیره‌ی نام کاربری که در یک روز کاری مشخص، کار می‌کند.
///
/// این انتخاب به همان روز کاری (بر اساس تاریخ شمسی) وصل است، نه به کل
/// برنامه؛ یعنی هر روز کاری می‌تواند کاربر متفاوتی داشته باشد و تا وقتی
/// که دوباره عوض نشود، همان باقی می‌ماند.
class WorkerSelectionService {
  static const String _keyPrefix = 'worker_for_day_';

  /// نام کاربر ثبت‌شده برای یک روز کاری خاص، بر اساس کلید ۸ رقمی روز
  /// (همان خروجی WorkDateService.folderNameFor).
  static Future<String?> getWorkerForDayKey(String dayKey) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_keyPrefix$dayKey');
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  /// نام کاربر ثبت‌شده برای یک تاریخ شمسی خاص.
  static Future<String?> getWorkerForDate(Jalali date) {
    return getWorkerForDayKey(WorkDateService.folderNameFor(date));
  }

  /// نام کاربر را برای یک تاریخ شمسی خاص ذخیره می‌کند.
  static Future<void> setWorkerForDate(Jalali date, String workerName) async {
    final prefs = await SharedPreferences.getInstance();
    final dayKey = WorkDateService.folderNameFor(date);
    await prefs.setString('$_keyPrefix$dayKey', workerName.trim());
  }

  /// نام نهایی پوشه‌ی روز را می‌سازد: اگر کاربری برای آن روز انتخاب شده
  /// باشد، نامش کنار تاریخ می‌آید تا معلوم شود آن روز چه کسی کار کرده
  /// (مثلاً «14050101 - علی»). اگر کسی انتخاب نشده باشد، فقط همان تاریخ
  /// ۸ رقمی برگردانده می‌شود؛ یعنی رفتار قبلی برنامه دست‌نخورده می‌ماند.
  static Future<String> resolveDayFolderName(Jalali date) async {
    final base = WorkDateService.folderNameFor(date);
    final worker = await getWorkerForDate(date);

    if (worker == null || worker.trim().isEmpty) return base;

    return '$base - ${_sanitize(worker)}';
  }

  /// کاراکترهایی که در نام پوشه مجاز نیستند را حذف می‌کند.
  static String _sanitize(String name) {
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    final cleaned = name.replaceAll(invalidChars, '').trim();
    return cleaned.isEmpty ? name : cleaned;
  }
}
