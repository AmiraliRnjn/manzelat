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
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFFFAFBFF),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              title: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'کارت با موفقیت خوانده شد',
                      style: TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172554),
                      ),
                    ),
                  ),
                ],
              ),
              content: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'سریال کارت بلیت:\n$ticketNumber',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'Traffic',
                    fontSize: 15,
                    height: 1.7,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'ادامه',
                      style: TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'Traffic',
            fontSize: 14,
          ),
        ),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF172554),
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
          'خواندن کارت بلیت',
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

                // آیکن اصلی صفحه
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
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
                          controller: manualController,
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
                          onPressed: _continueWithManualNumber,
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
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryBlue,
                            ),
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
                          nfcStatus,
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
                    onPressed: _enableManualMode,
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
