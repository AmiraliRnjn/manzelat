import 'package:flutter/material.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade700,

      appBar: AppBar(
        title: const Text('MiCard'),
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