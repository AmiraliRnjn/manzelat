import 'dart:io';

import 'package:flutter/material.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/backup_service.dart';
import '../services/storage_picker_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  static const primaryBlue = Color(0xFF1565C0);
  static const darkText = Color(0xFF151A2B);
  static const secondaryText = Color(0xFF707789);
  static const background = Color(0xFFFAFBFF);

  bool _loading = true;
  bool _busy = false;
  bool _autoEnabled = false;
  int _intervalDays = 1;
  String? _autoFolder;
  String? _lastPath;
  DateTime? _lastTime;
  BackupInspection? _lastInspection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      BackupService.isAutoBackupEnabled(),
      BackupService.getAutoBackupFolder(),
      BackupService.getAutoBackupIntervalDays(),
      BackupService.getLastBackupPath(),
      BackupService.getLastBackupTime(),
    ]);

    if (!mounted) return;
    setState(() {
      _autoEnabled = values[0] as bool;
      _autoFolder = values[1] as String?;
      _intervalDays = values[2] as int;
      _lastPath = values[3] as String?;
      _lastTime = values[4] as DateTime?;
      _loading = false;
    });

    if (_lastPath != null) {
      final file = File(_lastPath!);
      if (await file.exists()) {
        final inspection = await BackupService.inspectBackup(file);
        if (mounted) setState(() => _lastInspection = inspection);
      }
    }
  }

  Future<Directory?> _pickFolder() async {
    final path = await StoragePickerService.pickStorageFolder(context);
    return path == null ? null : Directory(path);
  }

  Future<File?> _pickBackupFile() async {
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return null;

      final parts = externalDir.path.split('/Android');
      if (parts.isEmpty) return null;

      final root = Directory(parts.first);
      final selected = await FilesystemPicker.open(
        title: 'انتخاب فایل Backup',
        context: context,
        rootDirectory: root,
        fsType: FilesystemType.file,
        allowedExtensions: const [BackupService.backupExtension],
        fileTileSelectMode: FileTileSelectMode.wholeTile,
        folderIconColor: primaryBlue,
      );
      return selected == null ? null : File(selected);
    } catch (_) {
      return null;
    }
  }

  Future<void> _createManualBackup() async {
    final folder = await _pickFolder();
    if (folder == null) return;

    setState(() => _busy = true);
    final result = await BackupService.createBackup(
      destinationDirectory: folder,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.success) {
      setState(() {
        _lastPath = result.path;
        _lastTime = DateTime.now();
      });
    }
    await _showResult(result.message, success: result.success);
  }

  Future<void> _configureAutoBackup() async {
    if (_autoFolder == null) {
      final folder = await _pickFolder();
      if (folder == null) return;
      _autoFolder = folder.path;
      await BackupService.setAutoBackupFolder(folder.path);
    }

    await BackupService.setAutoBackupEnabled(true);
    if (!mounted) return;
    setState(() => _autoEnabled = true);

    await _showResult(
      'Backup خودکار فعال شد. در اولین فرصت و سپس طبق فاصله‌ی انتخاب‌شده اجرا می‌شود.',
      success: true,
    );
  }

  Future<void> _changeAutoFolder() async {
    final folder = await _pickFolder();
    if (folder == null) return;
    await BackupService.setAutoBackupFolder(folder.path);
    if (!mounted) return;
    setState(() => _autoFolder = folder.path);
  }

  Future<void> _restore() async {
    final file = await _pickBackupFile();
    if (file == null) return;

    setState(() => _busy = true);
    final inspection = await BackupService.inspectBackup(file);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!inspection.valid) {
      await _showResult(inspection.message, success: false);
      return;
    }

    final choices = await showDialog<_RestoreChoices>(
      context: context,
      builder: (_) => const _RestoreDialog(),
    );
    if (choices == null) return;

    final targetFolder = await _chooseRestoreTarget();
    if (targetFolder == null) return;

    final confirmed = await _confirmRestore(
      choices,
      targetFolder,
      inspection,
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    final result = await BackupService.restoreBackup(
      backupFile: file,
      targetRoot: targetFolder,
      restoreFiles: choices.files,
      restoreAppState: choices.appState,
      overwriteExisting: choices.overwrite,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _showResult(result.message, success: result.success);

    if (result.success) {
      await _load();
    }
  }

  Future<Directory?> _chooseRestoreTarget() async {
    final folder = await _pickFolder();
    return folder;
  }

  Future<bool> _confirmRestore(
    _RestoreChoices choices,
    Directory target,
    BackupInspection inspection,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'تأیید Restore',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold),
        ),
        content: Text(
          'تعداد ${inspection.fileCount} فایل از Backup خوانده شد.\n'
          'محل مقصد:\n${target.path}\n\n'
          'فایل‌های موجود ${choices.overwrite ? 'در صورت انتخاب، جایگزین می‌شوند.' : 'دست‌نخورده باقی می‌مانند.'}',
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Traffic', height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف', style: TextStyle(fontFamily: 'Traffic')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: primaryBlue),
            child: const Text('شروع Restore', style: TextStyle(fontFamily: 'Traffic')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showResult(String message, {required bool success}) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? const Color(0xFF22B965) : const Color(0xFFE84C4C),
            ),
            const SizedBox(width: 10),
            Text(
              success ? 'عملیات موفق' : 'خطا',
              style: const TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Traffic', height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متوجه شدم', style: TextStyle(fontFamily: 'Traffic')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: darkText,
        centerTitle: true,
        title: const Text(
          'پشتیبان‌گیری و بازیابی',
          style: TextStyle(
            fontFamily: 'Traffic',
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                  children: [
                    _InfoCard(
                      icon: Icons.shield_outlined,
                      title: 'امنیت اطلاعات',
                      text:
                          'اطلاعات داخل مسیر ذخیره‌سازی برنامه، به همراه وضعیت‌های مرتبط، در یک Backup قابل انتقال ذخیره می‌شوند.',
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle(
                      title: 'عملیات',
                      icon: Icons.cloud_sync_outlined,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.backup_rounded,
                      title: 'Backup دستی',
                      subtitle: 'یک نسخه کامل از اطلاعات فعلی بساز',
                      onTap: _busy ? null : _createManualBackup,
                    ),
                    const SizedBox(height: 10),
                    _ActionCard(
                      icon: Icons.restore_rounded,
                      title: 'Restore',
                      subtitle: 'یک Backup معتبر را بررسی و بازیابی کن',
                      onTap: _busy ? null : _restore,
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: 'Backup خودکار',
                      icon: Icons.autorenew_rounded,
                    ),
                    const SizedBox(height: 12),
                    _SettingsPanel(
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _autoEnabled,
                            activeColor: primaryBlue,
                            title: const Text(
                              'Backup خودکار',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Traffic',
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            subtitle: Text(
                              _autoEnabled
                                  ? 'فعال • هر $_intervalDays روز'
                                  : 'غیرفعال',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: 'Traffic',
                                color: secondaryText,
                              ),
                            ),
                            onChanged: _busy
                                ? null
                                : (value) async {
                                    if (value) {
                                      await _configureAutoBackup();
                                    } else {
                                      await BackupService.setAutoBackupEnabled(false);
                                      if (mounted) setState(() => _autoEnabled = false);
                                    }
                                  },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.folder_outlined,
                              color: primaryBlue,
                            ),
                            title: const Text(
                              'محل Backup خودکار',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'Traffic'),
                            ),
                            subtitle: Text(
                              _autoFolder ?? 'انتخاب نشده',
                              textDirection: TextDirection.rtl,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Traffic',
                                color: secondaryText,
                              ),
                            ),
                            onTap: _changeAutoFolder,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.schedule_outlined,
                              color: primaryBlue,
                            ),
                            title: const Text(
                              'فاصله Backup',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'Traffic'),
                            ),
                            trailing: DropdownButton<int>(
                              value: _intervalDays,
                              underline: const SizedBox.shrink(),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('روزانه')),
                                DropdownMenuItem(value: 3, child: Text('هر ۳ روز')),
                                DropdownMenuItem(value: 7, child: Text('هفتگی')),
                                DropdownMenuItem(value: 14, child: Text('هر ۱۴ روز')),
                                DropdownMenuItem(value: 30, child: Text('ماهانه')),
                              ],
                              onChanged: (value) async {
                                if (value == null) return;
                                await BackupService.setAutoBackupIntervalDays(value);
                                if (mounted) setState(() => _intervalDays = value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: 'آخرین Backup',
                      icon: Icons.history_rounded,
                    ),
                    const SizedBox(height: 12),
                    _SettingsPanel(
                      child: _lastPath == null
                          ? const Text(
                              'هنوز Backup ثبت نشده است.',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Traffic',
                                color: secondaryText,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _lastTime == null
                                      ? 'زمان نامشخص'
                                      : _formatDateTime(_lastTime!),
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    fontFamily: 'Traffic',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _lastPath!,
                                  textDirection: TextDirection.ltr,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: secondaryText,
                                  ),
                                ),
                                if (_lastInspection != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      Icon(
                                        _lastInspection!.valid
                                            ? Icons.verified_rounded
                                            : Icons.warning_rounded,
                                        size: 20,
                                        color: _lastInspection!.valid
                                            ? const Color(0xFF22B965)
                                            : const Color(0xFFE84C4C),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          _lastInspection!.message,
                                          textDirection: TextDirection.rtl,
                                          style: const TextStyle(
                                            fontFamily: 'Traffic',
                                            color: secondaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
                if (_busy)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: primaryBlue),
                              SizedBox(height: 14),
                              Text(
                                'لطفاً صبر کنید...',
                                style: TextStyle(fontFamily: 'Traffic'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatDateTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _RestoreChoices {
  final bool files;
  final bool appState;
  final bool overwrite;

  const _RestoreChoices({
    required this.files,
    required this.appState,
    required this.overwrite,
  });
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog();

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  bool files = true;
  bool appState = true;
  bool overwrite = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'چه چیزی Restore شود؟',
        textDirection: TextDirection.rtl,
        style: TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            value: files,
            onChanged: (v) => setState(() => files = v ?? false),
            title: const Text(
              'فایل‌ها و پوشه‌ها',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Traffic'),
            ),
          ),
          CheckboxListTile(
            value: appState,
            onChanged: (v) => setState(() => appState = v ?? false),
            title: const Text(
              'وضعیت برنامه و رسیدها',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Traffic'),
            ),
          ),
          CheckboxListTile(
            value: overwrite,
            onChanged: (v) => setState(() => overwrite = v ?? false),
            title: const Text(
              'جایگزینی فایل‌های موجود',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Traffic'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف', style: TextStyle(fontFamily: 'Traffic')),
        ),
        FilledButton(
          onPressed: files || appState
              ? () => Navigator.pop(
                    context,
                    _RestoreChoices(
                      files: files,
                      appState: appState,
                      overwrite: overwrite,
                    ),
                  )
              : null,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
          child: const Text('ادامه', style: TextStyle(fontFamily: 'Traffic')),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFF7FAFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E3F7)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1565C0), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: 'Traffic',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  text,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: 'Traffic',
                    color: Color(0xFF526174),
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, color: const Color(0xFF1565C0), size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'Traffic',
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Color(0xFF151A2B),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  static const Color secondaryText = Color(0xFF707789);


  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: const Color(0xFF1565C0), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Traffic',
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Traffic',
                        color: secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final Widget child;

  const _SettingsPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E9EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
