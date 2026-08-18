import '../app_enum.dart';


class CustomerData {
  String fullName;

  List<CardType> cards;

  OperationType operationType;

  int currentCardIndex;

  // سریال کارت بلیت که از NFC یا ورود دستی دریافت می‌شود.
  String? ticketNumber;

  CustomerData({
    required this.fullName,
    required this.cards,
    required this.operationType,
    this.currentCardIndex = 0,
    this.ticketNumber,
  });
}
