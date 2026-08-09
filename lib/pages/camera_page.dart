import 'package:flutter/material.dart';
import '../card_type.dart';
import '../models/customer_data.dart';
import '../services/storage_service.dart';

class CameraPage extends StatefulWidget {

  final CustomerData customer;

  const CameraPage({
  super.key,
  required this.customer,
});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {

  int currentIndex = 0;

  String? customerFolderPath;
  bool folderReady = false;
  String? folderError;

  @override
  void initState() {
    super.initState();
    _prepareCustomerFolder();
  }

  Future<void> _prepareCustomerFolder() async {

    final folder = await StorageService.getCustomerFolder(
      operationType: widget.customer.operationType,
      customerFullName: widget.customer.fullName,
    );

    if (!mounted) return;

    if (folder == null) {

      setState(() {
        folderError = 'ابتدا باید مسیر ذخیره‌سازی را در بخش «مدیریت» تنظیم کنید.';
      });

      return;

    }

    setState(() {
      customerFolderPath = folder.path;
      folderReady = true;
    });

  }

  String getCardName(CardType card) {

    switch (card) {

      case CardType.ticket:
        return 'کارت بلیط';

      case CardType.national:
        return 'کارت ملی';

      case CardType.manzelat:
        return 'کارت منزلت';

    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('گرفتن عکس'),
      ),

      body: Center(

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Text(
              'مشتری: ${widget.customer.fullName}',
              style: const TextStyle(
                fontSize: 22,
              ),
            ),

            const SizedBox(height: 12),

            if (folderError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  folderError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              ),

            if (folderReady && customerFolderPath != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'پوشه‌ی ذخیره: $customerFolderPath',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            Text(
              'لطفا از ${getCardName(widget.customer.cards[currentIndex])} عکس بگیرید.',
              style: const TextStyle(
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(

              onPressed: () {

                setState(() {

                  if (currentIndex < widget.customer.cards.length - 1) {
                    currentIndex++;
                  } else {

                      Navigator.popUntil(
                      context,
                      ModalRoute.withName('/'),
                    );

                  }

                });

              },

              child: Text(
                currentIndex == widget.customer.cards.length - 1
                    ? 'پایان'
                    : 'بعدی',
              ),

            ),

          ],
        ),
      ),
    );
  }
}