import 'package:flutter/material.dart';
import '../models/customer_data.dart';
import '../app_enum.dart';
import 'issue_camera_page.dart';

class IssueCustomerInfoPage extends StatefulWidget {
  final String category;

  const IssueCustomerInfoPage({
    super.key,
    required this.category,
  });

  @override
  State<IssueCustomerInfoPage> createState() => _IssueCustomerInfoPageState();
}

class _IssueCustomerInfoPageState extends State<IssueCustomerInfoPage> {
  final TextEditingController fullNameController = TextEditingController();
  static const primaryBlue = Color(0xFF1565C0);

  List<CardType> _cardsForCategory() {
    switch (widget.category) {
      case 'منزلت':
        return [
          CardType.national,
          CardType.manzelat,
          CardType.personalPhoto,
        ];
      case 'جانبازان':
        return [
          CardType.veteranCard,
          CardType.national,
          CardType.shenasnameh,
          CardType.personalPhoto,
        ];
      case 'شهدا':
        return [
          CardType.national,
          CardType.martyrCard,
          CardType.personalPhoto,
        ];
      case 'بهزیستی':
        return [
          CardType.national,
          CardType.behzistiCard,
          CardType.personalPhoto,
        ];
      case 'دانشجویی و دانش‌آموزی':
      default:
        return [
          CardType.national,
          CardType.studentcard,
          CardType.personalPhoto,
        ];
    }
  }

  void _startProcess() {
    final fullName = fullNameController.text.trim();

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً نام و نام خانوادگی را وارد کنید.',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'Traffic', fontSize: 15),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final customer = CustomerData(
      fullName: fullName,
      cards: _cardsForCategory(),
      operationType: OperationType.issue,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueCameraPage(
          customer: customer,
          category: widget.category,
        ),
      ),
    );
  }

  @override
  void dispose() {
    fullNameController.dispose();
    super.dispose();
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
                  colors: [Color(0xFF0D47B5), Color(0xFF1976D2)],
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
                  Text(
                    'نام و نام خانوادگی مشتری را وارد کنید',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Traffic',
                      fontSize: 17,
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'نام مشتری',
                                        textDirection: TextDirection.rtl,
                                        style: const TextStyle(
                                          color: Color(0xFF172554),
                                          fontFamily: 'Traffic',
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
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
                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _startProcess,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text(
                          'شروع',
                          style: TextStyle(
                            fontFamily: 'Traffic',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مدارک موردنیاز',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: Color(0xFF172554),
                              fontFamily: 'Traffic',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._cardsForCategory().map(
                            (card) => Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                '• ${_cardName(card)}',
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontFamily: 'Traffic',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cardName(CardType card) {
    switch (card) {
      case CardType.national:
        return 'اصل کارت ملی';
      case CardType.manzelat:
        return 'کارت منزلت';
      case CardType.studentcard:
        return 'کارت دانشجویی اعتبار دار استان تهران';
      case CardType.veteranCard:
        return 'کارت جانبازی استان تهران';
      case CardType.shenasnameh:
        return 'اصل شناسنامه (صفحه دوم یا سوم)';
      case CardType.martyrCard:
        return 'کارت بنیاد شهید استان تهران';
      case CardType.behzistiCard:
        return 'کارت بهزیستی استان تهران';
      case CardType.personalPhoto:
        return 'عکس پرسنلی';
      case CardType.ticket:
        return 'کارت بلیت';
    }
  }
}

