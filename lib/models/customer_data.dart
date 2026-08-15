import '../app_enum.dart';


class CustomerData {
  String fullName;

  List<CardType> cards;

  OperationType operationType;

  int currentCardIndex;

  CustomerData({
    required this.fullName,
    required this.cards,
    required this.operationType,
    this.currentCardIndex = 0,
  });
}