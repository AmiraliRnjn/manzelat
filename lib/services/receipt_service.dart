import 'dart:io';
import 'customer_status_service.dart';

/// مسئول چسباندن عکس رسید (که از پیام‌رسان اشتراک‌گذاری شده) به پوشه‌ی
/// مشتری انتخاب‌شده، ثبت وضعیت «رسید دریافت شد»، و در صورت وجود، حذف
/// ZIP باقی‌مانده‌ی همان مشتری.
class ReceiptService {
  /// همه‌ی فایل‌های رسید با این پیشوند ذخیره می‌شوند تا از عکس‌های
  /// خودِ مدارک (کارت ملی، بلیط و ...) قابل تشخیص باشند.
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

    for (var i = 0; i < sourceImagePaths.length; i++) {
      final sourceFile = File(sourceImagePaths[i]);
      if (!await sourceFile.exists()) continue;

      final originalName = sourceFile.path.split(Platform.pathSeparator).last;
      final dotIndex = originalName.lastIndexOf('.');
      final ext = dotIndex != -1 ? originalName.substring(dotIndex + 1) : 'jpg';

      final suffix = sourceImagePaths.length > 1 ? '_${i + 1}' : '';
      final targetPath = [
        customerFolder.path,
        '$receiptPrefix${DateTime.now().millisecondsSinceEpoch}$suffix.$ext',
      ].join(Platform.pathSeparator);

      await sourceFile.copy(targetPath);
    }

    await CustomerStatusService.markReceiptReceived(customerFolder.path);

    // اگر فایل ZIP این مشتری هنوز پاک نشده بود (دقیقاً کنار پوشه، هم‌نام + .zip)،
    // حالا که مطمئنیم رسیدش رسیده، خودکار پاکش می‌کنیم.
    final zipFile = File('${customerFolder.path}.zip');
    if (await zipFile.exists()) {
      try {
        await zipFile.delete();
      } catch (_) {
        // اگر حذف با خطا مواجه شد، بی‌سروصدا رد می‌شویم؛ کاربر می‌تواند دستی حذفش کند.
      }
    }
  }

  /// آیا این پوشه حداقل یک فایل رسید دارد (برای نمایش آیکون مخصوص در لیست فایل‌ها).
  static bool hasReceiptFile(Directory folder) {
    if (!folder.existsSync()) return false;
    return folder.listSync().whereType<File>().any(
          (f) => f.path.split(Platform.pathSeparator).last.startsWith(receiptPrefix),
        );
  }
}