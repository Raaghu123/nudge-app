import 'dart:convert';

/// Defines how often a reminder repeats.
enum Recurrence {
  /// Fires only once.
  once,
  /// Fires every day.
  daily,
  /// Fires every week on the same weekday.
  weekly,
  /// Fires on a custom set of weekdays defined by [Reminder.daysMask].
  custom,
  /// Repeats every [Reminder.intervalMinutes] minutes. Without a window
  /// the next fire is always now + the interval; with
  /// [Reminder.windowStartMinutes]/[Reminder.windowEndMinutes] fires are
  /// the stateless ticks windowStart + N * interval inside the window.
  interval,
}

/// Categorizes the reminder for grouping and filtering.
enum Category {
  /// Medication or health-related reminder.
  medication,
  /// Water or hydration reminder.
  water,
  /// Workout or movement reminder (added for the Phase 2.1 natural-language
  /// parser; UI switches predate it — wire color/label handling when the
  /// parser is connected to the UI).
  exercise,
  /// Errand or chore reminder.
  errand,
  /// Study or learning reminder.
  study,
  /// Appointment or meeting reminder.
  appointment,
  /// Payment or bill reminder.
  payment,
  /// Any other reminder type.
  other,
}

/// How important a reminder is (Phase 2: set by the natural-language
/// parser from per-category defaults, editable on the confirm screen).
enum Importance {
  low,
  medium,
  high,
}

/// How time-sensitive a reminder is (Phase 2: set by the natural-language
/// parser from per-category defaults, editable on the confirm screen).
enum Urgency {
  low,
  medium,
  high,
}

/// Represents the current lifecycle state of a reminder.
enum ReminderStatus {
  /// Reminder is scheduled but not yet due.
  pending,
  /// Reminder time has arrived and it is ready to fire.
  due,
  /// Reminder notification has been delivered to the user.
  delivered,
  /// User has acknowledged the reminder (e.g., tapped the notification).
  acknowledged,
  /// User has marked the reminder as done.
  completed,
}

/// A single reminder entry with scheduling and status information.
class Reminder {
  /// Creates a new [Reminder].
  ///
  /// The [id] and [nextFireAt] fields are optional; the database assigns [id]
  /// and the scheduler computes [nextFireAt].
  ///
  /// [timesOfDayMinutes] is normalized to a sorted unique list. It must
  /// hold at least one entry in 0..1439 (enforced by assert; producers
  /// such as the NL parser and [Reminder.fromJson] normalize first).
  Reminder({
    this.id,
    required this.title,
    required List<int> timesOfDayMinutes,
    required this.recurrence,
    required this.daysMask,
    required this.category,
    required this.status,
    this.nextFireAt,
    required this.createdAt,
    required this.updatedAt,
    this.importance = Importance.medium,
    this.urgency = Urgency.low,
    this.intervalMinutes,
    this.windowStartMinutes,
    this.windowEndMinutes,
  })  : assert(timesOfDayMinutes.isNotEmpty,
            'timesOfDayMinutes needs at least one entry'),
        assert(
            timesOfDayMinutes.every((t) => t >= 0 && t < 1440),
            'timesOfDayMinutes entries must be minutes since midnight'),
        timesOfDayMinutes = _normalizedTimes(timesOfDayMinutes);

  /// Database primary key; null for new reminders not yet inserted.
  final int? id;

  /// User-visible title of the reminder.
  final String title;

  /// Fire times as minutes since midnight, sorted unique, each 0..1439.
  /// For daily/weekly/custom these are the times of day; for interval
  /// reminders the list is informational ([hour]/[minute] = first tick).
  final List<int> timesOfDayMinutes;

  /// Hour of day in 24-hour format (0–23), derived from the first entry
  /// of [timesOfDayMinutes] so existing read sites keep working.
  int get hour => timesOfDayMinutes[0] ~/ 60;

  /// Minute of hour (0–59), derived from the first entry of
  /// [timesOfDayMinutes] so existing read sites keep working.
  int get minute => timesOfDayMinutes[0] % 60;

  /// How often the reminder repeats.
  final Recurrence recurrence;

  /// Bitmask of weekdays when the reminder fires.
  /// Bit i corresponds to DateTime.weekday value i (Monday=1 ... Sunday=7).
  /// Also applies to [Recurrence.interval] (0 = all days).
  final int daysMask;

  /// Category for grouping and filtering.
  final Category category;

