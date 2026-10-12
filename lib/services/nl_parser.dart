import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/recurrence.dart';

/// Result of parsing a natural-language reminder request.
///
/// Every extracted field carries a confidence score in [0, 1]. The capture
/// UI treats any field with confidence below 0.7 as a guess and marks it
/// for the user to confirm (UX.md section 2.1).
class ParsedReminder {
  const ParsedReminder({
    required this.title,
    required this.titleConfidence,
    required this.hour,
    required this.minute,
    required this.timeConfidence,
    required this.recurrence,
    required this.daysMask,
    required this.recurrenceConfidence,
    required this.category,
    required this.categoryConfidence,
    required this.importance,
    required this.urgency,
    required this.scheduledAt,
    this.intervalMinutes,
  });

  /// Reminder title with command prefixes and time/recurrence expressions
  /// stripped out.
  final String title;

  /// 0.9 when a known command prefix was stripped, 0.6 when the title is
  /// a verbatim guess, 0.5 when even that was empty and we fell back.
  final double titleConfidence;

  /// Hour of day in 24-hour format (0-23).
  final int hour;

  /// Minute of hour (0-59).
  final int minute;

  /// 1.0 explicit am/pm, 0.8 tomorrow/tonight or bare "at X",
  /// 0.7 relative ("in N minutes/hours"), 0.5 inferred (time-of-day
  /// word, category default, or bare default).
  final double timeConfidence;

  /// Detected recurrence.
  final Recurrence recurrence;

  /// Weekday bitmask for weekly/custom (bit i = DateTime.weekday i).
  final int daysMask;

  /// 1.0 explicit ("every day", "every morning", ...), 0.95 interval
  /// expression ("every hour", "every N minutes"), 0.9 weekday or
  /// named day(s), 0.8 default assumption (no recurrence words found).
  final double recurrenceConfidence;

  /// Detected category.
  final Category category;

  /// 1.0 strong keyword, 0.7 general keyword only, 0.5 no keyword
  /// (falls back to [Category.other]).
  final double categoryConfidence;

  /// Per-category default importance (see [_importanceFor]).
  final Importance importance;

  /// Per-category default urgency (see [_urgencyFor]).
  final Urgency urgency;

  /// First fire time. Never null: one-off times that already passed today
  /// roll forward to tomorrow.
  final DateTime scheduledAt;

  /// Repeat interval in minutes for [Recurrence.interval] ("every hour"
  /// -> 60); null for every other recurrence. The first tick is already
  /// in [scheduledAt] (now + this offset).
  final int? intervalMinutes;
}

