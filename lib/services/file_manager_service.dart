
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

import '../app_enum.dart';
import 'customer_status_service.dart';
import 'storage_settings_service.dart';
import 'work_date_service.dart';

/// مدیریت مسیرها و فایل‌های مشتری.
///
/// ذخیره تصویر و ساخت ZIP به‌صورت atomic انجام می‌شود: ابتدا فایل موقت ساخته
/// و flush می‌شود، سپس وجود/حجم آن بررسی و در پایان با نام اصلی جایگزین می‌شود.
class FileManagerService {
  static Future<Directory?> getDayFolder(OperationType operationType) async {
    final rootPath = await StorageSettingsService.getStoragePath();
    if (rootPath == null || rootPath.trim().isEmpty) return null;

    final workDate = await WorkDateService.getWorkDate();
    final operationFolderName =
        operationType == OperationType.charge ? 'شارژ' : 'صدور';

    final dayPath = [
      rootPath,
      operationFolderName,
      workDate.year.toString(),
      workDate.month.toString().padLeft(2, '0'),
      WorkDateService.folderNameFor(workDate),
    ].join(Platform.pathSeparator);

    return Directory(dayPath);
  }

  static Future<List<Directory>> getCustomerFolders(
    OperationType operationType,
  ) async {
    final dayFolder = await getDayFolder(operationType);
    if (dayFolder == null || !await dayFolder.exists()) return [];

    final folders = dayFolder.listSync().whereType<Directory>().toList();
    folders.sort((a, b) => a.path.compareTo(b.path));
    return folders;
  }

  static Future<List<File>> getCustomerZipFiles(
    OperationType operationType,
  ) async {
    final dayFolder = await getDayFolder(operationType);
    if (dayFolder == null || !await dayFolder.exists()) return [];

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
      return entity.rename('$parentPath${Platform.pathSeparator}$targetName');
    }

    final folder = entity as Directory;
    final parentPath = folder.parent.path;
    final oldName = displayName(folder);
    if (oldName == sanitized) return folder;

    final newFolderPath = '$parentPath${Platform.pathSeparator}$sanitized';
    final oldZip = File('$parentPath${Platform.pathSeparator}$oldName.zip');
    final newZip = File('$parentPath${Platform.pathSeparator}$sanitized.zip');

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
      await CustomerStatusService.transfer(folder.path, renamedFolder.path);
      return renamedFolder;
    } catch (_) {
      if (zipRenamed && await newZip.exists() && !await oldZip.exists()) {
        try {
          await newZip.rename(oldZip.path);
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<void> delete(FileSystemEntity entity) async {
    if (entity is Directory) {
      final zipFile = File('${entity.path}.zip');
      await entity.delete(recursive: true);
      if (await zipFile.exists()) await zipFile.delete();
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
      final nameWithoutExt = dotIndex == -1
          ? fileName
          : fileName.substring(0, dotIndex);
      return nameWithoutExt == sanitized;
    });
  }

  /// ذخیره امن تصویر: [name].part -> flush -> وجود/حجم -> [name].jpg.
  /// اگر عملیات وسط کار قطع شود، فایل ناقص هرگز با نام نهایی باقی نمی‌ماند.
  static Future<File> addImageBytesToFolder({
    required Directory folder,
    required Uint8List bytes,
    required String desiredName,
  }) async {
    if (bytes.isEmpty) throw const FileSystemException('داده تصویر خالی است.');
    await folder.create(recursive: true);

    final sanitized = _sanitize(desiredName);
    final targetPath = [folder.path, '$sanitized.jpg'].join(Platform.pathSeparator);
    final target = File(targetPath);
    final part = File('$targetPath.part');

    if (await part.exists()) await part.delete();

    try {
      await part.writeAsBytes(bytes, flush: true);
      if (!await part.exists()) {
        throw const FileSystemException('فایل موقت تصویر ساخته نشد.');
      }
      final length = await part.length();
      if (length != bytes.length || length == 0) {
        throw FileSystemException(
          'حجم فایل تصویر با داده اصلی برابر نیست.',
          part.path,
        );
      }

      // اگر فایل نهایی از قبل وجود داشته باشد، آن را فقط بعد از آماده شدن
      // کامل فایل جدید حذف می‌کنیم.
      if (await target.exists()) await target.delete();
      final saved = await part.rename(target.path);

      if (!await saved.exists() || await saved.length() != bytes.length) {
        throw FileSystemException('تأیید نهایی ذخیره تصویر ناموفق بود.', target.path);
      }
      return saved;
    } catch (_) {
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// ZIP مشتری را ابتدا با نام .part می‌سازد و فقط پس از بررسی کامل به نام
  /// نهایی منتقل می‌کند. فایل صفر بایت یا ZIP بدون فایل موفق اعلام نمی‌شود.
  static Future<File> zipCustomerFolder(Directory folder) async {
    if (!await folder.exists()) {
      throw FileSystemException('پوشه مشتری وجود ندارد.', folder.path);
    }

    final name = displayName(folder);
    final parentPath = folder.parent.path;
    final zipPath = [parentPath, '$name.zip'].join(Platform.pathSeparator);
    final partPath = '$zipPath.part';
    final part = File(partPath);
    final target = File(zipPath);

    if (await part.exists()) await part.delete();

    var fileCount = 0;
    try {
      final files = <File>[];
      await for (final entity in folder.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (stat.size <= 0) {
          throw FileSystemException('فایل صفر بایت در پوشه مشتری وجود دارد.', entity.path);
        }
        files.add(entity);
      }
      fileCount = files.length;
      if (fileCount == 0) {
        throw FileSystemException('پوشه مشتری هیچ فایلی برای ZIP ندارد.', folder.path);
      }

      final encoder = ZipFileEncoder();
      try {
        encoder.create(partPath);
        await encoder.addDirectory(folder, includeDirName: false);
      } finally {
        await encoder.close();
      }

      if (!await part.exists()) {
        throw FileSystemException('فایل ZIP موقت ساخته نشد.', partPath);
      }
      final partLength = await part.length();
      if (partLength <= 0) {
        throw FileSystemException('ZIP ساخته‌شده صفر بایت است.', partPath);
      }

      // بررسی نهایی ZIP قبل از جایگزینی فایل اصلی.
      final input = InputFileStream(partPath);
      try {
        final archive = ZipDecoder().decodeStream(input);
        final archiveFiles = archive.where((entry) => entry.isFile).toList();
        if (archiveFiles.isEmpty) {
          throw FileSystemException('ZIP نهایی هیچ فایل قابل استفاده‌ای ندارد.', partPath);
        }
        for (final entry in archiveFiles) {
          if (entry.size <= 0) {
            throw FileSystemException('ZIP شامل فایل صفر بایت است.', entry.name);
          }
        }
      } finally {
        await input.close();
      }

      if (await target.exists()) await target.delete();
      final saved = await part.rename(target.path);
      if (!await saved.exists() || await saved.length() <= 0) {
        throw FileSystemException('تأیید نهایی ZIP ناموفق بود.', target.path);
      }
      return saved;
    } catch (_) {
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }
}



