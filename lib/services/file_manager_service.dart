import 'dart:io';
import 'package:archive/archive_io.dart';
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

  /// فایل‌های داخل یک پوشه‌ی مشتری (برای صفحه‌ی «باز کردن پوشه»).
  static List<File> getFilesInFolder(Directory folder) {
    final files = folder.listSync().whereType<File>().toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// تغییر نام یک پوشه یا فایل. برای فایل ZIP، پسوند .zip خودکار حفظ می‌شود.
  static Future<FileSystemEntity> rename(
    FileSystemEntity entity,
    String newName,
  ) async {
    final sanitized = _sanitize(newName);

    final parentPath = entity.parent.path;
    var targetName = sanitized;

    if (entity is File && entity.path.toLowerCase().endsWith('.zip')) {
      targetName = '$sanitized.zip';
    }

    final newPath = '$parentPath${Platform.pathSeparator}$targetName';

    if (entity is Directory) {
      return entity.rename(newPath);
    }

    return (entity as File).rename(newPath);
  }

  /// حذف یک پوشه (با همه‌ی محتویاتش) یا یک فایل تکی.
  static Future<void> delete(FileSystemEntity entity) async {
    if (entity is Directory) {
      await entity.delete(recursive: true);
      return;
    }

    await (entity as File).delete();
  }

  /// همان قانون پاکسازی نام که در StorageService استفاده شده.
  static String _sanitize(String name) {
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    final cleaned = name.replaceAll(invalidChars, '').trim();
    return cleaned.isEmpty ? 'نامشخص' : cleaned;
  }

  // --------------------------------------------------------------------
  // تنها متد جدید: ساخت ZIP از پوشه‌ی یک مشتری، دقیقاً کنار خودش
  // (لازم برای گزینه‌ی «زیپ کردن» در منوی پوشه‌های اصلی)
  // --------------------------------------------------------------------

  /// از محتویات پوشه یک ZIP در همان مسیر (پوشه‌ی روز) با نام پوشه می‌سازد.
  /// اگر ZIP هم‌نامی از قبل وجود داشته باشد، بازنویسی می‌شود.
  static Future<File> zipCustomerFolder(Directory folder) async {
    final name = displayName(folder);
    final parentPath = folder.parent.path;
    final zipPath = [parentPath, '$name.zip'].join(Platform.pathSeparator);

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    await encoder.addDirectory(folder, includeDirName: false);
    encoder.close();

    return File(zipPath);
  }
}