import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manzelat/pages/charge_category_page.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'settings_page.dart';
import 'search_page.dart';
import 'issue_category_page.dart';
import 'file_manager_page.dart';
import '../services/work_date_service.dart';
import '../services/worker_selection_service.dart';
import '../services/storage_settings_service.dart';
import '../app_enum.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const primaryBlue = Color(0xFF1565C0);
  static const purple = Color.fromARGB(255, 128, 68, 232);
  static const green = Color.fromARGB(255, 59, 211, 122);

  Jalali? workDate;
  int currentIndex = 0;
  String? selectedWorker;

  @override
  void initState() {
    super.initState();
    _loadWorkDate();
  }

  Future<void> _loadWorkDate() async {
    final date = await WorkDateService.getWorkDate();

    if (!mounted) return;

    setState(() {
      workDate = date;
    });

    await _loadWorkerForCurrentDate();
  }

  /// نام کاربر ثبت‌شده برای تاریخ فعال فعلی را می‌خواند (اگر کسی انتخاب
  /// نشده باشد، null است و آیکون آدمک قرمز می‌ماند).
  Future<void> _loadWorkerForCurrentDate() async {
    final date = workDate ?? Jalali.now();
    final worker = await WorkerSelectionService.getWorkerForDate(date);

    if (!mounted) return;

    setState(() {
      selectedWorker = worker;
    });
  }

  Future<void> _pickWorkDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: workDate ?? Jalali.now(),
      firstDate: Jalali(1400, 1),
      lastDate: Jalali(1450, 12),
    );

    if (picked == null) return;

    await WorkDateService.setWorkDate(picked);

    if (!mounted) return;

    setState(() {
      workDate = picked;
    });

    await _loadWorkerForCurrentDate();
  }

  /// نام کاربری که امروز کار می‌کند را می‌گیرد و برای تاریخ فعال ذخیره
  /// می‌کند؛ اگر پوشه‌ی آن روز از قبل ساخته شده باشد، نامش را هم به‌روز
  /// می‌کند تا معلوم شود آن روز چه کسی کار کرده.
  Future<void> _selectWorker() async {
    final controller = TextEditingController(text: selectedWorker ?? '');

    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'کاربر امروز',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Traffic',
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Traffic'),
            decoration: InputDecoration(
              hintText: 'نام کاربری که امروز کار می‌کند',
              hintTextDirection: TextDirection.rtl,
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
                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
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
                backgroundColor: primaryBlue,
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

    final name = input?.trim();
    if (name == null || name.isEmpty) return;

    final date = workDate ?? Jalali.now();

    // نام فعلیِ پوشه (قبل از تغییر) را می‌گیریم؛ چه بار اول باشد (فقط
    // تاریخ خام) چه بار دوم به بعد (تاریخ + نام کاربر قبلی). این باید
    // قبل از ذخیره‌ی نام جدید خوانده شود.
    final oldDayFolderName =
        await WorkerSelectionService.resolveDayFolderName(date);

    await WorkerSelectionService.setWorkerForDate(date, name);
    await _renameExistingDayFolders(date, oldDayFolderName);

    if (!mounted) return;

    setState(() {
      selectedWorker = name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'کاربر «$name» برای این تاریخ ثبت شد.',
          style: const TextStyle(fontFamily: 'Traffic'),
        ),
      ),
    );
  }

  /// اگر پوشه‌ی روز (شارژ و/یا صدور) از قبل با نام قدیمی ساخته شده باشد
  /// (چه فقط تاریخ خام، چه تاریخ+نام کاربر قبلی)، همین الان آن را با نام
  /// جدید (تاریخ+نام کاربر تازه) تغییر نام می‌دهد تا مشتری‌های قبل و بعد
  /// از تغییر کاربر، همگی در یک پوشه بمانند. [oldDayName] باید نام پوشه‌ی
  /// روز قبل از ذخیره‌ی نام کاربر جدید باشد (نه لزوماً نام خام تاریخ)،
  /// وگرنه رنیم‌های بعد از اولین بار اثر نمی‌کنند.
  Future<void> _renameExistingDayFolders(Jalali date, String oldDayName) async {
    final rootPath = await StorageSettingsService.getStoragePath();
    if (rootPath == null || rootPath.trim().isEmpty) return;

    final newDayName = await WorkerSelectionService.resolveDayFolderName(
      date,
    );

    if (newDayName == oldDayName) return;

    for (final operationFolderName in ['شارژ', 'صدور']) {
      final parentPath = [
        rootPath,
        operationFolderName,
        date.year.toString(),
        date.month.toString().padLeft(2, '0'),
      ].join(Platform.pathSeparator);

      final oldDir = Directory(
        [parentPath, oldDayName].join(Platform.pathSeparator),
      );
      final newDir = Directory(
        [parentPath, newDayName].join(Platform.pathSeparator),
      );

      if (await oldDir.exists() && !await newDir.exists()) {
        try {
          await oldDir.rename(newDir.path);
        } catch (_) {
          // اگر تغییر نام با خطا مواجه شود، پوشه با نام قبلی باقی می‌ماند
          // و همچنان قابل استفاده است؛ فقط نام کاربر کنارش نوشته نشده.
        }
      }
    }
  }

  bool _isToday() {
    if (workDate == null) return true;

    final today = Jalali.now();

    return workDate!.year == today.year &&
        workDate!.month == today.month &&
        workDate!.day == today.day;
  }

  void _openCharge() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChargeCategoryPage(),
      ),
    );
  }

  void _openIssue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const IssueCategoryPage(),
      ),
    );
  }

  void _openChargeFolders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FileManagerPage(
          operationType: OperationType.charge,
        ),
      ),
    );
  }

  void _openIssueFolders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FileManagerPage(
          operationType: OperationType.issue,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF0D47B5),
            Color(0xFF1976D2),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // دایره‌های خیلی کم‌رنگ برای ظاهر مدرن‌تر هدر
          Positioned(
            top: -48,
            left: -35,
            child: Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.055),
              ),
            ),
          ),
          Positioned(
            bottom: -62,
            right: -25,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.045),
              ),
            ),
          ),

          // عنوان دقیقاً وسط هدر
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'متروا',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Traffic',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'سلام در خدمت هستم 👋',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Traffic',
                  fontSize: 21,
                ),
              ),
            ],
          ),

          // آیکون آدمک در گوشه بالای سمت چپ: کاربر ثبت‌کننده‌ی امروز را
          // مشخص می‌کند. تا وقتی کسی انتخاب نشده قرمز است.
          Positioned(
            top: 0,
            left: 0,
            child: Tooltip(
              message: selectedWorker == null
                  ? 'کاربر امروز هنوز انتخاب نشده'
                  : 'کاربر امروز: $selectedWorker',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _selectWorker,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selectedWorker == null
                          ? Colors.red.withOpacity(0.78)
                          : Colors.white.withOpacity(0.16),
                      border: Border.all(
                        color: selectedWorker == null
                            ? Colors.red
                            : Colors.white.withOpacity(0.24),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // دکمه جستجو در گوشه بالای سمت راست
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openSearch,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.24),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDateCard() {
    final isToday = _isToday();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Material(
        color: Colors.white,
        elevation: 5,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _pickWorkDate,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F6FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: primaryBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      const Text(
                        'تاریخ فعال',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontFamily: 'Traffic',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        workDate != null
                            ? workDate!.formatFullDate()
                            : 'تاریخی انتخاب نشده است',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Traffic',
                          fontSize: 14,
                        ),
                      ),

                      // هشدار تاریخ غیرامروز
                      if (workDate != null && !isToday) ...[
                        const SizedBox(height: 9),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFFD98A),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            textDirection: TextDirection.rtl,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFFD97706),
                                size: 17,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'تاریخ انتخاب‌شده، تاریخ امروز نیست',
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    color: Color(0xFFB45309),
                                    fontFamily: 'Traffic',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 15),
                  child: Icon(
                    Icons.edit_calendar_outlined,
                    color: primaryBlue,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  color.withOpacity(0.88),
                  color,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 46,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Traffic',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Traffic',
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFolderTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 31,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Color(0xFF172554),
                        fontFamily: 'Traffic',
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'مشاهده فایل‌های ذخیره شده',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Traffic',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B7280),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Column(
                  children: [
                    // کارت تاریخ دیگر با Transform روی هدر قرار نمی‌گیرد.
                    // بنابراین با بزرگ شدن متن هشدار، صفحه به هم نمی‌ریزد.
                    _buildActiveDateCard(),
              
                    const SizedBox(height: 14),

                    

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              _buildMainAction(
                                title: 'شارژ',
                                subtitle: 'شارژ کارت‌ها',
                                icon: Icons.bolt_rounded,
                                color: purple,
                                onTap: _openCharge,
                              ),
                              const SizedBox(width: 14),
                              _buildMainAction(
                                title: 'صدور',
                                subtitle: 'صدور کارت‌ها',
                                icon: Icons.description_rounded,
                                color: green,
                                onTap: _openIssue,
                              ),
                            ],
                          ),
              
                          const SizedBox(height: 15),
              
                          const Text(
                            'پوشه‌ها',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: Color(0xFF172554),
                              fontFamily: 'Traffic',
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
              
                          const SizedBox(height: 5),
              
                          _buildFolderTile(
                            title: 'پوشه‌های شارژ',
                            icon: Icons.folder_rounded,
                            color: purple,
                            onTap: _openChargeFolders,
                          ),
              
                          const SizedBox(height: 12),
              
                          _buildFolderTile(
                            title: 'پوشه‌های صدور',
                            icon: Icons.folder_rounded,
                            color: green,
                            onTap: _openIssueFolders,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedItemColor: primaryBlue,
        unselectedItemColor: const Color(0xFF6B7280),
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Traffic',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Traffic',
          fontSize: 14,
        ),
        onTap: (index) {
          if (index == 0) {
            setState(() {
              currentIndex = 0;
            });
          } else {
            setState(() {
              currentIndex = 1;
            });
            _openSettings();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'خانه',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'تنظیمات',
          ),
        ],
      ),
    );
  }
}