/// Deterministic rule-based parser for natural-language reminders.
///
/// Primary path per ARCHITECTURE.md section 7: hand-written rules, no
/// packages, no network. Pure Dart so it is unit-testable without a
/// device.
///
/// Pattern table (owner-authorized):
/// - Title: strips "remind me to", "remind me", "remind to",
///   "don't forget to", "i need to", "i have to".
/// - Time: "at X", "at Xam/pm", "at HH:MM", "in N minutes/hours",
///   "tomorrow", "tomorrow at X", "tonight", "this morning/afternoon/
///   evening/night", bare time-of-day words.
/// - Recurrence: "every morning/night/evening/day", "every weekday",
///   "every <day name>", "every hour", "every N minutes".
/// - Category keywords per table below.
/// - Category default times and importance/urgency defaults per table.
///
/// Known limitations:
/// - Sub-daily intervals ("every hour", "every N minutes") parse to
///   [Recurrence.interval] with [ParsedReminder.intervalMinutes] set and
///   [ParsedReminder.scheduledAt] holding the first tick.
/// - Twice-daily phrasing ("every morning and night") keeps the first
///   time-of-day hint only.
class NlParser {
  /// Parses [input] into a [ParsedReminder].
  ///
  /// [now] is the reference time (defaults to [DateTime.now]); tests
  /// pass a fixed clock for determinism.
  static ParsedReminder parse(String input, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final normalized = input.replaceAll('\u2019', "'").trim();
    final text = normalized.toLowerCase();

    // Spans of [text] consumed by structural matches. The title is
    // whatever is left after removing these spans from the original.
    final spans = <_Span>[];

    // --- 1. Command prefix -> title confidence. ---
    var titleConfidence = 0.6;
    final prefixMatch = _prefixPattern.firstMatch(text);
    if (prefixMatch != null) {
      spans.add(_Span(0, prefixMatch.end));
      titleConfidence = 0.9;
    }

    // --- 2. Category (scanned on the full text; structural words never
    // contain category keywords). ---
    final categoryHit = _detectCategory(text);

    // --- 3. Recurrence (before bare time-of-day words so that "every
    // morning" is consumed as one recurrence span). ---
    final recurrenceHit = _detectRecurrence(text, spans);

    // --- 4. Time. ---
    final timeHit = _detectTime(
      text,
      spans,
      recurrenceHit,
      categoryHit.category,
    );

    // --- 5. Schedule. ---
    final int hour;
    final int minute;
    final DateTime scheduledAt;
    if (timeHit.relativeMinutes != null) {
      final base = ref.add(Duration(minutes: timeHit.relativeMinutes!));
      hour = base.hour;
      minute = base.minute;
      scheduledAt = base;
    } else {
      hour = timeHit.hour;
      minute = timeHit.minute;
      DateTime base;
      if (timeHit.isTomorrow) {
        base = DateTime(ref.year, ref.month, ref.day + 1, hour, minute);
      } else {
        base = nextOccurrence(
              now: ref,
              hour: hour,
              minute: minute,
              recurrence: recurrenceHit.recurrence,
              daysMask: recurrenceHit.daysMask,
            ) ??
            // One-off time already passed today: roll to tomorrow rather
            // than returning null. Weekly/custom masks always resolve.
            DateTime(ref.year, ref.month, ref.day + 1, hour, minute);
      }
      scheduledAt = base;
    }

    // --- 6. Title: original text minus consumed spans. Span indices
    // come from the lowercased copy; lowercasing can change string
    // length for exotic Unicode, so fall back to the lowered text when
    // lengths diverge (title keeps working, just loses original case).
    final titleSource =
        normalized.length == text.length ? normalized : text;
    spans.sort((a, b) => a.start.compareTo(b.start));
    final buffer = StringBuffer();
    var cursor = 0;
    for (final span in spans) {
      if (span.start > cursor) {
        buffer.write(titleSource.substring(cursor, span.start));
      }
      cursor = span.end > cursor ? span.end : cursor;
    }
    if (cursor < titleSource.length) {
      buffer.write(titleSource.substring(cursor));
    }
    var title =
        buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(
              RegExp(r'[.,!;:\s]+$'),
              '',
            );
    if (title.isEmpty) {
      title = 'Reminder';
      titleConfidence = 0.5;
    }

    return ParsedReminder(
      title: title,
      titleConfidence: titleConfidence,
      hour: hour,
      minute: minute,
      timeConfidence: timeHit.confidence,
      recurrence: recurrenceHit.recurrence,
      daysMask: recurrenceHit.daysMask,
      recurrenceConfidence: recurrenceHit.confidence,
      category: categoryHit.category,
      categoryConfidence: categoryHit.confidence,
      importance: _importanceFor(categoryHit.category),
      urgency: _urgencyFor(categoryHit.category),
      scheduledAt: scheduledAt,
      intervalMinutes: recurrenceHit.intervalMinutes,
    );
  }

  // ------------------------------------------------------------------
  // Patterns.
  // ------------------------------------------------------------------

  static final RegExp _prefixPattern = RegExp(
    r"^(remind me to|remind me|remind to|don't forget to|do not forget to|i need to|i have to)\b\s*",
  );

  static final RegExp _relativePattern = RegExp(
    r'\bin\s+(\d+)\s*(minutes?|mins?|hours?|hrs?)\b',
  );

  static final RegExp _tomorrowAtPattern = RegExp(
    r'\btomorrow\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\b',
  );
  static final RegExp _tomorrowPattern = RegExp(r'\btomorrow\b');

