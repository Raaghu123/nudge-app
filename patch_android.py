"""CI helper: inject manifest + gradle requirements into fresh flutter-create output.

Pattern (mirrors hydration_reminder/patch_android.py):
- Append-only edits. Gradle merges duplicate blocks, so extra blocks are safe.
- Never regex the middle of generated files.

Phase 0: nothing to patch yet — no notifications, no special permissions.

Phase 1 will add:
- POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM,
  RECEIVE_BOOT_COMPLETED, VIBRATE permissions
- flutter_local_notifications receiver entries inside <application>
- core library desugaring for flutter_local_notifications
"""
import pathlib

m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
if not m.exists():
    print('manifest missing, skipping (run flutter create first)')
    raise SystemExit(0)

print('Phase 0: no manifest patches required')
