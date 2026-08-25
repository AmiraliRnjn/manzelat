import 'dart:io';

import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/backup_service.dart';
import '../services/integrity_check_service.dart';
import '../services/storage_picker_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  static const primaryBlue = Color(0xFF1565C0);
  static const background = Color(0xFFFAFBFF);
  static const darkText = Color(0xFF151A2B);
  static const secondaryText = Color(0xFF707789);

  bool _loading = true;
  bool _busy = false;
  bool _autoEnabled = false;
  int _intervalDays = 1;
  String? _autoFolder;
  String? _lastPath;
  DateTime? _lastTime;

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

  Future<void> _createBackup() async {
    final folder = await _pickFolder();
    if (folder == null) return;
    setState(() => _busy = true);
    final result = await BackupService.createBackup(destinationDirectory: folder);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.success) {
      setState(() {
        _lastPath = result.path;
        _lastTime = DateTime.now();
      });
    }
    await _showMessage(result.message, success: result.success);
  }

  Future<void> _restoreOrMerge() async {
    final file = await _pickBackupFile();
    if (file == null) return;

    setState(() => _busy = true);
    final inspection = await BackupService.inspectBackup(file);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!inspection.valid) {
      await _showMessage(inspection.message, success: false);
      return;
    }

    final choices = await showDialog<_RestoreChoices>(
      context: context,
      builder: (_) => const _RestoreChoicesDialog(),
    );
    if (choices == null) return;

    final target = await _pickFolder();
    if (target == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          choices.overwrite ? 'تأیید Restore' : 'تأیید Merge',
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold),
        ),
        content: Text(
          choices.overwrite
              ? 'اطلاعات Backup روی مقصد بازیابی می‌شود و فایل‌های هم‌نام جایگزین خواهند شد.'
              : 'اطلاعات این Backup به اطلاعات موجود اضافه می‌شود. فایل‌های هم‌نام موجود دست‌نخورده می‌مانند؛ مناسب برای ادغام Backup چند گوشی.',
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
            child: Text(
              choices.overwrite ? 'شروع Restore' : 'شروع Merge',
              style: const TextStyle(fontFamily: 'Traffic'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final result = await BackupService.restoreBackup(
      backupFile: file,
      targetRoot: target,
      restoreFiles: choices.files,
      restoreAppState: choices.appState,
      overwriteExisting: choices.overwrite,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _showMessage(result.message, success: result.success);
  }

  Future<void> _runHealthCheck() async {
    setState(() => _busy = true);
    final result = await IntegrityCheckService.run();
    if (!mounted) return;
    setState(() => _busy = false);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(
              result.healthy ? Icons.verified_rounded : Icons.warning_rounded,
              color: result.healthy ? const Color(0xFF22B965) : const Color(0xFFD97706),
            ),
            const SizedBox(width: 10),
            Text(
              'بررسی سلامت',
              style: const TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.summary, style: const TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                for (final check in result.checks) ...[
                  Text(check, style: const TextStyle(fontFamily: 'Traffic', height: 1.8)),
                  const SizedBox(height: 2),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن', style: TextStyle(fontFamily: 'Traffic')),
          ),
        ],
      ),
    );
  }

  Future<void> _configureAutoBackup() async {
    if (_autoFolder == null) {
      final folder = await _pickFolder();
      if (folder == null) return;
      await BackupService.setAutoBackupFolder(folder.path);
      _autoFolder = folder.path;
    }
    await BackupService.setAutoBackupEnabled(true);
    if (mounted) setState(() => _autoEnabled = true);
  }

  Future<void> _showMessage(String message, {required bool success}) {
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
            Text(success ? 'عملیات موفق' : 'خطا', style: const TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Traffic', height: 1.8)),
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
        title: const Text('پشتیبان‌گیری و بازیابی', style: TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold, fontSize: 21)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                  children: [
                    const _InfoCard(
                      icon: Icons.merge_type_rounded,
                      title: 'ادغام چند گوشی',
                      text: 'برای جمع‌کردن اطلاعات ۳ گوشی، Backup هر گوشی را جداگانه انتخاب کنید و حالت Merge را نگه دارید. اطلاعات جدید اضافه می‌شوند و داده‌های موجود حذف نمی‌شوند.',
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle(title: 'عملیات', icon: Icons.cloud_sync_outlined),
                    const SizedBox(height: 10),
                    _ActionCard(
                      icon: Icons.backup_rounded,
                      title: 'Backup دستی',
                      subtitle: 'نسخه کامل اطلاعات فعلی را بساز',
                      onTap: _busy ? null : _createBackup,
                    ),
                    const SizedBox(height: 10),
                    _ActionCard(
                      icon: Icons.merge_rounded,
                      title: 'Restore / Merge',
                      subtitle: 'Backup را بازیابی یا با اطلاعات موجود ادغام کن',
                      onTap: _busy ? null : _restoreOrMerge,
                    ),
                    const SizedBox(height: 10),
                    _ActionCard(
                      icon: Icons.health_and_safety_rounded,
                      title: 'بررسی سلامت',
                      subtitle: 'فایل صفر بایت، .part و آخرین Backup را بررسی کن',
                      onTap: _busy ? null : _runHealthCheck,
                    ),
                    const SizedBox(height: 22),
                    const _SectionTitle(title: 'Backup خودکار', icon: Icons.autorenew_rounded),
                    const SizedBox(height: 10),
                    _SettingsPanel(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _autoEnabled,
                          activeColor: primaryBlue,
                          title: const Text('Backup خودکار', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold, fontSize: 17)),
                          subtitle: Text(_autoEnabled ? 'فعال • هر $_intervalDays روز' : 'غیرفعال', textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Traffic', color: secondaryText)),
                          onChanged: _busy ? null : (value) async {
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
                          leading: const Icon(Icons.schedule_outlined, color: primaryBlue),
                          title: const Text('فاصله Backup', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Traffic')),
                          trailing: DropdownButton<int>(
                            value: _intervalDays,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('روزانه')),
                              DropdownMenuItem(value: 3, child: Text('هر ۳ روز')),
                              DropdownMenuItem(value: 7, child: Text('هفتگی')),
                              DropdownMenuItem(value: 30, child: Text('ماهانه')),
                            ],
                            onChanged: _busy ? null : (value) async {
                              if (value == null) return;
                              await BackupService.setAutoBackupIntervalDays(value);
                              if (mounted) setState(() => _intervalDays = value);
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_outlined, color: primaryBlue),
                          title: const Text('محل Backup خودکار', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Traffic')),
                          subtitle: Text(_autoFolder ?? 'انتخاب نشده', textDirection: TextDirection.ltr, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Traffic', color: secondaryText)),
                          onTap: _busy ? null : () async {
                            final folder = await _pickFolder();
                            if (folder == null) return;
                            await BackupService.setAutoBackupFolder(folder.path);
                            if (mounted) setState(() => _autoFolder = folder.path);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_lastPath != null)
                      _LastBackupCard(path: _lastPath!, time: _lastTime),
                  ],
                ),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RestoreChoices {
  final bool files;
  final bool appState;
  final bool overwrite;

  const _RestoreChoices({required this.files, required this.appState, required this.overwrite});
}

class _RestoreChoicesDialog extends StatefulWidget {
  const _RestoreChoicesDialog();
  @override
  State<_RestoreChoicesDialog> createState() => _RestoreChoicesDialogState();
}

class _RestoreChoicesDialogState extends State<_RestoreChoicesDialog> {
  bool files = true;
  bool appState = true;
  bool overwrite = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('نوع بازیابی', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold)),
      content: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(value: files, onChanged: (v) => setState(() => files = v ?? false), title: const Text('فایل‌ها', style: TextStyle(fontFamily: 'Traffic'))),
            CheckboxListTile(value: appState, onChanged: (v) => setState(() => appState = v ?? false), title: const Text('وضعیت برنامه و رسیدها', style: TextStyle(fontFamily: 'Traffic'))),
            const Divider(),
            SwitchListTile.adaptive(value: overwrite, activeColor: const Color(0xFFE84C4C), onChanged: (v) => setState(() => overwrite = v), title: const Text('جایگزینی فایل‌های موجود', style: TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold)), subtitle: const Text('خاموش = Merge امن و مناسب ادغام چند گوشی', style: TextStyle(fontFamily: 'Traffic'))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف', style: TextStyle(fontFamily: 'Traffic'))),
        FilledButton(onPressed: () => Navigator.pop(context, _RestoreChoices(files: files, appState: appState, overwrite: overwrite)), child: Text(overwrite ? 'Restore' : 'Merge', style: const TextStyle(fontFamily: 'Traffic'))),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoCard({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E6FF)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1565C0), size: 30),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF172554))),
                const SizedBox(height: 6),
                Text(text, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Traffic', height: 1.8, color: Color(0xFF475569), fontSize: 13)),
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
        Icon(icon, size: 21, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF172554))),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(17)),
                child: Icon(icon, color: const Color(0xFF1565C0), size: 29),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Traffic', fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF172554))),
                    const SizedBox(height: 4),
                    Text(subtitle, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Traffic', fontSize: 12.5, color: Color(0xFF707789))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF9AA1AD)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final List<Widget> children;
  const _SettingsPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }
}

class _LastBackupCard extends StatelessWidget {
  final String path;
  final DateTime? time;
  const _LastBackupCard({required this.path, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF22B965)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('آخرین Backup ثبت‌شده', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Traffic', fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(path, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: Color(0xFF707789))),
                if (time != null) Text(time!.toLocal().toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF707789))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
