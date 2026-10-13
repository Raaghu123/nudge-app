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
    this.timesOfDayMinutes = const [],
    this.windowStartMinutes,
    this.windowEndMinutes,
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

  /// 1.0 explicit am/pm, 0.9 all-explicit time list, 0.85 window with
  /// explicit bounds, 0.8 tomorrow/tonight, bare "at X", or partially
  /// bare list, 0.7 relative ("in N minutes/hours"), 0.5 inferred
  /// (time-of-day word, category default, or bare default).
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

  /// Specific fire times as minutes since midnight, sorted unique. Set
  /// for multi-time phrases ("at 8am and 8pm"); single times also land
  /// here as a one-entry list. Empty for interval reminders.
  final List<int> timesOfDayMinutes;

  /// Window bounds as minutes since midnight, only with
  /// [Recurrence.interval] ("between 7am and 11pm"); null otherwise.
  final int? windowStartMinutes;

  /// Window end, see [windowStartMinutes].
  final int? windowEndMinutes;
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
/// - Time: "at X", "at Xam/pm", "at HH:MM", multi-time lists
///   ("at 1pm, 4pm and 11pm"), windows ("between 7am and 11pm",
///   "from 9am to 6pm"), "in N minutes/hours", "tomorrow",
///   "tomorrow at X", "tonight", "this morning/afternoon/
///   evening/night", bare time-of-day words.
/// - Recurrence: "every morning/night/evening/day", "every weekday",
///   "every <day name>", "every hour", "every N minutes",
///   "every half hour", "every 45m"/"every 2h" shorthands; intervals
///   compose with windows and day restrictions ("every 2 hours from
///   9am-6pm weekdays", "every hour on Mondays").
/// - Category keywords per table below.
/// - Category default times and importance/urgency defaults per table.
///
/// Known limitations:
/// - Sub-daily intervals ("every hour", "every N minutes") parse to
///   [Recurrence.interval] with [ParsedReminder.intervalMinutes] set and
///   [ParsedReminder.scheduledAt] holding the first tick.
/// - "every N days", midnight-wrapping windows, and open-ended windows
///   are not parsed (left in the title).
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
    final List<int> timesOfDay;
    int? windowStart;
    int? windowEnd;
    var recurrence = recurrenceHit.recurrence;
    var daysMask = recurrenceHit.daysMask;
    var recurrenceConfidence = recurrenceHit.confidence;
    if (timeHit.relativeMinutes != null) {
      final base = ref.add(Duration(minutes: timeHit.relativeMinutes!));
      hour = base.hour;
      minute = base.minute;
      scheduledAt = base;
      timesOfDay = const [];
    } else if (timeHit.windowStart != null &&
        recurrenceHit.recurrence == Recurrence.interval) {
      // Windowed interval: first stateless tick at/after now.
      windowStart = timeHit.windowStart;
      windowEnd = timeHit.windowEnd;
      final first = nextOccurrence(
            now: ref,
            timesOfDayMinutes: const [],
            recurrence: Recurrence.interval,
            daysMask: daysMask,
            intervalMinutes: recurrenceHit.intervalMinutes,
            windowStartMinutes: windowStart,
            windowEndMinutes: windowEnd,
          ) ??
          // Provably unreachable with a valid window (some day in any
          // 8-day span accepts), but never return null: roll to
          // tomorrow's window start.
          DateTime(ref.year, ref.month, ref.day + 1, windowStart! ~/ 60,
              windowStart % 60);
      hour = first.hour;
      minute = first.minute;
      scheduledAt = first;
      timesOfDay = const [];
    } else if (timeHit.times != null && timeHit.times!.length > 1) {
      // Multi-time list: daily by implication, or weekly/custom when a
      // day restriction was named and no stronger recurrence was found.
      timesOfDay = List<int>.of(timeHit.times!.toSet().toList())..sort();
      if (timeHit.dayMaskOverride != 0 &&
          recurrence == Recurrence.once) {
        daysMask = timeHit.dayMaskOverride;
        final single = (daysMask & (daysMask - 1)) == 0;
        recurrence = single ? Recurrence.weekly : Recurrence.custom;
        recurrenceConfidence = 0.9;
      } else if (recurrence == Recurrence.once) {
        recurrence = Recurrence.daily;
        recurrenceConfidence = 0.8;
      }
      hour = timesOfDay.first ~/ 60;
      minute = timesOfDay.first % 60;
      scheduledAt = nextOccurrence(
            now: ref,
            timesOfDayMinutes: timesOfDay,
            recurrence: recurrence,
            daysMask: daysMask,
          ) ??
          DateTime(ref.year, ref.month, ref.day + 1, hour, minute);
    } else {
      hour = timeHit.hour;
      minute = timeHit.minute;
      timesOfDay = [hour * 60 + minute];
      DateTime base;
      if (timeHit.isTomorrow) {
        base = DateTime(ref.year, ref.month, ref.day + 1, hour, minute);
      } else {
        base = nextOccurrence(
              now: ref,
              timesOfDayMinutes: timesOfDay,
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
    // Dangling infinitive marker left when the time phrase sat between
    // the prefix and the topic ("remind me at 8am ... to take my
    // medicine"): "to take my medicine" -> "take my medicine".
    title = title.replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '');
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
      recurrence: recurrence,
      daysMask: daysMask,
      recurrenceConfidence: recurrenceConfidence,
      category: categoryHit.category,
      categoryConfidence: categoryHit.confidence,
      importance: _importanceFor(categoryHit.category),
      urgency: _urgencyFor(categoryHit.category),
      scheduledAt: scheduledAt,
      intervalMinutes: recurrenceHit.intervalMinutes,
      timesOfDayMinutes: timesOfDay,
      windowStartMinutes: windowStart,
      windowEndMinutes: windowEnd,
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

  /// Groups 1-2 = amount + unit, 3 = "45m" shorthand amount,
  /// 4 = "2h" shorthand amount.
  static final RegExp _intervalPattern = RegExp(
    r'\bevery\s+(\d+)\s*(minutes?|mins?|hours?|hrs?)\b|\bevery\s+hour\b|\bhourly\b|\bevery\s+half\s+(?:an?\s+)?hours?\b|\bevery\s+(\d+)\s*m\b|\bevery\s+(\d+)\s*h\b',
  );

  /// "between 7am and 11pm" / "from 9am to 6pm" (also dash-joined:
  /// "from 9am-6pm"). Bounds require an explicit meridiem; bare numbers
  /// ("between 7 and 11") and open-ended windows ("from 9am" with no
  /// end) are not windows.
  /// Groups 1-3/4-6 = between start/end, 7-9/10-12 = from start/end.
  static final RegExp _windowPattern = RegExp(
    r'\b(?:between\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)\s*(?:and|-)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)|from\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)\s*(?:to|-)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.))\b',
  );

  /// Anchor + one item of a multi-time list: "at 1pm", "at 8:30".
  /// The space before a meridiem is consumed only with the meridiem, so
  /// a bare time never swallows the separator space the list
  /// continuation pattern needs ("at 21:40 and 21:41").
  static final RegExp _listAnchorPattern = RegExp(
    r'\bat\s+(\d{1,2})(?::(\d{2}))?(?:\s*(am|pm|a\.m\.|p\.m\.))?',
  );

  /// Continuation of a list after the first item: ", 4pm", " and 11pm".
  /// A comma or "and" is required so unrelated numbers are not glommed.
  /// Same trailing-space rule as the anchor.
  static final RegExp _listNextPattern = RegExp(
    r'^(?:\s*,\s*(?:and\s+)?|\s+and\s+)(\d{1,2})(?::(\d{2}))?(?:\s*(am|pm|a\.m\.|p\.m\.))?',
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
      strong: [
        r'water\b',
        r'tea\b',
        r'coffee\b',
        r'juice\b',
        r'soda\b',
      ],
      general: [
        r'hydrat\w*\b',
        r'drink\w*\b',
      ],
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

  /// Day restriction for interval phrases and time lists ("on Mondays",
  /// "on weekdays"): returns the weekday mask (0 = none found) and
  /// consumes the day words plus a preceding "on"/"every" connector so
  /// neither leaks into the title. Matches overlapping already-consumed
  /// spans are skipped. With [requireConnector], bare day names without
  /// a preceding "on"/"every" are left alone so topic words ("plan
  /// monday meeting") are never eaten; the weekday/weekend words are
  /// unambiguous enough to always count.
  static int _detectDayMask(
    String text,
    List<_Span> spans, {
    bool requireConnector = false,
  }) {
    int? consumeWithConnector(RegExpMatch match) {
      final candidate = _Span(match.start, match.end);
      if (spans.any((s) => s.overlaps(candidate))) return null;
      var start = match.start;
      final connector =
          RegExp(r'(on|every)\s*$').firstMatch(text.substring(0, start));
      if (connector != null) {
        start = connector.start;
      } else if (requireConnector) {
        return null;
      }
      spans.add(_Span(start, match.end));
      return start;
    }

    final weekday = _everyWeekdayPattern.firstMatch(text);
    if (weekday != null && consumeWithConnector(weekday) != null) {
      // Bits 1..5 = Monday..Friday.
      return 62;
    }
    final weekend = _everyWeekendPattern.firstMatch(text);
    if (weekend != null && consumeWithConnector(weekend) != null) {
      // Bits 6..7 = Saturday..Sunday.
      return 192;
    }
    var mask = 0;
    for (var i = 0; i < _dayNames.length; i++) {
      final dayPattern = RegExp('\\b${_dayNames[i]}s?\\b');
      for (final match in dayPattern.allMatches(text)) {
        if (consumeWithConnector(match) != null) {
          mask |= 1 << (i + 1);
          break;
        }
      }
    }
    return mask;
  }

  static _RecurrenceHit _detectRecurrence(String text, List<_Span> spans) {
    // Interval expressions ("every hour", "every N minutes", "every half
    // hour"): first-class [Recurrence.interval] with the first tick as
    // the fire time. A day restriction composes ("every hour on
    // Mondays"); the span is still consumed for the title.
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
      } else if (intervalMatch.group(3) != null) {
        // "every 45m" shorthand.
        intervalMinutes = int.parse(intervalMatch.group(3)!);
      } else if (intervalMatch.group(4) != null) {
        // "every 2h" shorthand.
        intervalMinutes = int.parse(intervalMatch.group(4)!) * 60;
      } else if (intervalMatch.group(0)!.contains('half')) {
        // "every half hour" / "every half an hour".
        intervalMinutes = 30;
      } else {
        // "every hour" / "hourly".
        intervalMinutes = 60;
      }
      final mask = _detectDayMask(text, spans);
      return _RecurrenceHit(
        Recurrence.interval,
        mask,
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

    // 5a. Window bounds for intervals: "between 7am and 11pm" /
    // "from 9am to 6pm". Bounds need an explicit meridiem and end >
    // start; anything else (bare numbers, wrapping, open-ended) is
    // left for the steps below and the title.
    final windowMatch = _firstNonOverlapping(text, spans, _windowPattern);
    if (windowMatch != null) {
      final isBetween = windowMatch.group(1) != null;
      final startClock = _clockFromParts(
        isBetween ? windowMatch.group(1) : windowMatch.group(7),
        isBetween ? windowMatch.group(2) : windowMatch.group(8),
        isBetween ? windowMatch.group(3) : windowMatch.group(9),
      );
      final endClock = _clockFromParts(
        isBetween ? windowMatch.group(4) : windowMatch.group(10),
        isBetween ? windowMatch.group(5) : windowMatch.group(11),
        isBetween ? windowMatch.group(6) : windowMatch.group(12),
      );
      if (startClock != null &&
          endClock != null &&
          startClock.explicitMeridiem &&
          endClock.explicitMeridiem) {
        final startMinutes = startClock.hour * 60 + startClock.minute;
        final endMinutes = endClock.hour * 60 + endClock.minute;
        if (endMinutes > startMinutes) {
          spans.add(_Span(windowMatch.start, windowMatch.end));
          return _TimeHit.window(
            windowStart: startMinutes,
            windowEnd: endMinutes,
            confidence: 0.85,
          );
        }
      }
    }

    // 5b. Time list: "at 1pm, 4pm, 8pm and 11pm". The anchor covers a
    // lone "at X" too, so single times resolve here with the old
    // confidence (explicit 1.0, bare 0.8). Continuations need a comma
    // or "and" so unrelated numbers are not glommed. Bare items
    // inherit the first explicit meridiem in the list ("1, 4 and 8pm"
    // -> all pm); with none explicit the raw 24-hour values stand.
    final anchor = _firstNonOverlapping(text, spans, _listAnchorPattern);
    if (anchor != null) {
      final first =
          _clockFromParts(anchor.group(1), anchor.group(2), anchor.group(3));
      if (first != null) {
        _TimeHit single() {
          spans.add(_Span(anchor.start, anchor.end));
          return _TimeHit(
            hour: first.hour,
            minute: first.minute,
            confidence: first.explicitMeridiem ? 1.0 : 0.8,
          );
        }

        final raws = <_RawClock>[
          _RawClock(anchor.group(1)!, anchor.group(2), anchor.group(3)),
        ];
        var cursor = anchor.end;
        var listEnd = anchor.end;
        while (cursor < text.length) {
          final next =
              _listNextPattern.firstMatch(text.substring(cursor));
          if (next == null) break;
          raws.add(_RawClock(next.group(1)!, next.group(2), next.group(3)));
          cursor += next.end;
          listEnd = cursor;
        }
        if (raws.length == 1) return single();

        String? inherited;
        for (final raw in raws) {
          if (raw.meridiem != null) {
            inherited = raw.meridiem;
            break;
          }
        }
        final resolved = <int>[];
        var allExplicit = true;
        for (final raw in raws) {
          _ClockTime? clock;
          if (raw.meridiem != null) {
            clock = _clockFromParts(raw.hour, raw.minute, raw.meridiem);
          } else {
            // Bare items inherit the list meridiem when it fits a
            // 12-hour clock; an unambiguous 24-hour value ("21:40"
            // next to "9:30am") stands on its own instead.
            if (inherited != null) {
              clock = _clockFromParts(raw.hour, raw.minute, inherited);
            }
            clock ??= _clockFromParts(raw.hour, raw.minute, null);
          }
          if (raw.meridiem == null) allExplicit = false;
          if (clock == null) return single();
          resolved.add(clock.hour * 60 + clock.minute);
        }
        spans.add(_Span(anchor.start, listEnd));
        final mask =
            _detectDayMask(text, spans, requireConnector: true);
        return _TimeHit.list(
          times: resolved,
          hour: first.hour,
          minute: first.minute,
          confidence: allExplicit ? 0.9 : 0.8,
          dayMaskOverride: mask,
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

  /// First match of [pattern] that does not overlap [spans], without
  /// consuming it. Callers add the span themselves once validated.
  static RegExpMatch? _firstNonOverlapping(
    String text,
    List<_Span> spans,
    RegExp pattern,
  ) {
    for (final match in pattern.allMatches(text)) {
      final candidate = _Span(match.start, match.end);
      if (!spans.any((s) => s.overlaps(candidate))) return match;
    }
    return null;
  }

  /// Builds a clock from raw digit/meridiem parts. Returns null when
  /// out of range (minutes > 59, 12-hour clock outside 1-12, 24-hour
  /// clock above 23).
  static _ClockTime? _clockFromParts(
    String? hourRaw,
    String? minuteRaw,
    String? meridiem,
  ) {
    if (hourRaw == null) return null;
    final hourValue = int.parse(hourRaw);
    final minuteValue = minuteRaw != null ? int.parse(minuteRaw) : 0;
    if (minuteValue > 59) return null;
    if (meridiem != null) {
      if (hourValue < 1 || hourValue > 12) return null;
      final isPm = meridiem.startsWith('p');
      var hour = hourValue % 12;
      if (isPm) hour += 12;
      return _ClockTime(hour, minuteValue, true);
    }
    if (hourValue > 23) return null;
    return _ClockTime(hourValue, minuteValue, false);
  }

  static _ClockTime? _parseClock(RegExpMatch match) {
    return _clockFromParts(
      match.group(1),
      match.group(2),
      match.group(3),
    );
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
  })  : relativeMinutes = null,
        times = null,
        windowStart = null,
        windowEnd = null,
        dayMaskOverride = 0;

  const _TimeHit.relative(int minutes)
      : hour = -1,
        minute = 0,
        confidence = 0.7,
        isTomorrow = false,
        relativeMinutes = minutes,
        times = null,
        windowStart = null,
        windowEnd = null,
        dayMaskOverride = 0;

  const _TimeHit.window({
    required int this.windowStart,
    required int this.windowEnd,
    required this.confidence,
  })  : hour = windowStart ~/ 60,
        minute = windowStart % 60,
        isTomorrow = false,
        relativeMinutes = null,
        times = null,
        dayMaskOverride = 0;

  const _TimeHit.list({
    required this.times,
    required this.hour,
    required this.minute,
    required this.confidence,
    this.dayMaskOverride = 0,
  })  : isTomorrow = false,
        relativeMinutes = null,
        windowStart = null,
        windowEnd = null;

  final int hour;
  final int minute;
  final double confidence;
  final bool isTomorrow;

  /// When set, [hour]/[minute] are derived from now + this offset.
  final int? relativeMinutes;

  /// Multi-time list as minutes since midnight (null unless a list).
  /// [hour]/[minute] carry the first entry for single-item fallback.
  final List<int>? times;

  /// Window bounds as minutes since midnight (null unless a window).
  final int? windowStart;

  /// Window end, see [windowStart].
  final int? windowEnd;

  /// Day restriction found next to a time list ("on Mondays"), 0 when
  /// none. The schedule step promotes once -> weekly/custom from this.
  final int dayMaskOverride;
}

/// One raw clock item inside a time list: digit parts plus the
/// meridiem suffix when present (null = bare).
class _RawClock {
  const _RawClock(this.hour, this.minute, this.meridiem);
  final String hour;
  final String? minute;
  final String? meridiem;
}

class _ClockTime {
  const _ClockTime(this.hour, this.minute, this.explicitMeridiem);
  final int hour;
  final int minute;
  final bool explicitMeridiem;
}
