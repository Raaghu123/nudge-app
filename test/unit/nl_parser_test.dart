import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/services/nl_parser.dart';

/// Fixed clock: Tuesday 2026-10-06 10:00 (matches the existing unit-test
/// dates; 2026-10-07 is a Wednesday per recurrence_test).
final _tue1000 = DateTime(2026, 10, 6, 10, 0);

void main() {
  group('title extraction', () {
    test('strips "remind me to" with 0.9 confidence', () {
      final parsed = NlParser.parse(
        'remind me to take my thyroid pill every morning',
        now: _tue1000,
      );
      expect(parsed.title, equals('take my thyroid pill'));
      expect(parsed.titleConfidence, equals(0.9));
    });

    test('no prefix guesses verbatim with 0.6 confidence', () {
      final parsed = NlParser.parse('thyroid pill every morning', now: _tue1000);
      expect(parsed.title, equals('thyroid pill'));
      expect(parsed.titleConfidence, equals(0.6));
    });

    test('strips other prefixes and keeps original case', () {
      final parsed = NlParser.parse(
        "Don't forget to Call John tomorrow at 3pm",
        now: _tue1000,
      );
      expect(parsed.title, equals('Call John'));
      expect(parsed.titleConfidence, equals(0.9));
    });
  });

  group('key scenario: thyroid pill every morning', () {
    late ParsedReminder parsed;

    setUp(() {
      parsed = NlParser.parse(
        'remind me to take my thyroid pill every morning',
        now: _tue1000,
      );
    });

    test('detects medication from strong keyword', () {
      expect(parsed.category, equals(Category.medication));
      expect(parsed.categoryConfidence, equals(1.0));
    });

    test('detects daily recurrence at 8am', () {
      expect(parsed.recurrence, equals(Recurrence.daily));
      expect(parsed.hour, equals(8));
      expect(parsed.minute, equals(0));
    });

    test('rolls first fire to tomorrow when today 8am passed', () {
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 7, 8, 0)));
    });

    test('uses medication importance/urgency defaults', () {
      expect(parsed.importance, equals(Importance.high));
      expect(parsed.urgency, equals(Urgency.high));
    });
  });

  group('explicit times', () {
    test('tomorrow at 3pm', () {
      final parsed = NlParser.parse(
        'remind me to call John tomorrow at 3pm',
        now: _tue1000,
      );
      expect(parsed.title, equals('call John'));
      expect(parsed.hour, equals(15));
      expect(parsed.minute, equals(0));
      expect(parsed.timeConfidence, equals(1.0));
      expect(parsed.recurrence, equals(Recurrence.once));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 7, 15, 0)));
      expect(parsed.category, equals(Category.appointment));
    });

    test('bare "at 9" is taken literally with 0.8 confidence', () {
      final parsed = NlParser.parse(
        'remind me to pay rent at 9',
        now: _tue1000,
      );
      expect(parsed.hour, equals(9));
      expect(parsed.timeConfidence, equals(0.8));
      expect(parsed.category, equals(Category.payment));
      expect(parsed.categoryConfidence, equals(1.0));
      expect(parsed.importance, equals(Importance.high));
      expect(parsed.urgency, equals(Urgency.medium));
    });

    test('"at 8:30pm" parses minutes and meridiem', () {
      final parsed = NlParser.parse(
        'remind me to study at 8:30pm',
        now: _tue1000,
      );
      expect(parsed.hour, equals(20));
      expect(parsed.minute, equals(30));
      expect(parsed.timeConfidence, equals(1.0));
    });

    test('one-off time already passed rolls to tomorrow', () {
      final parsed = NlParser.parse(
        'remind me to call John at 8',
        now: _tue1000,
      );
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 7, 8, 0)));
    });
  });

  group('relative and day-part times', () {
    test('"in 30 minutes" schedules off now with 0.7 confidence', () {
      final parsed = NlParser.parse(
        'remind me to drink water in 30 minutes',
        now: _tue1000,
      );
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 10, 30)));
      expect(parsed.hour, equals(10));
      expect(parsed.minute, equals(30));
      expect(parsed.timeConfidence, equals(0.7));
      expect(parsed.category, equals(Category.water));
    });

    test('"tonight" means 20:00 with 0.8 confidence', () {
      final parsed = NlParser.parse(
        'remind me to study tonight',
        now: _tue1000,
      );
      expect(parsed.hour, equals(20));
      expect(parsed.timeConfidence, equals(0.8));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 20, 0)));
    });

    test('"tonight" already passed rolls to tomorrow night', () {
      final parsed = NlParser.parse(
        'remind me to study tonight',
        now: DateTime(2026, 10, 6, 21, 0),
      );
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 7, 20, 0)));
    });

    test('bare "tomorrow" uses the category default time', () {
      final parsed = NlParser.parse(
        'remind me to buy milk tomorrow',
        now: _tue1000,
      );
      expect(parsed.hour, equals(18));
      expect(parsed.timeConfidence, equals(0.8));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 7, 18, 0)));
      expect(parsed.category, equals(Category.errand));
      expect(parsed.categoryConfidence, equals(0.7));
    });
  });

  group('recurrence', () {
    test('"every weekday" is custom Mon-Fri', () {
      final parsed = NlParser.parse(
        'remind me to go to the gym every weekday',
        now: _tue1000,
      );
      expect(parsed.recurrence, equals(Recurrence.custom));
      expect(parsed.daysMask, equals(62));
      expect(parsed.recurrenceConfidence, equals(0.9));
      expect(parsed.category, equals(Category.exercise));
      // Exercise default time when recurrence found but no clock time.
      expect(parsed.hour, equals(7));
      expect(parsed.timeConfidence, equals(0.5));
    });

    test('"every monday" is weekly with the Monday bit', () {
      final parsed = NlParser.parse(
        'remind me to call mom every monday',
        now: _tue1000,
      );
      expect(parsed.recurrence, equals(Recurrence.weekly));
      expect(parsed.daysMask, equals(1 << DateTime.monday));
      expect(parsed.recurrenceConfidence, equals(0.9));
      expect(parsed.scheduledAt.weekday, equals(DateTime.monday));
      expect(parsed.hour, equals(9));
    });

    test('"every hour" is interval 60 with the first tick', () {
      final parsed = NlParser.parse(
        'remind me to drink water every hour',
        now: _tue1000,
      );
      expect(parsed.recurrence, equals(Recurrence.interval));
      expect(parsed.intervalMinutes, equals(60));
      expect(parsed.recurrenceConfidence, equals(0.95));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 11, 0)));
    });

    test('"every 30 minutes" is interval 30 with the first tick', () {
      final parsed = NlParser.parse(
        'remind me to drink water every 30 minutes',
        now: _tue1000,
      );
      expect(parsed.recurrence, equals(Recurrence.interval));
      expect(parsed.intervalMinutes, equals(30));
      expect(parsed.recurrenceConfidence, equals(0.95));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 10, 30)));
    });

    test('"every night" keeps the medication 20:00 rule', () {
      final parsed = NlParser.parse(
        'remind me to take my pill every night',
        now: _tue1000,
      );
      expect(parsed.recurrence, equals(Recurrence.daily));
      expect(parsed.hour, equals(20));
      expect(parsed.category, equals(Category.medication));
    });
  });

  group('category defaults', () {
    test('water every day fires at 9am, medium/low', () {
      final parsed = NlParser.parse(
        'remind me to drink water every day',
        now: _tue1000,
      );
      expect(parsed.category, equals(Category.water));
      expect(parsed.hour, equals(9));
      expect(parsed.importance, equals(Importance.medium));
      expect(parsed.urgency, equals(Urgency.low));
    });

    test('study every day fires at 8pm', () {
      final parsed = NlParser.parse(
        'remind me to study AWS every day',
        now: _tue1000,
      );
      expect(parsed.category, equals(Category.study));
      expect(parsed.hour, equals(20));
    });

    test('unknown topic falls back to other with 0.5 confidence', () {
      final parsed = NlParser.parse(
        'remind me to florp the wug',
        now: _tue1000,
      );
      expect(parsed.category, equals(Category.other));
      expect(parsed.categoryConfidence, equals(0.5));
      expect(parsed.importance, equals(Importance.medium));
      expect(parsed.urgency, equals(Urgency.low));
    });
  });
}
