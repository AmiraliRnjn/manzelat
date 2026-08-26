import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../services/work_calendar_status_service.dart';

const List<String> _persianMonthNames = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

// ترتیب از شنبه تا جمعه (هفته‌ی شمسی از شنبه شروع می‌شود).
const List<String> _persianWeekDayShort = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

/// یک تقویم شمسی سفارشی، جایگزین [showPersianDatePicker]، که علاوه بر
/// انتخاب تاریخ، روی دایره‌ی هر روزی که پوشه یا ZIP بدون رسید (قرمز یا
/// زرد) دارد یک نقطه‌ی قرمز کوچک (مثل نقطه‌های یادآور روی پوشه‌ها و
/// تب‌ها) نشان می‌دهد؛ تا کاربر بفهمد آن روز کار ناتمام دارد و بعداً
/// برگردد سراغش.
Future<Jalali?> showWorkCalendarPicker({
  required BuildContext context,
  required Jalali initialDate,
  required Jalali firstDate,
  required Jalali lastDate,
}) {
  return showDialog<Jalali>(
    context: context,
    builder: (context) => _WorkCalendarDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

int _compareJalali(Jalali a, Jalali b) {
  if (a.year != b.year) return a.year.compareTo(b.year);
  if (a.month != b.month) return a.month.compareTo(b.month);
  return a.day.compareTo(b.day);
}

class _WorkCalendarDialog extends StatefulWidget {
  final Jalali initialDate;
  final Jalali firstDate;
  final Jalali lastDate;

  const _WorkCalendarDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_WorkCalendarDialog> createState() => _WorkCalendarDialogState();
}

class _WorkCalendarDialogState extends State<_WorkCalendarDialog> {
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color darkText = Color(0xFF172554);
  static const Color secondaryText = Color(0xFF707789);

  late int _displayedYear;
  late int _displayedMonth;
  Set<int> _incompleteDays = {};
  bool _loadingDots = true;

  @override
  void initState() {
    super.initState();
    _displayedYear = widget.initialDate.year;
    _displayedMonth = widget.initialDate.month;
    _loadIncompleteDays();
  }

  Future<void> _loadIncompleteDays() async {
    setState(() => _loadingDots = true);
    final year = _displayedYear;
    final month = _displayedMonth;
    final days = await WorkCalendarStatusService.incompleteDaysForMonth(
      year,
      month,
    );
    // اگر کاربر تا وقتی بررسی تمام می‌شد ماه را عوض کرده بود، نتیجه‌ی
    // کهنه را نادیده می‌گیریم.
    if (!mounted || year != _displayedYear || month != _displayedMonth) {
      return;
    }
    setState(() {
      _incompleteDays = days;
      _loadingDots = false;
    });
  }

  bool get _canGoPrev {
    final targetYear = _displayedMonth == 1 ? _displayedYear - 1 : _displayedYear;
    final targetMonth = _displayedMonth == 1 ? 12 : _displayedMonth - 1;
    return targetYear > widget.firstDate.year ||
        (targetYear == widget.firstDate.year &&
            targetMonth >= widget.firstDate.month);
  }

  bool get _canGoNext {
    final targetYear = _displayedMonth == 12 ? _displayedYear + 1 : _displayedYear;
    final targetMonth = _displayedMonth == 12 ? 1 : _displayedMonth + 1;
    return targetYear < widget.lastDate.year ||
        (targetYear == widget.lastDate.year &&
            targetMonth <= widget.lastDate.month);
  }

  void _goPrevMonth() {
    if (!_canGoPrev) return;
    setState(() {
      if (_displayedMonth == 1) {
        _displayedYear -= 1;
        _displayedMonth = 12;
      } else {
        _displayedMonth -= 1;
      }
    });
    _loadIncompleteDays();
  }

  void _goNextMonth() {
    if (!_canGoNext) return;
    setState(() {
      if (_displayedMonth == 12) {
        _displayedYear += 1;
        _displayedMonth = 1;
      } else {
        _displayedMonth += 1;
      }
    });
    _loadIncompleteDays();
  }

  @override
  Widget build(BuildContext context) {
    final monthLength = Jalali(_displayedYear, _displayedMonth, 1).monthLength;
    final firstDayOfMonth = Jalali(_displayedYear, _displayedMonth, 1);
    final leadingBlanks = firstDayOfMonth.weekDay - 1;
    final today = Jalali.now();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: primaryBlue),
                    onPressed: _canGoPrev ? _goPrevMonth : null,
                  ),
                  Text(
                    '${_persianMonthNames[_displayedMonth - 1]} $_displayedYear',
                    style: const TextStyle(
                      fontFamily: 'Traffic',
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: darkText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: primaryBlue),
                    onPressed: _canGoNext ? _goNextMonth : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: _persianWeekDayShort
                    .map(
                      (w) => Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: const TextStyle(
                              fontFamily: 'Traffic',
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 320,
                child: _loadingDots
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                        ),
                        itemCount: leadingBlanks + monthLength,
                        itemBuilder: (context, index) {
                          if (index < leadingBlanks) {
                            return const SizedBox.shrink();
                          }

                          final day = index - leadingBlanks + 1;
                          final date =
                              Jalali(_displayedYear, _displayedMonth, day);
                          final isSelected =
                              date.year == widget.initialDate.year &&
                                  date.month == widget.initialDate.month &&
                                  date.day == widget.initialDate.day;
                          final isToday = date.year == today.year &&
                              date.month == today.month &&
                              date.day == today.day;
                          final isOutOfRange =
                              _compareJalali(date, widget.firstDate) < 0 ||
                                  _compareJalali(date, widget.lastDate) > 0;
                          final hasIncomplete = _incompleteDays.contains(day);

                          return _DayCell(
                            day: day,
                            isSelected: isSelected,
                            isToday: isToday,
                            isDisabled: isOutOfRange,
                            showReminderDot: hasIncomplete,
                            onTap: isOutOfRange
                                ? null
                                : () => Navigator.pop(context, date),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'انصراف',
                    style: TextStyle(fontFamily: 'Traffic'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color darkText = Color(0xFF172554);

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool isDisabled;
  final bool showReminderDot;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isDisabled,
    required this.showReminderDot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryBlue : Colors.transparent,
                border: isToday && !isSelected
                    ? Border.all(color: primaryBlue, width: 1.2)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontFamily: 'Traffic',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDisabled
                      ? const Color(0xFFC7CBD4)
                      : isSelected
                          ? Colors.white
                          : darkText,
                ),
              ),
            ),
            if (showReminderDot)
              const Positioned(
                bottom: 2,
                child: _ReminderDot(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReminderDot extends StatelessWidget {
  const _ReminderDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red,
      ),
    );
  }
}
