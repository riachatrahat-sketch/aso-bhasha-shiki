/// Reads a date from an ISO string, a DateTime or a Firestore Timestamp
/// (anything with a `toDate()` method) without importing Firestore here.
DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

double asDouble(dynamic v) => (v is num) ? v.toDouble() : 0;

int asInt(dynamic v) => (v is num) ? v.toInt() : 0;

/// yyyy-MM-dd in the device's local time zone.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Stable string hash (String.hashCode is not guaranteed stable across runs).
int stableHash(String s) {
  var h = 5381;
  for (final c in s.codeUnits) {
    h = ((h << 5) + h + c) & 0x7fffffff;
  }
  return h;
}

class AppException implements Exception {
  AppException(this.message);
  final String message;

  @override
  String toString() => message;
}
