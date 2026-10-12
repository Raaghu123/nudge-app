import 'package:flutter/material.dart' hide Category;
import 'package:provider/provider.dart';
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/providers/reminder_provider.dart';
import 'package:nudge/services/nl_parser.dart';

/// Confirm screen for a parsed natural-language reminder.
///
/// Shows what the parser understood, marks low-confidence fields
/// (confidence < 0.7) with a grey dot, and saves via the provider.
/// The "When" row is display-only: schedule edits happen from the home
/// screen later, so there is no Change-link round-trip to the form.
class NlConfirmScreen extends StatefulWidget {
  const NlConfirmScreen({super.key, required this.parsed});

  final ParsedReminder parsed;

  @override
  State<NlConfirmScreen> createState() => _NlConfirmScreenState();
}

class _NlConfirmScreenState extends State<NlConfirmScreen> {
  late final TextEditingController _titleController;
  late Category _category;
  late Importance _importance;
  late Urgency _urgency;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.parsed.title);
    _category = widget.parsed.category;
    _importance = widget.parsed.importance;
    _urgency = widget.parsed.urgency;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = widget.parsed;
    await context.read<ReminderProvider>().addReminder(
          title: _titleController.text.trim(),
          hour: parsed.hour,
          minute: parsed.minute,
          recurrence: parsed.recurrence,
          daysMask: parsed.daysMask,
          category: _category,
          importance: _importance,
          urgency: _urgency,
          scheduledAt: parsed.scheduledAt,
          intervalMinutes: parsed.intervalMinutes,
          timesOfDayMinutes: parsed.timesOfDayMinutes,
          windowStartMinutes: parsed.windowStartMinutes,
          windowEndMinutes: parsed.windowEndMinutes,
        );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = widget.parsed;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'I understood this',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldRow(
                      label: 'Title',
                      lowConfidence:
                          parsed.titleConfidence < 0.7,
                      child: TextField(
                        key: const Key('nl_title'),
                        controller: _titleController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FieldRow(
                      label: 'Category',
                      lowConfidence:
                          parsed.categoryConfidence < 0.7,
                      child: DropdownButtonFormField<Category>(
                        key: const Key('nl_category'),
                        initialValue: _category,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: Category.values.map((Category value) {
                          return DropdownMenuItem<Category>(
                            value: value,
                            child: Text(_categoryLabel(value)),
                          );
                        }).toList(),
                        onChanged: (Category? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _category = newValue;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FieldRow(
                      label: 'When',
                      lowConfidence: parsed.timeConfidence < 0.7 ||
                          parsed.recurrenceConfidence < 0.7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _whenLabel(parsed),
                            key: const Key('nl_when'),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Edit from the home screen later',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FieldRow(
                      label: 'Importance',
                      lowConfidence: false,
                      child: SegmentedButton<Importance>(
                        segments: const [
                          ButtonSegment(
                              value: Importance.low, label: Text('low')),
                          ButtonSegment(
                              value: Importance.medium, label: Text('medium')),
                          ButtonSegment(
                              value: Importance.high, label: Text('high')),
                        ],
                        selected: {_importance},
                        onSelectionChanged: (Set<Importance> selected) {
                          setState(() {
                            _importance = selected.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FieldRow(
                      label: 'Urgency',
                      lowConfidence: false,
                      child: SegmentedButton<Urgency>(
                        segments: const [
                          ButtonSegment(
                              value: Urgency.low, label: Text('low')),
                          ButtonSegment(
                              value: Urgency.medium, label: Text('medium')),
                          ButtonSegment(
                              value: Urgency.high, label: Text('high')),
                        ],
                        selected: {_urgency},
                        onSelectionChanged: (Set<Urgency> selected) {
                          setState(() {
                            _urgency = selected.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save reminder'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled row with an optional grey confidence dot to the left of
/// the label.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.lowConfidence,
    required this.child,
  });

  final String label;
  final bool lowConfidence;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (lowConfidence)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

String _categoryLabel(Category category) {
  switch (category) {
    case Category.medication:
      return 'Medication';
    case Category.water:
      return 'Water';
    case Category.exercise:
      return 'Exercise';
    case Category.errand:
      return 'Errand';
    case Category.study:
      return 'Study';
    case Category.appointment:
      return 'Appointment';
    case Category.payment:
      return 'Payment';
    case Category.other:
      return 'Other';
  }
}

const List<String> _dayNames = [
  '',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthNames = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "8:00 AM" style 12-hour clock.
String _clockLabel(int hour, int minute) {
  final period = hour < 12 ? 'AM' : 'PM';
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelve:${minute.toString().padLeft(2, '0')} $period';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Human-readable schedule line computed from the parsed fields.
///
/// Plain [Recurrence.interval] renders short from
/// [ParsedReminder.intervalMinutes] ("Every 1h", "Every 30m"); windowed
/// intervals spell it out ("Every 30 minutes from 7:00 AM to 11:00 PM")
/// and day restrictions append ("on Mon, Wed"). Multi-time days join
/// every clock ("Every day at 1:00 PM, 4:00 PM"). The first fire is
/// already in scheduledAt and shown on the home screen after save.
String _whenLabel(ParsedReminder parsed) {
  final clock = _clockLabel(parsed.hour, parsed.minute);

  String daySuffix() {
    final days = <String>[];
    for (var weekday = 1; weekday <= 7; weekday++) {
      if ((parsed.daysMask & (1 << weekday)) != 0) {
        days.add(_dayNames[weekday]);
      }
    }
    if (days.isEmpty) return '';
    return ' on ${days.join(', ')}';
  }

  String timesLabel() {
    final times = parsed.timesOfDayMinutes;
    if (times.length > 1) {
      return times
          .map((t) => _clockLabel(t ~/ 60, t % 60))
          .join(', ');
    }
    return clock;
  }

  String intervalLabel(int? minutes, {required bool long}) {
    if (minutes == null) return 'Every hour';
    if (long) {
      if (minutes % 60 == 0) {
        final hours = minutes ~/ 60;
        return hours == 1 ? 'Every hour' : 'Every $hours hours';
      }
      return minutes == 1 ? 'Every minute' : 'Every $minutes minutes';
    }
    if (minutes % 60 == 0) return 'Every ${minutes ~/ 60}h';
    return 'Every ${minutes}m';
  }

  switch (parsed.recurrence) {
    case Recurrence.interval:
      final start = parsed.windowStartMinutes;
      final end = parsed.windowEndMinutes;
      final windowed = start != null && end != null;
      final every =
          intervalLabel(parsed.intervalMinutes, long: windowed);
      final window = windowed
          ? ' from ${_clockLabel(start ~/ 60, start % 60)}'
              ' to ${_clockLabel(end ~/ 60, end % 60)}'
          : '';
      return '$every$window${daySuffix()}';
    case Recurrence.daily:
      return 'Every day at ${timesLabel()}';
    case Recurrence.weekly:
    case Recurrence.custom:
      final days = <String>[];
      for (var weekday = 1; weekday <= 7; weekday++) {
        if ((parsed.daysMask & (1 << weekday)) != 0) {
          days.add(_dayNames[weekday]);
        }
      }
      if (days.isEmpty) return 'Every week at ${timesLabel()}';
      return 'Every ${days.join(', ')} at ${timesLabel()}';
    case Recurrence.once:
      final now = DateTime.now();
      final fireAt = parsed.scheduledAt;
      if (_isSameDay(fireAt, now)) return 'Today $clock';
      final tomorrow = now.add(const Duration(days: 1));
      if (_isSameDay(fireAt, tomorrow)) return 'Tomorrow $clock';
      return '${_dayNames[fireAt.weekday]}, '
          '${_monthNames[fireAt.month]} ${fireAt.day} at $clock';
  }
}
