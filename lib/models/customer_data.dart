import '../card_type.dart';
import '../operation_type.dart';

class CustomerData {

  String fullName;

  List<CardType> cards;

  OperationType operationType;

  CustomerData({

    required this.fullName,

    required this.cards,

    required this.operationType,

  });

}