  /// Current lifecycle state.
  final ReminderStatus status;

  /// Next scheduled fire time in UTC; null if not yet computed.
  final DateTime? nextFireAt;

  /// Creation timestamp in UTC.
  final DateTime createdAt;

  /// Last modification timestamp in UTC.
  final DateTime updatedAt;

  /// How important this reminder is. Defaults to medium.
  final Importance importance;

  /// How time-sensitive this reminder is. Defaults to low.
  final Urgency urgency;

  /// Repeat interval in minutes for [Recurrence.interval]; null otherwise.
  final int? intervalMinutes;

  /// Window start as minutes since midnight, only with
  /// [Recurrence.interval]; null means no window.
  final int? windowStartMinutes;

  /// Window end as minutes since midnight, only with
  /// [Recurrence.interval]; null means no window. Must be greater than
  /// [windowStartMinutes] (windows wrapping midnight are deferred).
  final int? windowEndMinutes;

  /// Sorts and dedupes a raw times list for the constructor.
  static List<int> _normalizedTimes(List<int> times) {
    final sorted = times.toSet().toList()..sort();
    return sorted;
  }

  /// Serializes this reminder to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'hour': hour,
      'minute': minute,
      'times_of_day_minutes': jsonEncode(timesOfDayMinutes),
      'recurrence': recurrence.name,
      'days_mask': daysMask,
      'category': category.name,
      'status': status.name,
      'next_fire_at': nextFireAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'importance': importance.name,
      'urgency': urgency.name,
      'interval_minutes': intervalMinutes,
      'window_start_minutes': windowStartMinutes,
      'window_end_minutes': windowEndMinutes,
    };
  }

  /// Looks up [raw] in [values] by name, returning [fallback] when [raw]
  /// is missing, null, or unknown (e.g. rows written before the column
  /// existed).
  static T _namedOr<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) {
    if (raw is String) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
    }
    return fallback;
  }

  /// Decodes the v4 times list; falls back to the legacy hour/minute
  /// columns for rows written before the v4 migration.
  static List<int> _decodeTimes(Object? raw, int hour, int minute) {
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final times = decoded.whereType<int>().toList();
          if (times.isNotEmpty) return times;
        }
      } on FormatException {
        // Corrupt payload: fall through to the legacy columns.
      }
    }
    return [hour * 60 + minute];
  }

  /// Creates a [Reminder] from a JSON-compatible map.
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as int?,
      title: json['title'] as String,
      timesOfDayMinutes: _decodeTimes(
        json['times_of_day_minutes'],
        json['hour'] as int,
        json['minute'] as int,
      ),
      recurrence: Recurrence.values.byName(json['recurrence'] as String),
      daysMask: json['days_mask'] as int,
      category: Category.values.byName(json['category'] as String),
      status: ReminderStatus.values.byName(json['status'] as String),
      nextFireAt: DateTime.tryParse(json['next_fire_at'] as String? ?? ''),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      importance:
          _namedOr(Importance.values, json['importance'], Importance.medium),
      urgency: _namedOr(Urgency.values, json['urgency'], Urgency.low),
      intervalMinutes: json['interval_minutes'] as int?,
      windowStartMinutes: json['window_start_minutes'] as int?,
      windowEndMinutes: json['window_end_minutes'] as int?,
    );
  }

  /// Returns a copy of this reminder with the given fields replaced.
  ///
  /// The [updatedAt] field defaults to the current time.
  Reminder copyWith({
    int? id,
    String? title,
    List<int>? timesOfDayMinutes,
    Recurrence? recurrence,
    int? daysMask,
    Category? category,
    ReminderStatus? status,
    DateTime? nextFireAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Importance? importance,
    Urgency? urgency,
    int? intervalMinutes,
    int? windowStartMinutes,
    int? windowEndMinutes,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      timesOfDayMinutes: timesOfDayMinutes ?? this.timesOfDayMinutes,
      recurrence: recurrence ?? this.recurrence,
      daysMask: daysMask ?? this.daysMask,
      category: category ?? this.category,
      status: status ?? this.status,
      nextFireAt: nextFireAt ?? this.nextFireAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      importance: importance ?? this.importance,
      urgency: urgency ?? this.urgency,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      windowStartMinutes: windowStartMinutes ?? this.windowStartMinutes,
      windowEndMinutes: windowEndMinutes ?? this.windowEndMinutes,
    );
  }
}