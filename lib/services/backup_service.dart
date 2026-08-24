import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'storage_settings_service.dart';
import 'work_date_service.dart';

/// نتیجه‌ی عملیات Backup/Restore.
class BackupResult {
  final bool success;
  final String message;
  final String? path;
  final int fileCount;
  final int totalBytes;

  const BackupResult({
    required this.success,
    required this.message,
    this.path,
    this.fileCount = 0,
    this.totalBytes = 0,
  });
}

class BackupInspection {
  final bool valid;
  final String message;
  final int fileCount;
  final int totalBytes;
  final DateTime? createdAt;
  final String? originalRoot;

  const BackupInspection({
    required this.valid,
    required this.message,
    this.fileCount = 0,
    this.totalBytes = 0,
    this.createdAt,
    this.originalRoot,
  });
}

/// مدیریت Backup/Restore کامل اطلاعات برنامه.
///
/// فرمت Backup اختصاصی برنامه:
///   manifest.json
///   app_state.json
///   data/...
///
/// فایل‌های داخل data با ZIP و به‌صورت stream ذخیره می‌شوند تا برای
/// فایل‌های حجیم، تمام اطلاعات هم‌زمان در RAM قرار نگیرد.
class BackupService {
  static const String backupExtension = '.mzbackup';
  static const String _lastBackupKey = 'backup_last_path';
  static const String _lastBackupTimeKey = 'backup_last_time';
  static const String _autoEnabledKey = 'backup_auto_enabled';
  static const String _autoFolderKey = 'backup_auto_folder';
  static const String _autoIntervalDaysKey = 'backup_auto_interval_days';

  static const int formatVersion = 1;

