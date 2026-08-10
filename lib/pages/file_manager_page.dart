import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../operation_type.dart';
import '../services/file_manager_service.dart';
import '../services/zip_share_status_service.dart';

class FileManagerPage extends StatefulWidget {
  final OperationType operationType;

  const FileManagerPage({super.key, required this.operationType});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  List<Directory> customerFolders = [];
  List<File> zipFiles = [];
  Set<String> sharedZipPaths = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final folders = await FileManagerService.getCustomerFolders(
      widget.operationType,
    );
    final zips = await FileManagerService.getCustomerZipFiles(
      widget.operationType,
    );
    final shared = await ZipShareStatusService.getSharedPaths();

    if (!mounted) return;

    setState(() {
      customerFolders = folders;
      zipFiles = zips;
      sharedZipPaths = shared;
      isLoading = false;
    });
  }

  /// آیا حداقل یک ZIP هنوز اشتراک‌گذاری نشده — برای نقطه‌ی روی خود تب ZIP.
  bool get _hasUnsharedZip =>
      zipFiles.any((z) => !sharedZipPaths.contains(z.path));

  // ------------------------------- اکشن‌های پوشه -------------------------------

  /// پوشه فقط داخل خود اپ باز می‌شود (لیست فایل‌ها) — نیازی به باز کردن
  /// پوشه با اپ خارجی نیست، این فقط برای چک کردن سریع محتویات پوشه است.
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

      // ZIP تازه ساخته شده (یا بازنویسی شده) هنوز فرستاده نشده، پس اگر قبلاً
      // علامت «اشتراک‌گذاری‌شده» داشت، پاکش می‌کنیم تا یادآور دوباره بیاد.
      await ZipShareStatusService.clear(existingZip.path);

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
  }

  // -------------------------------- اکشن‌های ZIP --------------------------------
  // طبق تصمیم، ZIP داخل خود اپ باز نمی‌شود؛ در صورت نیاز با یک اپ خارجی باز می‌شود.

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

      // اگر این فایل قبلاً «اشتراک‌گذاری‌شده» علامت خورده بود، همان وضعیت
      // را روی مسیر جدید هم منتقل می‌کنیم تا یادآور بی‌جهت برنگردد.
      await ZipShareStatusService.transfer(zip.path, renamedZip.path);

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
      await ZipShareStatusService.clear(zip.path);

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

    // فقط بعد از زدن روی «اشتراک‌گذاری» یادآور کنار این فایل برداشته می‌شود.
    await ZipShareStatusService.markAsShared(zip.path);

    if (!mounted) return;
    setState(() {
      sharedZipPaths.add(zip.path);
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'فایل اصلی'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ZIP'),
                    if (_hasUnsharedZip) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildCustomerFoldersList(),
                  _buildZipFilesList(),
                ],
              ),
      ),
    );
  }

  Widget _buildCustomerFoldersList() {
    if (customerFolders.isEmpty) {
      return const Center(child: Text('هنوز مشتری‌ای برای این تاریخ ثبت نشده'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: customerFolders.length,
        itemBuilder: (context, index) {
          final folder = customerFolders[index];
          final fileCount = folder.listSync().whereType<File>().length;

          return ListTile(
            leading: const Icon(Icons.folder, color: Colors.amber),
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
    if (zipFiles.isEmpty) {
      return const Center(child: Text('هنوز فایل ZIP‌ای برای این تاریخ ساخته نشده'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: zipFiles.length,
        itemBuilder: (context, index) {
          final zip = zipFiles[index];
          final isUnshared = !sharedZipPaths.contains(zip.path);

          return ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.folder_zip, color: Colors.deepOrange),
                if (isUnshared)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
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

/// صفحه‌ی ساده‌ی داخل‌اپی برای مرور فایل‌های یک پوشه‌ی مشتری —
/// با لمس هر فایل (مثلاً عکس)، همان فایل با یک اپ خارجی مناسب (گالری،
/// نمایشگر عکس و ...) باز می‌شود؛ خود اپ چیزی را رندر نمی‌کند.
class _FolderContentsPage extends StatelessWidget {
  final Directory folder;

  const _FolderContentsPage({required this.folder});

  static const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.heic'];

  bool _isImage(File file) {
    final path = file.path.toLowerCase();
    return _imageExtensions.any((ext) => path.endsWith(ext));
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

                return ListTile(
                  leading: Icon(
                    _isImage(file) ? Icons.image : Icons.insert_drive_file,
                    color: Colors.blueGrey,
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