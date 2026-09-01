import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crop_image/crop_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../app_enum.dart';
import '../reminder_status.dart';
import '../services/file_manager_service.dart';
import '../services/customer_status_service.dart';
import '../services/receipt_service.dart';
import '../services/route_observer.dart';

/// انتخاب کاربر وقتی بین ZIPهای قابل ترکیب، فایل بدون رسید وجود دارد.
enum _ZipAllChoice { completedOnly, ignoreAll }

class FileManagerPage extends StatefulWidget {
  final OperationType operationType;

  const FileManagerPage({super.key, required this.operationType});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> with RouteAware {
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _purple = Color.fromARGB(255, 128, 68, 232);
  static const Color _green = Color.fromARGB(255, 59, 211, 122);
  static const Color _pageBackground = Color(0xFFFAFBFF);
  static const Color _darkText = Color(0xFF172554);
  static const Color _secondaryText = Color(0xFF707789);

  List<Directory> customerFolders = [];
  List<File> zipFiles = [];
  Set<String> sentKeys = {};
  Set<String> receiptKeys = {};
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // این صفحه را برای اطلاع از باز/بسته شدن صفحه‌های بالای آن (مثلاً
    // صفحه‌ی ثبت رسید که با اشتراک‌گذاری باز می‌شود) در RouteObserver
    // عمومی ثبت می‌کنیم.
    appRouteObserver.subscribe(this, ModalRoute.of(context)! as PageRoute<void>);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  /// وقتی صفحه‌ای که روی این صفحه باز شده بود (مثلاً ثبت رسید از طریق
  /// اشتراک‌گذاری، یا صفحه‌ی جزئیات پوشه) بسته می‌شود و این صفحه دوباره
  /// نمایان می‌شود، اجرا می‌شود. قبلاً این‌جا رفرش نمی‌شد و کاربر باید کامل
  /// از صفحه‌ی مدیریت فایل خارج و دوباره وارد می‌شد تا نقطه‌ی رنگی (مثلاً
  /// بعد از ثبت رسید) به‌روز شود؛ حالا بلافاصله بعد از برگشت رفرش می‌شود.
  @override
  void didPopNext() {
    _loadData();
  }

  Future<void> _loadData() async {
    final folders = await FileManagerService.getCustomerFolders(
      widget.operationType,
    );
    final zips = await FileManagerService.getCustomerZipFiles(
      widget.operationType,
    );
    final sent = await CustomerStatusService.getSentKeys();
    final receipts = await CustomerStatusService.getReceiptKeys();

    if (!mounted) return;

    setState(() {
      customerFolders = folders;
      zipFiles = zips;
      sentKeys = sent;
      receiptKeys = receipts;
      isLoading = false;
    });
  }

  ReminderStatus _statusFor(FileSystemEntity entity) {
    return CustomerStatusService.statusFor(
      entity.path,
      sentKeys: sentKeys,
      receiptKeys: receiptKeys,
    );
  }

  List<Directory> get _filteredFolders {
    if (_query.isEmpty) return customerFolders;
    return customerFolders
        .where((f) => FileManagerService.displayName(f).contains(_query))
        .toList();
  }

  List<File> get _filteredZips {
    if (_query.isEmpty) return zipFiles;
    return zipFiles
        .where((f) => FileManagerService.displayName(f).contains(_query))
        .toList();
  }

  /// بدترین وضعیت داخل یک لیست، برای نقطه‌ی روی خود تب (قرمز > زرد > هیچ‌کدام).
  Color? _tabDotColor(List<FileSystemEntity> items) {
    bool anyRed = false;
    bool anyYellow = false;
    for (final item in items) {
      final status = _statusFor(item);
      if (status == ReminderStatus.notSent) anyRed = true;
      if (status == ReminderStatus.awaitingReceipt) anyYellow = true;
    }
    if (anyRed) return Colors.red;
    if (anyYellow) return Colors.amber;
    return null;
  }

  // ------------------------------- اکشن‌های پوشه -------------------------------

  void _openFolder(Directory folder) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FolderContentsPage(folder: folder)),
    );
  }

  Future<void> _renameFolder(Directory folder) async {
    final oldName = FileManagerService.displayName(folder);
    final input = await _askForName(
      title: 'تغییر نام پوشه',
      initialValue: oldName,
    );

    if (input == null || input.trim().isEmpty || input.trim() == oldName) {
      return;
    }

    try {
      final renamedFolder =
          await FileManagerService.rename(folder, input.trim()) as Directory;
      final newName = FileManagerService.displayName(renamedFolder);

      await CustomerStatusService.transfer(folder.path, renamedFolder.path);

      // اگر ZIP هم‌نامی (که با نام قبلی پوشه ساخته شده بود) کنارش باشد،
      // آن را هم خودکار با نام جدید هم‌نام می‌کنیم تا با پوشه هماهنگ بماند.
      final parentPath = renamedFolder.parent.path;
      final matchingZip = File(
        [parentPath, '$oldName.zip'].join(Platform.pathSeparator),
      );

      if (await matchingZip.exists()) {
        await FileManagerService.rename(matchingZip, newName);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام پوشه با موفقیت تغییر کرد.')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در تغییر نام: $e')));
    }
  }

  Future<void> _zipFolder(Directory folder) async {
    final name = FileManagerService.displayName(folder);
    final parentPath = folder.parent.path;
    final existingZip = File(
      [parentPath, '$name.zip'].join(Platform.pathSeparator),
    );

    if (await existingZip.exists()) {
      final confirmed = await _confirmAction(
        title: 'بازنویسی ZIP',
        message:
            'فایل ZIP «$name» از قبل وجود دارد. با نسخه‌ی جدید جایگزین شود؟',
        confirmLabel: 'بازنویسی',
      );

      if (confirmed != true) return;
    }

    try {
      await FileManagerService.zipCustomerFolder(folder);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل ZIP با موفقیت ساخته شد.')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ساخت ZIP با خطا مواجه شد: $e')));
    }
  }

  /// همه‌ی پوشه‌های مشتری این تاریخ را در یک ZIP واحد به نام
  /// [FileManagerService.allZipsFileName] ترکیب می‌کند (هر مشتری داخلش یک
  /// پوشه‌ی جداست) تا بشود یک‌جا برای سرپرست ارسال کرد. نتیجه در همین تب
  /// ZIP نمایش داده می‌شود.
  ///
  /// اگر بین مشتری‌ها کسی قرمز (ارسال‌نشده) یا زرد (در انتظار رسید) باشد،
  /// قبل از ادامه از کاربر می‌پرسیم: فقط انجام‌شده‌ها (سبزها) زیپ شوند،
  /// یا انجام‌نشده‌ها نادیده گرفته شوند و همه یک‌جا زیپ شوند. در حالت دوم،
  /// نام پوشه‌های انجام‌نشده داخل خودِ ZIP ترکیبی با «انجام نشده - »
  /// مشخص می‌شود تا روی سیستم/لپ‌تاپ هم معلوم باشد.
  Future<void> _zipAllForSending() async {
    final combinable = customerFolders
        .where(
          (f) =>
              FileManagerService.displayName(f) !=
              FileManagerService.allZipsFileName,
        )
        .toList();

    if (combinable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پوشه مشتری‌ای برای ترکیب کردن وجود ندارد.')),
      );
      return;
    }

    // هر مشتری‌ای که رسیدش نیامده (چه قرمز/ارسال‌نشده، چه زرد/در انتظار
    // رسید) «بدون رسید» حساب می‌شود.
    final incomplete = combinable
        .where((f) => _statusFor(f) != ReminderStatus.receiptReceived)
        .toList();
    final completedOnly = combinable
        .where((f) => _statusFor(f) == ReminderStatus.receiptReceived)
        .toList();

    List<Directory> foldersToCombine = combinable;
    Set<String> incompleteNamesToMark = {};

    if (incomplete.isNotEmpty) {
      final choice = await _askZipAllChoice(incomplete.length);
      if (choice == null) return;

      if (choice == _ZipAllChoice.completedOnly) {
        if (completedOnly.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('هیچ مشتری انجام‌شده‌ای (سبز) برای زیپ کردن وجود ندارد.'),
            ),
          );
          return;
        }
        foldersToCombine = completedOnly;
      } else {
        // نادیده گرفتن انجام‌نشده‌ها: همه با هم زیپ می‌شوند، ولی نام
        // پوشه‌های ناقص داخل آرشیو مشخص می‌شود.
        foldersToCombine = combinable;
        incompleteNamesToMark = incomplete
            .map((f) => FileManagerService.displayName(f))
            .toSet();
      }
    }

    final alreadyExists = zipFiles.any(
      (f) =>
          FileManagerService.displayName(f) ==
          FileManagerService.allZipsFileName,
    );

    if (alreadyExists) {
      final confirmed = await _confirmAction(
        title: 'بازنویسی ZIP ترکیبی',
        message:
            'فایل «${FileManagerService.allZipsFileName}» از قبل وجود دارد. با نسخه‌ی جدید جایگزین شود؟',
        confirmLabel: 'بازنویسی',
      );
      if (confirmed != true) return;
    }

    try {
      await FileManagerService.zipAllCustomerZips(
        widget.operationType,
        foldersOverride: foldersToCombine,
        markIncompleteNames: incompleteNamesToMark,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل ZIP ترکیبی با موفقیت ساخته شد.')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ساخت ZIP ترکیبی با خطا مواجه شد: $e')),
      );
    }
  }

  /// از کاربر می‌پرسد وقتی [incompleteCount] فایل بدون رسید (قرمز/زرد)
  /// بین ZIPهای قابل ترکیب هست، چه کار کند.
  Future<_ZipAllChoice?> _askZipAllChoice(int incompleteCount) {
    return showDialog<_ZipAllChoice>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'فایل‌های بدون رسید وجود دارند',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Traffic',
              color: _darkText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '$incompleteCount پوشه بدون رسید داری (قرمز یا زرد). می‌خوای فقط انجام‌شده‌ها (سبزها) زیپ بشن، یا انجام‌نشده‌ها رو نادیده بگیریم و همه با هم زیپ بشن؟',
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              color: _secondaryText,
              fontSize: 14,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    _ZipAllChoice.completedOnly,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'زیپ کردن انجام‌شده‌ها (سبزها)',
                    style: TextStyle(fontFamily: 'Traffic'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    _ZipAllChoice.ignoreAll,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE84C4C),
                    side: const BorderSide(color: Color(0xFFE84C4C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'نادیده گرفتن انجام‌نشده‌ها و زیپ همه',
                    style: TextStyle(fontFamily: 'Traffic'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'انصراف',
                    style: TextStyle(fontFamily: 'Traffic'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFolder(Directory folder) async {
    final confirmed = await _confirmAction(
      title: 'حذف پوشه',
      message:
          'پوشه‌ی «${FileManagerService.displayName(folder)}» و تمام فایل‌های داخل آن برای همیشه حذف می‌شود. مطمئن هستید؟',
      confirmLabel: 'حذف',
      danger: true,
    );

    if (confirmed != true) return;

    try {
      await FileManagerService.delete(folder);
      await CustomerStatusService.clearAll(folder.path);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('پوشه حذف شد.')));

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در حذف: $e')));
    }
  }

  Future<void> _shareFolder(Directory folder) async {
    final files = FileManagerService.getFilesInFolder(folder);

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('این پوشه فایلی برای اشتراک‌گذاری ندارد.'),
        ),
      );
      return;
    }

    final shareResult = await Share.shareXFiles(
      files.map((f) => XFile(f.path)).toList(),
      subject: FileManagerService.displayName(folder),
    );

    if (shareResult.status != ShareResultStatus.success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اشتراک‌گذاری لغو شد و وضعیت مشتری تغییر نکرد.'),
        ),
      );
      return;
    }

    await CustomerStatusService.markSent(folder.path);

    if (!mounted) return;
    setState(() {
      sentKeys.add(CustomerStatusService.keyForPath(folder.path));
    });
  }

  // -------------------------------- اکشن‌های ZIP --------------------------------

  Future<void> _renameZip(File zip) async {
    final currentName = FileManagerService.displayName(zip);
    final input = await _askForName(
      title: 'تغییر نام ZIP',
      initialValue: currentName,
    );

    if (input == null || input.trim().isEmpty || input.trim() == currentName) {
      return;
    }

    try {
      final renamedZip =
          await FileManagerService.rename(zip, input.trim()) as File;

      await CustomerStatusService.transfer(zip.path, renamedZip.path);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام فایل با موفقیت تغییر کرد.')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در تغییر نام: $e')));
    }
  }

  Future<void> _deleteZip(File zip) async {
    final confirmed = await _confirmAction(
      title: 'حذف فایل ZIP',
      message:
          'فایل «${FileManagerService.displayName(zip)}» برای همیشه حذف می‌شود. مطمئن هستید؟',
      confirmLabel: 'حذف',
      danger: true,
    );

    if (confirmed != true) return;

    try {
      await FileManagerService.delete(zip);
      // توجه: وضعیت (فرستاده‌شده/رسید) پاک نمی‌شود، چون این وضعیت مال خودِ
      // مشتری (پوشه) است؛ حذف ZIP به‌تنهایی نباید یادآور پوشه را ریست کند.

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('فایل حذف شد.')));

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در حذف: $e')));
    }
  }

  // ---------------------------- پاکسازی گروهی (سه‌نقطه) ----------------------------

  /// پاکسازی همه‌ی پوشه‌های اصلی که وضعیتشان سبز (رسید دریافت‌شده) است.
  /// فقط خودِ پوشه‌ها حذف می‌شوند؛ فایل‌های ZIP هم‌نام دست‌نخورده می‌مانند
  /// (پاکسازی پوشه و ZIP عمداً از هم جداست).
  Future<void> _cleanupReceivedFolders() async {
    final targets = customerFolders
        .where((f) => _statusFor(f) == ReminderStatus.receiptReceived)
        .toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پوشه‌ی سبز (دارای رسید) برای پاکسازی وجود ندارد.'),
        ),
      );
      return;
    }

    final confirmed = await _confirmAction(
      title: 'پاکسازی پوشه‌های اصلی',
      message:
          '${targets.length} پوشه که رسیدشان دریافت شده، برای همیشه حذف '
          'می‌شوند. فایل‌های ZIP هم‌نامشان دست‌نخورده باقی می‌مانند. مطمئن هستید؟',
      confirmLabel: 'پاکسازی',
      danger: true,
    );
    if (confirmed != true) return;

    var deleted = 0;
    for (final folder in targets) {
      try {
        await folder.delete(recursive: true);
        deleted++;
        // توجه: وضعیت (سبز) عمداً پاک نمی‌شود، چون ممکن است ZIP هم‌نام
        // هنوز مانده باشد و باید همان رنگ سبز را نشان دهد.
      } catch (_) {
        // اگر حذف یک پوشه با خطا مواجه شد، برای بقیه ادامه می‌دهیم.
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$deleted پوشه پاکسازی شد.')),
    );
    await _loadData();
  }

  /// پاکسازی همه‌ی فایل‌های ZIP که وضعیتشان سبز (رسید دریافت‌شده) است.
  /// پوشه‌های اصلی هم‌نام دست‌نخورده می‌مانند.
  Future<void> _cleanupReceivedZips() async {
    final targets = zipFiles
        .where((f) => _statusFor(f) == ReminderStatus.receiptReceived)
        .toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فایل ZIP سبز (دارای رسید) برای پاکسازی وجود ندارد.'),
        ),
      );
      return;
    }

    final confirmed = await _confirmAction(
      title: 'پاکسازی فایل‌های ZIP',
      message:
          '${targets.length} فایل ZIP که رسیدشان دریافت شده، برای همیشه حذف '
          'می‌شوند. پوشه‌های اصلی دست‌نخورده باقی می‌مانند. مطمئن هستید؟',
      confirmLabel: 'پاکسازی',
      danger: true,
    );
    if (confirmed != true) return;

    var deleted = 0;
    for (final zip in targets) {
      try {
        await zip.delete();
        deleted++;
      } catch (_) {
        // اگر حذف یک فایل با خطا مواجه شد، برای بقیه ادامه می‌دهیم.
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$deleted فایل ZIP پاکسازی شد.')),
    );
    await _loadData();
  }

  Future<void> _shareZip(File zip) async {
    final shareResult = await Share.shareXFiles([
      XFile(zip.path),
    ], subject: FileManagerService.displayName(zip));

    if (shareResult.status != ShareResultStatus.success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اشتراک‌گذاری لغو شد و وضعیت مشتری تغییر نکرد.'),
        ),
      );
      return;
    }

    await CustomerStatusService.markSent(zip.path);

    if (!mounted) return;
    setState(() {
      sentKeys.add(CustomerStatusService.keyForPath(zip.path));
    });
  }

  // ----------------------------- دیالوگ‌های مشترک -----------------------------

  Future<String?> _askForName({
    required String title,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              color: _darkText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Traffic'),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF7F8FB),
              hintText: 'نام جدید',
              hintStyle: const TextStyle(
                fontFamily: 'Traffic',
                color: Color(0xFF9AA0AD),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE3E6EC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE3E6EC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'انصراف',
                style: TextStyle(fontFamily: 'Traffic'),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'تایید',
                style: TextStyle(fontFamily: 'Traffic'),
              ),
            ),
          ],
        );
      },
    );
  }

  /// دیالوگ گرفتن «دلیل» برای سبز کردن دستی یک پوشه/فایل. متن خالی مجاز
  /// نیست (دکمه تایید غیرفعال می‌ماند) چون این دلیل قرار است به نام فایل
  /// اضافه شود و باید همیشه معنادار باشد.
  Future<String?> _askForReason({required String title}) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isValid = controller.text.trim().isNotEmpty;
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                title,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Traffic',
                  color: _darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                onChanged: (_) => setDialogState(() {}),
                style: const TextStyle(fontFamily: 'Traffic'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF7F8FB),
                  hintText: 'دلیل سبز کردن را بنویسید',
                  hintStyle: const TextStyle(
                    fontFamily: 'Traffic',
                    color: Color(0xFF9AA0AD),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFE3E6EC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFE3E6EC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: _green, width: 1.5),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'انصراف',
                    style: TextStyle(fontFamily: 'Traffic'),
                  ),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () => Navigator.pop(dialogContext, controller.text.trim())
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'سبز کردن',
                    style: TextStyle(fontFamily: 'Traffic'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// سبز کردن دستی یک پوشه‌ی مشتری «به هر دلیل» (مثلاً وقتی رسید واقعی
  /// نمی‌آید ولی کار نباید گیر کند). دلیل به‌عنوان ادامه‌ی نام پوشه اضافه
  /// می‌شود تا بعداً هم مشخص باشد چرا این مشتری بدون رسید سبز شده، و اگر
  /// ZIP هم‌نامی موجود باشد (که کلید وضعیتش با پوشه مشترک است) با همان نام
  /// جدید هماهنگ می‌شود تا رنگش هم سبز بماند.
  Future<void> _markFolderGreenWithReason(Directory folder) async {
    final reason = await _askForReason(title: 'سبز کردن پوشه به دلیل خاص');
    if (reason == null || reason.isEmpty) return;

    final oldName = FileManagerService.displayName(folder);
    final newName = '$oldName - $reason';

    try {
      final renamedFolder =
          await FileManagerService.rename(folder, newName) as Directory;

      await CustomerStatusService.transfer(folder.path, renamedFolder.path);

      final parentPath = renamedFolder.parent.path;
      final matchingZip = File(
        [parentPath, '$oldName.zip'].join(Platform.pathSeparator),
      );
      if (await matchingZip.exists()) {
        await FileManagerService.rename(matchingZip, newName);
      }

      await CustomerStatusService.markReceiptReceived(renamedFolder.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پوشه سبز شد و دلیل به نام آن اضافه شد.')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در سبز کردن: $e')));
    }
  }

  /// نسخه‌ی ZIP همان قابلیت بالا؛ برای وقتی که خودِ فایل ZIP (نه پوشه)
  /// نیاز به سبز شدن دستی دارد.
  Future<void> _markZipGreenWithReason(File zip) async {
    final reason = await _askForReason(title: 'سبز کردن ZIP به دلیل خاص');
    if (reason == null || reason.isEmpty) return;

    final oldName = FileManagerService.displayName(zip);
    final newName = '$oldName - $reason';

    try {
      final renamedZip =
          await FileManagerService.rename(zip, newName) as File;
      await CustomerStatusService.transfer(zip.path, renamedZip.path);
      await CustomerStatusService.markReceiptReceived(renamedZip.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل ZIP سبز شد و دلیل به نام آن اضافه شد.')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در سبز کردن: $e')));
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              color: _darkText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              color: _secondaryText,
              fontSize: 14,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'انصراف',
                style: TextStyle(fontFamily: 'Traffic'),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: danger
                    ? const Color(0xFFE84C4C)
                    : _primaryBlue,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                confirmLabel,
                style: const TextStyle(fontFamily: 'Traffic'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.operationType == OperationType.charge
        ? 'شارژ این تاریخ'
        : 'صدور این تاریخ';

    final subtitle = widget.operationType == OperationType.charge
        ? 'مدیریت فایل‌های شارژ'
        : 'مدیریت فایل‌های صدور';

    final folderDot = _tabDotColor(customerFolders);
    final zipDot = _tabDotColor(
      zipFiles
          .where(
            (f) =>
                FileManagerService.displayName(f) !=
                FileManagerService.allZipsFileName,
          )
          .toList(),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Traffic'),
        ),
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: _pageBackground,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF0D47C9), Color(0xFF1976E8)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(34),
                        bottomRight: Radius.circular(34),
                      ),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                          tooltip: 'بازگشت',
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                title,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Traffic',
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  color: Color(0xFFE4EEFF),
                                  fontFamily: 'Traffic',
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                          ),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onSelected: (value) {
                            if (value == 'zip_all') {
                              _zipAllForSending();
                            } else if (value == 'clean_folders') {
                              _cleanupReceivedFolders();
                            } else if (value == 'clean_zips') {
                              _cleanupReceivedZips();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'zip_all',
                              child: Text(
                                'زیپ همه فایل‌ها برای ارسال',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontFamily: 'Traffic'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'clean_folders',
                              child: Text(
                                'پاکسازی پوشه‌های اصلی (سبزها)',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontFamily: 'Traffic'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'clean_zips',
                              child: Text(
                                'پاکسازی فایل‌های ZIP (سبزها)',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontFamily: 'Traffic'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Material(
                        color: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                        child: TabBar(
                          labelColor: _primaryBlue,
                          unselectedLabelColor: _secondaryText,
                          indicatorColor: _primaryBlue,
                          indicatorSize: TabBarIndicatorSize.label,
                          indicatorWeight: 3,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                            fontFamily: 'Traffic',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontFamily: 'Traffic',
                            fontSize: 15,
                          ),
                          tabs: [
                            Tab(
                              height: 52,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('فایل اصلی'),
                                  if (folderDot != null) ...[
                                    const SizedBox(width: 7),
                                    _dot(folderDot, size: 8),
                                  ],
                                ],
                              ),
                            ),
                            Tab(
                              height: 52,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('ZIP'),
                                  if (zipDot != null) ...[
                                    const SizedBox(width: 7),
                                    _dot(zipDot, size: 8),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Traffic',
                        color: _darkText,
                      ),
                      decoration: InputDecoration(
                        hintText: 'جستجوی نام مشتری...',
                        hintStyle: const TextStyle(
                          fontFamily: 'Traffic',
                          color: Color(0xFF9AA0AD),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: _primaryBlue,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(17),
                          borderSide: const BorderSide(
                            color: Color(0xFFE3E6EC),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(17),
                          borderSide: const BorderSide(
                            color: Color(0xFFE3E6EC),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(17),
                          borderSide: const BorderSide(
                            color: _primaryBlue,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _primaryBlue,
                            ),
                          )
                        : TabBarView(
                            children: [
                              _buildCustomerFoldersList(),
                              _buildZipFilesList(),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color, {double size = 10}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }

  Widget _leadingWithDot(
    IconData icon,
    Color iconColor,
    ReminderStatus status,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: iconColor),
        Positioned(right: -2, top: -2, child: _dot(status.dotColor)),
      ],
    );
  }

  Widget _buildCustomerFoldersList() {
    final filtered = _filteredFolders;

    if (customerFolders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_off_rounded,
        title: 'هنوز مشتری‌ای برای این تاریخ ثبت نشده',
      );
    }

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: 'مشتری‌ای پیدا نشد.',
      );
    }

    return RefreshIndicator(
      color: _primaryBlue,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final folder = filtered[index];
          final fileCount = folder.listSync().whereType<File>().length;
          final status = _statusFor(folder);

          return _buildEntityCard(
            marginBottom: 10,
            leading: _leadingWithDot(Icons.folder_rounded, _purple, status),
            title: FileManagerService.displayName(folder),
            subtitle: '$fileCount فایل',
            onTap: () => _openFolder(folder),
            menu: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF6B7280),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'open':
                    _openFolder(folder);
                    break;
                  case 'rename':
                    _renameFolder(folder);
                    break;
                  case 'zip':
                    _zipFolder(folder);
                    break;
                  case 'share':
                    _shareFolder(folder);
                    break;
                  case 'greenReason':
                    _markFolderGreenWithReason(folder);
                    break;
                  case 'delete':
                    _deleteFolder(folder);
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'open', child: Text('باز کردن')),
                PopupMenuItem(value: 'rename', child: Text('تغییر نام')),
                PopupMenuItem(value: 'zip', child: Text('زیپ کردن')),
                PopupMenuItem(value: 'share', child: Text('اشتراک‌گذاری')),
                PopupMenuItem(
                  value: 'greenReason',
                  child: Text(
                    'سبز کردن (با دلیل)',
                    style: TextStyle(color: Color(0xFF2E7D32)),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'حذف',
                    style: TextStyle(color: Color(0xFFE84C4C)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: _primaryBlue, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _darkText,
                fontFamily: 'Traffic',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityCard({
    required Widget leading,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    required Widget menu,
    double marginBottom = 10,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F6FF),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  alignment: Alignment.center,
                  child: leading,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        title,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _darkText,
                          fontFamily: 'Traffic',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: _secondaryText,
                          fontFamily: 'Traffic',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                menu,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZipFilesList() {
    final filtered = _filteredZips;

    if (zipFiles.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_zip_rounded,
        title: 'هنوز فایل ZIP‌ای برای این تاریخ ساخته نشده',
      );
    }

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: 'فایلی پیدا نشد.',
      );
    }

    return RefreshIndicator(
      color: _primaryBlue,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final zip = filtered[index];
          final isCombinedZip =
              FileManagerService.displayName(zip) ==
              FileManagerService.allZipsFileName;
          final status = _statusFor(zip);

          return _buildEntityCard(
            leading: isCombinedZip
                ? Container(
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.folder_zip_rounded,
                      color: _primaryBlue,
                    ),
                  )
                : _leadingWithDot(
                    Icons.folder_zip_rounded,
                    const Color(0xFFF07A3A),
                    status,
                  ),
            title: FileManagerService.displayName(zip),
            subtitle: isCombinedZip
                ? 'فایل ترکیبی همه‌ی ZIPها'
                : 'فایل فشرده ZIP',
            onTap: null,
            menu: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF6B7280),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    _renameZip(zip);
                    break;
                  case 'share':
                    _shareZip(zip);
                    break;
                  case 'greenReason':
                    _markZipGreenWithReason(zip);
                    break;
                  case 'delete':
                    _deleteZip(zip);
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('تغییر نام')),
                PopupMenuItem(value: 'share', child: Text('اشتراک‌گذاری')),
                PopupMenuItem(
                  value: 'greenReason',
                  child: Text(
                    'سبز کردن (با دلیل)',
                    style: TextStyle(color: Color(0xFF2E7D32)),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'حذف',
                    style: TextStyle(color: Color(0xFFE84C4C)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// صفحه‌ی ساده‌ی داخل‌اپی برای مرور فایل‌های یک پوشه‌ی مشتری.
///
/// این کلاس عمومی است (نه private) چون از صفحه‌ی جستجوی سریع
/// (search_page.dart) هم برای باز کردن پوشه‌ی نتیجه‌ی جستجو استفاده می‌شود.
class FolderContentsPage extends StatefulWidget {
  final Directory folder;

  const FolderContentsPage({super.key, required this.folder});

  @override
  State<FolderContentsPage> createState() => _FolderContentsPageState();
}

class _FolderContentsPageState extends State<FolderContentsPage> {
  static const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.heic'];

  List<File> _files = [];
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() {
    setState(() {
      _files = FileManagerService.getFilesInFolder(widget.folder);
    });
  }

  bool _isImage(File file) {
    final path = file.path.toLowerCase();
    return _imageExtensions.any((ext) => path.endsWith(ext));
  }

  bool _isReceipt(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    return name.startsWith(ReceiptService.receiptPrefix);
  }

  Future<void> _openFile(BuildContext context, File file) async {
    final result = await OpenFilex.open(file.path);

    if (result.type != ResultType.done) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'برنامه‌ای برای باز کردن این فایل پیدا نشد: ${result.message}',
          ),
        ),
      );
    }
  }

  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D9E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: _FileManagerPageState._primaryBlue,
                    ),
                  ),
                  title: const Text(
                    'انتخاب از گالری',
                    style: TextStyle(
                      fontFamily: 'Traffic',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F8F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF22B965),
                    ),
                  ),
                  title: const Text(
                    'گرفتن عکس با دوربین',
                    style: TextStyle(
                      fontFamily: 'Traffic',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _askForFileName() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'نام عکس',
            style: TextStyle(
              fontFamily: 'Traffic',
              color: _FileManagerPageState._darkText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              color: _FileManagerPageState._darkText,
            ),
            decoration: InputDecoration(
              hintText: 'مثلاً: عکس اضافی',
              hintStyle: const TextStyle(fontFamily: 'Traffic'),
              filled: true,
              fillColor: const Color(0xFFF7F8FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE3E6EC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE3E6EC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: _FileManagerPageState._primaryBlue,
                  width: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: _FileManagerPageState._primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'ذخیره',
                style: TextStyle(fontFamily: 'Traffic'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmOverwrite(String name) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'بازنویسی فایل',
            style: TextStyle(
              fontFamily: 'Traffic',
              color: _FileManagerPageState._darkText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'فایلی با نام «$name» از قبل در این پوشه وجود دارد. بازنویسی شود؟',
            style: const TextStyle(
              fontFamily: 'Traffic',
              color: _FileManagerPageState._secondaryText,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _FileManagerPageState._primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'بازنویسی',
                style: TextStyle(fontFamily: 'Traffic'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addPhoto() async {
    final source = await _pickImageSource();
    if (source == null || _isAdding) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 90,
      // با همون سقف ابعادی محدودش می‌کنیم که دوربین اصلی مدارک داره
      // (ResolutionPreset.high ≈ ۱۲۸۰ پیکسل)، وگرنه عکس گالری با ابعاد
      // اصلی (مثلاً ۱۲+ مگاپیکسل) میاد که هم حجم برش‌خورده رو چند برابر
      // می‌کنه و هم پردازش برش رو کند می‌کنه.
      maxWidth: 1280,
      maxHeight: 1280,
      // برای عکاسی از مدرک، دوربین پشت باید پیش‌فرض باز شود، نه سلفی.
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;

    if (!mounted) return;
    final Uint8List? croppedBytes = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageCropPage(imageFile: File(picked.path)),
      ),
    );
    if (croppedBytes == null) return;

    final name = await _askForFileName();
    if (name == null || name.trim().isEmpty) return;
    final trimmedName = name.trim();

    if (FileManagerService.imageNameExists(widget.folder, trimmedName)) {
      final confirmed = await _confirmOverwrite(trimmedName);
      if (confirmed != true) return;
    }

    setState(() => _isAdding = true);

    try {
      await FileManagerService.addImageBytesToFolder(
        folder: widget.folder,
        bytes: croppedBytes,
        desiredName: trimmedName,
      );

      _loadFiles();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('عکس با موفقیت اضافه شد.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در افزودن عکس: $e')));
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Traffic'),
        ),
        child: Scaffold(
          backgroundColor: _FileManagerPageState._pageBackground,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF0D47C9), Color(0xFF1976E8)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(34),
                      bottomRight: Radius.circular(34),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.folder_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              FileManagerService.displayName(widget.folder),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Traffic',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'فایل‌ های ذخیره شده',
                              style: TextStyle(
                                color: Color(0xFFE4EEFF),
                                fontFamily: 'Traffic',
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _files.isEmpty
                      ? const Center(
                          child: Text(
                            'این پوشه هنوز فایلی ندارد.',
                            style: TextStyle(
                              color: _FileManagerPageState._darkText,
                              fontFamily: 'Traffic',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                          itemCount: _files.length,
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            final sizeKb = (file.lengthSync() / 1024)
                                .toStringAsFixed(1);
                            final isReceipt = _isReceipt(file);
                            final iconColor = isReceipt
                                ? const Color(0xFF22B965)
                                : const Color(0xFF607D8B);
                            final icon = isReceipt
                                ? Icons.receipt_long_rounded
                                : (_isImage(file)
                                      ? Icons.image_rounded
                                      : Icons.insert_drive_file_rounded);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: Colors.white,
                                elevation: 1,
                                shadowColor: Colors.black12,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _openFile(context, file),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 11,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            color: iconColor.withOpacity(0.10),
                                            borderRadius: BorderRadius.circular(
                                              17,
                                            ),
                                          ),
                                          child: Icon(
                                            icon,
                                            color: iconColor,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                FileManagerService.displayName(
                                                  file,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: _FileManagerPageState
                                                      ._darkText,
                                                  fontFamily: 'Traffic',
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                '$sizeKb KB',
                                                style: const TextStyle(
                                                  color: _FileManagerPageState
                                                      ._secondaryText,
                                                  fontFamily: 'Traffic',
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 20,
                                          color: Color(0xFF9AA0AD),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isAdding ? null : _addPhoto,
            backgroundColor: _FileManagerPageState._primaryBlue,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: _isAdding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_a_photo_rounded),
            label: const Text(
              'افزودن عکس',
              style: TextStyle(
                fontFamily: 'Traffic',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// صفحه‌ی برش عکسِ تازه اضافه‌شده به پوشه — دقیقاً همان تجربه‌ی برش که در
/// دوربین اصلی (issue_camera_page.dart) استفاده می‌شود، با پکیج crop_image.
class _ImageCropPage extends StatefulWidget {
  final File imageFile;

  const _ImageCropPage({required this.imageFile});

  @override
  State<_ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<_ImageCropPage> {
  final CropController cropController = CropController();
  bool _isProcessing = false;

  Future<Uint8List?> _cropToJpg() async {
    try {
      final ui.Image bitmap = await cropController.croppedBitmap();
      final ByteData? byteData = await bitmap.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;

      final img.Image? decodedImage = img.decodeImage(
        byteData.buffer.asUint8List(),
      );
      if (decodedImage == null) return null;

      return Uint8List.fromList(img.encodeJpg(decodedImage, quality: 85));
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);
    final bytes = await _cropToJpg();
    if (!mounted) return;

    if (bytes == null) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('برش تصویر انجام نشد.')));
      return;
    }

    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'برش عکس',
            style: TextStyle(
              fontFamily: 'Traffic',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CropImage(
                  controller: cropController,
                  image: Image.file(widget.imageFile, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 53,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text(
                            'انصراف',
                            style: TextStyle(
                              fontFamily: 'Traffic',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 53,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _confirm,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text(
                            'تأیید برش',
                            style: TextStyle(
                              fontFamily: 'Traffic',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF35B96B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}