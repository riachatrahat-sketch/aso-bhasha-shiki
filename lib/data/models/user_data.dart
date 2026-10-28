import '../../core/utils/json_helpers.dart';
import 'lesson.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.preferredLanguage,
    required this.dailyGoal,
  });

  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String gender;

  /// 'en' or 'ja'.
  final String preferredLanguage;

  /// Questions to pass per day.
  final int dailyGoal;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Learner' : parts.first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = String.fromCharCode(parts.first.runes.first).toUpperCase();
    if (parts.length == 1) return first;
    return first + String.fromCharCode(parts.last.runes.first).toUpperCase();
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) => UserProfile(
        uid: uid,
        fullName: (m['fullName'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        gender: (m['gender'] as String?) ?? 'Prefer not to say',
        preferredLanguage: (m['preferredLanguage'] as String?) ?? 'en',
        dailyGoal: (m['dailyGoal'] as num?)?.toInt() ?? 5,
      );
}

/// Raw score total (can be negative); use ScoringEngine.displayTotal to show it.
class UserStats {
  const UserStats({required this.totalPoints});
  const UserStats.empty() : totalPoints = 0;

  final double totalPoints;

  factory UserStats.fromMap(Map<String, dynamic> m) =>
      UserStats(totalPoints: asDouble(m['totalPoints']));
}

/// One learning day: how many questions were passed and the points earned.
class DailyActivity {
  const DailyActivity({required this.date, required this.passed, required this.points});

  /// yyyy-MM-dd
  final String date;
  final int passed;
  final double points;

  factory DailyActivity.fromMap(String id, Map<String, dynamic> m) => DailyActivity(
        date: id,
        passed: asInt(m['passed']),
        points: asDouble(m['points']),
      );
}

class Mistake {
  const Mistake({
    required this.id,
    required this.lessonId,
    required this.activity,
    required this.index,
    required this.prompt,
    required this.expected,
    required this.given,
    required this.at,
  });

  final String id;
  final String lessonId;
  final Activity activity;
  final int index;
  final String prompt;
  final String expected;
  final String given;
  final DateTime at;

  factory Mistake.fromMap(String id, Map<String, dynamic> m) => Mistake(
        id: id,
        lessonId: (m['lessonId'] as String?) ?? '',
        activity: ActivityX.parse((m['activity'] as String?) ?? 'speaking'),
        index: asInt(m['index']),
        prompt: (m['prompt'] as String?) ?? '',
        expected: (m['expected'] as String?) ?? '',
        given: (m['given'] as String?) ?? '',
        at: parseDate(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'activity': activity.name,
        'index': index,
        'prompt': prompt,
        'expected': expected,
        'given': given,
        'at': at.toIso8601String(),
      };
}
