import 'dart:io';

import 'package:shamsi_date/shamsi_date.dart';

import '../reminder_status.dart';
import 'customer_status_service.dart';
import 'file_manager_service.dart';
import 'storage_settings_service.dart';
import 'worker_selection_service.dart';

/// مسئول تشخیص اینکه در یک روز کاری خاص، پوشه یا ZIP بدون رسید (قرمز یا
/// زرد) باقی مانده یا نه. از این اطلاعات برای نمایش نقطه‌ی یادآور قرمز
/// روی دایره‌ی همان روز در تقویم استفاده می‌شود تا کاربر بعداً بتواند
/// برگردد و تکمیلش کند.
class WorkCalendarStatusService {
  /// برای یک ماه شمسی مشخص، شماره‌ی روزهایی که حداقل یک پوشه یا ZIP
  /// بدون رسید (چه شارژ چه صدور) دارند را برمی‌گرداند.
  static Future<Set<int>> incompleteDaysForMonth(int year, int month) async {
    final rootPath = await StorageSettingsService.getStoragePath();
    if (rootPath == null || rootPath.trim().isEmpty) return {};

    final sentKeys = await CustomerStatusService.getSentKeys();
    final receiptKeys = await CustomerStatusService.getReceiptKeys();

    final monthLength = Jalali(year, month, 1).monthLength;
    final incompleteDays = <int>{};

    for (var day = 1; day <= monthLength; day++) {
      final date = Jalali(year, month, day);
      final hasIncomplete = await _dayHasIncomplete(
        rootPath: rootPath,
        date: date,
        sentKeys: sentKeys,
        receiptKeys: receiptKeys,
      );
      if (hasIncomplete) incompleteDays.add(day);
    }

    return incompleteDays;
  }

  /// همان بررسی بالا ولی فقط برای یک روز مشخص (برای استفاده‌های سبک‌تر).
  static Future<bool> dayHasIncomplete(Jalali date) async {
    final rootPath = await StorageSettingsService.getStoragePath();
    if (rootPath == null || rootPath.trim().isEmpty) return false;

    final sentKeys = await CustomerStatusService.getSentKeys();
    final receiptKeys = await CustomerStatusService.getReceiptKeys();

    return _dayHasIncomplete(
      rootPath: rootPath,
      date: date,
      sentKeys: sentKeys,
      receiptKeys: receiptKeys,
    );
  }

  static Future<bool> _dayHasIncomplete({
    required String rootPath,
    required Jalali date,
    required Set<String> sentKeys,
    required Set<String> receiptKeys,
  }) async {
    final dayFolderName =
        await WorkerSelectionService.resolveDayFolderName(date);

    for (final operationFolderName in ['شارژ', 'صدور']) {
      final dayPath = [
        rootPath,
        operationFolderName,
        date.year.toString(),
        date.month.toString().padLeft(2, '0'),
        dayFolderName,
      ].join(Platform.pathSeparator);

      final dayDir = Directory(dayPath);
      if (!await dayDir.exists()) continue;

      List<FileSystemEntity> entities;
      try {
        entities = dayDir.listSync();
      } catch (_) {
        continue;
      }

      for (final entity in entities) {
        if (entity is Directory) {
          final status = CustomerStatusService.statusFor(
            entity.path,
            sentKeys: sentKeys,
            receiptKeys: receiptKeys,
          );
          if (status != ReminderStatus.receiptReceived) return true;
        } else if (entity is File &&
            entity.path.toLowerCase().endsWith('.zip')) {
          final name = FileManagerService.displayName(entity);
          // ZIP ترکیبی نماینده‌ی یک مشتری نیست، پس در این بررسی حساب نمی‌شود.
          if (name == FileManagerService.allZipsFileName) continue;

          final status = CustomerStatusService.statusFor(
            entity.path,
            sentKeys: sentKeys,
            receiptKeys: receiptKeys,
          );
          if (status != ReminderStatus.receiptReceived) return true;
        }
      }
    }

    return false;
  }
}
