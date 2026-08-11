import 'package:flutter/material.dart';

/// وضعیت یادآور یک مشتری (چه پوشه‌ی اصلی، چه ZIP هم‌نامش):
/// notSent      → قرمز: هنوز برای سرپرست فرستاده نشده
/// awaitingReceipt → زرد: فرستاده شده اما رسیدش هنوز نیامده
/// receiptReceived → سبز: رسید ثبت شده
enum ReminderStatus {
  notSent,
  awaitingReceipt,
  receiptReceived,
}

extension ReminderStatusColor on ReminderStatus {
  /// اگر null باشد یعنی اصلاً نقطه‌ای نشان داده نشود (فقط برای جمع‌بندی تب استفاده می‌شود).
  Color get dotColor {
    switch (this) {
      case ReminderStatus.notSent:
        return Colors.red;
      case ReminderStatus.awaitingReceipt:
        return Colors.amber;
      case ReminderStatus.receiptReceived:
        return Colors.green;
    }
  }
}