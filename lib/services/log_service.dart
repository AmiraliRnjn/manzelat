import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// سطح اهمیت هر لاگ.
enum LogLevel { debug, info, warning, error }

/// سرویس لاگ سبک برای کل اپ.
///
/// هدف:
/// - این لاگ برای کاربر عادی هیچ کاربردی ندارد؛ فقط برای مواقعی است که
///   یک مشکل (کرش، خطای Backup، خطای NFC و ...) پیش بیاید و بشود فایل
///   لاگ را با توسعه‌دهنده به اشتراک گذاشت.
/// - سبک بودن: فقط سطح warning و error نوشته می‌شود (پیش‌فرض)، یعنی در
///   حالت عادیِ بدون خطا عملاً هیچ‌چیز روی دیسک نوشته نمی‌شود و هیچ
///   overhead‌ای روی اپ نمی‌گذارد. حجم فایل هم محدود می‌شود (Rotate).
///
/// استفاده:
/// ```dart
/// LogService.w('Backup', 'یک هشدار غیرمنتظره');
/// LogService.e('Backup', 'خطا در backup', error, stackTrace);
/// ```
class LogService {
  LogService._();

  static const String _fileName = 'app_log.txt';
  static const String _oldFileName = 'app_log.old.txt';

  /// حداکثر حجم فایل لاگ فعال قبل از Rotate (بایت). عمداً کوچک نگه
  /// داشته شده تا لاگ هیچ‌وقت فضای قابل توجهی اشغال نکند.
  static const int _maxFileBytes = 1 * 1024 * 1024; // 1MB

  static final Queue<String> _buffer = Queue<String>();
  static File? _file;
  static bool _writing = false;

  /// سطح حداقلی که واقعاً نوشته می‌شود. پیش‌فرض روی warning است چون
  /// این لاگ فقط برای مواقعی است که چیزی خراب شده و کاربر با توسعه‌دهنده
  /// به اشتراک می‌گذارد؛ در حالت عادی (بدون خطا) عملاً هیچ‌چیز نوشته
  /// نمی‌شود و هیچ overhead‌ای روی اپ نمی‌گذارد.
  static LogLevel minLevel = LogLevel.warning;

  static Future<File> _ensureFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    final logsDir = Directory('${dir.path}${Platform.pathSeparator}logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    _file = File('${logsDir.path}${Platform.pathSeparator}$_fileName');
    return _file!;
  }

  static String _levelTag(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  static bool _allowed(LogLevel level) => level.index >= minLevel.index;

  /// ثبت یک خط لاگ. هرگز Exception پرتاب نمی‌کند (لاگ نباید خودش باعث
  /// کرش شود)؛ در بدترین حالت فقط چیزی نوشته نمی‌شود.
  static void log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!_allowed(level)) return;
    try {
      final now = DateTime.now();
      final ts = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';

      final buffer = StringBuffer()
        ..write('[$ts] [${_levelTag(level)}] [$tag] $message');
      if (error != null) {
        buffer.write(' | error: $error');
      }
      if (stackTrace != null) {
        // فقط چند خط اول Stacktrace کافی است؛ کل آن حجم را زیاد می‌کند.
        final lines = stackTrace.toString().split('\n').take(5).join(' <- ');
        buffer.write(' | stack: $lines');
      }

      _buffer.add(buffer.toString());

      // چون پیش‌فرض فقط warning/error ثبت می‌شود (یعنی این خط به‌ندرت
      // اجرا می‌شود)، همیشه بلافاصله نوشته می‌شود؛ نیازی به Timer یا
      // صبر کردن برای جمع شدن چند خط نیست.
      unawaited(_flush());
    } catch (_) {
      // لاگ نباید خودش خطا تولید کند.
    }
  }

  static Future<void> _flush() async {
    if (_writing || _buffer.isEmpty) return;
    _writing = true;
    try {
      final lines = _buffer.toList();
      _buffer.clear();

      final file = await _ensureFile();
      await _rotateIfNeeded(file);
      final sink = file.openWrite(mode: FileMode.append);
      try {
        sink.write('${lines.join('\n')}\n');
        await sink.flush();
      } finally {
        await sink.close();
      }
    } catch (_) {
      // اگر نوشتن شکست خورد، سیستم لاگ نباید کل اپ را تحت تاثیر بگذارد.
    } finally {
      _writing = false;
    }
  }

  /// وقتی فایل از حد مجاز بزرگ‌تر شد، یک نسخه‌ی قدیمی نگه داشته می‌شود
  /// و فایل فعال از نو شروع می‌شود. یعنی حداکثر ~2 برابر _maxFileBytes
  /// فضا اشغال می‌شود، نه بیشتر.
  static Future<void> _rotateIfNeeded(File file) async {
    try {
      if (!await file.exists()) return;
      final size = await file.length();
      if (size < _maxFileBytes) return;

      final dir = file.parent.path;
      final oldFile = File('$dir${Platform.pathSeparator}$_oldFileName');
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
      await file.rename(oldFile.path);
      _file = null;
      await _ensureFile();
    } catch (_) {
      // Rotate ناموفق نباید جلوی لاگ بعدی را بگیرد.
    }
  }

  /// همه‌ی لاگ‌های بافر شده را فوری روی دیسک می‌نویسد. مثلاً موقع
  /// didChangeAppLifecycleState(paused) خوب است صدا زده شود تا لاگ‌های
  /// آخر جلسه از دست نروند.
  static Future<void> flushNow() => _flush();

  /// متن کامل لاگ فعلی (برای نمایش در صفحه‌ی تنظیمات یا اشتراک‌گذاری
  /// جهت پشتیبانی). شامل فایل قدیمی هم می‌شود تا تاریخچه بیشتری داشته باشد.
  static Future<String> readAll() async {
    try {
      await _flush();
      final file = await _ensureFile();
      final dir = file.parent.path;
      final oldFile = File('$dir${Platform.pathSeparator}$_oldFileName');

      final parts = <String>[];
      if (await oldFile.exists()) {
        parts.add(await oldFile.readAsString());
      }
      if (await file.exists()) {
        parts.add(await file.readAsString());
      }
      return parts.join('\n');
    } catch (e) {
      return '(خواندن لاگ ناموفق بود: $e)';
    }
  }

  /// مسیر فایل لاگ فعال (برای اشتراک‌گذاری مستقیم فایل).
  static Future<String> currentFilePath() async {
    final file = await _ensureFile();
    return file.path;
  }

  /// پاک کردن کامل لاگ‌ها (مثلاً دکمه‌ی «پاک کردن لاگ» در تنظیمات).
  static Future<void> clear() async {
    try {
      _buffer.clear();
      final file = await _ensureFile();
      final dir = file.parent.path;
      final oldFile = File('$dir${Platform.pathSeparator}$_oldFileName');
      if (await file.exists()) await file.writeAsString('');
      if (await oldFile.exists()) await oldFile.delete();
    } catch (_) {}
  }

  // میانبرهای کوتاه برای استفاده‌ی راحت‌تر در بقیه‌ی کد.
  static void d(String tag, String message) => log(LogLevel.debug, tag, message);
  static void i(String tag, String message) => log(LogLevel.info, tag, message);
  static void w(String tag, String message, [Object? error]) =>
      log(LogLevel.warning, tag, message, error);
  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) =>
      log(LogLevel.error, tag, message, error, stackTrace);
}