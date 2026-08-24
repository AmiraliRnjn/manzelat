import 'package:flutter/material.dart';
import 'package:manzelat/pages/charge_category_page.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'settings_page.dart';
import 'search_page.dart';
import 'issue_category_page.dart';
import 'file_manager_page.dart';
import '../services/work_date_service.dart';
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
