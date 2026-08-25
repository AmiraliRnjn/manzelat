
import '../app_enum.dart';


class CustomerData {
  String fullName;

  /// کد ملی مشتری — شناسه‌ی یکتای هر مشتری. از همان صفحه‌ی اول
  /// (اطلاعات مشتری) گرفته می‌شود و برای ساخت پوشه‌ی مشتری استفاده
  /// می‌شود؛ همین باعث می‌شود در Restore/Merge بین چند گوشی، دو مشتری
  /// هم‌نام هرگز با هم قاطی نشوند.
  String nationalCode;

  List<CardType> cards;

  OperationType operationType;

  int currentCardIndex;

  // سریال کارت بلیت که از NFC یا ورود دستی دریافت می‌شود.
  String? ticketNumber;

  CustomerData({
    required this.fullName,
    required this.nationalCode,
    required this.cards,
    required this.operationType,
    this.currentCardIndex = 0,
    this.ticketNumber,
  });
}



