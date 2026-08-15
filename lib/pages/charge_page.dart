import 'package:flutter/material.dart';

import 'customer_info_page.dart';
import '../mode.dart';
import '../operation_type.dart';

class ChargePage extends StatelessWidget {
  const ChargePage({super.key});

  void _openCustomerInfo(
    BuildContext context,
    Mode mode,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerInfoPage(
          mode: mode,
          operationType: OperationType.charge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      body: SafeArea(
        child: Column(
          children: [
            // Header مشابه صفحات قبلی
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 38),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xFF0D47B5),
                    Color(0xFF1976D2),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const Text(
                    'شارژ',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Traffic',
                      fontSize: 31,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'نوع مدارک مشتری را انتخاب کنید',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Traffic',
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
                children: [
                  _ChargeOptionCard(
                    title: 'مدارک دارد',
                    subtitle: 'فقط کارت بلیت',
                    icon: Icons.credit_card_rounded,
                    color: const Color(0xFF7E57C2),
                    onTap: () => _openCustomerInfo(
                      context,
                      Mode.optional,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _ChargeOptionCard(
                    title: 'کارت ملی ندارد',
                    subtitle: 'ادامه فرایند بدون کارت ملی',
                    icon: Icons.badge_outlined,
                    color: const Color(0xFF4C8BF5),
                    onTap: () => _openCustomerInfo(
                      context,
                      Mode.noNational,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _ChargeOptionCard(
                    title: 'کارت منزلت ندارد',
                    subtitle: 'ادامه فرایند بدون کارت منزلت',
                    icon: Icons.credit_card_off_rounded,
                    color: const Color(0xFF35B96B),
                    onTap: () => _openCustomerInfo(
                      context,
                      Mode.noManzelat,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _ChargeOptionCard(
                    title: 'هیچ مدرکی ندارد',
                    subtitle: 'بدون هر سه مدرک',
                    icon: Icons.folder_off_outlined,
                    color: const Color(0xFFFFA62B),
                    onTap: () => _openCustomerInfo(
                      context,
                      Mode.all,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ChargeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF6B7280),
                size: 31,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF172554),
                        fontFamily: 'Traffic',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontFamily: 'Traffic',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
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
            ],
          ),
        ),
      ),
    );
  }
}
