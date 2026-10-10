import 'package:nudge/services/system_channel.dart';

/// An OEM autostart / background-start manager screen.
class OemComponent {
  final String packageName;
  final String className;

  const OemComponent(this.packageName, this.className);
}

/// Deep links into the OEM autostart / battery allowlist screens where
/// scheduled alarms survive aggressive power management.
///
/// [componentFor] is a pure manufacturer-to-component lookup (unit-tested);
/// unknown manufacturers yield null. [openAutostartSettings] opens the
/// matching screen, falling back to the app details settings page when the
/// manufacturer is unknown or its component cannot be opened.
class OemSettings {
  static OemComponent? componentFor(String manufacturer) {
    switch (manufacturer.toLowerCase()) {
      case 'xiaomi':
        return const OemComponent(
          'com.miui.securitycenter',
          'com.miui.permcenter.autostart.AutoStartManagementActivity',
        );
      case 'oneplus':
        return const OemComponent(
          'com.oneplus.security',
          'com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity',
        );
      case 'huawei':
        return const OemComponent(
          'com.huawei.systemmanager',
          'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
        );
      case 'oppo':
      case 'realme':
        return const OemComponent(
          'com.coloros.safecenter',
          'com.coloros.safecenter.permission.startup.StartupAppListActivity',
        );
      case 'vivo':
      case 'iqoo':
        return const OemComponent(
          'com.vivo.permissionmanager',
          'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
        );
      default:
        return null;
    }
  }

  /// Opens the autostart screen for this device, or the app details page
  /// as fallback. Returns true when something was opened.
  static Future<bool> openAutostartSettings() async {
    final manufacturer = await SystemChannel.getManufacturer();
    final component = componentFor(manufacturer);
    if (component != null) {
      final opened = await SystemChannel.openComponent(
        component.packageName,
        component.className,
      );
      if (opened) {
        print('NudgeOem: opened autostart screen for $manufacturer');
        return true;
      }
      print('NudgeOem: autostart component missing for $manufacturer, falling back to app details');
    } else {
      print('NudgeOem: no autostart mapping for $manufacturer, falling back to app details');
    }
    return SystemChannel.openAppDetails();
  }
}
