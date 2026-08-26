import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../reminder_status.dart';
import '../services/customer_status_service.dart';
import '../services/file_manager_service.dart';
import '../services/search_service.dart';
import 'file_manager_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const primaryBlue = Color(0xFF1565C0);
  static const background = Color(0xFFFAFBFF);
  static const darkText = Color(0xFF151A2B);
  static const secondaryText = Color(0xFF707789);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchResult> _results = const [];
  bool _loading = false;
  String _lastQuery = '';
  int _requestId = 0;

  // وضعیت یادآور (قرمز/زرد/سبز) هر مشتری، همان چیزی که صفحه‌ی مدیریت
  // فایل نشان می‌دهد؛ قبلاً این‌جا اصلاً بارگذاری نمی‌شد و نتیجه‌ی جستجو
  // هیچ نقطه‌ی رنگی‌ای نداشت.
  Set<String> sentKeys = {};
  Set<String> receiptKeys = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _loadStatusKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _loadStatusKeys() async {
    final sent = await CustomerStatusService.getSentKeys();
    final receipts = await CustomerStatusService.getReceiptKeys();
    if (!mounted) return;
    setState(() {
      sentKeys = sent;
      receiptKeys = receipts;
    });
  }

  ReminderStatus _statusFor(SearchResult result) {
    return CustomerStatusService.statusFor(
      result.path,
      sentKeys: sentKeys,
      receiptKeys: receiptKeys,
    );
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;
    final request = ++_requestId;

    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _runSearch(query, request);
  }

  Future<void> _runSearch(String query, int request) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || request != _requestId) return;

    final results = await SearchService.search(query);
    if (!mounted || request != _requestId) return;

    setState(() {
      _results = results;
      _loading = false;
    });
  }

  /// دوباره همان جستجوی آخر را اجرا می‌کند؛ بعد از رنیم/حذف/زیپ لازم است
  /// تا لیست نتایج با وضعیت جدید فایل‌ها هماهنگ بماند.
  Future<void> _refreshResults() async {
    await _loadStatusKeys();
    if (_lastQuery.isEmpty) return;
    final request = ++_requestId;
    final results = await SearchService.search(_lastQuery);
    if (!mounted || request != _requestId) return;
    setState(() => _results = results);
  }

  Future<void> _openResult(SearchResult result) async {
    if (result.isDirectory) {
      // درست مثل جستجوی داخل پوشه‌ها (صفحه‌ی مدیریت فایل): باز کردن یک
      // نتیجه‌ی پوشه، مستقیماً محتوای همان پوشه‌ی مشتری را نشان می‌دهد.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FolderContentsPage(folder: Directory(result.path)),
        ),
      );
      return;
    }

    final openResult = await OpenFilex.open(result.path);
    if (openResult.type != ResultType.done) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'برنامه‌ای برای باز کردن این فایل پیدا نشد: ${openResult.message}',
          ),
        ),
      );
    }
  }

  // ------------------------------- اکشن‌های پوشه -------------------------------

  Future<void> _renameFolder(SearchResult result) async {
    final folder = Directory(result.path);
    final oldName = FileManagerService.displayName(folder);
    final input = await _askForName(title: 'تغییر نام پوشه', initialValue: oldName);

    if (input == null || input.trim().isEmpty || input.trim() == oldName) return;

    try {
      final renamedFolder =
          await FileManagerService.rename(folder, input.trim()) as Directory;
      final newName = FileManagerService.displayName(renamedFolder);

      await CustomerStatusService.transfer(folder.path, renamedFolder.path);

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
      await _refreshResults();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در تغییر نام: $e')));
    }
  }

  Future<void> _zipFolder(SearchResult result) async {
    final folder = Directory(result.path);
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
      await _refreshResults();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ساخت ZIP با خطا مواجه شد: $e')));
    }
  }

  Future<void> _deleteFolder(SearchResult result) async {
    final folder = Directory(result.path);
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
      await _refreshResults();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در حذف: $e')));
    }
  }

  Future<void> _shareFolder(SearchResult result) async {
    final folder = Directory(result.path);
    final files = FileManagerService.getFilesInFolder(folder);

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('این پوشه فایلی برای اشتراک‌گذاری ندارد.')),
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
        const SnackBar(content: Text('اشتراک‌گذاری لغو شد و وضعیت مشتری تغییر نکرد.')),
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

  Future<void> _renameZip(SearchResult result) async {
    final zip = File(result.path);
    final currentName = FileManagerService.displayName(zip);
    final input = await _askForName(title: 'تغییر نام ZIP', initialValue: currentName);

    if (input == null || input.trim().isEmpty || input.trim() == currentName) return;

    try {
      final renamedZip = await FileManagerService.rename(zip, input.trim()) as File;
      await CustomerStatusService.transfer(zip.path, renamedZip.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام فایل با موفقیت تغییر کرد.')),
      );
      await _refreshResults();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در تغییر نام: $e')));
    }
  }

  Future<void> _deleteZip(SearchResult result) async {
    final zip = File(result.path);
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('فایل حذف شد.')));
      await _refreshResults();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در حذف: $e')));
    }
  }

  Future<void> _shareZip(SearchResult result) async {
    final zip = File(result.path);
    final shareResult = await Share.shareXFiles(
      [XFile(zip.path)],
      subject: FileManagerService.displayName(zip),
    );

    if (shareResult.status != ShareResultStatus.success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اشتراک‌گذاری لغو شد و وضعیت مشتری تغییر نکرد.')),
      );
      return;
    }

    await CustomerStatusService.markSent(zip.path);

    if (!mounted) return;
    setState(() {
      sentKeys.add(CustomerStatusService.keyForPath(zip.path));
    });
  }

  // ---------------------------- سبز کردن دستی (سه‌نقطه) ----------------------------

  /// دیالوگ گرفتن «دلیل» برای سبز کردن دستی؛ متن خالی مجاز نیست چون این
  /// دلیل قرار است به نام فایل اضافه شود.
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                title,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Traffic',
                  color: darkText,
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
                  hintStyle: const TextStyle(fontFamily: 'Traffic', color: Color(0xFF9AA0AD)),
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
                    borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('انصراف', style: TextStyle(fontFamily: 'Traffic')),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () => Navigator.pop(dialogContext, controller.text.trim())
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('سبز کردن', style: TextStyle(fontFamily: 'Traffic')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// سبز کردن دستی «به هر دلیل» — دلیل به‌عنوان ادامه‌ی نام پوشه/فایل اضافه
  /// می‌شود تا بعداً هم معلوم باشد چرا بدون رسید سبز شده، و کار سرپرست/ارسال
  /// روی این مشتری گیر نکند.
  Future<void> _markGreenWithReason(SearchResult result) async {
    final title = result.isDirectory ? 'سبز کردن پوشه به دلیل خاص' : 'سبز کردن ZIP به دلیل خاص';
    final reason = await _askForReason(title: title);
    if (reason == null || reason.isEmpty) return;

    try {
      if (result.isDirectory) {
        final folder = Directory(result.path);
        final oldName = FileManagerService.displayName(folder);
        final newName = '$oldName - $reason';

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
      } else {
        final zip = File(result.path);
        final oldName = FileManagerService.displayName(zip);
        final newName = '$oldName - $reason';

        final renamedZip = await FileManagerService.rename(zip, newName) as File;
        await CustomerStatusService.transfer(zip.path, renamedZip.path);
        await CustomerStatusService.markReceiptReceived(renamedZip.path);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سبز شد و دلیل به نام آن اضافه شد.')),
      );
      await _refreshResults();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در سبز کردن: $e')));
    }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              color: darkText,
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
              hintStyle: const TextStyle(fontFamily: 'Traffic', color: Color(0xFF9AA0AD)),
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
                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف', style: TextStyle(fontFamily: 'Traffic')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('تایید', style: TextStyle(fontFamily: 'Traffic')),
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              color: darkText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Traffic', color: secondaryText, fontSize: 14),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف', style: TextStyle(fontFamily: 'Traffic')),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: danger ? const Color(0xFFE84C4C) : primaryBlue,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel, style: const TextStyle(fontFamily: 'Traffic')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'جستجوی مشتری',
          style: TextStyle(
            fontFamily: 'Traffic',
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textDirection: TextDirection.rtl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'نام مشتری را وارد کنید',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.search_rounded, color: primaryBlue),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _controller.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE1E6EF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE1E6EF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: primaryBlue, width: 1.4),
                ),
              ),
              style: const TextStyle(fontFamily: 'Traffic', fontSize: 17),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: primaryBlue,
              backgroundColor: Color(0xFFEAF2FF),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.text.trim().isEmpty) {
      return const _EmptyState(
        icon: Icons.manage_search_rounded,
        title: 'جستجوی سریع مشتری',
        subtitle: 'فقط نام مشتری جستجو می‌شود و نتیجه شامل پوشه مشتری و ZIP آن است.',
      );
    }

    if (!_loading && _results.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'مشتری پیدا نشد',
        subtitle: 'نام دیگری را امتحان کنید.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (_, index) {
        final result = _results[index];
        return _ResultTile(
          result: result,
          status: _statusFor(result),
          onTap: () => _openResult(result),
          menu: _buildMenuFor(result),
        );
      },
    );
  }

  /// درست مثل صفحه‌ی مدیریت فایل: پوشه‌ی مشتری منوی «باز کردن / تغییر
  /// نام / زیپ کردن / اشتراک‌گذاری / حذف» دارد و فایل ZIP منوی «تغییر
  /// نام / اشتراک‌گذاری / حذف».
  Widget _buildMenuFor(SearchResult result) {
    final isDirectory = result.isDirectory;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF6B7280)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        switch (value) {
          case 'open':
            _openResult(result);
            break;
          case 'rename':
            isDirectory ? _renameFolder(result) : _renameZip(result);
            break;
          case 'zip':
            _zipFolder(result);
            break;
          case 'share':
            isDirectory ? _shareFolder(result) : _shareZip(result);
            break;
          case 'greenReason':
            _markGreenWithReason(result);
            break;
          case 'delete':
            isDirectory ? _deleteFolder(result) : _deleteZip(result);
            break;
        }
      },
      itemBuilder: (context) => [
        if (isDirectory) const PopupMenuItem(value: 'open', child: Text('باز کردن')),
        const PopupMenuItem(value: 'rename', child: Text('تغییر نام')),
        if (isDirectory) const PopupMenuItem(value: 'zip', child: Text('زیپ کردن')),
        const PopupMenuItem(value: 'share', child: Text('اشتراک‌گذاری')),
        const PopupMenuItem(
          value: 'greenReason',
          child: Text('سبز کردن (با دلیل)', style: TextStyle(color: Color(0xFF2E7D32))),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('حذف', style: TextStyle(color: Color(0xFFE84C4C))),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _ResultTile extends StatelessWidget {
  final SearchResult result;
  final ReminderStatus status;
  final VoidCallback onTap;
  final Widget menu;

  const _ResultTile({
    required this.result,
    required this.status,
    required this.onTap,
    required this.menu,
  });

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

  @override
  Widget build(BuildContext context) {
    final isZip = result.type == SearchResultType.archive;
    final color = isZip ? const Color(0xFF6B7280) : const Color(0xFF1565C0);
    final icon = isZip ? Icons.folder_zip_rounded : Icons.folder_rounded;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: color, size: 28),
                    Positioned(right: 4, top: 4, child: _dot(status.dotColor)),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172554),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 12.5,
                        color: Color(0xFF707789),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              menu,
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(icon, color: const Color(0xFF1565C0), size: 43),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Traffic',
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172554),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Traffic',
                fontSize: 14,
                color: Color(0xFF707789),
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}