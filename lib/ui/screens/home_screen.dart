import 'package:flutter/material.dart' hide Category;
import 'package:provider/provider.dart';
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/providers/reminder_provider.dart';
import 'package:nudge/ui/screens/create_reminder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReminderProvider>();
    final upcoming = provider.upcoming;

    return Scaffold(
      appBar: AppBar(title: const Text('Nudge')),
      body: upcoming.isEmpty
          ? const Center(
              child: Text('No upcoming reminders.', style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: upcoming.length,
              itemBuilder: (context, index) {
                final reminder = upcoming[index];
                return _ReminderTile(reminder: reminder);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateReminderScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final Reminder reminder;

  const _ReminderTile({required this.reminder});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _CategoryBadge(category: reminder.category),
      title: Text(reminder.title),
      subtitle: Text('Next: ${_formatTime(reminder.nextFireAt)}'),
      trailing: reminder.id != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    context.read<ReminderProvider>().complete(reminder.id!);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.snooze),
                  onPressed: () {
                    context.read<ReminderProvider>().snooze(reminder.id!);
                  },
                ),
              ],
            )
          : null,
    );
  }
}

String _formatTime(DateTime? dt) {
  if (dt == null) {
    return '--:--';
  }
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _CategoryBadge extends StatelessWidget {
  final Category category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    final label = _categoryLabel(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _categoryColor(Category category) {
    switch (category) {
      case Category.medication:
        return Colors.red;
      case Category.errand:
        return Colors.orange;
      case Category.study:
        return Colors.blue;
      case Category.appointment:
        return Colors.green;
      case Category.payment:
        return Colors.purple;
      case Category.other:
        return Colors.grey;
    }
  }

  String _categoryLabel(Category category) {
    switch (category) {
      case Category.medication:
        return 'medication';
      case Category.errand:
        return 'errand';
      case Category.study:
        return 'study';
      case Category.appointment:
        return 'appointment';
      case Category.payment:
        return 'payment';
      case Category.other:
        return 'other';
    }
  }
}