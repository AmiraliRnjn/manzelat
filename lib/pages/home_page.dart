import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'settings_page.dart';
import '../services/work_date_service.dart';

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

    if (picked == null) {
      return;
    }

    await WorkDateService.setWorkDate(picked);

    if (!mounted) return;

    setState(() {
      workDate = picked;
    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.grey.shade700,

      appBar: AppBar(
        title: const Text('MiCard'),

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
              decoration: BoxDecoration(color: Colors.grey),
              child: Text(
                'منو',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('مدیریت'),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              if (workDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [

                      const Text(
                        'تاریخ کاری فعال:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        workDate!.formatFullDate(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    ],
                  ),
                ),

              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/first');
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
                child: const Text('شارژ'),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/second');
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
                child: const Text('صدور'),
              ),

            ],
          ),
        ),
      ),
    );
  }
}