import 'package:flutter/material.dart';

import 'customer_info_page.dart';
import '../mode.dart';
import '../operation_type.dart';

class ChargePage extends StatelessWidget {
  const ChargePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 120, 143),

      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // مدارک دارد
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerInfoPage(
                        mode: Mode.optional,
                        operationType: OperationType.charge,
                      ),
                    ),
                  );
                },

                style: TextButton.styleFrom(
                  backgroundColor: Colors.lightGreenAccent.shade100,
                ),

                child: const Text(
                  'مدارک دارد (فقط کارت بلیط)',
                ),
              ),

              const SizedBox(height: 15),

              // کارت ملی ندارد
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerInfoPage(
                        mode: Mode.noNational,
                        operationType: OperationType.charge,
                      ),
                    ),
                  );
                },

                style: TextButton.styleFrom(
                  backgroundColor: Colors.lightBlueAccent.shade100,
                ),

                child: const Text(
                  'کارت ملی ندارد',
                ),
              ),

              const SizedBox(height: 15),

              // کارت منزلت ندارد
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerInfoPage(
                        mode: Mode.noManzelat,
                        operationType: OperationType.charge,
                      ),
                    ),
                  );
                },

                style: TextButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),

                child: const Text(
                  'کارت منزلت ندارد',
                ),
              ),

              const SizedBox(height: 15),

              // هیچ مدرکی ندارد
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerInfoPage(
                        mode: Mode.all,
                        operationType: OperationType.charge,
                      ),
                    ),
                  );
                },

                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                ),

                child: const Text(
                  'مدارک ندارد (هر سه مدرک)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}