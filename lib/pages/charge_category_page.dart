import 'package:flutter/material.dart';
import 'package:manzelat/app_enum.dart';
import 'package:manzelat/pages/charge_page.dart';
import 'package:manzelat/pages/customer_info_page.dart';

class ChargeCategoryPage extends StatelessWidget {
  const ChargeCategoryPage({super.key});

  void _onCategorySelected(BuildContext context, String category) {
    if(category=='منزلت'){
      Navigator.push(context, MaterialPageRoute(builder: (context) => ChargePage(),));
    }else if (category=='جانبازان'){
      Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerInfoPage(mode:Mode.janbaz , operationType: OperationType.charge),));
    }else if (category=='شهدا'){
      Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerInfoPage(mode:Mode.shohada , operationType: OperationType.charge),));
    }else if (category=='بهزیستی'){
      Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerInfoPage(mode:Mode.behzisti , operationType: OperationType.charge),));
    }else if (category=='دانشجویی و دانش‌آموزی'){
      Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerInfoPage(mode:Mode.daneshjo , operationType: OperationType.charge),));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      body: SafeArea(
        child: Column(
          children: [
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
                        Icons.arrow_back_rounded,
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
                    'لطفاً دسته مشتری را انتخاب کنید',
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
                  _CategoryCard(
                    title: 'منزلت',
                    subtitle: 'شارژ کارت منزلت',
                    icon: Icons.credit_card_rounded,
                    color: const Color(0xFF7E57C2),
                    onTap: () => _onCategorySelected(context, 'منزلت'),
                  ),
                  const SizedBox(height: 14),

                  _CategoryCard(
                    title: 'جانبازان',
                    subtitle: 'شارژ کارت جانبازان',
                    icon: Icons.shield_rounded,
                    color: const Color(0xFF4C8BF5),
                    onTap: () => _onCategorySelected(context, 'جانبازان'),
                  ),
                  const SizedBox(height: 14),

                  _CategoryCard(
                    title: 'شهدا',
                    subtitle: 'شارژ کارت خانواده شهدا',
                    icon: Icons.local_florist_rounded,
                    color: const Color(0xFFE85D75),
                    onTap: () => _onCategorySelected(context, 'شهدا'),
                  ),
                  const SizedBox(height: 14),

                  _CategoryCard(
                    title: 'بهزیستی',
                    subtitle: 'شارژ کارت بهزیستی',
                    icon: Icons.accessible_rounded,
                    color: const Color(0xFF35B96B),
                    onTap: () => _onCategorySelected(context, 'بهزیستی'),
                  ),
                  const SizedBox(height: 14),

                  _CategoryCard(
                    title: 'دانشجویی و دانش‌آموزی',
                    subtitle: 'شارژ کارت دانشجویی و دانش‌آموزی',
                    icon: Icons.school_rounded,
                    color: const Color(0xFFFFA62B),
                    onTap: () => _onCategorySelected(
                      context,
                      'دانشجویی و دانش‌آموزی',
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

class _CategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
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
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
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
             const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B7280),
                size: 31,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