  static final RegExp _tonightPattern = RegExp(r'\btonight\b');

  static final RegExp _thisPartPattern = RegExp(
    r'\bthis\s+(morning|afternoon|evening|night)\b',
  );

  static final RegExp _atTimePattern = RegExp(
    r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\b',
  );

  static final RegExp _barePartPattern =
      RegExp(r'\b(morning|afternoon|evening|night)\b');

  static final RegExp _everyDayPattern =
      RegExp(r'\bevery\s+day\b|\beveryday\b|\bdaily\b');

  static final RegExp _everyPartPattern =
      RegExp(r'\bevery\s+(morning|evening|night)\b');

  static final RegExp _everyWeekdayPattern =
      RegExp(r'\bevery\s+weekdays?\b|\bweekdays\b');

  // Owner extension beyond the minimum table: weekend support.
  static final RegExp _everyWeekendPattern =
      RegExp(r'\bevery\s+weekends?\b|\bweekends?\b');

  static final RegExp _intervalPattern = RegExp(
    r'\bevery\s+(\d+)\s*(minutes?|mins?|hours?|hrs?)\b|\bevery\s+hour\b|\bhourly\b',
  );

  static const List<String> _dayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  /// Time-of-day word -> hour. "night" defaults to 21:00; medication keeps
  /// the table's explicit 20:00 rule (see [_detectTime]).
  static const Map<String, int> _partHours = {
    'morning': 8,
    'afternoon': 14,
    'evening': 19,
    'night': 21,
  };

  // ------------------------------------------------------------------
  // Category keywords: strong hits score 2, general hits score 1.
  // ------------------------------------------------------------------

  static final Map<Category, _KeywordSet> _categoryKeywords = {
    Category.medication: const _KeywordSet(
      strong: [
        r'pills?\b',
        r'medicines?\b',
        r'medication\b',
        r'tablets?\b',
        r'prescription\b',
        r'insulin\b',
        r'thyroid\b',
      ],
      general: [
        r'\bmeds?\b',
        r'\bdose\b',
        r'\bbp\b',
        r'vitamins?\b',
      ],
    ),
    Category.water: const _KeywordSet(
      strong: [r'water\b'],
      general: [r'hydrat\w*\b'],
    ),
    Category.exercise: const _KeywordSet(
      strong: [
        r'workouts?\b',
        r'exercise\b',
        r'\bgym\b',
        r'yoga\b',
      ],
      general: [
        r'runs?\b',
        r'running\b',
        r'jogs?\b',
        r'jogging\b',
        r'walks?\b',
        r'walking\b',
      ],
    ),
    Category.study: const _KeywordSet(
      strong: [
        r'stud(y|ies|ying)\b',
        r'homework\b',
        r'revis(e|ion|ing)\b',
      ],
      general: [
        r'learn\w*\b',
        r'courses?\b',
        r'class\b',
        r'\bread\b',
        r'reading\b',
      ],
    ),
    Category.errand: const _KeywordSet(
      strong: [
        r'grocer(y|ies)\b',
        r'pickups?\b',
        r'pick\s+up\b',
      ],
      general: [
        r'\bbuy\b',
        r'shops?\b',
        r'shopping\b',
        r'milk\b',
        r'bread\b',
        r'stores?\b',
        r'mall\b',
      ],
    ),
    Category.payment: const _KeywordSet(
      strong: [
        r'invoices?\b',
        r'rent\b',
        r'electricity\b',
        r'subscriptions?\b',
      ],
      general: [
        r'\bpay\b',
        r'bills?\b',
        r'internet\b',
      ],
    ),
    Category.appointment: const _KeywordSet(
      strong: [
        r'appointments?\b',
        r'dentist\b',
        r'interviews?\b',
      ],
      general: [
        r'meetings?\b',
        r'calls?\b',
        r'doctor\b',
        r'visits?\b',
      ],
    ),
  };

  /// Fixed tie-break order (table order) when two categories score equal.
  static const List<Category> _categoryPrecedence = [
    Category.medication,
    Category.water,
    Category.exercise,
    Category.study,
    Category.errand,
    Category.payment,
    Category.appointment,
  ];

