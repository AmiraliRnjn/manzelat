import 'package:flutter/material.dart';
import '../card_type.dart';
import '../models/customer_data.dart';

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