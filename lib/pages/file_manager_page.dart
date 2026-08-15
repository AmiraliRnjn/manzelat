import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../app_enum.dart';
import '../reminder_status.dart';
import '../services/file_manager_service.dart';
import '../services/customer_status_service.dart';
import '../services/receipt_service.dart';

class FileManagerPage extends StatefulWidget {
  final OperationType operationType;

  const FileManagerPage({super.key, required this.operationType});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
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
      MaterialPageRoute(builder: (_) => _FolderContentsPage(folder: folder)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در تغییر نام: $e')),
      );
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
        message: 'فایل ZIP «$name» از قبل وجود دارد. با نسخه‌ی جدید جایگزین شود؟',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ساخت ZIP با خطا مواجه شد: $e')),
      );
    }
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پوشه حذف شد.')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در حذف: $e')),
      );
    }
  }

  Future<void> _shareFolder(Directory folder) async {
    final files = FileManagerService.getFilesInFolder(folder);

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('این پوشه فایلی برای اشتراک‌گذاری ندارد.')),
      );
      return;
    }

    await Share.shareXFiles(
      files.map((f) => XFile(f.path)).toList(),
      subject: FileManagerService.displayName(folder),
    );

    // فقط بعد از زدن روی «اشتراک‌گذاری» یادآور به حالت زرد (منتظر رسید) می‌رود.
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در تغییر نام: $e')),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل حذف شد.')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در حذف: $e')),
      );
    }
  }

  Future<void> _shareZip(File zip) async {
    await Share.shareXFiles(
      [XFile(zip.path)],
      subject: FileManagerService.displayName(zip),
    );

    // فقط بعد از زدن روی «اشتراک‌گذاری» یادآور به حالت زرد (منتظر رسید) می‌رود.
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
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('تایید'),
            ),
          ],
        );
      },
    );
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
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: danger ? Colors.red : null,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
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

    final folderDot = _tabDotColor(customerFolders);
    final zipDot = _tabDotColor(zipFiles);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('فایل اصلی'),
                    if (folderDot != null) ...[
                      const SizedBox(width: 6),
                      _dot(folderDot, size: 8),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ZIP'),
                    if (zipDot != null) ...[
                      const SizedBox(width: 6),
                      _dot(zipDot, size: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: 'جستجوی نام مشتری...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCustomerFoldersList(),
                        _buildZipFilesList(),
                      ],
                    ),
                  ),
                ],
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

  Widget _leadingWithDot(IconData icon, Color iconColor, ReminderStatus status) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: iconColor),
        Positioned(
          right: -2,
          top: -2,
          child: _dot(status.dotColor),
        ),
      ],
    );
  }

  Widget _buildCustomerFoldersList() {
    final filtered = _filteredFolders;

    if (customerFolders.isEmpty) {
      return const Center(child: Text('هنوز مشتری‌ای برای این تاریخ ثبت نشده'));
    }

    if (filtered.isEmpty) {
      return const Center(child: Text('مشتری‌ای پیدا نشد.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final folder = filtered[index];
          final fileCount = folder.listSync().whereType<File>().length;
          final status = _statusFor(folder);

          return ListTile(
            leading: _leadingWithDot(Icons.folder, Colors.amber, status),
            title: Text(FileManagerService.displayName(folder)),
            subtitle: Text('$fileCount فایل'),
            onTap: () => _openFolder(folder),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
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
                  value: 'delete',
                  child: Text('حذف', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildZipFilesList() {
    final filtered = _filteredZips;

    if (zipFiles.isEmpty) {
      return const Center(child: Text('هنوز فایل ZIP‌ای برای این تاریخ ساخته نشده'));
    }

    if (filtered.isEmpty) {
      return const Center(child: Text('مشتری‌ای پیدا نشد.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final zip = filtered[index];
          final status = _statusFor(zip);

          return ListTile(
            leading: _leadingWithDot(Icons.folder_zip, Colors.deepOrange, status),
            title: Text(FileManagerService.displayName(zip)),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    _renameZip(zip);
                    break;
                  case 'share':
                    _shareZip(zip);
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
                  value: 'delete',
                  child: Text('حذف', style: TextStyle(color: Colors.red)),
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
class _FolderContentsPage extends StatelessWidget {
  final Directory folder;

  const _FolderContentsPage({required this.folder});

  static const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.heic'];

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

  @override
  Widget build(BuildContext context) {
    final files = FileManagerService.getFilesInFolder(folder);

    return Scaffold(
      appBar: AppBar(
        title: Text(FileManagerService.displayName(folder)),
      ),
      body: files.isEmpty
          ? const Center(child: Text('این پوشه هنوز فایلی ندارد.'))
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final sizeKb = (file.lengthSync() / 1024).toStringAsFixed(1);
                final isReceipt = _isReceipt(file);

                return ListTile(
                  leading: Icon(
                    isReceipt
                        ? Icons.receipt_long
                        : (_isImage(file) ? Icons.image : Icons.insert_drive_file),
                    color: isReceipt ? Colors.green : Colors.blueGrey,
                  ),
                  title: Text(FileManagerService.displayName(file)),
                  subtitle: Text('$sizeKb KB'),
                  trailing: const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
                  onTap: () => _openFile(context, file),
                );
              },
            ),
    );
  }
}