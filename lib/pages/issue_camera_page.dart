
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:camera/camera.dart';
import 'package:crop_image/crop_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';

import '../app_enum.dart';
import '../models/customer_data.dart';
import '../services/storage_service.dart';
import '../services/customer_status_service.dart';

class _StyledDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? content;
  final Widget? contentWidget;
  final List<Widget>? actions;

  const _StyledDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.content,
    this.contentWidget,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxHeight =
        MediaQuery.sizeOf(context).height - viewInsets.bottom - 32;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: maxHeight.clamp(280.0, 760.0),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFF),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(height: 11),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF172554),
                    fontFamily: 'Traffic',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (content != null) ...[
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        content!,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontFamily: 'Traffic',
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
                if (contentWidget != null) ...[
                  const SizedBox(height: 12),
                  Flexible(child: contentWidget!),
                ],
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < actions!.length; i++) ...[
                          if (i > 0) const SizedBox(width: 9),
                          actions![i],
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String text;
  final bool filled;
  final Color color;
  final IconData? icon;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.text,
    required this.filled,
    required this.color,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 7)],
        Text(
          text,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'Traffic',
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.65)),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: child,
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontFamily: 'Traffic',
        fontSize: 16,
        color: Color(0xFF172554),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Traffic',
          fontSize: 13,
          color: Color(0xFF64748B),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
      ),
    );
  }
}

class IssueCameraPage extends StatefulWidget {
  final CustomerData customer;
  final String category;

  const IssueCameraPage({
    super.key,
    required this.customer,
    required this.category,
  });

  @override
  State<IssueCameraPage> createState() => _IssueCameraPageState();
}

class _IssueCameraPageState extends State<IssueCameraPage> {
  final CropController cropController = CropController();
  CameraController? cameraController;
  List<CameraDescription> cameras = [];
  File? capturedImage;
  bool isCameraReady = false;
  bool isTakingPicture = false;

  final List<Map<String, dynamic>> savedCardsData = [];
  final Map<CardType, TextEditingController> textControllers = {};

  CardType get currentCard =>
      widget.customer.cards[widget.customer.currentCardIndex];

  // مدرک هر دسته که شماره تلفن روی آن ثبت می‌شود (به ازای هر دسته فقط یکی
  // از این‌ها در لیست مدارک آن دسته وجود دارد).
  static const List<CardType> _phoneNumberCandidates = [
    CardType.manzelat,
    CardType.veteranCard,
    CardType.martyrCard,
    CardType.behzistiCard,
    CardType.studentcard,
  ];

  CardType? get _phoneNumberCardType {
    for (final candidate in _phoneNumberCandidates) {
      if (widget.customer.cards.contains(candidate)) return candidate;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    initializeCamera();

    if (widget.customer.cards.contains(CardType.national)) {
      textControllers[CardType.national] = TextEditingController(
        text: widget.customer.nationalCode,
      );
    }
    final phoneCard = _phoneNumberCardType;
    if (phoneCard != null) {
      textControllers[phoneCard] = TextEditingController();
    }
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await cameraController!.initialize();
      if (!mounted) return;
      setState(() => isCameraReady = true);
    } catch (e) {
      _showStyledSnackBar('دوربین آماده نشد: $e', isError: true);
    }
  }

  String getCardName(CardType card) {
    switch (card) {
      case CardType.national:
        return 'اصل کارت ملی';
      case CardType.manzelat:
        return 'کارت منزلت';
      case CardType.personalPhoto:
        return 'عکس پرسنلی';
      case CardType.studentcard:
        return 'کارت دانشجویی اعتبار دار استان تهران';
      case CardType.veteranCard:
        return 'کارت جانبازی استان تهران';
      case CardType.shenasnameh:
        return 'اصل شناسنامه';
      case CardType.shenasnamehPage2:
        return 'عکس صفحه دوم شناسنامه';
      case CardType.martyrCard:
        return 'کارت بنیاد شهید استان تهران';
      case CardType.behzistiCard:
        return 'کارت بهزیستی استان تهران';
      case CardType.ticket:
        throw StateError('Ticket is not allowed in issue flow.');
    }
  }

  IconData getCardIcon(CardType card) {
    switch (card) {
      case CardType.national:
        return Icons.badge_rounded;
      case CardType.manzelat:
        return Icons.card_membership_rounded;
      case CardType.studentcard:
        return Icons.school_rounded;
      case CardType.personalPhoto:
        return Icons.person_rounded;
      case CardType.veteranCard:
        return Icons.shield_rounded;
      case CardType.shenasnameh:
        return Icons.menu_book_rounded;
      case CardType.shenasnamehPage2:
        return Icons.description_rounded;
      case CardType.martyrCard:
        return Icons.local_florist_rounded;
      case CardType.behzistiCard:
        return Icons.accessible_rounded;
      case CardType.ticket:
        throw StateError('Ticket is not allowed in issue flow.');
    }
  }

