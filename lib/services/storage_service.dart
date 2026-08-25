
import 'dart:io';

import 'storage_settings_service.dart';
import 'work_date_service.dart';
import '../app_enum.dart';

/// مسئول ساخت مسیر و پوشه‌ی مخصوص هر مشتری، بر اساس:
/// مسیر ریشه (از تنظیمات) + نوع عملیات (شارژ/صدور) + تاریخ کاری + نام مشتری.
///
/// ساختار نهایی چیزی شبیه این می‌شود:
/// <ریشه>/شارژ/1405/05/14050503/<نام مشتری>
///
/// اگر در یک روز چند مشتری با نام یکسان ثبت شوند، برای جلوگیری از
/// ادغام اطلاعات دو نفر، پوشه‌ی دوم با پسوند _2، سپس _3 و ... ساخته می‌شود.
/// این یعنی هر اجرای عملیات یک پوشه‌ی مستقل دارد.
class StorageService {
  /// پوشه‌ی مخصوص این مشتری را برمی‌گرداند (و در صورت نیاز می‌سازد).
  /// اگر مسیر ذخیره‌سازی هنوز در تنظیمات مشخص نشده باشد، null برمی‌گرداند.
  static Future<Directory?> getCustomerFolder({
    required OperationType operationType,
    required String customerFullName,
    String? nationalCode,
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
    final sanitizedCode = (nationalCode ?? '').trim();

    final dayPath = [
      rootPath,
      operationFolderName,
      yearFolderName,
      monthFolderName,
      dayFolderName,
    ].join(Platform.pathSeparator);

    final dayDirectory = Directory(dayPath);
    await dayDirectory.create(recursive: true);

    // اگر کد ملی داریم، همان شناسه‌ی یکتای سراسری مشتری است؛ پوشه بر
    // اساس «نام + کد ملی» ساخته می‌شود. این‌طور حتی بین چند گوشی جدا،
    // دو مشتری هم‌نام هرگز در یک پوشه ادغام نمی‌شوند و در Merge با هم
    // قاطی نمی‌شوند، ولی همان مشتری (همان کد ملی) همیشه به همان پوشه
    // می‌رسد.
    if (sanitizedCode.isNotEmpty) {
      final folderName = '${customerFolderName}_${_sanitize(sanitizedCode)}';
      final candidatePath = [dayPath, folderName].join(Platform.pathSeparator);
      final candidate = Directory(candidatePath);
      await candidate.create(recursive: true);
      return candidate;
    }

    // Fallback قدیمی (فقط برای جریان‌هایی که کد ملی ندارند): هر اجرا
    // پوشه‌ی مستقل خودش را می‌گیرد تا اطلاعات نفر دوم با نفر اول
    // ادغام نشود.
    var folderName = customerFolderName;
    var counter = 1;

    while (true) {
      final candidatePath = [
        dayPath,
        folderName,
      ].join(Platform.pathSeparator);

      final candidate = Directory(candidatePath);

      if (!await candidate.exists()) {
        await candidate.create(recursive: true);
        return candidate;
      }

      counter++;
      folderName = '${customerFolderName}_$counter';
    }
  }

  /// کاراکترهایی که در نام فایل/پوشه مجاز نیستند (به‌خصوص در ویندوز) را حذف می‌کند.
  static String _sanitize(String name) {
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    final cleaned = name.replaceAll(invalidChars, '').trim();

    // جلوگیری از نام‌های مشکل‌ساز ویندوز.
    final reserved = RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$',
      caseSensitive: false,
    );

    if (cleaned.isEmpty) return 'نامشخص';
    if (reserved.hasMatch(cleaned)) return '${cleaned}_1';

    return cleaned.replaceFirst(RegExp(r'[. ]+$'), '');
  }

  /// یک نام فایل یکتا (بدون پسوند) داخل این پوشه برمی‌گرداند.
  static String uniqueFileName({
    required Directory folder,
    required String desiredName,
    required Set<String> alreadyPlanned,
    String extension = 'jpg',
  }) {
    final sanitizedName = _sanitize(desiredName);

    bool isTaken(String name) {
      if (alreadyPlanned.contains(name)) return true;

      final file = File(
        '${folder.path}${Platform.pathSeparator}$name.$extension',
      );

      return file.existsSync();
    }

    if (!isTaken(sanitizedName)) return sanitizedName;

    var counter = 2;
    String candidate;

    do {
      candidate = '${sanitizedName}_$counter';
      counter++;
    } while (isTaken(candidate));

    return candidate;
  }
}



