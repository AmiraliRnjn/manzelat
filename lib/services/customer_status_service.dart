import 'package:shared_preferences/shared_preferences.dart';
import '../reminder_status.dart';

/// مسئول یادآوردن وضعیت هر «مشتری» (نه فایل تکی): آیا مدارکش برای سرپرست
/// فرستاده شده، و آیا رسیدش برگشته یا نه.
///
/// چون پوشه‌ی اصلی مشتری و ZIP هم‌نامش («<نام>» و «<نام>.zip») هر دو
/// نماینده‌ی یک مشتری‌اند، کلید ذخیره‌سازی همیشه مسیر «پوشه» است — اگر
/// مسیر یک ZIP داده شود، پسوند .zip قبل از استفاده حذف می‌شود. این یعنی
/// اشتراک‌گذاری زیپ یا اشتراک‌گذاری خودِ پوشه، هر دو روی یک وضعیت مشترک اثر می‌گذارند.
class CustomerStatusService {
  static const String _sentKey = 'customer_sent_keys';
  static const String _receiptKey = 'customer_receipt_keys';

  static String keyForPath(String path) {
    if (path.toLowerCase().endsWith('.zip')) {
      return path.substring(0, path.length - 4);
    }
    return path;
  }

  static Future<Set<String>> getSentKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_sentKey) ?? []).toSet();
  }

  static Future<Set<String>> getReceiptKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_receiptKey) ?? []).toSet();
  }

  /// علامت می‌زند که مدارک این مشتری فرستاده شده (زرد، مگر رسیدش قبلاً آمده باشد).
  static Future<void> markSent(String path) async {
    final key = keyForPath(path);
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_sentKey) ?? []).toSet();
    current.add(key);
    await prefs.setStringList(_sentKey, current.toList());
  }

  static Future<void> clearSent(String path) async {
    final key = keyForPath(path);
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_sentKey) ?? []).toSet();
    current.remove(key);
    await prefs.setStringList(_sentKey, current.toList());
  }

  /// علامت می‌زند که رسید این مشتری ثبت شده (سبز).
  static Future<void> markReceiptReceived(String path) async {
    final key = keyForPath(path);
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_receiptKey) ?? []).toSet();
    current.add(key);
    await prefs.setStringList(_receiptKey, current.toList());
  }

  static Future<void> clearReceiptReceived(String path) async {
    final key = keyForPath(path);
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_receiptKey) ?? []).toSet();
    current.remove(key);
    await prefs.setStringList(_receiptKey, current.toList());
  }

  /// وقتی پوشه یا ZIP رنیم می‌شود، وضعیت (فرستاده‌شده/رسید) هم به نام جدید منتقل می‌شود.
  static Future<void> transfer(String oldPath, String newPath) async {
    final oldKey = keyForPath(oldPath);
    final newKey = keyForPath(newPath);
    final prefs = await SharedPreferences.getInstance();

    final sent = (prefs.getStringList(_sentKey) ?? []).toSet();
    if (sent.remove(oldKey)) {
      sent.add(newKey);
      await prefs.setStringList(_sentKey, sent.toList());
    }

    final receipts = (prefs.getStringList(_receiptKey) ?? []).toSet();
    if (receipts.remove(oldKey)) {
      receipts.add(newKey);
      await prefs.setStringList(_receiptKey, receipts.toList());
    }
  }

  /// وقتی خودِ مشتری (پوشه) کامل حذف می‌شود، وضعیتش هم پاک می‌شود.
  static Future<void> clearAll(String path) async {
    await clearSent(path);
    await clearReceiptReceived(path);
  }

  /// وضعیت نهایی یک مسیر (پوشه یا ZIP) — اولویت: رسید > فرستاده‌شده > هیچ‌کدام.
  static ReminderStatus statusFor(
    String path, {
    required Set<String> sentKeys,
    required Set<String> receiptKeys,
  }) {
    final key = keyForPath(path);
    if (receiptKeys.contains(key)) return ReminderStatus.receiptReceived;
    if (sentKeys.contains(key)) return ReminderStatus.awaitingReceipt;
    return ReminderStatus.notSent;
  }
}