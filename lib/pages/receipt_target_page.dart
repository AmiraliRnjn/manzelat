import 'dart:io';
import 'package:flutter/material.dart';
import '../operation_type.dart';
import '../services/file_manager_service.dart';
import '../services/receipt_service.dart';

/// وقتی سرپرست از طریق پیام‌رسان روی عکس رسید «اشتراک‌گذاری» می‌زند و این
/// اپ انتخاب می‌شود، این صفحه باز می‌شود: دو تب (شارژ/صدور)، هرکدوم لیست
/// پوشه‌های اصلی همان تاریخ کاری به‌همراه جستجو، تا مشتری مقصد انتخاب شود.
class ReceiptTargetPage extends StatefulWidget {
  final List<String> receiptImagePaths;

  const ReceiptTargetPage({super.key, required this.receiptImagePaths});

  @override
  State<ReceiptTargetPage> createState() => _ReceiptTargetPageState();
}

class _ReceiptTargetPageState extends State<ReceiptTargetPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<Directory> _chargeFolders = [];
  List<Directory> _issueFolders = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final charge = await FileManagerService.getCustomerFolders(OperationType.charge);
    final issue = await FileManagerService.getCustomerFolders(OperationType.issue);

    if (!mounted) return;
    setState(() {
      _chargeFolders = charge;
      _issueFolders = issue;
      _isLoading = false;
    });
  }

  List<Directory> _filtered(List<Directory> folders) {
    if (_query.isEmpty) return folders;
    return folders
        .where((f) => FileManagerService.displayName(f).contains(_query))
        .toList();
  }

  Future<void> _selectCustomer(Directory folder) async {
    final name = FileManagerService.displayName(folder);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأیید ثبت رسید'),
          content: Text('رسید دریافتی برای «$name» ثبت شود؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ثبت رسید'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      await ReceiptService.attachReceiptToCustomer(
        customerFolder: folder,
        sourceImagePaths: widget.receiptImagePaths,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رسید «$name» با موفقیت ثبت شد.')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ثبت رسید: $e')),
      );
    }
  }

  Widget _buildList(List<Directory> folders) {
    final filtered = _filtered(folders);

    if (filtered.isEmpty) {
      return const Center(child: Text('مشتری‌ای پیدا نشد.'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final folder = filtered[index];
        return ListTile(
          leading: const Icon(Icons.folder, color: Colors.amber),
          title: Text(FileManagerService.displayName(folder)),
          onTap: _isSaving ? null : () => _selectCustomer(folder),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.receiptImagePaths.length > 1
                ? 'انتخاب مشتری برای ثبت ${widget.receiptImagePaths.length} رسید'
                : 'انتخاب مشتری برای ثبت رسید',
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'شارژ'),
              Tab(text: 'صدور'),
            ],
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildList(_chargeFolders),
                            _buildList(_issueFolders),
                          ],
                        ),
                ),
              ],
            ),
            if (_isSaving)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}