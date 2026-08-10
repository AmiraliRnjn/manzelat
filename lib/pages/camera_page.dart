import 'dart:io';
import 'package:flutter/services.dart';

import '../services/storage_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../card_type.dart';
import '../models/customer_data.dart';
import 'package:crop_image/crop_image.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';

class CameraPage extends StatefulWidget {
  final CustomerData customer;
  const CameraPage({super.key, required this.customer});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final CropController cropController = CropController();
  CameraController? cameraController;
  List<CameraDescription> cameras = [];
  File? capturedImage;
  bool isCameraReady = false;

  final List<Map<String, dynamic>> savedCardsData = [];
  final Map<CardType, TextEditingController> textControllers = {};

  @override
  void initState() {
    super.initState();
    initializeCamera();
    for (var card in widget.customer.cards) {
      textControllers[card] = TextEditingController();
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
    }
  }

  String getCardNumberTitle(CardType cardType) {
    switch (cardType) {
      case CardType.national:
        return 'کد ملی';
      case CardType.manzelat:
        return 'شماره همراه';
      case CardType.ticket:
        return 'سریال پشت کارت بلیط';
      case CardType.personalPhoto:
        return 'عکس پرسنلی';
    }
  }

  Future<void> takePicture() async {
    if (cameraController == null || !cameraController!.value.isInitialized)
      return;
    final XFile image = await cameraController!.takePicture();
    if (!mounted) return;
    setState(() => capturedImage = File(image.path));
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
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              content: ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (context, statusText, child) {
                  return Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
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
    final List<FileSystemEntity> entities = customerFolder.listSync(recursive: false);
    
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
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('عملیات با موفقیت انجام شد',style: TextStyle(fontSize: 20),),
              ],
            ),
            content: Text(
              'پوشه مشتری ایجاد و در مسیر زیر ذخیره شد:\n\n$folderPath\n\nنسخه ZIP نیز با موفقیت شامل تمام تصاویر ساخته شد.',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('بعداً'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final xFile = XFile(zipFile.path);
                  await Share.shareXFiles([
                    xFile,
                  ], text: 'فایل زیپ مدارک مشتری: ${widget.customer.fullName}');
                },
                icon: const Icon(Icons.share),
                label: const Text('اشتراک‌گذاری فایل ZIP'),
              ),
            ],
          ),
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
            return AlertDialog(
              title: const Text(
                'ثبت نهایی و ایجاد پوشه مشتری',
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نام مشتری: ${widget.customer.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    ...widget.customer.cards.map((card) {
                      if (card == CardType.personalPhoto) return SizedBox();
                      final controller = textControllers[card]!;
                      final textLength = controller.text.trim().length;
                      final showWarning = textLength > 0 && textLength != 10;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: TextField(
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            controller: controller,
                            keyboardType: TextInputType.number,
                            onChanged: (value) => setDialogState(() {}),
                            decoration: InputDecoration(
                              labelText: getCardNumberTitle(card),
                              border: const OutlineInputBorder(),
                              errorText: showWarning
                                  ? 'تعداد ارقام باید ۱۰ رقم باشد (فعلاً $textLength رقم)'
                                  : null,
                              errorStyle: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('بازگشت'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    for (var card in widget.customer.cards) {
                      if (card == CardType.personalPhoto) continue;

                      if (textControllers[card]!.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'لطفاً ${getCardNumberTitle(card)} را وارد کنید',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    final statusNotifier = ValueNotifier<String>(
                      'در حال ایجاد پوشه مشتری...',
                    );
                    Navigator.pop(context);
                    _showLoadingDialog(this.context, statusNotifier);

                    try {
                      final customerFolder =
                          await StorageService.getCustomerFolder(
                            operationType: widget.customer.operationType,
                            customerFullName: widget.customer.fullName,
                          );

                      if (customerFolder == null) {
                        if (mounted) Navigator.pop(this.context);
                        return;
                      }

                      if (!await customerFolder.exists()) {
                        await customerFolder.create(recursive: true);
                      }

                      statusNotifier.value =
                          'در حال ذخیره‌سازی و پردازش تصاویر...';
                      List<Future<void>> writeOperations = [];
                      for (var cardData in savedCardsData) {
                        final CardType type = cardData['type'];
                        final Uint8List bytes = cardData['bytes'];
                        String fileName;

                        if (type == CardType.personalPhoto) {
                          final timestamp = DateTime.now().millisecondsSinceEpoch;
                          fileName = '${widget.customer.fullName}_personal_$timestamp';
                        } else {
                          fileName = textControllers[type]!.text.trim();
                        }

                        final file = File(
                          '${customerFolder.path}/$fileName.jpg',
                        );
                        writeOperations.add(
                          file.writeAsBytes(bytes, flush: true),
                        );
                      }
                      await Future.wait(writeOperations);

                      statusNotifier.value = 'در حال ایجاد فایل فشرده ZIP...';
                      final File zipFile = await _createZipFile(customerFolder);

                      if (!mounted) return;
                      Navigator.pop(this.context);

                      await _showSuccessDialog(customerFolder.path, zipFile);
                    } catch (e) {
                      if (mounted) Navigator.pop(this.context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('خطا در ذخیره‌سازی: $e')),
                      );
                    }
                  },
                  child: const Text('تایید و ذخیره نهایی'),
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
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('هشدار خروج'),
          content: const Text(
            'آیا از خروج اطمینان دارید؟ عکس‌های گرفته شده ذخیره نخواهند شد.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = widget.customer.cards[widget.customer.currentCardIndex];
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
        appBar: AppBar(title: Text(getCardName(currentCard))),
        body: Column(
          children: [
            Expanded(
              child: capturedImage == null
                  ? buildCamera()
                  : buildCapturedImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (capturedImage == null) ...[
                    Text(
                      'کارت فعلی برای عکاسی: ${getCardName(currentCard)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  capturedImage == null
                      ? ElevatedButton.icon(
                          onPressed: takePicture,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('گرفتن عکس'),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() {
                                  capturedImage = null;
                                }),
                                child: const Text('دوباره'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
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
                                child: const Text('تأیید برش'),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCamera() {
    if (!isCameraReady || cameraController == null)
      return const Center(child: CircularProgressIndicator());
    final width = MediaQuery.of(context).size.width * 0.85;
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(cameraController!),
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
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
                  width: width,
                  height: width * (3 / 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: width,
            height: width * (3 / 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCapturedImage() => CropImage(
    controller: cropController,
    image: Image.file(capturedImage!, fit: BoxFit.contain),
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
