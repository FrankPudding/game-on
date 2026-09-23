import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/core/config.dart';

void main() {
  group('AppConfig – Fargo V3', () {
    test('default hiveDbVersion is 3', () {
      final config = AppConfig();
      expect(config.hiveDbVersion, 3);
    });

    test('hiveDbVersion can be overridden but defaults to 3', () {
      final custom = AppConfig(hiveDbVersion: 2);
      expect(custom.hiveDbVersion, 2);
      expect(AppConfig().hiveDbVersion, 3);
    });
  });
}
