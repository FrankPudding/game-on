import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:game_on/data/services/hive/hive_database_migration_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('HiveDatabaseMigrationService', () {
    test('should start with version 0 by default', () async {
      final box = await Hive.openBox('meta');
      expect(box.get('db_version', defaultValue: 0), 0);
    });

    test('migrate should update version to target version', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(1);

      final box = await Hive.openBox('meta');
      expect(box.get('db_version'), 1);
    });

    test('migrate should sequentially update version', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(1);

      var box = await Hive.openBox('meta');
      expect(box.get('db_version'), 1);

      await service.migrate(3);
      box = await Hive.openBox('meta');
      expect(box.get('db_version'), 3);
    });

    test('migrate should specific migration steps', () async {
      // NOTE: This test depends on the internal _migrations map of the service.
      // Since the map is currently empty or hardcoded, we can only verify
      // that the version eventually reaches the target.
      // If we add actual migrations, we should verify their side effects here.

      final service = HiveDatabaseMigrationService();
      await service.migrate(5);
      final box = await Hive.openBox('meta');
      expect(box.get('db_version'), 5);
    });

    test('migrate should not lower the version', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(5);

      // Try to migrate to lower version
      await service.migrate(2);

      final box = await Hive.openBox('meta');
      expect(box.get('db_version'), 5);
    });
  });
}
