import 'dart:typed_data';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../app_enum.dart';
import 'customer_status_service.dart';
import 'storage_settings_service.dart';
import 'work_date_service.dart';

/// مسئول پیدا کردن مسیر پوشه‌ی «روز» (شارژ یا صدور) برای تاریخ کاری فعال،
/// دقیقاً با همان قواعد StorageService — بدون ساخت پوشه (فقط خواندن).
class FileManagerService {
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

  static String displayName(FileSystemEntity entity) {
    final name = entity.path.split(Platform.pathSeparator).last;

    if (entity is File && name.toLowerCase().endsWith('.zip')) {
      return name.substring(0, name.length - 4);
    }

    return name;
  }

  static List<File> getFilesInFolder(Directory folder) {
    final files = folder.listSync().whereType<File>().toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// تغییر نام مشتری/ZIP به صورت جفتی انجام می‌شود.
  ///
  /// اگر پوشه مشتری ZIP هم‌نام داشته باشد، اول ZIP و بعد پوشه تغییرنام می‌شوند.
  /// اگر تغییر نام پوشه شکست بخورد، ZIP به نام قبلی برگردانده می‌شود تا
  /// وضعیت نیمه‌کاره ایجاد نشود.
  static Future<FileSystemEntity> rename(
    FileSystemEntity entity,
    String newName,
  ) async {
    final sanitized = _sanitize(newName);

    if (entity is File) {
      final parentPath = entity.parent.path;
      final targetName = entity.path.toLowerCase().endsWith('.zip')
          ? '$sanitized.zip'
          : sanitized;

      final newPath =
          '$parentPath${Platform.pathSeparator}$targetName';

      return entity.rename(newPath);
    }

    final folder = entity as Directory;
    final parentPath = folder.parent.path;
    final oldName = displayName(folder);

    if (oldName == sanitized) {
      return folder;
    }

    final newFolderPath =
        '$parentPath${Platform.pathSeparator}$sanitized';
    final oldZip = File(
      '$parentPath${Platform.pathSeparator}$oldName.zip',
    );
    final newZip = File(
      '$parentPath${Platform.pathSeparator}$sanitized.zip',
    );

    if (await Directory(newFolderPath).exists()) {
      throw Exception('پوشه‌ای با نام «$sanitized» از قبل وجود دارد.');
    }

    if (await newZip.exists()) {
      throw Exception('فایل ZIP با نام «$sanitized» از قبل وجود دارد.');
    }

    var zipRenamed = false;

    try {
      if (await oldZip.exists()) {
        await oldZip.rename(newZip.path);
        zipRenamed = true;
      }

      final renamedFolder = await folder.rename(newFolderPath);

      // وضعیت SharedPreferences فقط بعد از موفقیت هر دو rename منتقل می‌شود.
      await CustomerStatusService.transfer(
        folder.path,
        renamedFolder.path,
      );

      return renamedFolder;
    } catch (e) {
      // Rollback در صورت شکست.
      if (zipRenamed && await newZip.exists() && !await oldZip.exists()) {
        try {
          await newZip.rename(oldZip.path);
        } catch (_) {}
      }

      rethrow;
    }
  }

  /// حذف پوشه مشتری همراه با ZIP هم‌نام آن.
  static Future<void> delete(FileSystemEntity entity) async {
    if (entity is Directory) {
      final zipFile = File('${entity.path}.zip');

      await entity.delete(recursive: true);

      if (await zipFile.exists()) {
        await zipFile.delete();
      }

      return;
    }

    await (entity as File).delete();
  }

  static String _sanitize(String name) {
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    final cleaned = name.replaceAll(invalidChars, '').trim();

    if (cleaned.isEmpty) return 'نامشخص';

    return cleaned.replaceFirst(RegExp(r'[. ]+$'), '');
  }

  static bool imageNameExists(Directory folder, String desiredName) {
    final sanitized = _sanitize(desiredName);

    if (!folder.existsSync()) return false;

    return folder.listSync().whereType<File>().any((f) {
      final fileName = f.path.split(Platform.pathSeparator).last;
      final dotIndex = fileName.lastIndexOf('.');
      final nameWithoutExt =
          dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);

      return nameWithoutExt == sanitized;
    });
  }

  static Future<File> addImageBytesToFolder({
    required Directory folder,
    required Uint8List bytes,
    required String desiredName,
  }) async {
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final sanitized = _sanitize(desiredName);
    final targetPath =
        [folder.path, '$sanitized.jpg'].join(Platform.pathSeparator);

    return File(targetPath).writeAsBytes(bytes, flush: true);
  }

  static Future<File> zipCustomerFolder(Directory folder) async {
    final name = displayName(folder);
    final parentPath = folder.parent.path;
    final zipPath =
        [parentPath, '$name.zip'].join(Platform.pathSeparator);

    final encoder = ZipFileEncoder();

    try {
      encoder.create(zipPath);
      await encoder.addDirectory(folder, includeDirName: false);
      return File(zipPath);
    } finally {
      encoder.close();
    }
  }
}
