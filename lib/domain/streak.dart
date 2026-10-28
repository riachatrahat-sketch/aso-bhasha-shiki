import '../core/utils/json_helpers.dart';

class StreakCalculator {
  StreakCalculator._();

  /// Consecutive active days ending today. If today has no activity yet the
  /// streak is still alive when yesterday was active (the day is not over).
  static int current(Set<String> activeDays, DateTime today) {
    var day = DateTime(today.year, today.month, today.day);
    if (!activeDays.contains(dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
      // DateTime.subtract on local midnight can land 1h off across DST, so rebuild.
      day = DateTime(day.year, day.month, day.day);
    }
    var count = 0;
    while (activeDays.contains(dayKey(day))) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }
}
