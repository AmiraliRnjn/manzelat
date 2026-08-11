import 'package:flutter/material.dart';
import 'package:manzelat/operation_type.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'settings_page.dart';
import 'customer_info_page.dart';
import 'file_manager_page.dart';
import '../services/work_date_service.dart';
import '../mode.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Jalali? workDate;

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

  // چهار حالت نوبار پایین (به‌ترتیب همان چیزی که در آرایه‌ی items چیده می‌شود).
  void _handleBottomNavTap(int index) {
    switch (index) {
      case 0: // شارژ این تاریخ
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const FileManagerPage(operationType: OperationType.charge),
          ),
        );
        break;

      case 1: // شارژ
        Navigator.pushNamed(context, '/first');
        break;

      case 2: // صدور
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CustomerInfoPage(
              mode: Mode.export,
              operationType: OperationType.issue,
            ),
          ),
        );
        break;

      case 3: // صدور این تاریخ
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const FileManagerPage(operationType: OperationType.issue),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('متروا' ,style: TextStyle(color: Colors.white , fontFamily: 'Traffic',fontWeight: FontWeight.bold),),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'انتخاب تاریخ کاری',
            onPressed: _pickWorkDate,
          ),
        ],
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
              ),
              child: Text(
                'منو',
                style: TextStyle(color: Colors.white, fontSize: 22,fontFamily: 'Traffic'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: primaryBlue),
              title: const Text('تنظیمات',style: TextStyle(fontFamily: 'Traffic'),),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // کارت تاریخ
              if (workDate != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'تاریخ کاری فعال',
                        style: TextStyle(color: Colors.grey, fontSize: 14,fontFamily: 'Traffic'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        workDate!.formatFullDate(),
                        style: const TextStyle(
                          color: primaryBlue,
                          fontFamily: 'Traffic',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  'برای شروع، تاریخ کاری را از گوشه‌ی بالا انتخاب کنید.',
                  style: TextStyle(color: Colors.grey, fontFamily: 'Traffic'),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),

      // نوار پایین: شارژ/صدور (که قبلاً وسط صفحه بودند) کنار «این تاریخ»‌ها آمدند.
      // ترتیب آرایه‌ی items عمداً همین‌طور چیده شده تا با راست‌به‌چپ بودن صفحه،
      // نمایش نهایی از چپ به راست این شود:
      // صدور این تاریخ ، صدور ، شارژ ، شارژ این تاریخ
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: TextStyle(fontFamily: "Traffic" ),
        unselectedLabelStyle: TextStyle(fontFamily: "Traffic"),
        onTap: _handleBottomNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder ,size: 15,),
            label: 'شارژ این تاریخ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on,size: 30,),
            label: 'شارژ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.badge ,size: 30,),
            label: 'صدور',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder ,size: 15,),
            label: 'صدور این تاریخ',
          ),
        ],
      ),
    );
  }
}