  Future<void> takePicture() async {
    if (cameraController == null ||
        !cameraController!.value.isInitialized ||
        isTakingPicture) {
      return;
    }

    try {
      setState(() => isTakingPicture = true);
      final XFile image = await cameraController!.takePicture();
      if (!mounted) return;
      setState(() => capturedImage = File(image.path));
    } catch (e) {
      _showStyledSnackBar('خطا در عکاسی: $e', isError: true);
    } finally {
      if (mounted) setState(() => isTakingPicture = false);
    }
  }

  Future<Uint8List?> cropCurrentImageToJpg() async {
    try {
      final ui.Image bitmap = await cropController.croppedBitmap();
      final ByteData? byteData = await bitmap.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;

      final img.Image? decodedImage = img.decodeImage(
        byteData.buffer.asUint8List(),
      );
      if (decodedImage == null) return null;

      return Uint8List.fromList(img.encodeJpg(decodedImage, quality: 85));
    } catch (e) {
      _showStyledSnackBar('برش تصویر انجام نشد.', isError: true);
      return null;
    }
  }

  Future<void> _acceptCurrentImage() async {
    final jpgBytes = await cropCurrentImageToJpg();
    if (jpgBytes == null) return;

    savedCardsData.add({'type': currentCard, 'bytes': jpgBytes});

    if (widget.customer.currentCardIndex < widget.customer.cards.length - 1) {
      setState(() {
        widget.customer.currentCardIndex++;
        capturedImage = null;
      });
    } else {
      await showFinalSaveDialog();
    }
  }

