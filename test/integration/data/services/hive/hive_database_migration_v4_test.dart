import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/data/models/hive/category_hive_model.dart';
import 'package:game_on/data/services/hive/hive_database_migration_service.dart';
import 'package:game_on/hive_registrar.g.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(11)) {
      try {
        Hive.registerAdapters();
      } catch (_) {}
    }
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('Migration V4 – cat_tabletennis', () {
    test('3->4 migration seeds cat_tabletennis under cat_sports with sports_tennis icon and rebuilds indexes', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(3);

      final box = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      final tt = box.get('cat_tabletennis');
      expect(tt, isNull);

      await service.migrate(4);

      final ttAfter = box.get('cat_tabletennis');
      expect(ttAfter, isNotNull);
      expect(ttAfter!.name, 'Table Tennis');
      expect(ttAfter.slug, 'table-tennis');
      expect(ttAfter.iconName, 'sports_tennis');
      expect(ttAfter.parentId, 'cat_sports');
      expect(ttAfter.isBuiltIn, isTrue);

      final meta = Hive.box('meta');
      expect(meta.get('db_version'), 4);

      // Verify slug index
      final slugIndex = Hive.box<String>(HiveBoxNames.categorySlugIndex);
      expect(slugIndex.get('table-tennis'), 'cat_tabletennis');

      // Verify parent index for cat_sports contains cat_tabletennis
      final parentIndex = Hive.box<String>(HiveBoxNames.categoryParentIndex);
      final sportsChildren = parentIndex.get('cat_sports');
      expect(sportsChildren, isNotNull);
      expect(sportsChildren!.split(',').contains('cat_tabletennis'), isTrue);
    });

    test('0->4 fresh install seeds table tennis along with other built-in categories', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(4);

      final box = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      final tt = box.get('cat_tabletennis');
      expect(tt, isNotNull);
      expect(tt!.parentId, 'cat_sports');
      expect(tt.iconName, 'sports_tennis');

      final meta = Hive.box('meta');
      expect(meta.get('db_version'), 4);
    });
  });
}
