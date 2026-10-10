import 'package:shared_preferences/shared_preferences.dart';
import 'package:nudge/core/db/database_helper.dart';
import 'package:nudge/core/models/reminder.dart';
import 'package:nudge/core/repositories/reminder_repository.dart';
import 'package:nudge/services/notification_service.dart';
import 'package:nudge/services/system_channel.dart';

/// Cold-start self-heal for reboots.
///
/// On several OEM skins (Xiaomi, OnePlus, Huawei, Oppo, Vivo) BOOT_COMPLETED
/// is suppressed for sideloaded apps, so the boot receiver never re-arms
/// alarms wiped by the reboot. This check runs on every app init instead:
/// Settings.Global.BOOT_COUNT is compared against the value stored in
/// SharedPreferences, and any delta means the device rebooted since the
/// last launch, so every persisted pending reminder is re-armed via
/// NotificationService. Re-arming is idempotent (same alarm ids replace
/// the previous schedule), so a spurious heal is harmless.
class BootRecovery {
  static const String _prefsKey = 'nudge_last_boot_count';

  static Future<void> checkAndHeal() async {
    final prefs = await SharedPreferences.getInstance();
    final bootCount = await SystemChannel.getBootCount();
    final stored = prefs.getInt(_prefsKey);
    if (bootCount == null) {
      // Channel unavailable: heal as a precaution. ReminderProvider also
      // re-arms on init, so this only duplicates idempotent schedules.
      print('NudgeBoot: boot count unavailable, re-arming pending as precaution');
      await _rearmPending();
      return;
    }
    if (stored == null) {
      await prefs.setInt(_prefsKey, bootCount);
      print('NudgeBoot: first run, stored bootCount=$bootCount');
      return;
    }
    if (bootCount != stored) {
      print('NudgeBoot: reboot detected (stored=$stored now=$bootCount), re-arming pending reminders');
      await _rearmPending();
      await prefs.setInt(_prefsKey, bootCount);
    } else {
      print('NudgeBoot: no reboot (bootCount=$bootCount)');
    }
  }

  static Future<void> _rearmPending() async {
    try {
      final db = await openAppDatabase();
      final repo = ReminderRepository(db);
      final all = await repo.getAll();
      var n = 0;
      for (final r in all) {
        if (r.status == ReminderStatus.pending) {
          await NotificationService.scheduleNext(r);
          n++;
        }
      }
      print('NudgeBoot: re-armed $n pending reminder(s)');
    } catch (e) {
      print('NudgeBoot: re-arm failed: $e');
    }
  }
}
