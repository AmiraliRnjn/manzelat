import 'dart:io';
import 'package:flutter/material.dart';
import '../app_enum.dart';
import '../reminder_status.dart';
import '../services/customer_status_service.dart';
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
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _purple = Color.fromARGB(255, 128, 68, 232);
  static const Color _pageBackground = Color(0xFFFAFBFF);
  static const Color _darkText = Color(0xFF172554);
  static const Color _secondaryText = Color(0xFF707789);

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<Directory> _chargeFolders = [];
  List<Directory> _issueFolders = [];
  Set<String> _sentKeys = {};
  Set<String> _receiptKeys = {};
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
    final charge =
        await FileManagerService.getCustomerFolders(OperationType.charge);
    final issue =
        await FileManagerService.getCustomerFolders(OperationType.issue);
    final sent = await CustomerStatusService.getSentKeys();
    final receipts = await CustomerStatusService.getReceiptKeys();

    if (!mounted) return;

    setState(() {
      _chargeFolders = charge;
      _issueFolders = issue;
      _sentKeys = sent;
      _receiptKeys = receipts;
      _isLoading = false;
    });
  }

  ReminderStatus _statusFor(Directory folder) {
    return CustomerStatusService.statusFor(
      folder.path,
      sentKeys: _sentKeys,
      receiptKeys: _receiptKeys,
    );
  }

  List<Directory> _filtered(List<Directory> folders) {
    if (_query.isEmpty) return folders;

    return folders
        .where(
          (f) => FileManagerService.displayName(f).contains(_query),
        )
        .toList();
  }

  /// فقط برای پوشه‌ی قرمز (ارسال‌نشده) هشدار نمایش داده می‌شود.
  /// پوشه‌ی زرد (ارسال شده و منتظر رسید) بدون هشدار ثبت می‌شود.
  /// پوشه‌ی سبز نیز مثل قبل بدون هشدار ثبت می‌شود.
  Future<void> _selectCustomer(Directory folder) async {
    final name = FileManagerService.displayName(folder);
    final status = _statusFor(folder);

    // فقط وضعیت قرمز باید هشدار داشته باشد.
    final needsWarning = status == ReminderStatus.notSent;

    final warningColor = const Color(0xFFDC2626);
    final warningBg = const Color(0xFFFEF2F2);
    const warningText =
        'این پوشه هنوز قرمز است؛ یعنی اصلاً برای سرپرست ارسال نشده.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'تأیید ثبت رسید',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Traffic',
              color: _darkText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needsWarning) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: warningBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: warningColor,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          warningText,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'Traffic',
                            color: warningColor,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                needsWarning
                    ? 'با این حال، رسید دریافتی برای «$name» ثبت شود؟'
                    : 'رسید دریافتی برای «$name» ثبت شود؟',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Traffic',
                  color: _secondaryText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
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
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    needsWarning ? warningColor : _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                needsWarning ? 'بله، مطمئنم' : 'ثبت رسید',
                style: const TextStyle(fontFamily: 'Traffic'),
              ),
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
        SnackBar(
          content: Text(
            'رسید «$name» با موفقیت ثبت شد.',
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              fontSize: 15,
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خطا در ثبت رسید: $e',
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              fontSize: 15,
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
  }) {
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
              child: Icon(
                icon,
                color: _primaryBlue,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
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

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildFolderCard(Directory folder) {
    final fileCount =
        FileManagerService.getFilesInFolder(folder).length;
    final status = _statusFor(folder);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isSaving
              ? null
              : () => _selectCustomer(folder),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.folder_rounded,
                        color: _purple,
                      ),
                      Positioned(
                        right: -2,
                        top: -2,
                        child: _dot(status.dotColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        FileManagerService.displayName(folder),
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _darkText,
                          fontFamily: 'Traffic',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$fileCount فایل',
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
                const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFFC7CBD4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Directory> folders) {
    final filtered = _filtered(folders);

    if (folders.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) =>
          _buildFolderCard(filtered[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.receiptImagePaths.length;
    final title = count > 1 ? 'ثبت $count رسید' : 'ثبت رسید';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context)
              .textTheme
              .apply(fontFamily: 'Traffic'),
        ),
        child: Scaffold(
          backgroundColor: _pageBackground,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    // هدر گرادیانی هماهنگ با بقیه‌ی صفحات برنامه
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(
                        22,
                        22,
                        22,
                        24,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            Color(0xFF0D47C9),
                            Color(0xFF1976E8),
                          ],
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
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Traffic',
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'مشتری مقصد را انتخاب کنید',
                                  textDirection: TextDirection.rtl,
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

                    // کارت سفید تب‌ها، دقیقاً روی هدر شناور می‌شود
                    Transform.translate(
                      offset: const Offset(0, -8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        child: Material(
                          color: Colors.white,
                          elevation: 4,
                          shadowColor: Colors.black12,
                          borderRadius: BorderRadius.circular(20),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: _primaryBlue,
                            unselectedLabelColor: _secondaryText,
                            indicatorColor: _primaryBlue,
                            indicatorSize:
                                TabBarIndicatorSize.label,
                            indicatorWeight: 3,
                            dividerColor: Colors.transparent,
                            labelStyle: const TextStyle(
                              fontFamily: 'Traffic',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            unselectedLabelStyle:
                                const TextStyle(
                              fontFamily: 'Traffic',
                              fontSize: 15,
                            ),
                            tabs: const [
                              Tab(
                                height: 52,
                                text: 'شارژ',
                              ),
                              Tab(
                                height: 52,
                                text: 'صدور',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        10,
                      ),
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
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(17),
                            borderSide: const BorderSide(
                              color: Color(0xFFE3E6EC),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(17),
                            borderSide: const BorderSide(
                              color: Color(0xFFE3E6EC),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(17),
                            borderSide: const BorderSide(
                              color: _primaryBlue,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: _primaryBlue,
                              ),
                            )
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
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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