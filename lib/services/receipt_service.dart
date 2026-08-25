import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'customer_status_service.dart';

/// مسئول چسباندن عکس رسید به پوشه‌ی مشتری و ثبت وضعیت رسید.
///
/// رسیدهایی که از طریق اشتراک‌گذاری (گالری/پیام‌رسان و ...) وارد اپ
/// می‌شوند معمولاً حجم و رزولوشن بسیار بالاتری نسبت به عکس‌های خودِ
/// دوربین برنامه دارند. برای هماهنگی با حجم عکس‌های دوربین (که با
/// ResolutionPreset.high گرفته و با کیفیت ۸۵ درصد JPEG ذخیره می‌شوند)،
/// اینجا هم رسید قبل از ذخیره، هم از نظر ابعاد و هم کیفیت، فشرده می‌شود.
class ReceiptService {
  static const String receiptPrefix = 'رسید_';

  /// کیفیت فشرده‌سازی JPEG، هم‌تراز با عکس‌های دوربین برنامه.
  static const int _jpegQuality = 85;

  /// حداکثر طول ضلع بزرگ‌تر تصویر، هم‌تراز با ResolutionPreset.high
  /// دوربین برنامه (تقریباً ۱۲۸۰ پیکسل).
  static const int _maxDimension = 1280;

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
