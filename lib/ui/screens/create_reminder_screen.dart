import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/providers/reminder_provider.dart';

class CreateReminderScreen extends StatefulWidget {
  const CreateReminderScreen({super.key});

  @override
  State<CreateReminderScreen> createState() => _CreateReminderScreenState();
}

class _CreateReminderScreenState extends State<CreateReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _hourController = TextEditingController(text: '9');
  final _minuteController = TextEditingController(text: '0');
  Recurrence _recurrence = Recurrence.once;
  Category _category = Category.other;
  final Set<int> _weekdays = {DateTime.now().weekday};

  @override
  void dispose() {
    _titleController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _weekdayLabel(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Reminder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Take medication',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hourController,
                        decoration: const InputDecoration(
                          labelText: 'Hour',
                          hintText: '0–23',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Hour is required';
                          }
                          final h = int.tryParse(value);
                          if (h == null || h < 0 || h > 23) {
                            return 'Hour must be 0–23';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _minuteController,
                        decoration: const InputDecoration(
                          labelText: 'Minute',
                          hintText: '0–59',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Minute is required';
                          }
                          final m = int.tryParse(value);
                          if (m == null || m < 0 || m > 59) {
                            return 'Minute must be 0–59';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<Recurrence>(
                  value: _recurrence,
                  decoration: const InputDecoration(
                    labelText: 'Recurrence',
                    border: OutlineInputBorder(),
                  ),
                  items: Recurrence.values.map((Recurrence value) {
                    return DropdownMenuItem<Recurrence>(
                      value: value,
                      child: Text(_recurrenceLabel(value)),
                    );
                  }).toList(),
                  onChanged: (Recurrence? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _recurrence = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),
                if (_recurrence == Recurrence.weekly || _recurrence == Recurrence.custom)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final day = index + 1;
                      return FilterChip(
                        label: Text(_weekdayLabel(day)),
                        selected: _weekdays.contains(day),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _weekdays.add(day);
                            } else {
                              _weekdays.remove(day);
                            }
                          });
                        },
                      );
                    }),
                  ),
                const SizedBox(height: 24),
                DropdownButtonFormField<Category>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
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
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;

                        final hour = int.tryParse(_hourController.text) ?? 9;
                        final minute = int.tryParse(_minuteController.text) ?? 0;

                        int daysMask = 0;
                        if (_recurrence == Recurrence.weekly || _recurrence == Recurrence.custom) {
                          daysMask = _weekdays.fold(0, (acc, w) => acc | (1 << w));
                        }

                        await context.read<ReminderProvider>().addReminder(
                          title: _titleController.text.trim(),
                          hour: hour,
                          minute: minute,
                          recurrence: _recurrence,
                          daysMask: daysMask,
                          category: _category,
                        );

                        Navigator.of(context).pop();
                      },
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _recurrenceLabel(Recurrence type) {
    switch (type) {
      case Recurrence.once:
        return 'Once';
      case Recurrence.daily:
        return 'Daily';
      case Recurrence.weekly:
        return 'Weekly';
      case Recurrence.custom:
        return 'Custom';
    }
  }

  String _categoryLabel(Category category) {
    switch (category) {
      case Category.medication:
        return 'Medication';
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
}