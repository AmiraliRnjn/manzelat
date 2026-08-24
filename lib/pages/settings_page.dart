import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../services/storage_settings_service.dart';
import '../services/permission_service.dart';
import '../services/storage_picker_service.dart';
import '../services/work_date_service.dart';
import '../services/backup_service.dart';
import 'backup_page.dart';
import 'home_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color darkText = Color(0xFF20263A);
  static const Color secondaryText = Color(0xFF707789);

  final TextEditingController pathController = TextEditingController();

  bool isLoading = true;
  bool hasPermission = false;
  Jalali? workDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStatus();
    }
  }

  Future<void> _refreshPermissionStatus() async {
    final permission = await PermissionService.hasStoragePermission();

    if (!mounted) return;

    setState(() {
      hasPermission = permission;
    });
  }

  Future<void> _loadData() async {
    final path = await StorageSettingsService.getStoragePath();
    final permission = await PermissionService.hasStoragePermission();
    final date = await WorkDateService.getWorkDate();

    if (!mounted) return;

    setState(() {
      pathController.text = path ?? '';
      hasPermission = permission;
      workDate = date;
      isLoading = false;
    });
  }

  Future<void> _requestPermission() async {
    final granted = await PermissionService.requestStoragePermission();

    if (!mounted) return;

    setState(() {
      hasPermission = granted;
    });

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'مجوز داده نشد. برای فعال کردن دستی به تنظیمات اپ بروید.',
            style: TextStyle(fontFamily: 'Traffic'),
          ),
        ),
      );
    }
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

  Future<void> _pickFolder() async {
    final selectedPath =
        await StoragePickerService.pickStorageFolder(context);

    if (selectedPath == null) return;

    if (!mounted) return;

    setState(() {
      pathController.text = selectedPath;
    });
  }

  Future<void> _saveStoragePath() async {
    final path = pathController.text.trim();

    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً یک مسیر معتبر وارد کنید.',
            style: TextStyle(fontFamily: 'Traffic'),
          ),
        ),
      );
      return;
    }

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ابتدا باید مجوز دسترسی به حافظه را فعال کنید.',
            style: TextStyle(fontFamily: 'Traffic'),
          ),
        ),
      );
      return;
    }

    await StorageSettingsService.setStoragePath(path);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'مسیر ذخیره‌سازی با موفقیت ذخیره شد.',
          style: TextStyle(fontFamily: 'Traffic'),
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFC),

        // هدر آبی مشابه صفحه اصلی
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(
                      'تنظیمات',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Traffic',
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'مدیریت تنظیمات برنامه',
                      style: TextStyle(
                        color: Color(0xFFE4EEFF),
                        fontFamily: 'Traffic',
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: primaryBlue,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionTitle(
                              title: 'دسترسی',
                              icon: Icons.security_outlined,
                            ),
                            const SizedBox(height: 12),

                            _SettingsCard(
                              icon: hasPermission
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              iconColor: hasPermission
                                  ? const Color(0xFF22B965)
                                  : const Color(0xFFE84C4C),
                              iconBackground: hasPermission
                                  ? const Color(0xFFE9F8F0)
                                  : const Color(0xFFFDECEC),
                              title: 'مجوز دسترسی به حافظه',
                              subtitle: hasPermission
                                  ? 'مجوز دسترسی فعال است.'
                                  : 'مجوز هنوز فعال نشده است.',
                              trailing: hasPermission
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Color(0xFF22B965),
                                    )
                                  : TextButton(
                                      onPressed: _requestPermission,
                                      child: const Text(
                                        'فعال‌سازی',
                                        style: TextStyle(
                                          color: primaryBlue,
                                          fontFamily: 'Traffic',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),

                            if (!hasPermission) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () {
                                  PermissionService
                                      .openAllFilesAccessSettingsList();
                                },
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  color: primaryBlue,
                                ),
                                label: const Text(
                                  'باز کردن تنظیمات دسترسی',
                                  style: TextStyle(
                                    color: primaryBlue,
                                    fontFamily: 'Traffic',
                                    fontSize: 15,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize:
                                      const Size(double.infinity, 52),
                                  side: const BorderSide(
                                    color: Color(0xFFD7E3F7),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 28),
                            const _SectionTitle(
                              title: 'ذخیره‌سازی',
                              icon: Icons.folder_outlined,
                            ),
                            const SizedBox(height: 12),

                            _SettingsPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'مسیر ذخیره‌سازی',
                                    style: TextStyle(
                                      color: darkText,
                                      fontFamily: 'Traffic',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  const Text(
                                    'مسیر پوشه‌ای که فایل‌های برنامه در آن ذخیره می‌شوند.',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontFamily: 'Traffic',
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: pathController,
                                    style: const TextStyle(
                                      color: darkText,
                                      fontFamily: 'Traffic',
                                    ),
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      labelText: 'مسیر ذخیره‌سازی',
                                      hintText:
                                          '/storage/emulated/0/MiCardData',
                                      labelStyle: const TextStyle(
                                        fontFamily: 'Traffic',
                                      ),
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF9AA0AD),
                                        fontFamily: 'Traffic',
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF7F8FB),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(15),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE3E6EC),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(15),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE3E6EC),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(15),
                                        borderSide: const BorderSide(
                                          color: primaryBlue,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _pickFolder,
                                          icon: const Icon(
                                            Icons.folder_open_rounded,
                                            size: 21,
                                          ),
                                          label: const Text(
                                            'انتخاب پوشه',
                                            style: TextStyle(
                                              fontFamily: 'Traffic',
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: primaryBlue,
                                            minimumSize:
                                                const Size(double.infinity, 50),
                                            side: const BorderSide(
                                              color: Color(0xFFD7E3F7),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _saveStoragePath,
                                          icon: const Icon(
                                            Icons.save_rounded,
                                            size: 21,
                                          ),
                                          label: const Text(
                                            'ذخیره مسیر',
                                            style: TextStyle(
                                              fontFamily: 'Traffic',
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryBlue,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            minimumSize:
                                                const Size(double.infinity, 50),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),
                            const _SectionTitle(
                              title: 'اطلاعات و پشتیبان',
                              icon: Icons.cloud_sync_outlined,
                            ),
                            const SizedBox(height: 12),

                            _SettingsPanel(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF2FF),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.backup_rounded,
                                    color: primaryBlue,
                                    size: 29,
                                  ),
                                ),
                                title: const Text(
                                  'Backup و Restore',
                                  style: TextStyle(
                                    color: darkText,
                                    fontFamily: 'Traffic',
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: const Text(
                                  'نسخه پشتیبان، بازیابی و Backup خودکار',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontFamily: 'Traffic',
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: primaryBlue,
                                  size: 30,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const BackupPage(),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 28),
                            const _SectionTitle(
                              title: 'تاریخ کاری',
                              icon: Icons.calendar_month_outlined,
                            ),
                            const SizedBox(height: 12),

                            _SettingsPanel(
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF2FF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_month_outlined,
                                      color: primaryBlue,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'تاریخ فعال',
                                          style: TextStyle(
                                            color: darkText,
                                            fontFamily: 'Traffic',
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          workDate != null
                                              ? workDate!.formatFullDate()
                                              : 'هنوز تاریخی انتخاب نشده است.',
                                          style: const TextStyle(
                                            color: secondaryText,
                                            fontFamily: 'Traffic',
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _pickWorkDate,
                                    icon: const Icon(
                                      Icons.edit_calendar_outlined,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                             Container(
                              padding: EdgeInsets.only(top: 20),
                              alignment: Alignment.center,
                              child: Text('This App Build With ❤️ By Knightra',style: TextStyle(fontWeight: FontWeight.w500),),
                            )
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),

        // همان Bottom Navigation صفحه اصلی
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 58,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE9EBF0),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 18,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.home_rounded,
                    label: 'خانه',
                    selected: false,
                    onTap: _goHome,
                  ),
                ),
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.settings_rounded,
                    label: 'تنظیمات',
                    selected: true,
                    onTap: () {},
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
    WidgetsBinding.instance.removeObserver(this);
    pathController.dispose();
    super.dispose();
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF1565C0),
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF151A2B),
            fontFamily: 'Traffic',
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final Widget child;

  const _SettingsPanel({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE7E9EE),
        ),
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

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE7E9EE),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF20263A),
                    fontFamily: 'Traffic',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF707789),
                    fontFamily: 'Traffic',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const Color(0xFF1565C0) : const Color(0xFF697080);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Traffic',
              fontSize: 14,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
