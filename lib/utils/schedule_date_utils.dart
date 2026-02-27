import '../config/schedule_service_config.dart';

class ScheduleDateUtils {
  const ScheduleDateUtils._();

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime getNextAvailableDate(DateTime date) {
    DateTime currentDate = DateTime(date.year, date.month, date.day);
    while (isHolidayOrSunday(currentDate)) {
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return currentDate;
  }

  static DateTime getMinBookingDate() {
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return getNextAvailableDate(tomorrow);
  }

  static bool isHolidayOrSunday(DateTime date) {
    return date.weekday == DateTime.sunday || isBrazilHoliday(date);
  }

  static bool isBrazilHoliday(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final year = normalizedDate.year;

    final Set<DateTime> fixedHolidays = {
      DateTime(year, 1, 1),
      DateTime(year, 4, 21),
      DateTime(year, 5, 1),
      DateTime(year, 9, 7),
      DateTime(year, 10, 12),
      DateTime(year, 11, 2),
      DateTime(year, 11, 15),
      DateTime(year, 12, 25),
    };

    final easterSunday = calculateEasterSunday(year);
    final Set<DateTime> movableHolidays = {
      easterSunday.subtract(const Duration(days: 48)),
      easterSunday.subtract(const Duration(days: 47)),
      easterSunday.subtract(const Duration(days: 2)),
      easterSunday,
      easterSunday.add(const Duration(days: 60)),
    };

    return fixedHolidays.contains(normalizedDate) ||
        movableHolidays.contains(normalizedDate);
  }

  static DateTime calculateEasterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static List<String> getDefaultSlotsForDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
      case DateTime.tuesday:
      case DateTime.wednesday:
      case DateTime.thursday:
      case DateTime.friday:
        return ScheduleServiceConfig.weekdayDefaultSlots;
      case DateTime.saturday:
        return ScheduleServiceConfig.saturdayDefaultSlots;
      default:
        return const [];
    }
  }
}
