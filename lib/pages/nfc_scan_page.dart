import 'package:flutter/material.dart';

import '../models/customer_data.dart';
import '../services/native_nfc_service.dart';
import 'camera_page.dart';

class NfcScanPage extends StatefulWidget {
  final CustomerData customer;

  const NfcScanPage({
    super.key,
    required this.customer,
  });

  @override
  State<NfcScanPage> createState() => _NfcScanPageState();
}

class _NfcScanPageState extends State<NfcScanPage> {
  final TextEditingController manualSerialController =
      TextEditingController();

  bool isReading = false;
  bool manualMode = false;
  String status = 'در حال آماده‌سازی NFC...';

  @override
  void initState() {
    super.initState();
    NativeNfcService.setTagListener(_onNfcTag);
    _startNfc();
  }

  Future<void> _startNfc() async {
    if (isReading || manualMode) return;

    try {
      setState(() {
        isReading = true;
        status = 'کارت بلیت را پشت گوشی قرار دهید...';
      });

      await NativeNfcService.startReader();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isReading = false;
        status = 'فعال‌سازی NFC ناموفق بود.';
      });
    }
  }

  Future<void> _onNfcTag(dynamic arguments) async {
    if (!mounted) return;

    try {
      final map = Map<dynamic, dynamic>.from(arguments as Map);
      final ticketNumber = (map['ticketNumber'] ?? '').toString().trim();

      if (ticketNumber.isEmpty) {
        throw Exception('شماره سریال از کارت دریافت نشد.');
      }

      widget.customer.ticketNumber = ticketNumber;

      await _stopNfc();

      if (!mounted) return;

      setState(() {
        status = 'کارت با موفقیت خوانده شد\nسریال: $ticketNumber';
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ادامه'),
            ),
          ],
        ),
      );

      if (mounted) {
        _goToCamera();
      }
    } catch (e) {
      if (!mounted) return;

      await _stopNfc();

      setState(() {
        status = 'خطا در خواندن کارت.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'خواندن NFC ناموفق بود: $e',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  Future<void> _stopNfc() async {
    try {
      await NativeNfcService.stopReader();
    } catch (_) {}

    if (mounted) {
      setState(() {
        isReading = false;
      });
    }
  }

  Future<void> _skipNfc() async {
    await _stopNfc();

    if (!mounted) return;

    setState(() {
      manualMode = true;
      status = 'سریال کارت بلیت را دستی وارد کنید.';
    });
  }

  void _continueManual() {
    final serial = manualSerialController.text.trim();

    if (serial.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً سریال کارت بلیت را وارد کنید.',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
      return;
    }

    widget.customer.ticketNumber = serial;
    _goToCamera();
  }

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

  @override
  void dispose() {
    NativeNfcService.removeTagListener();
    NativeNfcService.stopReader().catchError((_) {});
    manualSerialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      appBar: AppBar(
        title: const Text(
          'کارت بلیت',
          style: TextStyle(fontFamily: 'Traffic'),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 28),
              Icon(
                manualMode ? Icons.edit_rounded : Icons.nfc_rounded,
                size: 72,
                color: const Color(0xFF1565C0),
              ),
              const SizedBox(height: 20),
              Text(
                manualMode ? 'ورود دستی سریال' : 'خواندن کارت بلیت',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Traffic',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172554),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                manualMode
                    ? 'سریال پشت کارت بلیت را وارد کنید.'
                    : 'کارت بلیت را پشت گوشی، نزدیک قسمت NFC قرار دهید.',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Traffic',
                  fontSize: 16,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 30),

              if (manualMode) ...[
                TextField(
                  controller: manualSerialController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'سریال کارت بلیت',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _continueManual,
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (isReading)
                        const CircularProgressIndicator(),
                      if (isReading) const SizedBox(height: 18),
                      Text(
                        status,
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
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _skipNfc,
                    icon: const Icon(Icons.edit_rounded),
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
