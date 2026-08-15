import 'package:flutter/material.dart';
import 'camera_page.dart';
import '../card_type.dart';
import '../mode.dart';
import '../operation_type.dart';
import '../models/customer_data.dart';

class CustomerInfoPage extends StatefulWidget {
  final Mode mode;
  final OperationType operationType;

  const CustomerInfoPage({
    super.key,
    required this.mode,
    required this.operationType,
  });

  @override
  State<CustomerInfoPage> createState() => _CustomerInfoPageState();
}

class _CustomerInfoPageState extends State<CustomerInfoPage> {
  final TextEditingController fullNameController = TextEditingController();

  static const primaryBlue = Color(0xFF1565C0);

  void _startProcess() {
    final fullName = fullNameController.text.trim();

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً نام و نام خانوادگی را وارد کنید.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Traffic',
              fontSize: 15,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final customer = CustomerData(
      fullName: fullName,
      cards: [],
      operationType: widget.operationType,
    );

    switch (widget.mode) {
      case Mode.optional:
        customer.cards = [CardType.ticket];
        break;

      case Mode.noNational:
        customer.cards = [
          CardType.ticket,
          CardType.national,
          CardType.personalPhoto,
        ];
        break;

      case Mode.noManzelat:
        customer.cards = [
          CardType.ticket,
          CardType.manzelat,
          CardType.personalPhoto,
        ];
        break;

      case Mode.shohada:
        customer.cards = [
          CardType.national,
          CardType.personalPhoto,
        ];
        break;

      case Mode.all:
        customer.cards = [
          CardType.ticket,
          CardType.national,
          CardType.manzelat,
          CardType.personalPhoto,
        ];
        break;

      case Mode.export:
        customer.cards.add(CardType.national);
        customer.cards.add(CardType.manzelat);
        customer.cards.add(CardType.personalPhoto);
        break;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPage(customer: customer),
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
            // Header
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
                    'اطلاعات مشتری',
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
                    'نام و نام خانوادگی مشتری را وارد کنید',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main input card
                    Material(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.black12,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF2FF),
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: primaryBlue,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'نام مشتری',
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          color: Color(0xFF172554),
                                          fontFamily: 'Traffic',
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'اطلاعات را با دقت وارد کنید',
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontFamily: 'Traffic',
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            TextField(
                              controller: fullNameController,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _startProcess(),
                              decoration: InputDecoration(
                                labelText: 'نام و نام خانوادگی',
                                hintText: 'مثال: علی رضایی',
                                prefixIcon: const Icon(
                                  Icons.badge_outlined,
                                  color: primaryBlue,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFF),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  borderSide: const BorderSide(
                                    color: primaryBlue,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Information hint
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        textDirection: TextDirection.rtl,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: primaryBlue,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'پس از ثبت نام، مدارک موردنیاز این مشتری برای عکاسی نمایش داده می‌شود.',
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFF334155),
                                fontFamily: 'Traffic',
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _startProcess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: primaryBlue.withOpacity(0.25),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          textDirection: TextDirection.rtl,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'شروع',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Traffic',
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    fullNameController.dispose();
    super.dispose();
  }
}