  static Future<String?> getLastBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBackupKey);
  }

  static Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_lastBackupTimeKey);
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoEnabledKey) ?? false;
  }

  static Future<void> setAutoBackupEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoEnabledKey, value);
  }

  static Future<String?> getAutoBackupFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_autoFolderKey);
  }

  static Future<void> setAutoBackupFolder(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await prefs.remove(_autoFolderKey);
    } else {
      await prefs.setString(_autoFolderKey, path);
    }
  }

  static Future<int> getAutoBackupIntervalDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoIntervalDaysKey) ?? 1;
  }

  static Future<void> setAutoBackupIntervalDays(int days) async {
    final safeDays = days.clamp(1, 30).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoIntervalDaysKey, safeDays);
  }

  /// در شروع برنامه اجرا شود. اگر Backup خودکار فعال باشد و موعدش رسیده
  /// باشد، یک Backup جدید ساخته می‌شود.
  static Future<void> maybeRunAutoBackup() async {
    try {
      if (!await isAutoBackupEnabled()) return;

      final folder = await getAutoBackupFolder();
      if (folder == null || folder.trim().isEmpty) return;

      final directory = Directory(folder);
      if (!await directory.exists()) return;

      final last = await getLastBackupTime();
      final interval = await getAutoBackupIntervalDays();

      if (last != null &&
          DateTime.now().difference(last).inHours < interval * 24) {
        return;
      }

      await createBackup(
        destinationDirectory: directory,
        isAutomatic: true,
      );
    } catch (_) {
      // Backup خودکار نباید باعث Crash شدن برنامه شود.
    }
  }

  static Future<BackupResult> createBackup({
    required Directory destinationDirectory,
    bool isAutomatic = false,
  }) async {
    try {
      final rootPath = await StorageSettingsService.getStoragePath();
      if (rootPath == null || rootPath.trim().isEmpty) {
        return const BackupResult(
          success: false,
          message: 'مسیر ذخیره‌سازی برنامه هنوز مشخص نشده است.',
        );
      }

      final sourceRoot = Directory(rootPath);
      if (!await sourceRoot.exists()) {
        return const BackupResult(
          success: false,
          message: 'پوشه‌ی اصلی اطلاعات برنامه پیدا نشد.',
        );
      }

      await destinationDirectory.create(recursive: true);

      final now = DateTime.now();
      final stamp = _timestamp(now);
      final output = File(
        '${destinationDirectory.path}${Platform.pathSeparator}'
        'Manzelat_Backup_$stamp$backupExtension',
      );

      // Backup موقت می‌سازیم تا در صورت قطع شدن عملیات، فایل خراب با نام
      // Backup نهایی باقی نماند.
      final temp = File('${output.path}.part');
      if (await temp.exists()) await temp.delete();

      final files = <_BackupEntry>[];
      var totalBytes = 0;

      await for (final entity in sourceRoot.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;

        // Backup قبلی نباید دوباره داخل Backup بعدی قرار بگیرد.
        if (entity.path.toLowerCase().endsWith(backupExtension)) continue;
        if (entity.path.toLowerCase().endsWith('$backupExtension.part')) continue;

        final relative = _relativePath(sourceRoot.path, entity.path);
        final stat = await entity.stat();

        files.add(
          _BackupEntry(
            path: relative,
            size: stat.size,
            modified: stat.modified.millisecondsSinceEpoch,
          ),
        );
        totalBytes += stat.size;
      }

      final prefs = await SharedPreferences.getInstance();
      final state = <String, dynamic>{
        'work_date_year': (await WorkDateService.getWorkDate()).year,
        'work_date_month': (await WorkDateService.getWorkDate()).month,
        'work_date_day': (await WorkDateService.getWorkDate()).day,
        'receipt_keys': prefs.getStringList('customer_receipt_keys') ?? const [],
        // storage_path عمداً Restore نمی‌شود؛ چون مسیر دستگاه جدید ممکن است متفاوت باشد.
        'auto_backup_enabled': prefs.getBool(_autoEnabledKey) ?? false,
        'auto_backup_interval_days': prefs.getInt(_autoIntervalDaysKey) ?? 1,
      };

      final manifest = <String, dynamic>{
        'format': 'manzelat_backup',
        'version': formatVersion,
        'created_at': now.toIso8601String(),
        'original_root': sourceRoot.path,
        'file_count': files.length,
        'total_bytes': totalBytes,
        'entries': files.map((e) => e.toJson()).toList(),
      };

      // manifest و state در tempهای جدا ساخته می‌شوند.
      final tempDir = await Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'manzelat_backup_${now.microsecondsSinceEpoch}',
      ).create(recursive: true);

      final manifestFile = File(
        '${tempDir.path}${Platform.pathSeparator}manifest.json',
      );
      final stateFile = File(
        '${tempDir.path}${Platform.pathSeparator}app_state.json',
      );

      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );
      await stateFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(state),
        flush: true,
      );

      final encoder = ZipFileEncoder();
      try {
        encoder.create(temp.path);
        await encoder.addFile(manifestFile, 'manifest.json');
        await encoder.addFile(stateFile, 'app_state.json');

        // داده‌ها مستقیماً از دیسک خوانده و داخل ZIP نوشته می‌شوند.
        for (final entry in files) {
          final source = File(
            '${sourceRoot.path}${Platform.pathSeparator}'
            '${entry.path.split('/').join(Platform.pathSeparator)}',
          );
          await encoder.addFile(
            source,
            'data/${entry.path}',
          );
        }
      } finally {
        await encoder.close();
      }

      try {
        await manifestFile.delete();
        await stateFile.delete();
        await tempDir.delete(recursive: true);
      } catch (_) {
        // فایل‌های موقت در صورت خطای cleanup روی Backup نهایی اثری ندارند.
      }

      if (!await temp.exists()) {
        return const BackupResult(
          success: false,
          message: 'فایل Backup ساخته نشد.',
        );
      }

      await temp.rename(output.path);

      // یک بار فایل نهایی را باز می‌کنیم و ساختار آن را بررسی می‌کنیم.
      final inspection = await inspectBackup(output);
      if (!inspection.valid) {
        try { await output.delete(); } catch (_) {}
        return BackupResult(
          success: false,
          message: 'Backup ساخته شد اما اعتبارسنجی آن ناموفق بود: ${inspection.message}',
        );
      }

      await prefs.setString(_lastBackupKey, output.path);
      await prefs.setInt(
        _lastBackupTimeKey,
        now.millisecondsSinceEpoch,
      );

      return BackupResult(
        success: true,
        message: isAutomatic
            ? 'Backup خودکار با موفقیت انجام شد.'
            : 'Backup با موفقیت ساخته شد.',
        path: output.path,
        fileCount: files.length,
        totalBytes: totalBytes,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'خطا هنگام ساخت Backup: $e',
      );
    }
  }

  static Future<BackupInspection> inspectBackup(File backupFile) async {
    try {
      if (!await backupFile.exists()) {
        return const BackupInspection(
          valid: false,
          message: 'فایل Backup وجود ندارد.',
        );
      }

      if (!backupFile.path.toLowerCase().endsWith(backupExtension)) {
        return const BackupInspection(
          valid: false,
          message: 'فرمت فایل Backup معتبر نیست.',
        );
      }

      final input = InputFileStream(backupFile.path);
      try {
        final archive = ZipDecoder().decodeStream(input);
        ArchiveFile? manifestEntry;

        for (final entry in archive) {
          if (entry.isFile && entry.name == 'manifest.json') {
            manifestEntry = entry;
            break;
          }
        }

        if (manifestEntry == null) {
          return const BackupInspection(
            valid: false,
            message: 'manifest.json در Backup وجود ندارد.',
          );
        }

        final manifest = jsonDecode(
          utf8.decode(manifestEntry.readBytes()!.toList()),
        );

        if (manifest is! Map<String, dynamic> ||
            manifest['format'] != 'manzelat_backup' ||
            manifest['version'] != formatVersion) {
          return const BackupInspection(
            valid: false,
            message: 'نسخه یا ساختار Backup پشتیبانی نمی‌شود.',
          );
        }

        final entries = manifest['entries'];
        if (entries is! List) {
          return const BackupInspection(
            valid: false,
            message: 'فهرست فایل‌های Backup خراب است.',
          );
        }

        final archiveNames = archive
            .where((e) => e.isFile)
            .map((e) => e.name)
            .toSet();

        for (final item in entries) {
          if (item is! Map) {
            return const BackupInspection(
              valid: false,
              message: 'یکی از رکوردهای Backup نامعتبر است.',
            );
          }

          final relative = item['path'];
          if (relative is! String ||
              relative.isEmpty ||
              _isUnsafeRelativePath(relative)) {
            return const BackupInspection(
              valid: false,
              message: 'مسیر مشکوک یا نامعتبر داخل Backup پیدا شد.',
            );
          }

          if (!archiveNames.contains('data/$relative')) {
            return BackupInspection(
              valid: false,
              message: 'فایل $relative در آرشیو ناقص است.',
            );
          }
        }

        return BackupInspection(
          valid: true,
          message: 'Backup سالم و قابل Restore است.',
          fileCount: (manifest['file_count'] as num?)?.toInt() ?? entries.length,
          totalBytes: (manifest['total_bytes'] as num?)?.toInt() ?? 0,
          createdAt: DateTime.tryParse(manifest['created_at']?.toString() ?? ''),
          originalRoot: manifest['original_root']?.toString(),
        );
      } finally {
        await input.close();
      }
    } catch (e) {
      return BackupInspection(
        valid: false,
        message: 'فایل Backup خراب یا غیرقابل خواندن است: $e',
      );
    }
  }

  /// Restore انتخابی:
  /// - restoreFiles: تمام فایل‌ها و پوشه‌های اطلاعاتی
  /// - restoreAppState: وضعیت‌های غیر وابسته به مسیر مثل رسیدها و تاریخ کاری
  ///
  /// مسیر storage فعلی کاربر حفظ می‌شود و هرگز از Backup جایگزین نمی‌شود.
  static Future<BackupResult> restoreBackup({
    required File backupFile,
    required Directory targetRoot,
    required bool restoreFiles,
    required bool restoreAppState,
    bool overwriteExisting = false,
  }) async {
    try {
      final inspection = await inspectBackup(backupFile);
      if (!inspection.valid) {
        return BackupResult(
          success: false,
          message: inspection.message,
        );
      }

      if (!restoreFiles && !restoreAppState) {
        return const BackupResult(
          success: false,
          message: 'حداقل یک بخش برای Restore انتخاب کنید.',
        );
      }

      await targetRoot.create(recursive: true);

      final input = InputFileStream(backupFile.path);
      try {
        final archive = ZipDecoder().decodeStream(input);
        var restoredFiles = 0;
        var restoredBytes = 0;

        if (restoreFiles) {
          for (final entry in archive) {
            if (!entry.isFile || !entry.name.startsWith('data/')) continue;

            final relative = entry.name.substring('data/'.length);
            if (_isUnsafeRelativePath(relative)) {
              return const BackupResult(
                success: false,
                message: 'Backup شامل مسیر غیرمجاز است و Restore متوقف شد.',
              );
            }

            final destination = File(
              '${targetRoot.path}${Platform.pathSeparator}'
              '${relative.split('/').join(Platform.pathSeparator)}',
            );

            if (await destination.exists() && !overwriteExisting) {
              continue;
            }

            await destination.parent.create(recursive: true);

            final output = OutputFileStream(destination.path);
            try {
              entry.writeContent(output);
            } finally {
              output.closeSync();
            }

            restoredFiles++;
            restoredBytes += entry.size;
          }
        }

        if (restoreAppState) {
          ArchiveFile? stateEntry;
          for (final entry in archive) {
            if (entry.isFile && entry.name == 'app_state.json') {
              stateEntry = entry;
              break;
            }
          }

          if (stateEntry != null) {
            final decoded = jsonDecode(
              utf8.decode(stateEntry.readBytes()!.toList()),
            );
            if (decoded is Map) {
              final prefs = await SharedPreferences.getInstance();

              final receipts = decoded['receipt_keys'];
              if (receipts is List) {
                await prefs.setStringList(
                  'customer_receipt_keys',
                  receipts.whereType<String>().toList(),
                );
              }

              final workYear = decoded['work_date_year'];
              final workMonth = decoded['work_date_month'];
              final workDay = decoded['work_date_day'];
              if (workYear is num && workMonth is num && workDay is num) {
                try {
                  await WorkDateService.setWorkDate(
                    Jalali(
                      workYear.toInt(),
                      workMonth.toInt(),
                      workDay.toInt(),
                    ),
                  );
                } catch (_) {
                  // تاریخ Backup نامعتبر است؛ تاریخ فعلی حفظ می‌شود.
                }
              }

              // مسیر ذخیره‌سازی فعلی عمداً دست‌نخورده می‌ماند.
              final autoEnabled = decoded['auto_backup_enabled'];
              if (autoEnabled is bool) {
                await prefs.setBool(_autoEnabledKey, autoEnabled);
              }

              final interval = decoded['auto_backup_interval_days'];
              if (interval is num) {
                await prefs.setInt(
                  _autoIntervalDaysKey,
                  interval.toInt().clamp(1, 30).toInt(),
                );
              }
            }
          }
        }

        return BackupResult(
          success: true,
          message: 'Restore با موفقیت انجام شد.',
          fileCount: restoredFiles,
          totalBytes: restoredBytes,
        );
      } finally {
        await input.close();
      }
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'خطا هنگام Restore: $e',
      );
    }
  }

  static String _timestamp(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}${two(date.month)}${two(date.day)}_'
        '${two(date.hour)}${two(date.minute)}${two(date.second)}';
  }

  static String _relativePath(String root, String path) {
    final normalizedRoot = root.replaceAll('\\', '/').replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.replaceAll('\\', '/');
    if (normalizedPath == normalizedRoot) return '';
    final prefix = '$normalizedRoot/';
    if (normalizedPath.startsWith(prefix)) {
      return normalizedPath.substring(prefix.length);
    }
    return normalizedPath.split('/').last;
  }

  static bool _isUnsafeRelativePath(String path) {
    if (path.isEmpty) return true;
    final normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.startsWith('~')) return true;
    final parts = normalized.split('/');
    return parts.any((part) => part.isEmpty || part == '.' || part == '..');
  }
}

class _BackupEntry {
  final String path;
  final int size;
  final int modified;

  const _BackupEntry({
    required this.path,
    required this.size,
    required this.modified,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'size': size,
        'modified': modified,
      };
}
