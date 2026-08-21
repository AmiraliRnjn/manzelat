import 'dart:io';
import 'package:flutter/services.dart';

import '../services/storage_service.dart';
import '../services/customer_status_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../app_enum.dart';
import '../models/customer_data.dart';
import 'package:crop_image/crop_image.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';


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
    final maxHeight = MediaQuery.sizeOf(context).height -
        viewInsets.bottom -
        32;

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
                  Flexible(
                    child: contentWidget!,
                  ),
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
        if (icon != null) ...[
          Icon(icon, size: 19),
          const SizedBox(width: 7),
        ],
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
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 13,
          ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
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
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF1565C0),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF1565C0),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class CameraPage extends StatefulWidget {
  final CustomerData customer;
  final String? ticketNumber;

  const CameraPage({
    super.key,
    required this.customer,
    this.ticketNumber,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final CropController cropController = CropController();
  CameraController? cameraController;
  List<CameraDescription> cameras = [];
  File? capturedImage;
  bool isCameraReady = false;

bool isTakingPicture = false;

  final List<Map<String, dynamic>> savedCardsData = [];
  final Map<CardType, TextEditingController> textControllers = {};

  // مدارک مخصوص دسته‌های جدید (جانبازان/شهدا/بهزیستی/دانشجویی) که وقتی در
  // مدارک مشتری باشند یعنی این جریان یکی از حالت‌های منعطف قدیمی منزلت
  // (مدارک دارد/کارت ملی ندارد/کارت منزلت ندارد/هیچ‌کدام ندارد) نیست، بلکه
  // یکی از دسته‌های جدید با مدارک ثابت خودش است.
  static const List<CardType> _newCategoryCardTypes = [
    CardType.veteranCard,
    CardType.shenasnameh,
    CardType.shenasnamehPage2,
    CardType.martyrCard,
    CardType.behzistiCard,
    CardType.studentcard,
  ];

  bool get _isNewCategoryFlow =>
      widget.customer.cards.any(_newCategoryCardTypes.contains);

  // مدرکی که شماره تلفن مشتری رویش ثبت می‌شود (برای دسته‌های جدید).
  static const List<CardType> _phoneNumberCandidates = [
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
    initializeCamera(); // Your existing camera initialization method

    // Explicitly initialize controllers for all 3 required input fields
    // so they are guaranteed to exist in memory regardless of widget.customer.cards
    textControllers[CardType.ticket] = TextEditingController(
      text: widget.customer.ticketNumber ?? '',
    );
    textControllers[CardType.national] = TextEditingController();
    textControllers[CardType.manzelat] = TextEditingController();

    // برای دسته‌های جدید، کنترلر مدرک مخصوص شماره تلفن همان دسته را هم می‌سازیم.
    final phoneCard = _phoneNumberCardType;
    if (phoneCard != null) {
      textControllers[phoneCard] = TextEditingController();
    }
  }

  Future<void> initializeCamera() async {
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
  }

  String getCardName(CardType card) {
    switch (card) {
      case CardType.ticket:
        return 'کارت بلیط';
      case CardType.national:
        return 'کارت ملی';
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
    }
  }

  String getCardNumberTitle(CardType cardType) {
    switch (cardType) {
      case CardType.national:
        return 'کد ملی';
      case CardType.manzelat ||
            CardType.studentcard ||
            CardType.veteranCard ||
            CardType.martyrCard ||
            CardType.behzistiCard:
        return 'شماره همراه';
      case CardType.ticket:
        return 'سریال پشت کارت بلیط';
      case CardType.personalPhoto:
        return 'عکس پرسنلی';
      case CardType.shenasnameh:
        return 'شناسنامه';
      case CardType.shenasnamehPage2:
        return 'شناسنامه صفحه دوم';
    }
  }

  IconData getCardIcon(CardType card) {
    switch (card) {
      case CardType.ticket:
        return Icons.credit_card_rounded;
      case CardType.national:
        return Icons.badge_rounded;
      case CardType.manzelat:
        return Icons.card_membership_rounded;
      case CardType.studentcard:
        return Icons.school_rounded;
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
      case CardType.personalPhoto:
        return Icons.person_rounded;
    }
  }

Future<void> takePicture() async {
  if (cameraController == null || !cameraController!.value.isInitialized) return;
  
  // ۱. اگر عکس قبلی هنوز در حال پردازش است، کلیک جدید را کاملاً نادیده بگیر
  if (isTakingPicture) return;

  try {
    setState(() {
      isTakingPicture = true; 
    });

    // ۲. فقط یک‌بار متد عکاسی فلاتر صدا زده می‌شود
    final XFile image = await cameraController!.takePicture();
    
    if (!mounted) return;
    
    // ۳. ذخیره عکس گرفته شده در متغیر خودتان برای نمایش در صفحه
    setState(() => capturedImage = File(image.path));

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در عکاسی: $e')));
  } finally {
    if (mounted) {
      setState(() {
        isTakingPicture = false; // ۴. آزاد کردن شاتر برای عکاسی‌های بعدی
      });
    }
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
      return null;
    }
  }

  void _showLoadingDialog(
    BuildContext context,
    ValueNotifier<String> statusNotifier,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: _StyledDialog(
            icon: Icons.sync_rounded,
            iconColor: const Color(0xFF1565C0),
            title: 'در حال ثبت اطلاعات',
            contentWidget: ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, statusText, child) {
                return Row(
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
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<File> _createZipFile(Directory customerFolder) async {
    // ایجاد یک آرشیو خام در حافظه رم
    final archive = Archive();

    // خواندن فایل‌های واقعی داخل پوشه مشتری
    final List<FileSystemEntity> entities = customerFolder.listSync(
      recursive: false,
    );

    for (final item in entities) {
      if (item is File && item.lengthSync() > 0) {
        // خواندن بایت‌های واقعی فایل عکس به صورت مستقیم از روی دیسک
        final Uint8List fileBytes = item.readAsBytesSync();

        // استخراج نام فایل (مثلاً ۱۲۳۴۵۶۷۸۹۰.jpg) بدون مسیر طولانی آن
        final String fileName = item.path.split(Platform.pathSeparator).last;

        // ساخت مستقیم شیء فایل آرشیو و تزریق بایت‌ها به آن
        final archiveFile = ArchiveFile(fileName, fileBytes.length, fileBytes);
        archive.addFile(archiveFile);
      }
    }

    // فشرده‌سازی و کدگذاری کل آرشیو به دیتای نهایی ZIP
    final zipEncoder = ZipEncoder();
    final List<int>? compressedBytes = zipEncoder.encode(archive);

    if (compressedBytes == null) {
      throw Exception('خطا در فشرده‌سازی و کدگذاری فایل زیپ');
    }

    // نوشتن فیزیکی فایل زیپ نهایی و پر شده روی هارد گوشی
    final zipPath = '${customerFolder.path}.zip';
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(compressedBytes, flush: true);

    return zipFile;
  }

  Future<void> _showSuccessDialog(String folderPath, File zipFile) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _StyledDialog(
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
                final xFile = XFile(zipFile.path);
                await Share.shareXFiles(
                  [xFile],
                  text: 'فایل زیپ مدارک مشتری: ${widget.customer.fullName}',
                );

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
        );
      },
    );
  }


  Future<void> showFinalSaveDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _StyledDialog(
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

                      _StyledTextField(
                        controller: textControllers[CardType.ticket]!,
                        label: 'سریال پشت کارت بلیط را وارد کنید',
                        icon: Icons.confirmation_number_outlined,
                      ),
                      const SizedBox(height: 12),

                    if (!_isNewCategoryFlow) ...[
                      // فیلد دوم: کد ملی
                      _StyledTextField(
                        controller: textControllers[CardType.national]!,
                        label: 'کد ملی را وارد کنید',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),

                      // فیلد سوم: شماره تلفن (منزلت)
                      _StyledTextField(
                        controller: textControllers[CardType.manzelat]!,
                        label: 'شماره تلفن همراه را وارد کنید',
                        icon: Icons.phone_outlined,
                      ),
                    ] else ...[
                      if (widget.customer.cards.contains(CardType.national)) ...[
                        _StyledTextField(
                          controller: textControllers[CardType.national]!,
                          label: 'کد ملی را وارد کنید',
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_phoneNumberCardType != null)
                        _StyledTextField(
                          controller: textControllers[_phoneNumberCardType]!,
                          label: 'شماره تلفن همراه را وارد کنید',
                          icon: Icons.phone_outlined,
                        ),
                    ],
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
                    // ۱. گرفتن متن‌ها از کنترلرها
                    String ticketText = textControllers[CardType.ticket]!.text
                        .trim();
                    String nationalText = textControllers[CardType.national]!
                        .text
                        .trim();
                    String manzelatText = textControllers[CardType.manzelat]!
                        .text
                        .trim();
                    final phoneCard = _phoneNumberCardType;
                    final phoneNumberText = phoneCard != null
                        ? (textControllers[phoneCard]?.text.trim() ?? '')
                        : '';

                    // ۲. فقط فیلدهای مربوط به مدارک انتخاب‌شده باید پر باشند.
                    // سریال کارت بلیت اگر از NFC آمده باشد از قبل پر شده است.
                    final hasTicket =
                        widget.customer.cards.contains(CardType.ticket);
                    final hasNational =
                        widget.customer.cards.contains(CardType.national);
                    final hasManzelat =
                        widget.customer.cards.contains(CardType.manzelat);

                    if ((hasTicket && ticketText.isEmpty) ||
                        (hasNational && nationalText.isEmpty) ||
                        (hasManzelat && manzelatText.isEmpty) ||
                        (phoneCard != null && phoneNumberText.isEmpty)) {
                      _showStyledSnackBar(
                        'لطفاً نام فایل مدارک انتخاب‌شده را کامل کنید',
                        isError: true,
                      );
                      return;
                    }

                    // شماره بلیت NFC را هم در مدل مشتری نگه می‌داریم.
                    if (hasTicket && ticketText.isNotEmpty) {
                      widget.customer.ticketNumber = ticketText;
                    }

                    // ۳. باز کردن دیالوگ لودینگ
                    final statusNotifier = ValueNotifier<String>(
                      'در حال ایجاد پوشه...',
                    );
                    Navigator.pop(context);
                    _showLoadingDialog(this.context, statusNotifier);

                    try {
                      // ۴. ساخت یا واکشی پوشه مشتری
                      final customerFolder =
                          await StorageService.getCustomerFolder(
                            operationType: widget.customer.operationType,
                            customerFullName: widget.customer.fullName,
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

                      // ========================================================
                      // ۵. شروع ساختار شرطی اصلی (جایگاه دقیق کدی که پرسیدی اینجاست)
                      // ========================================================

                      if (widget.customer.cards.length == 1 &&
                          widget.customer.cards.first == CardType.ticket) {
                        // ------------- [بخش اول: دکمه ۱ (مدارک دارد - تک عکس)] -------------
                        final ticketCardData = savedCardsData.firstWhere(
                          (element) => element['type'] == CardType.ticket,
                          orElse: () => {},
                        );

                        if (ticketCardData.isEmpty)
                          throw Exception('تصویر یافت نشد.');
                        final Uint8List originalBytes = ticketCardData['bytes'];
                        List<Future<void>> writeOperations = [];

                        // تکثیر یک عکس به ۳ فایل مجزا با نام‌های متفاوت
                        writeOperations.add(
                          File(
                            '${customerFolder.path}/$ticketText.jpg',
                          ).writeAsBytes(originalBytes, flush: true),
                        );
                        writeOperations.add(
                          File(
                            '${customerFolder.path}/$nationalText.jpg',
                          ).writeAsBytes(originalBytes, flush: true),
                        );
                        writeOperations.add(
                          File(
                            '${customerFolder.path}/$manzelatText.jpg',
                          ).writeAsBytes(originalBytes, flush: true),
                        );

                        await Future.wait(writeOperations);
                      } else {
                        // ------------- [بخش دوم: کدی که پرسیدی دقیقاً اینجا در ELSE قرار می‌گیرد] -------------
                        // منطق دقیق دکمه‌های ۲، ۳ و ۴ بر اساس مدارکی که کاربر عکاسی می‌کند
                        List<Future<void>> writeOperations = [];

                        // بررسی وضعیت مدارک برای تشخیص دکمه فشرده شده
                        bool containsNational = savedCardsData.any(
                          (e) => e['type'] == CardType.national,
                        );
                        bool containsManzelat = savedCardsData.any(
                          (e) => e['type'] == CardType.manzelat,
                        );

                        for (var cardData in savedCardsData) {
                          final CardType type = cardData['type'];
                          final Uint8List bytes = cardData['bytes'];
                          String fileName = '';
                          final phoneCard = _phoneNumberCardType;

                          if (type == CardType.ticket) {
                            // عکس اول: کارت بلیط -> نام فایل: سریال کارت بلیط
                            fileName = textControllers[CardType.ticket]!.text
                                .trim();
                          } else if (type == CardType.national) {
                            // عکس دوم در حالت ۲: کارت ملی -> نام فایل: کد ملی
                            fileName = textControllers[CardType.national]!.text
                                .trim();
                          } else if (type == CardType.manzelat) {
                            // عکس دوم در حالت ۳: کارت منزلت -> نام فایل: شماره تلفن همراه
                            fileName = textControllers[CardType.manzelat]!.text
                                .trim();
                          } else if (phoneCard != null && type == phoneCard) {
                            // مدرک مخصوص دسته جدید (جانبازی/شهدا/بهزیستی/دانشجویی)
                            // که شماره تلفن مشتری رویش ثبت می‌شود.
                            fileName =
                                textControllers[phoneCard]!.text.trim();
                          } else if (type == CardType.shenasnameh) {
                            // شناسنامه (مخصوص جانبازان): نام فایل پیش‌فرض.
                            fileName =
                                '${widget.customer.fullName}_شناسنامه';
                          } else if (type == CardType.shenasnamehPage2) {
                            // صفحه دوم شناسنامه: نام فایل پیش‌فرض جدا از خودِ شناسنامه.
                            fileName =
                                '${widget.customer.fullName}_شناسنامه_صفحه_دوم';
                          } else if (type == CardType.personalPhoto) {
                            if (_isNewCategoryFlow) {
                              // دسته‌های جدید مدارک ثابت خودشان را دارند،
                              // پس عکس پرسنلی همیشه نام پیش‌فرض می‌گیرد.
                              fileName =
                                  '${widget.customer.fullName}_پرسنلی';
                            } else if (containsNational && !containsManzelat) {
                              // منطق طلایی نام‌گذاری عکس پرسنلی (فقط منزلت):
                              // دکمه ۲ (ملی ندارد): چون ملی گرفته شده، اسم پرسنلی می‌شود شماره تلفن
                              fileName = textControllers[CardType.manzelat]!
                                  .text
                                  .trim();
                            } else if (containsManzelat && !containsNational) {
                              // دکمه ۳ (منزلت ندارد): چون منزلت گرفته شده، اسم پرسنلی می‌شود کد ملی
                              fileName = textControllers[CardType.national]!
                                  .text
                                  .trim();
                            } else {
                              // دکمه ۴ (هیچ مدارکی ندارد): اسم پرسنلی می‌شود نام مشتری + پرسنلی
                              fileName = '${widget.customer.fullName}_پرسنلی';
                            }
                          }

                          if (fileName.isEmpty) {
                            fileName =
                                '${widget.customer.fullName}_${type.name}';
                          }

                          final file = File(
                            '${customerFolder.path}/$fileName.jpg',
                          );
                          writeOperations.add(
                            file.writeAsBytes(bytes, flush: true),
                          );
                        }

                        await Future.wait(writeOperations);
                      }

                      // ========================================================
                      // پایان ساختار شرطی - ادامه فرآیند ذخیره و خروجی ZIP
                      // ========================================================

                      statusNotifier.value = 'در حال ایجاد فایل فشرده ZIP...';
                      final File zipFile = await _createZipFile(customerFolder);
                      if (!mounted) return;
                      Navigator.pop(this.context);
                      await _showSuccessDialog(customerFolder.path, zipFile);
                    } catch (e, stackTrace) {
                      debugPrint('FINAL SAVE ERROR: $e');
                      debugPrintStack(stackTrace: stackTrace);

                      if (mounted) {
                        Navigator.pop(this.context);
                        _showStyledSnackBar(
                          'ذخیره انجام نشد: $e',
                          isError: true,
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
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

  void _showStyledSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFE85D75) : const Color(0xFF1565C0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
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
    final currentCard =
        widget.customer.cards[widget.customer.currentCardIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFF),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                        Icons.arrow_forward_rounded,
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
                            onPressed:
                                isTakingPicture ? null : takePicture,
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
                                    foregroundColor:
                                        const Color(0xFF1565C0),
                                    side: const BorderSide(
                                      color: Color(0xFF1565C0),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(17),
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
                                  onPressed: () async {
                                    final jpgBytes =
                                        await cropCurrentImageToJpg();
                                    if (jpgBytes == null) return;

                                    savedCardsData.add({
                                      'type': currentCard,
                                      'bytes': jpgBytes,
                                    });

                                    if (widget.customer.currentCardIndex <
                                        widget.customer.cards.length - 1) {
                                      setState(() {
                                        widget.customer.currentCardIndex++;
                                        capturedImage = null;
                                      });
                                    } else {
                                      await showFinalSaveDialog();
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.check_rounded,
                                  ),
                                  label: const Text(
                                    'تأیید',
                                    style: TextStyle(
                                      fontFamily: 'Traffic',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF35B96B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(17),
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
        child: CircularProgressIndicator(
          color: Color(0xFF1565C0),
        ),
      );
    }

    final controller = cameraController!;
    final previewSize = controller.value.previewSize;
    final frameWidth = MediaQuery.sizeOf(context).width * 0.82;

    Widget cameraPreview;

    if (previewSize != null) {
      final isPortrait = MediaQuery.orientationOf(context) ==
          Orientation.portrait;

      // CameraPreview در حالت عمودی ابعاد previewSize را برعکس گزارش می‌کند.
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
        // دوربین کل فضای کادر را پر می‌کند؛ هیچ حاشیه مشکی ایجاد نمی‌شود.
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: Colors.black,
            child: cameraPreview,
          ),
        ),

        // ناحیه خارج از کادر کمی تیره می‌شود، اما خود تصویر دوربین کامل باقی می‌ماند.
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
              border: Border.all(
                color: Colors.white,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),

        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
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

  Widget buildCapturedImage() => CropImage(
        controller: cropController,
        image: Image.file(
          capturedImage!,
          fit: BoxFit.contain,
        ),
      );

  @override
  void dispose() {
    cameraController?.dispose();
    for (var c in textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}

