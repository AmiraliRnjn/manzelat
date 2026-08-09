import 'package:flutter/material.dart';
import 'camera_page.dart';
import '../card_type.dart';
import '../mode.dart';
import '../operation_type.dart';
import 'optional_cards_page.dart';
import '../models/customer_data.dart';

class CustomerInfoPage extends StatefulWidget {

  final Mode mode;
  final OperationType operationType;

  const CustomerInfoPage({
    super.key,
    required this.mode,
    required this.operationType,
  });

  @override
  State<CustomerInfoPage> createState() => _CustomerInfoPageState();
}

class _CustomerInfoPageState extends State<CustomerInfoPage> {

  final TextEditingController fullNameController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('اطلاعات مشتری'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          children: [

            TextField(

              controller: fullNameController,

              decoration: const InputDecoration(
                labelText: 'نام و نام خانوادگی',
                hintText: 'مثال: علی رضایی',
                border: OutlineInputBorder(),
              ),

            ),

            const SizedBox(height: 20),

            ElevatedButton(

              onPressed: () {

                if (fullNameController.text.trim().isEmpty) {
                  return;
                }

                CustomerData customer = CustomerData(

                  fullName: fullNameController.text.trim(),

                  cards: [],

                  operationType: widget.operationType,

                  );

                switch (widget.mode) {

                  case Mode.optional:

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OptionalCardsPage(
                          customer: customer,
                        ),
                      ),
                    );

                    break;

                  case Mode.noNational:

                  customer.cards = [
                    CardType.ticket,
                    CardType.national,
                    ];


                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraPage(
                          customer: customer,
                        ),
                      ),
                    );

                    break;

                  case Mode.noManzelat:

                  customer.cards = [
                    CardType.ticket,
                    CardType.manzelat,
                    ];

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraPage(
                          customer: customer,
                        ),
                      ),
                    );

                    break;

                  case Mode.all:

                  customer.cards = [
                    CardType.ticket,
                    CardType.national,
                    CardType.manzelat
                    ];

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraPage(
                          customer: customer,
                        ),
                      ),
                    );

                    break;

                }

              },

              child: const Text('شروع'),

            ),

          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    fullNameController.dispose();
    super.dispose();
  }

}