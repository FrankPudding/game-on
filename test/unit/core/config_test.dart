import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/core/config.dart';

void main() {
  group('AppConfig', () {
    test('should default to hive data source', () {
      final config = AppConfig();

      expect(config.dataSourceType, DataSourceType.hive);
      expect(config.hiveDbVersion, 4);
    });

    test('should accept custom values', () {
      final config = AppConfig(
        dataSourceType: DataSourceType.mock,
        hiveDbVersion: 4,
      );

      expect(config.dataSourceType, DataSourceType.mock);
      expect(config.hiveDbVersion, 4);
    });
  });
}
