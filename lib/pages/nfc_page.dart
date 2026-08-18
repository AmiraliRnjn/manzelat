import 'package:flutter/material.dart';

import '../models/customer_data.dart';
import '../services/native_nfc_service.dart';
import 'camera_page.dart';

class NfcPage extends StatefulWidget {
  final CustomerData customer;

  const NfcPage({
    super.key,
    required this.customer,
  });

  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> {
  final TextEditingController manualController = TextEditingController();

  bool isReadingNfc = false;
  bool manualMode = false;

  String nfcStatus = 'آماده برای خواندن کارت';

  @override
  void initState() {
    super.initState();

    NativeNfcService.setTagListener(_handleNativeNfcTag);

    // NFC را به محض ورود به صفحه شروع می‌کنیم.
    _startNfcReader();
  }

  // ============================================================
  // شروع NFC
  // ============================================================

  Future<void> _startNfcReader() async {
    if (isReadingNfc) return;

    try {
      setState(() {
        isReadingNfc = true;
        nfcStatus =
            'کارت بلیت را پشت گوشی، نزدیک قسمت NFC قرار دهید...';
      });

      await NativeNfcService.startReader();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isReadingNfc = false;
        nfcStatus = 'فعال‌سازی NFC ناموفق بود.';
      });

      _showMessage(
        'فعال‌سازی NFC ناموفق بود.\nمی‌توانید سریال را دستی وارد کنید.',
        isError: true,
      );
    }
  }

  // ============================================================
  // دریافت کارت از Android
  // ============================================================

  Future<void> _handleNativeNfcTag(dynamic arguments) async {
    if (!mounted) return;

    try {
      final map = Map<dynamic, dynamic>.from(arguments as Map);

      final uidHex = (map['uid'] ?? '').toString();
      final ticketNumber = (map['ticketNumber'] ?? '').toString();

      if (uidHex.isEmpty || ticketNumber.isEmpty) {
        throw Exception(
          'UID یا شماره بلیت از Android دریافت نشد.',
        );
      }

      // ذخیره شماره کارت در CustomerData
      widget.customer.ticketNumber = ticketNumber;

      // توقف خواندن بعد از دریافت کارت
      await _stopNfcReader();

      if (!mounted) return;

      setState(() {
        nfcStatus =
            'کارت با موفقیت شناسایی شد\n'
            'سریال: $ticketNumber';
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'کارت با موفقیت خوانده شد',
              textDirection: TextDirection.rtl,
            ),
            content: Text(
              'سریال کارت بلیت:\n$ticketNumber',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('ادامه'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      _goToCamera();
    } catch (e) {
      if (!mounted) return;

      await _stopNfcReader();

      setState(() {
        nfcStatus = 'خطا در خواندن کارت';
      });

      _showMessage(
        'خطا در دریافت اطلاعات کارت:\n$e',
        isError: true,
      );
    }
  }

  // ============================================================
  // توقف NFC
  // ============================================================

  Future<void> _stopNfcReader() async {
    try {
      await NativeNfcService.stopReader();
    } catch (_) {}

    if (mounted) {
      setState(() {
        isReadingNfc = false;
      });
    }
  }

  // ============================================================
  // ورود دستی
  // ============================================================

  Future<void> _enableManualMode() async {
    await _stopNfcReader();

    if (!mounted) return;

    setState(() {
      manualMode = true;
      nfcStatus = 'سریال کارت بلیت را وارد کنید.';
    });
  }

  // ============================================================
  // تأیید سریال دستی
  // ============================================================

  void _continueWithManualNumber() {
    final serial = manualController.text.trim();

    if (serial.isEmpty) {
      _showMessage(
        'لطفاً سریال کارت بلیت را وارد کنید.',
        isError: true,
      );
      return;
    }

    widget.customer.ticketNumber = serial;

    _goToCamera();
  }

  // ============================================================
  // رفتن به Camera
  // ============================================================

  void _goToCamera() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPage(
          customer: widget.customer,
        ),
      ),
    );
  }

  // ============================================================
  // پیام
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        backgroundColor:
            isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  void dispose() {
    NativeNfcService.removeTagListener();
    NativeNfcService.stopReader().catchError((_) {});
    manualController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),

      appBar: AppBar(
        title: const Text(
          'خواندن کارت بلیت',
          style: TextStyle(
            fontFamily: 'Traffic',
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),

              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0)
                      .withOpacity(0.10),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  manualMode
                      ? Icons.edit_rounded
                      : Icons.nfc_rounded,
                  size: 60,
                  color: const Color(0xFF1565C0),
                ),
              ),

              const SizedBox(height: 25),

              Text(
                manualMode
                    ? 'ورود دستی سریال'
                    : 'خواندن کارت بلیت',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Traffic',
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172554),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                manualMode
                    ? 'سریال پشت کارت بلیت را وارد کنید.'
                    : 'کارت بلیت را پشت گوشی قرار دهید.',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Traffic',
                  fontSize: 16,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 35),

              if (manualMode) ...[
                TextField(
                  controller: manualController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'سریال کارت بلیت',
                    hintText: 'سریال را وارد کنید',
                    prefixIcon: const Icon(
                      Icons.confirmation_number_outlined,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _continueWithManualNumber,
                    child: const Text(
                      'ادامه',
                      style: TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),

                      const SizedBox(height: 18),

                      Text(
                        nfcStatus,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Traffic',
                          fontSize: 15,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: _enableManualMode,
                    icon: const Icon(
                      Icons.edit_rounded,
                    ),
                    label: const Text(
                      'رد کردن اسکن و ورود دستی',
                      style: TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}