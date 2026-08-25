import 'package:shared_preferences/shared_preferences.dart';


/// مسئول ذخیره و خواندن تنظیمات مربوط به محل ذخیره‌سازی فایل‌ها.
/// در آینده تنظیمات دیگری (مثل تاریخ کاری) هم می‌تواند به همین سرویس
/// یا یک سرویس مشابه اضافه شود.
class StorageSettingsService {

  static const String _storagePathKey = 'storage_path';
  static const String _systemNumberKey = 'system_number';

  /// مسیر ذخیره‌شده را برمی‌گرداند. اگر هنوز چیزی ذخیره نشده باشد null است.
  static Future<String?> getStoragePath() async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_storagePathKey);

  }

  /// مسیر جدید را ذخیره می‌کند و مسیر قبلی را جایگزین می‌کند.
  static Future<void> setStoragePath(String path) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_storagePathKey, path);

  }

  /// شماره‌ی سیستم یا موبایل (بین ۱ تا ۵) که در تنظیمات انتخاب شده را
  /// برمی‌گرداند. اگر هنوز چیزی انتخاب نشده باشد null است.
  static Future<int?> getSystemNumber() async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(_systemNumberKey);

  }

  /// شماره‌ی جدید سیستم یا موبایل را ذخیره می‌کند و شماره‌ی قبلی را
  /// جایگزین می‌کند. تا وقتی دوباره عوض نشود، همین مقدار باقی می‌ماند.
  static Future<void> setSystemNumber(int number) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_systemNumberKey, number);

  }

}
