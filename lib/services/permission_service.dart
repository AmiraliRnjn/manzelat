import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// مسئول بررسی و درخواست مجوز دسترسی کامل به حافظه (All Files Access).
/// این مجوز چون برنامه باید بتواند در مسیر دلخواه کاربر (مثلاً روی
/// کارت حافظه یا هر پوشه‌ای غیر از پوشه‌ی اختصاصی اپ) فایل بنویسد لازم است.
class PermissionService {

  static const MethodChannel _channel =
      MethodChannel('com.example.first_test/permissions');

  /// بررسی می‌کند که آیا مجوز از قبل داده شده یا نه.
  static Future<bool> hasStoragePermission() async {

    final status = await Permission.manageExternalStorage.status;

    return status.isGranted;

  }

  /// درخواست مجوز از کاربر. اگر قبلاً به‌طور دائم رد شده باشد،
  /// اندروید دیگر دیالوگ نشان نمی‌دهد و باید کاربر را به تنظیمات هدایت کرد.
  static Future<bool> requestStoragePermission() async {

    final status = await Permission.manageExternalStorage.request();

    return status.isGranted;

  }

  /// کاربر را به صفحه‌ی تنظیمات اپ در اندروید می‌برد
  /// (برای مواقعی که مجوز به‌طور دائم رد شده).
  static Future<void> openSettings() async {

    await openAppSettings();

  }

  /// روش جایگزین: به‌جای صفحه‌ی اختصاصی این اپ (که روی بعضی امولاتورها
  /// باز نمی‌شود)، صفحه‌ی عمومی لیست همه‌ی اپ‌ها را باز می‌کند.
  /// کاربر باید خودش این اپ را در آن لیست پیدا کند و فعالش کند.
  static Future<void> openAllFilesAccessSettingsList() async {

    try {

      await _channel.invokeMethod('openAllFilesAccessSettings');

    } catch (e) {

      // اگر باز هم نشد، کاری از دست ما ساخته نیست؛
      // خطا را بی‌سروصدا نادیده می‌گیریم چون UI خودش وضعیت مجوز را نشان می‌دهد.

    }

  }

}
