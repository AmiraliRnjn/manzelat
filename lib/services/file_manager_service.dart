import 'dart:io';
import '../operation_type.dart';
import 'storage_settings_service.dart';
import 'work_date_service.dart';

/// مسئول پیدا کردن مسیر پوشه‌ی «روز» (شارژ یا صدور) برای تاریخ کاری فعال،
/// دقیقاً با همان قواعد StorageService — بدون ساخت پوشه (فقط خواندن).
class FileManagerService {

  /// پوشه‌ی روز را برمی‌گرداند. اگر مسیر ذخیره‌سازی هنوز تنظیم نشده باشد، null است.
  static Future<Directory?> getDayFolder(OperationType operationType) async {
    final rootPath = await StorageSettingsService.getStoragePath();

    if (rootPath == null || rootPath.trim().isEmpty) {
      return null;
    }

    final workDate = await WorkDateService.getWorkDate();

    final operationFolderName =
        operationType == OperationType.charge ? 'شارژ' : 'صدور';

    final yearFolderName = workDate.year.toString();
    final monthFolderName = workDate.month.toString().padLeft(2, '0');
    final dayFolderName = WorkDateService.folderNameFor(workDate);

    final dayPath = [
      rootPath,
      operationFolderName,
      yearFolderName,
      monthFolderName,
      dayFolderName,
    ].join(Platform.pathSeparator);

    return Directory(dayPath);
  }

  /// پوشه‌های مشتری (فایل اصلی) در روز جاری. اگر پوشه‌ی روز هنوز
  /// ساخته نشده (هیچ مشتری‌ای امروز ثبت نشده)، لیست خالی برمی‌گردد.
  static Future<List<Directory>> getCustomerFolders(
    OperationType operationType,
  ) async {
    final dayFolder = await getDayFolder(operationType);

    if (dayFolder == null || !await dayFolder.exists()) {
      return [];
    }

    final folders = dayFolder
        .listSync()
        .whereType<Directory>()
        .toList();

    folders.sort((a, b) => a.path.compareTo(b.path));
    return folders;
  }

  /// فایل‌های ZIP مشتری‌ها در روز جاری.
  static Future<List<File>> getCustomerZipFiles(
    OperationType operationType,
  ) async {
    final dayFolder = await getDayFolder(operationType);

    if (dayFolder == null || !await dayFolder.exists()) {
      return [];
    }

    final zips = dayFolder
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.zip'))
        .toList();

    zips.sort((a, b) => a.path.compareTo(b.path));
    return zips;
  }

  /// نام نمایشی (بدون مسیر کامل، و بدون پسوند .zip برای فایل‌های زیپ).
  static String displayName(FileSystemEntity entity) {
    final name = entity.path.split(Platform.pathSeparator).last;

    if (entity is File && name.toLowerCase().endsWith('.zip')) {
      return name.substring(0, name.length - 4);
    }

    return name;
  }
}