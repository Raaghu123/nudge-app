import 'package:flutter/services.dart';

/// Thin wrapper over the `nudge/system` platform channel, which
/// patch_android.py injects into the CI-generated MainActivity.
///
/// Every call degrades to a safe default when the channel is absent (a build
/// where the patch did not apply) or the call fails: features log and skip
/// instead of crashing app init.
class SystemChannel {
  static const MethodChannel _channel = MethodChannel('nudge/system');

  /// Device boot count from Settings.Global.BOOT_COUNT. Null when unknown.
  static Future<int?> getBootCount() async {
    try {
      return await _channel.invokeMethod<int>('getBootCount');
    } on PlatformException catch (e) {
      print('NudgeBoot: getBootCount failed: ${e.message}');
      return null;
    } catch (e) {
      print('NudgeBoot: system channel missing: $e');
      return null;
    }
  }

  /// Build.MANUFACTURER in its raw casing, or 'unknown' when unavailable.
  static Future<String> getManufacturer() async {
    try {
      final m = await _channel.invokeMethod<String>('getManufacturer');
      if (m != null && m.isNotEmpty) return m;
    } on PlatformException catch (e) {
      print('NudgeOem: getManufacturer failed: ${e.message}');
    } catch (e) {
      print('NudgeOem: system channel missing: $e');
    }
    return 'unknown';
  }

  /// Opens an explicit OEM component. False when the activity is absent.
  static Future<bool> openComponent(String packageName, String className) async {
    try {
      final opened = await _channel.invokeMethod<bool>('openComponent', {
        'package': packageName,
        'class': className,
      });
      return opened ?? false;
    } on PlatformException catch (e) {
      print('NudgeOem: openComponent failed: ${e.message}');
      return false;
    } catch (e) {
      print('NudgeOem: system channel missing: $e');
      return false;
    }
  }

  /// Opens this app's system details page. Always available; the fallback
  /// when no OEM autostart screen exists or can be opened.
  static Future<bool> openAppDetails() async {
    try {
      final opened = await _channel.invokeMethod<bool>('openAppDetails');
      return opened ?? false;
    } on PlatformException catch (e) {
      print('NudgeOem: openAppDetails failed: ${e.message}');
      return false;
    } catch (e) {
      print('NudgeOem: system channel missing: $e');
      return false;
    }
  }
}
