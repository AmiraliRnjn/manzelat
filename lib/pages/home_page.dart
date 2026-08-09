import 'package:flutter/material.dart';
import 'package:manzelat/operation_type.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'settings_page.dart';
import 'customer_info_page.dart';
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

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);
    const lightBlue = Color(0xFF42A5F5);

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('MiCard' ,style: TextStyle(color: Colors.white),),
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
              title: const Text('مدیریت',style: TextStyle(fontFamily: 'Traffic'),),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // کارت تاریخ
              if (workDate != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 30),
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
                ),

              const Spacer(),

              // دکمه شارژ
              _buildMainButton(
                text: 'شارژ',
                onTap: () {
                  Navigator.pushNamed(context, '/first');
                },
                primaryBlue: primaryBlue,
                lightBlue: lightBlue,
              ),

              const SizedBox(height: 20),

              // دکمه صدور
              _buildMainButton(
                text: 'صدور',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerInfoPage(
                        mode: Mode.export,
                        operationType: OperationType.issue,
                      ),
                    ),
                  );
                },
                primaryBlue: primaryBlue,
                lightBlue: lightBlue,
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton({
    required String text,
    required VoidCallback onTap,
    required Color primaryBlue,
    required Color lightBlue,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: [primaryBlue, lightBlue]),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Traffic',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
