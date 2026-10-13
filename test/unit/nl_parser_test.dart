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

  group('rich time patterns', () {
    test('multi-time list parses to daily with all four times', () {
      final parsed = NlParser.parse(
        'drink water at 1pm,4pm,8pm,11pm everyday',
        now: _tue1000,
      );
      expect(parsed.title, equals('drink water'));
      expect(parsed.recurrence, equals(Recurrence.daily));
      expect(parsed.timesOfDayMinutes, equals([780, 960, 1200, 1380]));
      expect(parsed.timeConfidence, equals(0.9));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 13, 0)));
    });

    test('half-hour interval with a between window', () {
      final parsed = NlParser.parse(
        'drink water every half hour between 7am and 11pm',
        now: _tue1000,
      );
      expect(parsed.title, equals('drink water'));
      expect(parsed.recurrence, equals(Recurrence.interval));
      expect(parsed.intervalMinutes, equals(30));
      expect(parsed.windowStartMinutes, equals(420));
      expect(parsed.windowEndMinutes, equals(1380));
      expect(parsed.timeConfidence, equals(0.85));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 10, 30)));
    });

    test('interval with a from window and weekday restriction', () {
      final parsed = NlParser.parse(
        'remind me to stretch every 2 hours from 9am-6pm weekdays',
        now: _tue1000,
      );
      expect(parsed.title, equals('stretch'));
      expect(parsed.recurrence, equals(Recurrence.interval));
      expect(parsed.intervalMinutes, equals(120));
      expect(parsed.windowStartMinutes, equals(540));
      expect(parsed.windowEndMinutes, equals(1080));
      expect(parsed.daysMask, equals(62));
      // Ticks are 9:00, 11:00, ... from window start; at 10:00 the next
      // tick is 11:00.
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 11, 0)));
    });

    test('two times parse to daily at both', () {
      final parsed = NlParser.parse(
        'take medication at 8am and 8pm',
        now: _tue1000,
      );
      expect(parsed.title, equals('take medication'));
      expect(parsed.recurrence, equals(Recurrence.daily));
      expect(parsed.timesOfDayMinutes, equals([480, 1200]));
      expect(parsed.category, equals(Category.medication));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 20, 0)));
    });

    test('hourly interval composes with a named day', () {
      final parsed = NlParser.parse(
        'water plants every hour Mondays',
        now: _tue1000,
      );
      expect(parsed.title, equals('water plants'));
      expect(parsed.recurrence, equals(Recurrence.interval));
      expect(parsed.intervalMinutes, equals(60));
      expect(parsed.daysMask, equals(2));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 11, 0)));
    });

    test('topic after the time phrase keeps the trailing words', () {
      final parsed = NlParser.parse(
        'remind me at 8am and 8pm every day to take my medicine',
        now: _tue1000,
      );
      expect(parsed.title, equals('take my medicine'));
      expect(parsed.recurrence, equals(Recurrence.daily));
      expect(parsed.timesOfDayMinutes, equals([480, 1200]));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 20, 0)));
    });

    test('24-hour list parses both times', () {
      final parsed = NlParser.parse(
        'remind me to drink tea at 21:40 and 21:41',
        now: _tue1000,
      );
      expect(parsed.title, equals('drink tea'));
      expect(parsed.timesOfDayMinutes, equals([1300, 1301]));
      expect(parsed.category, equals(Category.water));
    });

    test('24-hour singular time parses', () {
      final parsed = NlParser.parse(
        'remind me to drink tea at 21:40',
        now: _tue1000,
      );
      expect(parsed.title, equals('drink tea'));
      expect(parsed.timesOfDayMinutes, equals([1300]));
      expect(parsed.category, equals(Category.water));
    });

    test('mixed 12-hour and 24-hour list keeps the 24-hour value as-is',
        () {
      final parsed = NlParser.parse(
        'remind me to drink tea at 9:30am and 21:40',
        now: _tue1000,
      );
      expect(parsed.title, equals('drink tea'));
      expect(parsed.timesOfDayMinutes, equals([570, 1300]));
      expect(parsed.category, equals(Category.water));
    });

    test('minute shorthand with a dash window', () {
      final parsed = NlParser.parse(
        'drink water every 45m between 10am-5pm',
        now: _tue1000,
      );
      expect(parsed.title, equals('drink water'));
      expect(parsed.recurrence, equals(Recurrence.interval));
      expect(parsed.intervalMinutes, equals(45));
      expect(parsed.windowStartMinutes, equals(600));
      expect(parsed.windowEndMinutes, equals(1020));
      expect(parsed.scheduledAt, equals(DateTime(2026, 10, 6, 10, 45)));
    });
  });
}
