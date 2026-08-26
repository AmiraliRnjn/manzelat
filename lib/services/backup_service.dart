import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'storage_settings_service.dart';
import 'work_date_service.dart';
import 'log_service.dart';

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

/// Backup/Restore کامل برنامه.
///
/// حالت Restore بدون overwrite به‌صورت Merge عمل می‌کند؛ بنابراین می‌توان
/// Backup سه گوشی را یکی‌یکی روی یک حافظه مقصد Restore کرد و داده‌های موجود
/// را حذف نکرد. وضعیت receiptها نیز در حالت Merge به‌صورت union ادغام می‌شود.
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoIntervalDaysKey, days.clamp(1, 30).toInt());
  }

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

      LogService.i('Backup', 'شروع backup خودکار به مسیر: $folder');
      await createBackup(destinationDirectory: directory, isAutomatic: true);
    } catch (e, st) {
      // Backup خودکار نباید باعث Crash برنامه شود.
      LogService.e('Backup', 'خطا در backup خودکار', e, st);
    }
  }

  static Future<BackupResult> createBackup({
    required Directory destinationDirectory,
    bool isAutomatic = false,
  }) async {
    Directory? tempDir;
    File? temp;
    LogService.i('Backup', 'createBackup شروع شد (isAutomatic=$isAutomatic, مقصد=${destinationDirectory.path})');
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
          message: 'پوشه اصلی اطلاعات برنامه پیدا نشد.',
        );
      }

      await destinationDirectory.create(recursive: true);
      final now = DateTime.now();
      final output = File(
        '${destinationDirectory.path}${Platform.pathSeparator}'
        'Manzelat_Backup_${_timestamp(now)}$backupExtension',
      );
      temp = File('${output.path}.part');
      if (await temp.exists()) await temp.delete();

      final files = <_BackupEntry>[];
      var totalBytes = 0;
      await for (final entity in sourceRoot.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final lower = entity.path.toLowerCase();
        if (lower.endsWith(backupExtension) ||
            lower.endsWith('$backupExtension.part')) {
          continue;
        }

        final stat = await entity.stat();
        final relative = _relativePath(sourceRoot.path, entity.path);
        if (relative.isEmpty || _isUnsafeRelativePath(relative)) continue;
        files.add(_BackupEntry(
          path: relative,
          size: stat.size,
          modified: stat.modified.millisecondsSinceEpoch,
        ));
        totalBytes += stat.size;
      }

      final prefs = await SharedPreferences.getInstance();
      final workDate = await WorkDateService.getWorkDate();
      final state = <String, dynamic>{
        'work_date_year': workDate.year,
        'work_date_month': workDate.month,
        'work_date_day': workDate.day,
        'receipt_keys': prefs.getStringList('customer_receipt_keys') ?? const [],
        'sent_keys': prefs.getStringList('customer_sent_keys') ?? const [],
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

      tempDir = await Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'manzelat_backup_${now.microsecondsSinceEpoch}',
      ).create(recursive: true);

      final manifestFile = File('${tempDir.path}${Platform.pathSeparator}manifest.json');
      final stateFile = File('${tempDir.path}${Platform.pathSeparator}app_state.json');
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
        for (final entry in files) {
          final source = File(
            '${sourceRoot.path}${Platform.pathSeparator}'
            '${entry.path.split('/').join(Platform.pathSeparator)}',
          );
          await encoder.addFile(source, 'data/${entry.path}');
        }
      } finally {
        await encoder.close();
      }

      if (!await temp.exists() || await temp.length() <= 0) {
        return const BackupResult(
          success: false,
          message: 'فایل Backup موقت ساخته نشد یا صفر بایت است.',
        );
      }

      await temp.rename(output.path);
      temp = null;

      final inspection = await inspectBackup(output);
      if (!inspection.valid) {
        if (await output.exists()) await output.delete();
        return BackupResult(
          success: false,
          message: 'اعتبارسنجی Backup ناموفق بود: ${inspection.message}',
        );
      }

      await prefs.setString(_lastBackupKey, output.path);
      await prefs.setInt(_lastBackupTimeKey, now.millisecondsSinceEpoch);

      LogService.i('Backup',
          'Backup موفق: ${files.length} فایل، ${totalBytes} بایت، مسیر=${output.path}');
      return BackupResult(
        success: true,
        message: isAutomatic
            ? 'Backup خودکار با موفقیت انجام شد.'
            : 'Backup با موفقیت ساخته شد.',
        path: output.path,
        fileCount: files.length,
        totalBytes: totalBytes,
      );
    } catch (e, st) {
      if (temp != null && await temp.exists()) {
        try { await temp.delete(); } catch (_) {}
      }
      LogService.e('Backup', 'خطا هنگام ساخت Backup', e, st);
      return BackupResult(
        success: false,
        message: 'خطا هنگام ساخت Backup: $e',
      );
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        try { await tempDir.delete(recursive: true); } catch (_) {}
      }
    }
  }

  static Future<BackupInspection> inspectBackup(File backupFile) async {
    try {
      if (!await backupFile.exists()) {
        return const BackupInspection(valid: false, message: 'فایل Backup وجود ندارد.');
      }
      if (!backupFile.path.toLowerCase().endsWith(backupExtension)) {
        return const BackupInspection(valid: false, message: 'فرمت فایل Backup معتبر نیست.');
      }
      if (await backupFile.length() <= 0) {
        return const BackupInspection(valid: false, message: 'فایل Backup صفر بایت است.');
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
          return const BackupInspection(valid: false, message: 'manifest.json در Backup وجود ندارد.');
        }

        final decoded = jsonDecode(utf8.decode(manifestEntry.readBytes()!.toList()));
        if (decoded is! Map<String, dynamic> ||
            decoded['format'] != 'manzelat_backup' ||
            decoded['version'] != formatVersion) {
          return const BackupInspection(valid: false, message: 'نسخه یا ساختار Backup پشتیبانی نمی‌شود.');
        }

        final entries = decoded['entries'];
        if (entries is! List || entries.isEmpty) {
          return const BackupInspection(valid: false, message: 'Backup هیچ فایل اطلاعاتی ندارد.');
        }

        final archiveNames = archive.where((e) => e.isFile).map((e) => e.name).toSet();
        var countedBytes = 0;
        var countedFiles = 0;

        for (final item in entries) {
          if (item is! Map) {
            return const BackupInspection(valid: false, message: 'یکی از رکوردهای Backup نامعتبر است.');
          }
          final relative = item['path'];
          final expectedSize = (item['size'] as num?)?.toInt();
          if (relative is! String || relative.isEmpty || _isUnsafeRelativePath(relative)) {
            return const BackupInspection(valid: false, message: 'مسیر مشکوک یا نامعتبر داخل Backup پیدا شد.');
          }
          if (expectedSize == null || expectedSize < 0) {
            return const BackupInspection(valid: false, message: 'حجم یکی از فایل‌های Backup نامعتبر است.');
          }
          if (!archiveNames.contains('data/$relative')) {
            return BackupInspection(valid: false, message: 'فایل $relative در آرشیو ناقص است.');
          }
          countedFiles++;
          countedBytes += expectedSize;
        }

        final manifestCount = (decoded['file_count'] as num?)?.toInt();
        final manifestBytes = (decoded['total_bytes'] as num?)?.toInt();
        if (manifestCount != null && manifestCount != countedFiles) {
          return const BackupInspection(valid: false, message: 'تعداد فایل‌های Backup با manifest یکسان نیست.');
        }
        if (manifestBytes != null && manifestBytes != countedBytes) {
          return const BackupInspection(valid: false, message: 'حجم فایل‌های Backup با manifest یکسان نیست.');
        }

        return BackupInspection(
          valid: true,
          message: 'Backup سالم و قابل Restore/Merge است.',
          fileCount: countedFiles,
          totalBytes: countedBytes,
          createdAt: DateTime.tryParse(decoded['created_at']?.toString() ?? ''),
          originalRoot: decoded['original_root']?.toString(),
        );
      } finally {
        await input.close();
      }
    } catch (e) {
      return BackupInspection(valid: false, message: 'فایل Backup خراب یا غیرقابل خواندن است: $e');
    }
  }

  /// اگر [overwriteExisting] false باشد، Restore به شکل Merge انجام می‌شود:
  /// فایل‌های جدید اضافه می‌شوند و فایل‌های هم‌مسیر موجود دست‌نخورده می‌مانند.
  static Future<BackupResult> restoreBackup({
    required File backupFile,
    required Directory targetRoot,
    required bool restoreFiles,
    required bool restoreAppState,
    bool overwriteExisting = false,
  }) async {
    LogService.i('Backup',
        'restoreBackup شروع شد (فایل=${backupFile.path}, overwrite=$overwriteExisting)');
    try {
      final inspection = await inspectBackup(backupFile);
      if (!inspection.valid) {
        return BackupResult(success: false, message: inspection.message);
      }
      if (!restoreFiles && !restoreAppState) {
        return const BackupResult(success: false, message: 'حداقل یک بخش برای Restore انتخاب کنید.');
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
              return const BackupResult(success: false, message: 'Backup شامل مسیر غیرمجاز است و Restore متوقف شد.');
            }

            final destination = File(
              '${targetRoot.path}${Platform.pathSeparator}'
              '${relative.split('/').join(Platform.pathSeparator)}',
            );
            if (await destination.exists() && !overwriteExisting) continue;

            await destination.parent.create(recursive: true);
            final part = File('${destination.path}.part');
            if (await part.exists()) await part.delete();

            try {
              final output = OutputFileStream(part.path);
              try {
                entry.writeContent(output);
              } finally {
                output.closeSync();
              }
              if (!await part.exists() || await part.length() != entry.size) {
                throw FileSystemException('ذخیره فایل Restore کامل نشد.', part.path);
              }
              if (await destination.exists()) await destination.delete();
              await part.rename(destination.path);
              if (!await destination.exists() || await destination.length() != entry.size) {
                throw FileSystemException('تأیید نهایی Restore ناموفق بود.', destination.path);
              }
              restoredFiles++;
              restoredBytes += entry.size;
            } catch (_) {
              if (await part.exists()) {
                try { await part.delete(); } catch (_) {}
              }
              rethrow;
            }
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
            final decoded = jsonDecode(utf8.decode(stateEntry.readBytes()!.toList()));
            if (decoded is Map) {
              final prefs = await SharedPreferences.getInstance();

              final backupReceipts = decoded['receipt_keys'] is List
                  ? (decoded['receipt_keys'] as List).whereType<String>().toSet()
                  : <String>{};
              final currentReceipts = prefs.getStringList('customer_receipt_keys')?.toSet() ?? <String>{};
              final mergedReceipts = {...currentReceipts, ...backupReceipts}.toList()..sort();
              await prefs.setStringList('customer_receipt_keys', mergedReceipts);

              // «سبز» (رسید دریافت‌شده) قبلاً این‌جا Merge می‌شد ولی «زرد»
              // (فرستاده‌شده، در انتظار رسید) اصلاً ذخیره/بازیابی نمی‌شد؛ یعنی
              // بعد از Restore/Merge یک Backup، مشتری‌های زرد دوباره قرمز
              // نشان داده می‌شدند. حالا همان‌طور union می‌شود.
              final backupSent = decoded['sent_keys'] is List
                  ? (decoded['sent_keys'] as List).whereType<String>().toSet()
                  : <String>{};
              final currentSent = prefs.getStringList('customer_sent_keys')?.toSet() ?? <String>{};
              final mergedSent = {...currentSent, ...backupSent}.toList()..sort();
              await prefs.setStringList('customer_sent_keys', mergedSent);

              // در Merge، تاریخ و تنظیمات دستگاه مقصد تغییر نمی‌کنند. در Restore
              // جایگزین‌کننده، وضعیت Backup اعمال می‌شود.
              if (overwriteExisting) {
                final workYear = decoded['work_date_year'];
                final workMonth = decoded['work_date_month'];
                final workDay = decoded['work_date_day'];
                if (workYear is num && workMonth is num && workDay is num) {
                  try {
                    await WorkDateService.setWorkDate(
                      Jalali(workYear.toInt(), workMonth.toInt(), workDay.toInt()),
                    );
                  } catch (_) {}
                }

                final autoEnabled = decoded['auto_backup_enabled'];
                if (autoEnabled is bool) {
                  await prefs.setBool(_autoEnabledKey, autoEnabled);
                }
                final interval = decoded['auto_backup_interval_days'];
                if (interval is num) {
                  await prefs.setInt(_autoIntervalDaysKey, interval.toInt().clamp(1, 30).toInt());
                }
              }
            }
          }
        }

        LogService.i('Backup',
            'Restore موفق: $restoredFiles فایل، $restoredBytes بایت، overwrite=$overwriteExisting');
        return BackupResult(
          success: true,
          message: overwriteExisting
              ? 'Restore با موفقیت انجام شد.'
              : 'Merge با موفقیت انجام شد؛ اطلاعات موجود حذف نشدند.',
          fileCount: restoredFiles,
          totalBytes: restoredBytes,
        );
      } finally {
        await input.close();
      }
    } catch (e, st) {
      LogService.e('Backup', 'خطا هنگام Restore/Merge', e, st);
      return BackupResult(success: false, message: 'خطا هنگام Restore/Merge: $e');
    }
  }

  static String _timestamp(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}${two(date.month)}${two(date.day)}_${two(date.hour)}${two(date.minute)}${two(date.second)}';
  }

  static String _relativePath(String root, String path) {
    final normalizedRoot = root.replaceAll('\\', '/').replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.replaceAll('\\', '/');
    if (normalizedPath == normalizedRoot) return '';
    final prefix = '$normalizedRoot/';
    return normalizedPath.startsWith(prefix)
        ? normalizedPath.substring(prefix.length)
        : normalizedPath.split('/').last;
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