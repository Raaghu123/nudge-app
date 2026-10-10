import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/oem_settings.dart';

void main() {
  group('OemSettings.componentFor', () {
    test('maps xiaomi to autostart management', () {
      final c = OemSettings.componentFor('Xiaomi');
      expect(c, isNotNull);
      expect(c!.packageName, equals('com.miui.securitycenter'));
      expect(c.className, contains('AutoStart'));
    });

    test('maps oneplus to chain launch list', () {
      final c = OemSettings.componentFor('OnePlus');
      expect(c, isNotNull);
      expect(c!.packageName, equals('com.oneplus.security'));
    });

    test('maps huawei to startup manager', () {
      final c = OemSettings.componentFor('HUAWEI');
      expect(c, isNotNull);
      expect(c!.packageName, equals('com.huawei.systemmanager'));
    });

    test('maps oppo and realme to startup list', () {
      for (final m in ['OPPO', 'Realme', 'oppo']) {
        final c = OemSettings.componentFor(m);
        expect(c, isNotNull, reason: m);
        expect(c!.packageName, equals('com.coloros.safecenter'));
      }
    });

    test('maps vivo and iqoo to background start manager', () {
      for (final m in ['vivo', 'iQOO']) {
        final c = OemSettings.componentFor(m);
        expect(c, isNotNull, reason: m);
        expect(c!.packageName, equals('com.vivo.permissionmanager'));
      }
    });

    test('matching is case-insensitive', () {
      expect(OemSettings.componentFor('XIAOMI')?.packageName,
          equals(OemSettings.componentFor('xiaomi')?.packageName));
    });

    test('returns null for unknown manufacturers', () {
      expect(OemSettings.componentFor('Google'), isNull);
      expect(OemSettings.componentFor('Samsung'), isNull);
      expect(OemSettings.componentFor('unknown'), isNull);
      expect(OemSettings.componentFor(''), isNull);
    });
  });
}
