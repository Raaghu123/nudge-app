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
}

/// Categorizes the reminder for grouping and filtering.
enum Category {
  /// Medication or health-related reminder.
  medication,
  /// Water or hydration reminder.
  water,
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
  const Reminder({
    this.id,
    required this.title,
    required this.hour,
    required this.minute,
    required this.recurrence,
    required this.daysMask,
    required this.category,
    required this.status,
    this.nextFireAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Database primary key; null for new reminders not yet inserted.
  final int? id;

  /// User-visible title of the reminder.
  final String title;

  /// Hour of day in 24-hour format (0–23).
  final int hour;

  /// Minute of hour (0–59).
  final int minute;

  /// How often the reminder repeats.
  final Recurrence recurrence;

  /// Bitmask of weekdays when the reminder fires.
  /// Bit i corresponds to DateTime.weekday value i (Monday=1 ... Sunday=7).
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

  /// Serializes this reminder to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'hour': hour,
      'minute': minute,
      'recurrence': recurrence.name,
      'days_mask': daysMask,
      'category': category.name,
      'status': status.name,
      'next_fire_at': nextFireAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a [Reminder] from a JSON-compatible map.
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as int?,
      title: json['title'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      recurrence: Recurrence.values.byName(json['recurrence'] as String),
      daysMask: json['days_mask'] as int,
      category: Category.values.byName(json['category'] as String),
      status: ReminderStatus.values.byName(json['status'] as String),
      nextFireAt: DateTime.tryParse(json['next_fire_at'] as String? ?? ''),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Returns a copy of this reminder with the given fields replaced.
  ///
  /// The [updatedAt] field defaults to the current time.
  Reminder copyWith({
    int? id,
    String? title,
    int? hour,
    int? minute,
    Recurrence? recurrence,
    int? daysMask,
    Category? category,
    ReminderStatus? status,
    DateTime? nextFireAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      recurrence: recurrence ?? this.recurrence,
      daysMask: daysMask ?? this.daysMask,
      category: category ?? this.category,
      status: status ?? this.status,
      nextFireAt: nextFireAt ?? this.nextFireAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}