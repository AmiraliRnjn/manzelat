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
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFFDC2626),
          content: const Text(
            'لطفاً سریال کارت بلیت را وارد کنید.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Traffic',
              fontSize: 14,
            ),
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
    const primaryBlue = Color(0xFF1565C0);
    const darkBlue = Color(0xFF172554);
    const textSecondary = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);
    const background = Color(0xFFFAFBFF);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkBlue),
        title: const Text(
          'کارت بلیت',
          style: TextStyle(
            fontFamily: 'Traffic',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                const SizedBox(height: 12),

                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Icon(
                    manualMode ? Icons.edit_rounded : Icons.nfc_rounded,
                    size: 58,
                    color: primaryBlue,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  manualMode ? 'ورود دستی سریال' : 'خواندن کارت بلیت',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Traffic',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  manualMode
                      ? 'سریال پشت کارت بلیت را وارد کنید.'
                      : 'کارت بلیت را پشت گوشی، نزدیک قسمت NFC قرار دهید.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Traffic',
                    fontSize: 15.5,
                    height: 1.7,
                    color: textSecondary,
                  ),
                ),

                const SizedBox(height: 28),

                if (manualMode) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.035),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.confirmation_number_outlined,
                                color: primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'شماره سریال کارت',
                                style: TextStyle(
                                  fontFamily: 'Traffic',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: manualSerialController,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Traffic',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: darkBlue,
                            letterSpacing: 1.2,
                          ),
                          decoration: InputDecoration(
                            hintText: 'سریال را وارد کنید',
                            hintStyle: const TextStyle(
                              fontFamily: 'Traffic',
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 17,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: primaryBlue,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _primaryButton(
                          label: 'ادامه',
                          icon: Icons.arrow_back_rounded,
                          onPressed: _continueManual,
                          color: primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.035),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.09),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(18),
                          child: isReading
                              ? const CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                    primaryBlue,
                                  ),
                                )
                              : const Icon(
                                  Icons.nfc_rounded,
                                  color: primaryBlue,
                                  size: 30,
                                ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'در انتظار کارت بلیت',
                          style: TextStyle(
                            fontFamily: 'Traffic',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Traffic',
                            fontSize: 14.5,
                            height: 1.7,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _secondaryButton(
                    label: 'ورود دستی سریال',
                    icon: Icons.edit_rounded,
                    onPressed: _skipNfc,
                    color: primaryBlue,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Traffic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Traffic',
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.28), width: 1.2),
          backgroundColor: color.withOpacity(0.035),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }
}
