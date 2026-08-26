import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'customer_status_service.dart';
import 'file_manager_service.dart';

/// مسئول چسباندن عکس رسید به پوشه‌ی مشتری و ثبت وضعیت رسید.
///
/// رسیدهایی که از طریق اشتراک‌گذاری (گالری/پیام‌رسان و ...) وارد اپ
/// می‌شوند معمولاً حجم و رزولوشن بسیار بالاتری نسبت به عکس‌های خودِ
/// دوربین برنامه دارند. چون رسید فقط برای بایگانی و خواندن متن‌اش لازم
/// است (نه جزئیات تصویری دقیق مثل عکس مدارک)، اینجا عمداً محکم‌تر از
/// عکس‌های دوربین فشرده می‌شود تا حجم نهایی هرچه پایین‌تر بیاید.
class ReceiptService {
  static const String receiptPrefix = 'رسید_';

  /// کیفیت فشرده‌سازی JPEG رسید. پایین‌تر از کیفیت عکس‌های دوربین (۸۵)
  /// چون خوانا بودن متن رسید کافی است و نیازی به کیفیت بالا نیست.
  static const int _jpegQuality = 50;

  /// حداکثر طول ضلع بزرگ‌تر تصویر رسید. رسیدها معمولاً عکس/اسکرین‌شاتی از
  /// یک برگه‌اند، پس ابعاد کوچک‌تر از عکس‌های دوربین (۱۲۸۰) هم برای خوانا
  /// ماندن متن کافی است و حجم را قابل‌توجه پایین می‌آورد.
  static const int _maxDimension = 720;

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

      final suffix = sourceImagePaths.length > 1 ? '_${i + 1}' : '';
      final baseName =
          '$receiptPrefix${DateTime.now().millisecondsSinceEpoch}$suffix';

      final compressed = await _compressToJpg(sourceFile);

      if (compressed != null) {
        final targetPath = [
          customerFolder.path,
          '$baseName.jpg',
        ].join(Platform.pathSeparator);
        await File(targetPath).writeAsBytes(compressed, flush: true);
      } else {
        // اگر تصویر قابل decode نبود (فرمت ناشناخته یا فایل خراب)، همان
        // فایل اصلی بدون فشرده‌سازی کپی می‌شود تا رسید از دست نرود.
        final originalName =
            sourceFile.path.split(Platform.pathSeparator).last;
        final dotIndex = originalName.lastIndexOf('.');
        final ext =
            dotIndex != -1 ? originalName.substring(dotIndex + 1) : 'jpg';
        final targetPath = [
          customerFolder.path,
          '$baseName.$ext',
        ].join(Platform.pathSeparator);
        await sourceFile.copy(targetPath);
      }

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

    // قبلاً بعد از دریافت رسید، ZIP قدیمی مشتری حذف می‌شد چون رسید تازه
    // داخلش نبود. حالا به‌جای حذف، اگر مشتری از قبل ZIP داشت، همان ZIP از
    // روی پوشه (که الان شامل رسید تازه هم هست) دوباره ساخته می‌شود؛ یعنی
    // رسید هم داخل ZIP می‌آید و خودِ ZIP باقی می‌ماند.
    final zipFile = File('${customerFolder.path}.zip');

    if (await zipFile.exists()) {
      try {
        await FileManagerService.zipCustomerFolder(customerFolder);
      } catch (_) {
        // اگر بازسازی ZIP با خطا مواجه شود، نباید ثبت موفق رسید را خراب
        // کند؛ در این حالت ZIP قدیمی (بدون رسید تازه) دست‌نخورده می‌ماند
        // و کاربر می‌تواند بعداً از تب ZIP دوباره «زیپ کردن» را بزند.
      }
    }
  }

  /// تصویر را decode می‌کند، در صورت نیاز تا سقف [_maxDimension] کوچک
  /// می‌کند (نسبت ابعاد حفظ می‌شود) و در نهایت با کیفیت [_jpegQuality]
  /// به JPEG تبدیل می‌کند.
  static Future<Uint8List?> _compressToJpg(File file) async {
    try {
      final bytes = await file.readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      if (decoded.width > _maxDimension || decoded.height > _maxDimension) {
        decoded = decoded.width >= decoded.height
            ? img.copyResize(decoded, width: _maxDimension)
            : img.copyResize(decoded, height: _maxDimension);
      }

      return Uint8List.fromList(img.encodeJpg(decoded, quality: _jpegQuality));
    } catch (_) {
      return null;
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