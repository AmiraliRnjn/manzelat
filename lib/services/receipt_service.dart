import 'dart:io';

import 'customer_status_service.dart';

/// مسئول چسباندن عکس رسید به پوشه‌ی مشتری و ثبت وضعیت رسید.
class ReceiptService {
  static const String receiptPrefix = 'رسید_';

  static Future<void> attachReceiptToCustomer({
    required Directory customerFolder,
    required List<String> sourceImagePaths,
  }) async {
    if (sourceImagePaths.isEmpty) {
      throw Exception('هیچ فایلی برای ثبت رسید دریافت نشد.');
    }

    if (!await customerFolder.exists()) {
      await customerFolder.create(recursive: true);
    }

    var copiedCount = 0;

    for (var i = 0; i < sourceImagePaths.length; i++) {
      final sourceFile = File(sourceImagePaths[i]);

      if (!await sourceFile.exists()) {
        continue;
      }

      final originalName =
          sourceFile.path.split(Platform.pathSeparator).last;
      final dotIndex = originalName.lastIndexOf('.');
      final ext =
          dotIndex != -1 ? originalName.substring(dotIndex + 1) : 'jpg';

      final suffix = sourceImagePaths.length > 1 ? '_${i + 1}' : '';
      final targetPath = [
        customerFolder.path,
        '$receiptPrefix${DateTime.now().millisecondsSinceEpoch}$suffix.$ext',
      ].join(Platform.pathSeparator);

      await sourceFile.copy(targetPath);
      copiedCount++;
    }

    // اگر هیچ فایل واقعی از مسیرهای ورودی پیدا/کپی نشد، وضعیت مشتری
    // نباید به «رسید دریافت شد» تغییر کند.
    if (copiedCount == 0) {
      throw Exception('هیچ فایل رسید معتبری برای ثبت پیدا نشد.');
    }

    await CustomerStatusService.markReceiptReceived(
      customerFolder.path,
    );

    // بعد از دریافت رسید، ZIP قدیمی مشتری دیگر لازم نیست.
    final zipFile = File('${customerFolder.path}.zip');

    if (await zipFile.exists()) {
      try {
        await zipFile.delete();
      } catch (_) {
        // عدم حذف ZIP نباید ثبت موفق رسید را خراب کند.
      }
    }
  }

  static bool hasReceiptFile(Directory folder) {
    if (!folder.existsSync()) return false;

    return folder.listSync().whereType<File>().any(
          (f) => f.path
              .split(Platform.pathSeparator)
              .last
              .startsWith(receiptPrefix),
        );
  }
}
