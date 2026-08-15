import 'package:flutter/material.dart';
import 'camera_page.dart';
import '../app_enum.dart';
import '../models/customer_data.dart';

class OptionalCardsPage extends StatefulWidget {
  final CustomerData customer;

  const OptionalCardsPage({super.key, required this.customer});

  @override
  State<OptionalCardsPage> createState() => _OptionalCardsPageState();
}

class _OptionalCardsPageState extends State<OptionalCardsPage> {
  bool nationalSelected = false;
  bool manzelatSelected = false;
  bool personalPhotoSelected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مدارک اختیاری')),

      body: Column(
        children: [
          Text('مشتری: ${widget.customer.fullName}'),

          CheckboxListTile(
            title: const Text('گرفتن کارت ملی'),
            value: nationalSelected,
            onChanged: (value) {
              setState(() {
                nationalSelected = value!;
              });
            },
          ),

          CheckboxListTile(
            title: const Text('گرفتن کارت منزلت'),
            value: manzelatSelected,
            onChanged: (value) {
              setState(() {
                manzelatSelected = value!;
              });
            },
          ),
            CheckboxListTile(
            title: const Text('گرفتن عکس پرسنلی '),
            value: personalPhotoSelected,
            onChanged: (value) {
              setState(() {
                personalPhotoSelected = value!;
              });
            },
          ),

          ElevatedButton(
            onPressed: () {
              widget.customer.cards.clear();

              widget.customer.cards.add(CardType.ticket);

              if (nationalSelected) {
                widget.customer.cards.add(CardType.national);
              }

              if (manzelatSelected) {
                widget.customer.cards.add(CardType.manzelat);
              }
              if (personalPhotoSelected) {
                widget.customer.cards.add(CardType.personalPhoto);
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraPage(customer: widget.customer,),
                ),
              );
            },

            child: const Text('ادامه'),
          ),
        ],
      ),
    );
  }
}