  void _showLoadingDialog(
    BuildContext context,
    ValueNotifier<String> statusNotifier,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: _StyledDialog(
          icon: Icons.sync_rounded,
          iconColor: const Color(0xFF1565C0),
          title: 'در حال ثبت اطلاعات',
          contentWidget: ValueListenableBuilder<String>(
            valueListenable: statusNotifier,
            builder: (context, statusText, child) => Row(
              textDirection: TextDirection.rtl,
              children: [
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    statusText,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
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
        ),
      ),
    );
  }

  Future<void> _writeFileSafely(File target, Uint8List bytes) async {
    final partFile = File('${target.path}.part');

    try {
      if (await partFile.exists()) {
        await partFile.delete();
      }

      final randomAccessFile = await partFile.open(mode: FileMode.write);
      try {
        await randomAccessFile.writeFrom(bytes);
        await randomAccessFile.flush();
      } finally {
        await randomAccessFile.close();
      }

      if (!await partFile.exists() || await partFile.length() <= 0) {
        throw Exception('فایل موقت ${target.path} ناقص یا خالی است.');
      }

      if (await target.exists()) {
        throw Exception('فایل مقصد از قبل وجود دارد: ${target.path}');
      }

      await partFile.rename(target.path);

      if (!await target.exists() || await target.length() <= 0) {
        throw Exception('فایل نهایی ${target.path} به‌درستی ذخیره نشد.');
      }
    } catch (_) {
      if (await partFile.exists()) {
        await partFile.delete();
      }
      if (await target.exists() && await target.length() <= 0) {
        await target.delete();
      }
      rethrow;
    }
  }

  Future<void> _writeFilesSafely(List<MapEntry<File, Uint8List>> files) async {
    final createdFiles = <File>[];
    final partFiles = <File>[];

    try {
      for (final entry in files) {
        final target = entry.key;
        final partFile = File('${target.path}.part');
        partFiles.add(partFile);
        await _writeFileSafely(target, entry.value);
        createdFiles.add(target);
      }

      for (final file in createdFiles) {
        if (!await file.exists() || await file.length() <= 0) {
          throw Exception('اعتبارسنجی فایل ذخیره‌شده ناموفق بود: ${file.path}');
        }
      }
    } catch (_) {
      for (final partFile in partFiles) {
        if (await partFile.exists()) {
          await partFile.delete();
        }
      }
      for (final file in createdFiles) {
        if (await file.exists()) {
          await file.delete();
        }
      }
      rethrow;
    }
  }

  Future<File> _createZipFile(Directory customerFolder) async {
    final inputFiles = <File>[];

    for (final item in await customerFolder.list(recursive: false).toList()) {
      if (item is! File) continue;
      if (item.path.endsWith('.part')) {
        throw Exception('فایل موقت ناقص در پوشه پیدا شد: ${item.path}');
      }

      if (!await item.exists() || await item.length() <= 0) {
        throw Exception('فایل ورودی ZIP سالم نیست: ${item.path}');
      }
      inputFiles.add(item);
    }

    if (inputFiles.isEmpty) {
      throw Exception('هیچ فایل سالمی برای ساخت ZIP وجود ندارد.');
    }

    final zipFile = File('${customerFolder.path}.zip');
    final zipPartFile = File('${zipFile.path}.part');

    try {
      if (await zipPartFile.exists()) {
        await zipPartFile.delete();
      }

      final encoder = ZipFileEncoder();
      encoder.create(zipPartFile.path);
      try {
        for (final inputFile in inputFiles) {
          if (!await inputFile.exists() || await inputFile.length() <= 0) {
            throw Exception('فایل ورودی هنگام ساخت ZIP دیگر سالم نیست: ${inputFile.path}');
          }
          await encoder.addFile(
            inputFile,
            inputFile.path.split(Platform.pathSeparator).last,
          );
        }
      } finally {
        await encoder.close();
      }

      if (!await zipPartFile.exists() || await zipPartFile.length() <= 0) {
        throw Exception('فایل ZIP موقت ناقص یا خالی است.');
      }

      for (final inputFile in inputFiles) {
        if (!await inputFile.exists() || await inputFile.length() <= 0) {
          throw Exception('اعتبارسنجی فایل ورودی ZIP ناموفق بود: ${inputFile.path}');
        }
      }

      final inputStream = InputFileStream(zipPartFile.path);
      try {
        final decodedArchive = ZipDecoder().decodeStream(inputStream);
        final entries = decodedArchive.where((entry) => entry.isFile).toList();

        if (entries.length != inputFiles.length) {
          throw Exception('تعداد فایل‌های ZIP با فایل‌های ورودی برابر نیست.');
        }

        for (final inputFile in inputFiles) {
          final fileName =
              inputFile.path.split(Platform.pathSeparator).last;
          final expectedSize = await inputFile.length();
          final entry = entries.cast<dynamic>().firstWhere(
            (item) => item.name == fileName,
            orElse: () => null,
          );

          if (entry == null || entry.size != expectedSize) {
            throw Exception('فایل $fileName داخل ZIP معتبر نیست.');
          }
        }
      } finally {
        inputStream.close();
      }

      final backupZip = File('${zipFile.path}.backup');
      var hadExistingZip = false;
      try {
        if (await backupZip.exists()) {
          await backupZip.delete();
        }
        if (await zipFile.exists()) {
          hadExistingZip = true;
          await zipFile.rename(backupZip.path);
        }

        await zipPartFile.rename(zipFile.path);

        if (!await zipFile.exists() || await zipFile.length() <= 0) {
          throw Exception('فایل ZIP نهایی به‌درستی ذخیره نشد.');
        }

        if (await backupZip.exists()) {
          await backupZip.delete();
        }
        return zipFile;
      } catch (_) {
        if (await zipPartFile.exists()) {
          await zipPartFile.delete();
        }
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
        if (hadExistingZip && await backupZip.exists()) {
          await backupZip.rename(zipFile.path);
        }
        rethrow;
      }
    } catch (_) {
      if (await zipPartFile.exists()) {
        await zipPartFile.delete();
      }
      rethrow;
    }
  }

  Future<void> _showSuccessDialog(String folderPath, File zipFile) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StyledDialog(
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFF35B96B),
        title: 'عملیات با موفقیت انجام شد',
        content:
            'پوشه مشتری ایجاد و در مسیر زیر ذخیره شد:\n\n$folderPath\n\nنسخه ZIP نیز با موفقیت شامل تمام تصاویر ساخته شد.',
        actions: [
          _DialogButton(
            text: 'بعداً',
            filled: false,
            color: const Color(0xFF1565C0),
            onPressed: () {
              Navigator.pop(context);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
          _DialogButton(
            text: 'اشتراک‌گذاری ZIP',
            filled: true,
            color: const Color(0xFF1565C0),
            icon: Icons.share_rounded,
            onPressed: () async {
              final shareResult = await Share.shareXFiles([
                XFile(zipFile.path),
              ], text: 'فایل زیپ مدارک مشتری: ${widget.customer.fullName}');

              if (shareResult.status != ShareResultStatus.success) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'اشتراک‌گذاری لغو شد و وضعیت مشتری تغییر نکرد.',
                      ),
                    ),
                  );
                }
                return;
              }

              await CustomerStatusService.markSent(zipFile.path);

              // بعد از اشتراک‌گذاری، یادآور این مشتری زرد (منتظر رسید)
              // می‌شود و خودِ دیالوگ هم بسته می‌شود، دقیقاً مثل «بعداً».
              await CustomerStatusService.markSent(zipFile.path);

              if (context.mounted) {
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }

  String _safeFileName(CardType type) {
    final national = textControllers[CardType.national]?.text.trim() ?? '';
    final phoneCard = _phoneNumberCardType;
    final phoneNumber = phoneCard != null
        ? (textControllers[phoneCard]?.text.trim() ?? '')
        : '';

    switch (type) {
      case CardType.national:
        return national;
      case CardType.manzelat:
      case CardType.veteranCard:
      case CardType.martyrCard:
      case CardType.behzistiCard:
      case CardType.studentcard:
        // برای مدرکی که شماره تلفن رویش ثبت می‌شود، همان شماره نام فایل است.
        if (type == phoneCard) return phoneNumber;
        return '${widget.customer.fullName}_${getCardName(type)}';
      case CardType.personalPhoto:
        return '${widget.customer.fullName}_پرسنلی';
      case CardType.shenasnameh:
        return '${widget.customer.fullName}_شناسنامه';
      case CardType.shenasnamehPage2:
        return '${widget.customer.fullName}_شناسنامه_صفحه_دوم';
      case CardType.ticket:
        throw StateError('Ticket is not allowed in issue flow.');
    }
  }

  Future<void> showFinalSaveDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _StyledDialog(
          icon: Icons.fact_check_rounded,
          iconColor: const Color(0xFF1565C0),
          title: 'ثبت نهایی و ایجاد پوشه',
          contentWidget: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF1565C0),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'نام مشتری: ${widget.customer.fullName}',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF172554),
                            fontFamily: 'Traffic',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (widget.customer.cards.contains(CardType.national))
                  _StyledTextField(
                    controller: textControllers[CardType.national]!,
                    label: 'کد ملی را وارد کنید',
                    icon: Icons.badge_outlined,
                  ),

