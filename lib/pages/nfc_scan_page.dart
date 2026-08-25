
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

class _NfcScanPageState extends State<NfcScanPage>
    with WidgetsBindingObserver {
  static const primaryBlue = Color(0xFF1565C0);
  static const darkBlue = Color(0xFF172554);
  static const background = Color(0xFFFAFBFF);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFDC2626);

  final TextEditingController manualSerialController =
      TextEditingController();

  bool isReading = false;
  bool manualMode = false;
  bool nfcEnabled = false;
  bool checkingNfc = true;

  String status = 'در حال بررسی وضعیت NFC...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    NativeNfcService.setListeners(
      onTag: _onNfcTag,
      onState: _onNfcStateChanged,
    );

    _refreshNfcStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNfcStatus();
    }
  }

  Future<void> _onNfcStateChanged(bool enabled) async {
    if (!mounted) return;

    setState(() {
      nfcEnabled = enabled;
      checkingNfc = false;
    });

    if (!enabled) {
      await _stopNfc();
      if (!mounted || manualMode) return;
      setState(() {
        status = 'NFC خاموش است. آن را روشن کنید تا اسکن شروع شود.';
      });
      return;
    }

    if (!manualMode && !isReading) {
      await _startNfc();
    } else if (!manualMode) {
      setState(() {
        status = 'NFC روشن است؛ کارت بلیت را پشت گوشی قرار دهید.';
      });
    }
  }

  Future<void> _refreshNfcStatus() async {
    if (!mounted) return;

    setState(() {
      checkingNfc = true;
    });

    try {
      final enabled = await NativeNfcService.isNfcEnabled();
      await _onNfcStateChanged(enabled);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        checkingNfc = false;
        nfcEnabled = false;
        status = 'وضعیت NFC قابل تشخیص نیست.';
      });
    }
  }

  Future<void> _startNfc() async {
    if (isReading || manualMode || !nfcEnabled) return;

    try {
      setState(() {
        isReading = true;
        status = 'کارت بلیت را پشت گوشی، نزدیک قسمت NFC قرار دهید...';
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
      final ticketNumber =
          (map['ticketNumber'] ?? '').toString().trim();

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'کارت با موفقیت خوانده شد',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Traffic',
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          content: Text(
            'سریال کارت بلیت:\n$ticketNumber',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'Traffic',
              fontSize: 15,
              color: textSecondary,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'ادامه',
                style: TextStyle(fontFamily: 'Traffic'),
              ),
            ),
          ],
        ),
      );

      if (mounted) _goToCamera();
    } catch (e) {
      if (!mounted) return;

      await _stopNfc();

      setState(() {
        status = 'خطا در خواندن کارت.';
      });

      _showMessage('خواندن NFC ناموفق بود: $e', isError: true);
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

  Future<void> _openNfcSettings() async {
    try {
      await NativeNfcService.openNfcSettings();
    } catch (_) {
      _showMessage('امکان باز کردن تنظیمات NFC وجود ندارد.', isError: true);
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
      _showMessage('لطفاً سریال کارت بلیت را وارد کنید.', isError: true);
      return;
    }

    widget.customer.ticketNumber = serial;
    _goToCamera();
  }

  void _goToCamera() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPage(customer: widget.customer),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isError ? error : primaryBlue,
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Traffic'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NativeNfcService.removeTagListener();
    NativeNfcService.stopReader().catchError((_) {});
    manualSerialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'کارت بلیت',
          style: TextStyle(
            fontFamily: 'Traffic',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        iconTheme: const IconThemeData(color: darkBlue),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildHero(),
              const SizedBox(height: 24),
              if (manualMode) _buildManual() else _buildNfcCard(),
              const SizedBox(height: 16),
              if (!manualMode) _buildManualButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0D47B5), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              manualMode ? Icons.edit_rounded : Icons.nfc_rounded,
              color: Colors.white,
              size: 46,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            manualMode ? 'ورود دستی سریال' : 'خواندن کارت بلیت',
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Traffic',
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            manualMode
                ? 'سریال پشت کارت بلیت را وارد کنید.'
                : 'کارت بلیت را پشت گوشی، نزدیک قسمت NFC قرار دهید.',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Traffic',
              fontSize: 15,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNfcCard() {
    final Color stateColor =
        checkingNfc ? primaryBlue : (nfcEnabled ? success : error);

    final IconData stateIcon =
        checkingNfc
            ? Icons.sync_rounded
            : (nfcEnabled
                ? Icons.check_circle_rounded
                : Icons.nfc_rounded);

    final String stateTitle =
        checkingNfc
            ? 'در حال بررسی NFC'
            : (nfcEnabled ? 'NFC روشن است' : 'NFC خاموش است');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: stateColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(stateIcon, color: stateColor, size: 29),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      stateTitle,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: stateColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Traffic',
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!nfcEnabled && !checkingNfc) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _openNfcSettings,
                icon: const Icon(Icons.settings_rounded, size: 21),
                label: const Text(
                  'روشن کردن NFC',
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
    );
  }

  Widget _buildManual() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: manualSerialController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'سریال کارت بلیت',
              hintText: 'سریال را وارد کنید',
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              filled: true,
              fillColor: background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: primaryBlue,
                  width: 1.5,
                ),
              ),
              labelStyle: const TextStyle(fontFamily: 'Traffic'),
              hintStyle: const TextStyle(fontFamily: 'Traffic'),
            ),
          ),
          const SizedBox(height: 16),
          _primaryButton(
            label: 'ادامه',
            icon: Icons.arrow_forward_rounded,
            onPressed: _continueManual,
          ),
        ],
      ),
    );
  }

  Widget _buildManualButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _skipNfc,
        icon: const Icon(Icons.edit_rounded, size: 21),
        label: const Text(
          'رد کردن اسکن و ورود دستی',
          style: TextStyle(
            fontFamily: 'Traffic',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: Color(0xFFB8C7E6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Traffic',
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryBlue.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}



