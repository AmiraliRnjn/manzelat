import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'dart:io';

/// یک صفحه‌ی داخلی مرور فایل‌سیستم (نه دیالوگ رسمی اندروید) برای
/// انتخاب پوشه‌ی ذخیره‌سازی باز می‌کند و مسیر انتخابی را برمی‌گرداند.
/// اگر کاربر انصراف بدهد یا خطایی پیش بیاید، null برمی‌گرداند.
class StoragePickerService {

  static Future<String?> pickStorageFolder(BuildContext context) async {

    try {

      // مسیر اختصاصی اپ را می‌گیریم تا از روی آن ریشه‌ی اصلی حافظه را پیدا کنیم
      final externalDir = await getExternalStorageDirectory();

      if (externalDir == null) {
        return null;
      }

      // تبدیل .../Android/data/... به ریشه‌ی اصلی حافظه‌ی گوشی
      final pathParts = externalDir.path.split('/Android');

      if (pathParts.isEmpty) {
        return null;
      }

      final rootPath = pathParts[0];
      final rootDirectory = Directory(rootPath);

      if (!context.mounted) return null;

      final selectedPath = await FilesystemPicker.open(
        title: 'انتخاب محل ذخیره فایل‌ها',
        context: context,
        rootDirectory: rootDirectory,
        fsType: FilesystemType.folder,
        pickText: 'تایید و انتخاب این پوشه',
        folderIconColor: Colors.amber,
      );

      return selectedPath;

    } catch (e) {

      return null;

    }

  }

}