                if (_phoneNumberCardType != null) ...[
                  const SizedBox(height: 12),
                  _StyledTextField(
                    controller: textControllers[_phoneNumberCardType]!,
                    label: 'شماره تلفن همراه را وارد کنید',
                    icon: Icons.phone_outlined,
                  ),
                ],

                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'مدارک ثبت‌شده: ${widget.customer.cards.map(getCardName).join('، ')}',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontFamily: 'Traffic',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            _DialogButton(
              text: 'بازگشت',
              filled: false,
              color: const Color(0xFF64748B),
              onPressed: () => Navigator.pop(context),
            ),
            _DialogButton(
              text: 'تأیید و ذخیره',
              filled: true,
              color: const Color(0xFF35B96B),
              icon: Icons.check_rounded,
              onPressed: () async {
                final hasNational = widget.customer.cards.contains(
                  CardType.national,
                );
                final phoneCard = _phoneNumberCardType;

                final national =
                    textControllers[CardType.national]?.text.trim() ?? '';
                final phoneNumber = phoneCard != null
                    ? (textControllers[phoneCard]?.text.trim() ?? '')
                    : '';

                if (hasNational && national.isEmpty) {
                  _showStyledSnackBar(
                    'لطفاً کد ملی را وارد کنید.',
                    isError: true,
                  );
                  return;
                }

                if (phoneCard != null && phoneNumber.isEmpty) {
                  _showStyledSnackBar(
                    'لطفاً شماره تلفن همراه را وارد کنید.',
                    isError: true,
                  );
                  return;
                }

                final statusNotifier = ValueNotifier<String>(
                  'در حال ایجاد پوشه...',
                );

                Navigator.pop(context);
                _showLoadingDialog(this.context, statusNotifier);

                try {
                  final customerFolder = await StorageService.getCustomerFolder(
                    operationType: widget.customer.operationType,
                    customerFullName: widget.customer.fullName,
                    nationalCode: widget.customer.nationalCode,
                  );

                  if (customerFolder == null) {
                    if (mounted) {
                      Navigator.pop(this.context);
                      _showStyledSnackBar(
                        'محل ذخیره‌سازی مشخص نشده است. ابتدا مسیر ذخیره‌سازی را از تنظیمات تعیین کنید.',
                        isError: true,
                      );
                    }
                    return;
                  }

                  if (!await customerFolder.exists()) {
                    await customerFolder.create(recursive: true);
                  }

                  final filesToWrite = <MapEntry<File, Uint8List>>[];
                  final usedFileNames = <String>{};

                  for (final cardData in savedCardsData) {
                    final CardType type = cardData['type'] as CardType;
                    final Uint8List bytes = cardData['bytes'] as Uint8List;
                    String fileName = _safeFileName(type);

                    if (fileName.isEmpty) {
                      throw Exception(
                        'نام فایل برای ${getCardName(type)} خالی است.',
                      );
                    }

                    fileName = StorageService.uniqueFileName(
                      folder: customerFolder,
                      desiredName: fileName,
                      alreadyPlanned: usedFileNames,
                    );
                    usedFileNames.add(fileName);

                    filesToWrite.add(
                      MapEntry(
                        File('${customerFolder.path}/$fileName.jpg'),
                        bytes,
                      ),
                    );
                  }

                  await _writeFilesSafely(filesToWrite);

                  statusNotifier.value = 'در حال ایجاد فایل فشرده ZIP...';
                  final zipFile = await _createZipFile(customerFolder);

                  if (!mounted) return;
                  Navigator.pop(this.context);
                  await _showSuccessDialog(customerFolder.path, zipFile);
                } catch (e, stackTrace) {
                  debugPrint('ISSUE FINAL SAVE ERROR: $e');
                  debugPrintStack(stackTrace: stackTrace);

                  if (mounted) {
                    Navigator.pop(this.context);
                    _showStyledSnackBar('ذخیره انجام نشد: $e', isError: true);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _StyledDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFFFA62B),
        title: 'خروج از فرایند',
        content:
            'آیا از خروج اطمینان دارید؟ عکس‌های گرفته شده ذخیره نخواهند شد.',
        actions: [
          _DialogButton(
            text: 'انصراف',
            filled: false,
            color: const Color(0xFF64748B),
            onPressed: () => Navigator.pop(context, false),
          ),
          _DialogButton(
            text: 'خروج',
            filled: true,
            color: const Color(0xFFE85D75),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showStyledSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? const Color(0xFFE85D75)
            : const Color(0xFF1565C0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        content: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Traffic',
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = widget.customer.cards[widget.customer.currentCardIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFF),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF0D47B5), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                  ),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    IconButton(
                      onPressed: () async {
                        final shouldPop = await _onWillPop();
                        if (shouldPop && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            getCardName(currentCard),
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Traffic',
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'مدرک ${widget.customer.currentCardIndex + 1} از ${widget.customer.cards.length}',
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Traffic',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        getCardIcon(currentCard),
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.black,
                          elevation: 3,
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: capturedImage == null
                              ? buildCamera()
                              : buildCapturedImage(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (capturedImage == null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF1565C0),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'لطفاً تصویر ${getCardName(currentCard)} را داخل کادر قرار دهید.',
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontFamily: 'Traffic',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: isTakingPicture ? null : takePicture,
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text(
                              'گرفتن عکس',
                              style: TextStyle(
                                fontFamily: 'Traffic',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 53,
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() {
                                    capturedImage = null;
                                  }),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text(
                                    'دوباره',
                                    style: TextStyle(
                                      fontFamily: 'Traffic',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1565C0),
                                    side: const BorderSide(
                                      color: Color(0xFF1565C0),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 53,
                                child: ElevatedButton.icon(
                                  onPressed: _acceptCurrentImage,
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text(
                                    'تأیید',
                                    style: TextStyle(
                                      fontFamily: 'Traffic',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF35B96B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCamera() {
    if (!isCameraReady || cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1565C0)),
      );
    }

    final controller = cameraController!;
    final previewSize = controller.value.previewSize;
    final frameWidth = MediaQuery.sizeOf(context).width * 0.82;

    Widget cameraPreview;

    if (previewSize != null) {
      final isPortrait =
          MediaQuery.orientationOf(context) == Orientation.portrait;

      final previewWidth = isPortrait ? previewSize.height : previewSize.width;
      final previewHeight = isPortrait ? previewSize.width : previewSize.height;

      cameraPreview = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: CameraPreview(controller),
        ),
      );
    } else {
      cameraPreview = CameraPreview(controller);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(color: Colors.black, child: cameraPreview),
        ),
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: frameWidth,
                  height: frameWidth * (3 / 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: frameWidth,
            height: frameWidth * (3 / 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.5),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 17,
                ),
                SizedBox(width: 6),
                Text(
                  'داخل کادر قرار دهید',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Traffic',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCapturedImage() {
    return CropImage(
      controller: cropController,
      image: Image.file(capturedImage!, fit: BoxFit.contain),
    );
  }

  @override
  void dispose() {
    cameraController?.dispose();
    for (final c in textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}



