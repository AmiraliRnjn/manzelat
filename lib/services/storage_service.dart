import 'dart:io';
import '../operation_type.dart';
import 'storage_settings_service.dart';
import 'work_date_service.dart';

/// مسئول ساخت مسیر و پوشه‌ی مخصوص هر مشتری، بر اساس:
/// مسیر ریشه (از تنظیمات) + نوع عملیات (شارژ/صدور) + تاریخ کاری + نام مشتری.
///
/// ساختار نهایی چیزی شبیه این می‌شود:
/// <ریشه>/شارژ/1405/05/14050503/<نام مشتری>
///
/// پوشه‌هایی که از قبل وجود دارند دوباره ساخته نمی‌شوند — این متد idempotent است.
class StorageService {

  /// پوشه‌ی مخصوص این مشتری را برمی‌گرداند (و در صورت نیاز می‌سازد).
  /// اگر مسیر ذخیره‌سازی هنوز در تنظیمات مشخص نشده باشد، null برمی‌گرداند
  /// تا صفحه‌ی فراخواننده بتواند کاربر را به تنظیمات هدایت کند.
  static Future<Directory?> getCustomerFolder({
    required OperationType operationType,
    required String customerFullName,
  }) async {

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

    final customerFolderName = _sanitize(customerFullName);

    final customerPath = [
      rootPath,
      operationFolderName,
      yearFolderName,
      monthFolderName,
      dayFolderName,
      customerFolderName,
    ].join(Platform.pathSeparator);

    final customerDirectory = Directory(customerPath);

    // create(recursive: true) خودش idempotent است: اگر پوشه از قبل
    // وجود داشته باشد خطا نمی‌دهد و چیزی را از نو نمی‌سازد.
    await customerDirectory.create(recursive: true);

    return customerDirectory;

  }

  /// کاراکترهایی که در نام فایل/پوشه مجاز نیستند (به‌خصوص در ویندوز) را حذف می‌کند.
  static String _sanitize(String name) {

    final invalidChars = RegExp(r'[\\/:*?"<>|]');

    final cleaned = name.replaceAll(invalidChars, '').trim();

    return cleaned.isEmpty ? 'نامشخص' : cleaned;

  }

}
