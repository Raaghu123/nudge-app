"""CI helper: inject permissions + core desugaring into fresh flutter-create output.

Desugaring is APPENDED as extra blocks (Gradle merges duplicate blocks),
so it works regardless of template formatting — no fragile regex.
"""
import pathlib

m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
if not m.exists():
    print('manifest missing, skipping (run flutter create first)')
    raise SystemExit(0)
t = m.read_text()

# ---- Phase 1: Permissions for flutter_local_notifications v17+ ----
perms = (
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
    '    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>\n'
    '    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>\n'
    '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
    '    <uses-permission android:name="android.permission.VIBRATE"/>\n'
    '    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n'
)
if 'POST_NOTIFICATIONS' not in t:
    t = t.replace('<application', perms + '<application', 1)
    m.write_text(t)
    print('permissions injected')
else:
    print('permissions already present')

# ---- Phase 1: flutter_local_notifications receivers inside <application> ----
# ActionBroadcastReceiver is REQUIRED for notification action buttons
# (Done/Snooze): without it the action PendingIntents have no target and
# taps silently do nothing. Matches the plugin README manifest setup.
receivers = (
    '    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />\n'
    '    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
    '    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
    '        <intent-filter>\n'
    '            <action android:name="android.intent.action.BOOT_COMPLETED" />\n'
    '            <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />\n'
    '            <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
    '            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />\n'
    '        </intent-filter>\n'
    '    </receiver>\n'
)
if 'ActionBroadcastReceiver' not in t or 'ScheduledNotificationReceiver' not in t:
    t = t.replace('</application>', receivers + '</application>', 1)
    m.write_text(t)
    print('receivers injected')
else:
    print('receivers already present')

# Core desugaring for flutter_local_notifications v17+
groovy = pathlib.Path('android/app/build.gradle')
kts = pathlib.Path('android/app/build.gradle.kts')
if kts.exists():
    s = kts.read_text()
    if 'desugar_jdk_libs' not in s:
        with kts.open('a') as f:
            f.write(
                '\n// Nudge: core desugaring for flutter_local_notifications\n'
                'android {\n'
                '    compileOptions {\n'
                '        isCoreLibraryDesugaringEnabled = true\n'
                '    }\n'
                '}\n'
                'dependencies {\n'
                '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
                '}\n'
            )
        print('desugaring appended to build.gradle.kts')
    else:
        print('kts already has desugaring')
elif groovy.exists():
    s = groovy.read_text()
    if 'desugar_jdk_libs' not in s:
        with groovy.open('a') as f:
            f.write(
                '\n// Nudge: core desugaring for flutter_local_notifications\n'
                'android {\n'
                '    compileOptions {\n'
                '        coreLibraryDesugaringEnabled true\n'
                '    }\n'
                '}\n'
                'dependencies {\n'
                "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n"
                '}\n'
            )
        print('desugaring appended to build.gradle')
    else:
        print('groovy already has desugaring')
else:
    print('WARNING: no app build file found')