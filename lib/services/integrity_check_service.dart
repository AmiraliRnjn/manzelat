
import 'dart:io';

import 'backup_service.dart';
import 'storage_settings_service.dart';

class IntegrityCheckResult {
  final bool healthy;
  final String summary;
  final List<String> checks;

  const IntegrityCheckResult({
    required this.healthy,
    required this.summary,
    required this.checks,
  });
}

/// بررسی سلامت ذخیره‌سازی و Backup برای تشخیص سریع فایل‌های ناقص.
class IntegrityCheckService {
  static Future<IntegrityCheckResult> run() async {
    final checks = <String>[];
    var healthy = true;

    final rootPath = await StorageSettingsService.getStoragePath();
    if (rootPath == null || rootPath.trim().isEmpty) {
      return const IntegrityCheckResult(
        healthy: false,
        summary: 'مسیر ذخیره‌سازی تنظیم نشده است.',
        checks: ['✗ مسیر ذخیره‌سازی تنظیم نشده است.'],
      );
    }

    final root = Directory(rootPath);
    if (!await root.exists()) {
      return IntegrityCheckResult(
        healthy: false,
        summary: 'پوشه اصلی ذخیره‌سازی پیدا نشد.',
        checks: ['✗ $rootPath'],
      );
    }
    checks.add('✓ پوشه اصلی ذخیره‌سازی در دسترس است.');

    var zeroByteFiles = 0;
    var partFiles = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.toLowerCase();
      if (name.endsWith('.part')) {
        partFiles++;
        continue;
      }
      if (await entity.length() == 0) zeroByteFiles++;
    }

    if (zeroByteFiles == 0) {
      checks.add('✓ فایل صفر بایت در حافظه اصلی پیدا نشد.');
    } else {
      healthy = false;
      checks.add('✗ $zeroByteFiles فایل صفر بایت پیدا شد.');
    }

    if (partFiles == 0) {
      checks.add('✓ فایل موقت .part باقی‌مانده وجود ندارد.');
    } else {
      healthy = false;
      checks.add('✗ $partFiles فایل موقت .part باقی مانده است.');
    }

    final lastBackup = await BackupService.getLastBackupPath();
    if (lastBackup == null) {
      checks.add('! هنوز Backup موفقی ثبت نشده است.');
    } else {
      final inspection = await BackupService.inspectBackup(File(lastBackup));
      if (inspection.valid) {
        checks.add('✓ آخرین Backup معتبر است (${inspection.fileCount} فایل).');
      } else {
        healthy = false;
        checks.add('✗ آخرین Backup نامعتبر است: ${inspection.message}');
      }
    }

    return IntegrityCheckResult(
      healthy: healthy,
      summary: healthy ? 'ذخیره‌سازی سالم است.' : 'یک یا چند مورد نیاز به بررسی دارد.',
      checks: checks,
    );
  }
}



