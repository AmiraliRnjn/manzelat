import 'package:shared_preferences/shared_preferences.dart';

/// مسئول یادآوردن اینکه کدام فایل‌های ZIP «هنوز اشتراک‌گذاری نشده‌اند».
/// فقط تا زمانی که کاربر روی گزینه‌ی «اشتراک‌گذاری» یک ZIP بزند، آن مسیر
/// از لیست یادآوری خارج می‌شود. هیچ فایلی به‌خاطر این قابلیت حذف نمی‌شود؛
/// این فقط یک علامت داخلی (کنار SharedPreferences) است، نه تغییری در فایل‌ها.
class ZipShareStatusService {
  static const String _key = 'shared_zip_paths';

  static Future<Set<String>> getSharedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }

  /// فایل را «اشتراک‌گذاری‌شده» علامت می‌زند (یادآور کنارش دیگر نشان داده نمی‌شود).
  static Future<void> markAsShared(String zipPath) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_key) ?? []).toSet();
    current.add(zipPath);
    await prefs.setStringList(_key, current.toList());
  }

  /// علامت اشتراک‌گذاری را از یک مسیر پاک می‌کند — برای وقتی که فایل حذف
  /// می‌شود، یا وقتی ZIP دوباره ساخته می‌شود (چون محتوای جدید هنوز فرستاده نشده).
  static Future<void> clear(String zipPath) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_key) ?? []).toSet();
    current.remove(zipPath);
    await prefs.setStringList(_key, current.toList());
  }

  /// وقتی یک ZIP رنیم می‌شود، اگر قبلاً «اشتراک‌گذاری‌شده» بود، همان وضعیت
  /// را روی نام جدید هم منتقل می‌کند تا یادآور بی‌جهت دوباره ظاهر نشود.
  static Future<void> transfer(String oldPath, String newPath) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_key) ?? []).toSet();

    if (current.remove(oldPath)) {
      current.add(newPath);
      await prefs.setStringList(_key, current.toList());
    }
  }
}