  static _CategoryHit _detectCategory(String text) {
    var best = Category.other;
    var bestScore = 0;
    var bestStrong = false;
    for (final category in _categoryPrecedence) {
      final keywords = _categoryKeywords[category]!;
      var score = 0;
      var strong = false;
      for (final pattern in keywords.strong) {
        if (RegExp(pattern).hasMatch(text)) {
          score += 2;
          strong = true;
        }
      }
      for (final pattern in keywords.general) {
        if (RegExp(pattern).hasMatch(text)) {
          score += 1;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = category;
        bestStrong = strong;
      }
    }
    if (bestScore == 0) {
      return const _CategoryHit(Category.other, 0.5);
    }
    return _CategoryHit(best, bestStrong ? 1.0 : 0.7);
  }

  // ------------------------------------------------------------------
  // Recurrence.
  // ------------------------------------------------------------------

  static _RecurrenceHit _detectRecurrence(String text, List<_Span> spans) {
    // Interval expressions ("every hour", "every N minutes"): first-class
    // [Recurrence.interval] with the first tick as the fire time. The
    // span is still consumed for the title.
    final intervalMatch = _intervalPattern.firstMatch(text);
    if (intervalMatch != null) {
      spans.add(_Span(intervalMatch.start, intervalMatch.end));
      final amountRaw = intervalMatch.group(1);
      final int intervalMinutes;
      if (amountRaw != null) {
        final amount = int.parse(amountRaw);
        final unit = intervalMatch.group(2)!;
        intervalMinutes = unit.startsWith('hour') || unit.startsWith('hr')
            ? amount * 60
            : amount;
      } else {
        // "every hour" / "hourly".
        intervalMinutes = 60;
      }
      return _RecurrenceHit(
        Recurrence.interval,
        0,
        0.95,
        intervalMinutes: intervalMinutes,
      );
    }

    if (_everyDayPattern.hasMatch(text)) {
      final match = _everyDayPattern.firstMatch(text)!;
      spans.add(_Span(match.start, match.end));
      return const _RecurrenceHit(Recurrence.daily, 0, 1.0);
    }

    final everyPart = _everyPartPattern.firstMatch(text);
    if (everyPart != null) {
      spans.add(_Span(everyPart.start, everyPart.end));
      return _RecurrenceHit(
        Recurrence.daily,
        0,
        1.0,
        partOfDay: everyPart.group(1),
      );
    }

    if (_everyWeekdayPattern.hasMatch(text)) {
      final match = _everyWeekdayPattern.firstMatch(text)!;
      spans.add(_Span(match.start, match.end));
      // Bits 1..5 = Monday..Friday.
      return const _RecurrenceHit(Recurrence.custom, 62, 0.9);
    }

    if (_everyWeekendPattern.hasMatch(text)) {
      final match = _everyWeekendPattern.firstMatch(text)!;
      spans.add(_Span(match.start, match.end));
      // Bits 6..7 = Saturday..Sunday.
      return const _RecurrenceHit(Recurrence.custom, 192, 0.9);
    }

    // Named days ("every monday", "every monday and friday").
    if (text.contains('every')) {
      var mask = 0;
      for (var i = 0; i < _dayNames.length; i++) {
        final dayPattern =
            RegExp('\\b${_dayNames[i]}s?\\b');
        final match = dayPattern.firstMatch(text);
        if (match != null) {
          spans.add(_Span(match.start, match.end));
          mask |= 1 << (i + 1);
        }
      }
      if (mask != 0) {
        // Consume the "every" connector too so it does not leak into
        // the title.
        final everyMatch = RegExp(r'\bevery\b').firstMatch(text);
        if (everyMatch != null) {
          spans.add(_Span(everyMatch.start, everyMatch.end));
        }
        final single = (mask & (mask - 1)) == 0;
        return _RecurrenceHit(
          single ? Recurrence.weekly : Recurrence.custom,
          mask,
          0.9,
        );
      }
    }

    return const _RecurrenceHit(Recurrence.once, 0, 0.8);
  }

  // ------------------------------------------------------------------
  // Time.
  // ------------------------------------------------------------------

  static _TimeHit _detectTime(
    String text,
    List<_Span> spans,
    _RecurrenceHit recurrence,
    Category category,
  ) {
    // 1. Relative: "in N minutes/hours".
    final relative = _matchSpan(text, spans, _relativePattern);
    if (relative != null) {
      final amount = int.parse(relative.group(1)!);
      final unit = relative.group(2)!;
      final minutes = unit.startsWith('hour') || unit.startsWith('hr')
          ? amount * 60
          : amount;
      return _TimeHit.relative(minutes);
    }

    // 2. "tomorrow at X" then bare "tomorrow".
    final tomorrowAt = _matchSpan(text, spans, _tomorrowAtPattern);
    if (tomorrowAt != null) {
      final parsed = _parseClock(tomorrowAt);
      if (parsed != null) {
        return _TimeHit(
          hour: parsed.hour,
          minute: parsed.minute,
          confidence: parsed.explicitMeridiem ? 1.0 : 0.8,
          isTomorrow: true,
        );
      }
    }
    if (_matchSpan(text, spans, _tomorrowPattern) != null) {
      final fallback = _defaultTimeFor(category, text);
      return _TimeHit(
        hour: fallback.hour,
        minute: fallback.minute,
        confidence: 0.8,
        isTomorrow: true,
      );
    }

    // 3. "tonight" -> 20:00.
    if (_matchSpan(text, spans, _tonightPattern) != null) {
      return const _TimeHit(
        hour: 20,
        minute: 0,
        confidence: 0.8,
      );
    }

    // 4. "this morning/afternoon/evening/night".
    final thisPart = _matchSpan(text, spans, _thisPartPattern);
    if (thisPart != null) {
      final part = thisPart.group(1)!;
      return _TimeHit(
        hour: _partHourFor(part, category),
        minute: 0,
        confidence: 0.5,
      );
    }

    // 5. Explicit clock: "at X", "at Xam/pm", "at HH:MM".
    final atTime = _matchSpan(text, spans, _atTimePattern);
    if (atTime != null) {
      final parsed = _parseClock(atTime);
      if (parsed != null) {
        return _TimeHit(
          hour: parsed.hour,
          minute: parsed.minute,
          confidence: parsed.explicitMeridiem ? 1.0 : 0.8,
        );
      }
    }

    // 6. Sub-daily interval ("every hour", "every N minutes"): the next
    // tick, like a relative time. Explicit clock times above win over
    // the interval when both are present.
    if (recurrence.intervalMinutes != null) {
      return _TimeHit.relative(recurrence.intervalMinutes!);
    }

    // 7. Time-of-day hint: from "every morning/..." or a bare word.
    final part = recurrence.partOfDay ??
        _matchSpan(text, spans, _barePartPattern)?.group(1);
    if (part != null) {
      return _TimeHit(
        hour: _partHourFor(part, category),
        minute: 0,
        confidence: 0.5,
      );
    }

    // 8. Category default when recurrence was found but no time.
    if (recurrence.recurrence != Recurrence.once) {
      final fallback = _defaultTimeFor(category, text);
      return _TimeHit(
        hour: fallback.hour,
        minute: fallback.minute,
        confidence: 0.5,
      );
    }

    // 9. Bare default.
    return const _TimeHit(hour: 9, minute: 0, confidence: 0.5);
  }

  /// First non-overlapping match of [pattern]; records its span.
  static RegExpMatch? _matchSpan(
    String text,
    List<_Span> spans,
    RegExp pattern,
  ) {
    for (final match in pattern.allMatches(text)) {
      final candidate = _Span(match.start, match.end);
      final overlaps = spans.any((s) => s.overlaps(candidate));
      if (!overlaps) {
        spans.add(candidate);
        return match;
      }
    }
    return null;
  }

  static _ClockTime? _parseClock(RegExpMatch match) {
    final hourRaw = int.parse(match.group(1)!);
    final minuteRaw =
        match.group(2) != null ? int.parse(match.group(2)!) : 0;
    final meridiem = match.group(3);
    if (minuteRaw > 59) return null;
    if (meridiem != null) {
      if (hourRaw < 1 || hourRaw > 12) return null;
      final isPm = meridiem.startsWith('p');
      var hour = hourRaw % 12;
      if (isPm) hour += 12;
      return _ClockTime(hour, minuteRaw, true);
    }
    if (hourRaw > 23) return null;
    return _ClockTime(hourRaw, minuteRaw, false);
  }

  /// Table rule: medication keeps 20:00 for "night"; every other
  /// time-of-day word maps via [_partHours].
  static int _partHourFor(String part, Category category) {
    if (part == 'night' && category == Category.medication) return 20;
    return _partHours[part]!;
  }

  /// Default time by category when recurrence is found but no time:
  /// medication 8:00 (20:00 if "night" appears), water 9:00,
  /// exercise 7:00, study 20:00, errand 18:00, payment/appointment/
  /// other 9:00.
  static _ClockTime _defaultTimeFor(Category category, String text) {
    switch (category) {
      case Category.medication:
        return _ClockTime(text.contains('night') ? 20 : 8, 0, false);
      case Category.water:
        return const _ClockTime(9, 0, false);
      case Category.exercise:
        return const _ClockTime(7, 0, false);
      case Category.study:
        return const _ClockTime(20, 0, false);
      case Category.errand:
        return const _ClockTime(18, 0, false);
      case Category.appointment:
      case Category.payment:
      case Category.other:
        return const _ClockTime(9, 0, false);
    }
  }

  // ------------------------------------------------------------------
  // Importance / urgency defaults by category (owner-authorized table).
  // ------------------------------------------------------------------

  static Importance _importanceFor(Category category) {
    switch (category) {
      case Category.medication:
      case Category.payment:
      case Category.appointment:
        return Importance.high;
      case Category.study:
      case Category.exercise:
      case Category.water:
      case Category.errand:
      case Category.other:
        return Importance.medium;
    }
  }

  static Urgency _urgencyFor(Category category) {
    switch (category) {
      case Category.medication:
      case Category.appointment:
        return Urgency.high;
      case Category.payment:
        return Urgency.medium;
      case Category.study:
      case Category.exercise:
      case Category.water:
      case Category.errand:
      case Category.other:
        return Urgency.low;
    }
  }
}

// ----------------------------------------------------------------------
// Internal value types.
// ----------------------------------------------------------------------

class _Span {
  const _Span(this.start, this.end);
  final int start;
  final int end;

