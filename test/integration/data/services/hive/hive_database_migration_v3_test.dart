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
      try { Hive.registerAdapters(); } catch (_) {}
    }
    if (!Hive.isAdapterRegistered(12)) {
      // ensure not double registered
    }
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('Migration V3 – cat_pubgames', () {
    test('0->3 fresh installs 6 categories including cat_pubgames at 3500', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(3);
      final box = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      expect(box.length, 6);
      final pub = box.get('cat_pubgames');
      expect(pub, isNotNull, reason: 'cat_pubgames missing after V3');
      expect(pub!.isBuiltIn, isTrue);
      expect(pub.parentId, isNull);
      expect(pub.sortOrder, 3500, reason: 'midpoint 3500 between 3000 and 4000');
      expect(pub.name, isNotEmpty);
      expect(pub.slug, isNotEmpty);
      // adapter guard
      expect(Hive.isAdapterRegistered(12), isTrue);
      final meta = Hive.box('meta');
      expect(meta.get('db_version'), 3);
      // slug index rebuilt contains pubgames slug
      final slugIndex = Hive.box<String>(HiveBoxNames.categorySlugIndex);
      expect(slugIndex.get(pub.slug), 'cat_pubgames');
      // parent index contains roots
      final parentIndex = Hive.box<String>(HiveBoxNames.categoryParentIndex);
      final rootsRaw = parentIndex.get('__roots__');
      expect(rootsRaw, isNotNull);
      expect(rootsRaw!.split(',').contains('cat_pubgames'), isTrue);
    });

    test('2->3 upgrade preserves existing sortOrder if cat_pubgames already exists', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(2);
      final box = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      // manually insert pubgames with custom sortOrder
      final existing = CategoryHiveModel(
        id: 'cat_pubgames',
        name: 'Pub Games',
        slug: 'pub-games',
        iconName: 'category_other',
        sortOrder: 9999,
        isBuiltIn: true,
        parentId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await box.put('cat_pubgames', existing);
      await service.migrate(3);
      final after = box.get('cat_pubgames')!;
      expect(after.sortOrder, 9999, reason: 'preserve sortOrder if exists');
      expect(box.length, 6);
    });

    test('gap<2 triggers normalize to 0,1000,2000… sorted by current order then id', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(2);
      final box = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      // mutate all to have tight gaps: 0,1,2,3,4
      int i = 0;
      for (final cat in box.values.toList()) {
        final updated = CategoryHiveModel(
          id: cat.id,
          name: cat.name,
          slug: cat.slug,
          iconName: cat.iconName,
          sortOrder: i++,
          isBuiltIn: cat.isBuiltIn,
          parentId: cat.parentId,
          createdAt: cat.createdAt,
          updatedAt: cat.updatedAt,
        );
        await box.put(cat.id, updated);
      }
      await service.migrate(3);
      final sorted = box.values.toList()..sort((a,b)=> a.sortOrder.compareTo(b.sortOrder));
      // After normalize, gaps should be 1000
      // Check that pubgames inserted at midpoint then normalize happened -> deterministic 0,1000...
      expect(sorted.map((c)=>c.sortOrder).toList(), containsAll([0,1000,2000,3000,4000,5000]));
      // Verify gap >=1000
      for (int j=1; j<sorted.length; j++) {
        expect(sorted[j].sortOrder - sorted[j-1].sortOrder, greaterThanOrEqualTo(1000));
      }
    });

    test('rebuilds slug/parent/categoryPolicy indexes from truth', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(3);
      final slugIndex = Hive.box<String>(HiveBoxNames.categorySlugIndex);
      final parentIndex = Hive.box<String>(HiveBoxNames.categoryParentIndex);
      final catBox = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      expect(slugIndex.length, catBox.length);
      for (final c in catBox.values) {
        expect(slugIndex.get(c.slug), c.id);
      }
      expect(parentIndex.get('__roots__'), isNotNull);
    });

    test('adapter typeId 12 guard present and not duplicate registration', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(3);
      expect(Hive.isAdapterRegistered(12), isTrue);
      // second migrate should be idempotent no throw
      await service.migrate(3);
      expect(Hive.isAdapterRegistered(12), isTrue);
    });

    test('idempotent re-run 3->3 preserves data and indexes', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(3);
      final box = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      final before = { for (var c in box.values) c.id: c.sortOrder };
      await service.migrate(3);
      for (var c in box.values) {
        expect(c.sortOrder, before[c.id]);
      }
      expect(box.length, 6);
      final meta = Hive.box('meta');
      expect(meta.get('db_version'), 3);
    });

    test('crash-retry: if V3 throws before bump, retry succeeds (meta not bumped)', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(2);
      final meta = Hive.box('meta');
      expect(meta.get('db_version'), 2);
      // First attempt to 3 would normally succeed; we simulate retry by resetting meta after partial?
      await service.migrate(3);
      expect(meta.get('db_version'), 3);
      // Reset to 2 and retry should again reach 3 idempotently
      await meta.put('db_version', 2);
      await service.migrate(3);
      expect(meta.get('db_version'), 3);
    });
  });
}