  bool overlaps(_Span other) => start < other.end && other.start < end;
}

class _KeywordSet {
  const _KeywordSet({required this.strong, required this.general});
  final List<String> strong;
  final List<String> general;
}

class _CategoryHit {
  const _CategoryHit(this.category, this.confidence);
  final Category category;
  final double confidence;
}

class _RecurrenceHit {
  const _RecurrenceHit(
    this.recurrence,
    this.daysMask,
    this.confidence, {
    this.partOfDay,
    this.intervalMinutes,
  });
  final Recurrence recurrence;
  final int daysMask;
  final double confidence;

  /// Time-of-day word consumed inside "every morning/...", if any.
  final String? partOfDay;

  /// Sub-daily interval in minutes ("every hour" -> 60). When set, the
  /// fire time is now + this offset (see class docs).
  final int? intervalMinutes;
}

class _TimeHit {
  const _TimeHit({
    required this.hour,
    required this.minute,
    required this.confidence,
    this.isTomorrow = false,
  }) : relativeMinutes = null;

  const _TimeHit.relative(int minutes)
      : hour = -1,
        minute = 0,
        confidence = 0.7,
        isTomorrow = false,
        relativeMinutes = minutes;

  final int hour;
  final int minute;
  final double confidence;
  final bool isTomorrow;

  /// When set, [hour]/[minute] are derived from now + this offset.
  final int? relativeMinutes;
}

class _ClockTime {
  const _ClockTime(this.hour, this.minute, this.explicitMeridiem);
  final int hour;
  final int minute;
  final bool explicitMeridiem;
}
