import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/data/models/hive/category_hive_model.dart';
import 'package:game_on/data/models/hive/ranking_policy_hive_model.dart';
import 'package:game_on/data/models/hive/ranking_policies/simple_ranking_policy_hive_model.dart';
import 'package:game_on/data/models/hive/ranking_policies/goal_difference_ranking_policy_hive_model.dart';
import 'package:game_on/data/services/hive/hive_database_migration_service.dart';
import 'package:game_on/hive_registrar.g.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    // Ensure adapters for tests that open boxes directly (idempotent)
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

    test('migrate should not lower the version', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(5);
      await service.migrate(2);
      final box = await Hive.openBox('meta');
      expect(box.get('db_version'), 5);
    });

    test('0->2 fresh install seeds 5 deterministic categories', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(2);

      final categoriesBox =
          Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      expect(categoriesBox.length, 5);
      // Verify deterministic seeds
      final expected = [
        {
          'id': 'cat_boardgames',
          'name': 'Board Games',
          'slug': 'board-games',
          'iconName': 'chess',
          'sortOrder': 0
        },
        {
          'id': 'cat_cardgames',
          'name': 'Card Games',
          'slug': 'card-games',
          'iconName': 'playing_cards',
          'sortOrder': 1000
        },
        {
          'id': 'cat_sports',
          'name': 'Sports',
          'slug': 'sports',
          'iconName': 'sports_soccer',
          'sortOrder': 2000
        },
        {
          'id': 'cat_videogames',
          'name': 'Video Games',
          'slug': 'video-games',
          'iconName': 'sports_esports',
          'sortOrder': 3000
        },
        {
          'id': 'cat_custom_league_001',
          'name': 'Custom',
          'slug': 'custom',
          'iconName': 'category_other',
          'sortOrder': 4000
        },
      ];
      for (final e in expected) {
        final model = categoriesBox.get(e['id'] as String);
        expect(model, isNotNull, reason: 'missing ${e['id']}');
        expect(model!.name, e['name']);
        expect(model.slug, e['slug']);
        expect(model.iconName, e['iconName']);
        expect(model.sortOrder, e['sortOrder']);
        expect(model.isBuiltIn, true);
        expect(model.parentId, isNull);
      }

      // Slug and parent indexes rebuilt
      final slugIndex = Hive.box<String>(HiveBoxNames.categorySlugIndex);
      expect(slugIndex.length, 5);
      for (final e in expected) {
        expect(slugIndex.get(e['slug'] as String), e['id']);
      }
      final parentIndex = Hive.box<String>(HiveBoxNames.categoryParentIndex);
      final rootsRaw = parentIndex.get('__roots__');
      expect(rootsRaw, isNotNull);
      final roots = rootsRaw!.split(',').where((s) => s.isNotEmpty).toList();
      expect(roots.length, 5);
      expect(roots.toSet().containsAll(expected.map((e) => e['id'] as String)),
          true);

      // Meta bumped to 2
      final meta = Hive.box('meta');
      expect(meta.get('db_version'), 2);
    });

    test('1->2 upgrade seeds categories and backfills empty policies',
        () async {
      // Simulate v1: meta=1 with one legacy policy empty categoryIds
      final service = HiveDatabaseMigrationService();
      await service.migrate(1);
      // Create legacy policy with empty categoryIds via direct box put
      final rankingBox = await Hive.openBox<RankingPolicyHiveModel>(
          HiveBoxNames.rankingPolicies);
      final legacy = SimpleRankingPolicyHiveModel(
        id: 'policy_legacy_1',
        name: 'Legacy',
        leagueId: 'league_1',
        categoryIds: const [],
      );
      await rankingBox.put(legacy.id, legacy);
      // Now migrate to 2
      await service.migrate(2);

      final categoriesBox =
          Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      expect(categoriesBox.length, 5);
      // Backfill check
      final updated =
          rankingBox.get('policy_legacy_1') as SimpleRankingPolicyHiveModel;
      expect(updated.categoryIds, [kFallbackCategoryId]);

      // Policy index rebuilt
      final policyIndex = Hive.box<String>(HiveBoxNames.categoryPolicyIndex);
      expect(policyIndex.get(kFallbackCategoryId), contains('policy_legacy_1'));

      final meta = Hive.box('meta');
      expect(meta.get('db_version'), 2);
    });

    test('2->2 no-op does not duplicate or mutate sortOrder', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(2);
      final categoriesBox =
          Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      // Change sortOrder of a built-in to verify preservation
      final custom = categoriesBox.get('cat_custom_league_001')!;
      final mutated = CategoryHiveModel(
        id: custom.id,
        name: custom.name,
        slug: custom.slug,
        iconName: custom.iconName,
        sortOrder: 9999,
        isBuiltIn: custom.isBuiltIn,
        parentId: custom.parentId,
        createdAt: custom.createdAt,
        updatedAt: custom.updatedAt,
      );
      await categoriesBox.put(custom.id, mutated);

      await service.migrate(2); // no-op

      final after = categoriesBox.get('cat_custom_league_001')!;
      expect(after.sortOrder, 9999,
          reason: 'sortOrder should be preserved on 2->2 no-op');
      expect(categoriesBox.length, 5);
      final meta = Hive.box('meta');
      expect(meta.get('db_version'), 2);
    });

    test('crash-retry: version not bumped on failure, re-migrate succeeds',
        () async {
      final service = HiveDatabaseMigrationService();
      // Simulate crash by manually creating boxes but not bumping version to 2
      // First migrate to 1
      await service.migrate(1);
      // Manually inject a policy empty
      final rankingBox = await Hive.openBox<RankingPolicyHiveModel>(
          HiveBoxNames.rankingPolicies);
      await rankingBox.put(
        'policy_crash',
        SimpleRankingPolicyHiveModel(
            id: 'policy_crash',
            name: 'Crash',
            leagueId: 'l1',
            categoryIds: const []),
      );
      // Simulate failed 2 migration by putting meta still at 1
      final meta = Hive.box('meta');
      expect(meta.get('db_version'), 1);
      // Retry migrate to 2 should succeed idempotently
      await service.migrate(2);
      expect(meta.get('db_version'), 2);
      final updated =
          rankingBox.get('policy_crash') as SimpleRankingPolicyHiveModel;
      expect(updated.categoryIds, [kFallbackCategoryId]);

      // Second retry when already 2 should be no-op but data stays consistent
      await service.migrate(2);
      expect(meta.get('db_version'), 2);
      expect(
          (rankingBox.get('policy_crash') as SimpleRankingPolicyHiveModel)
              .categoryIds,
          [kFallbackCategoryId]);
    });

    test('backfill handles both simple and goalDifference empty', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(1);
      final rankingBox = await Hive.openBox<RankingPolicyHiveModel>(
          HiveBoxNames.rankingPolicies);
      await rankingBox.put(
        'p_simple',
        SimpleRankingPolicyHiveModel(
            id: 'p_simple', name: 'S', leagueId: 'l', categoryIds: const []),
      );
      await rankingBox.put(
        'p_goal',
        GoalDifferenceRankingPolicyHiveModel(
            id: 'p_goal', name: 'G', leagueId: 'l', categoryIds: const []),
      );
      await service.migrate(2);
      expect(
          (rankingBox.get('p_simple') as SimpleRankingPolicyHiveModel)
              .categoryIds,
          [kFallbackCategoryId]);
      expect(
          (rankingBox.get('p_goal') as GoalDifferenceRankingPolicyHiveModel)
              .categoryIds,
          [kFallbackCategoryId]);
    });

    test('idempotent re-run via direct boxes preserves sortOrder', () async {
      final service = HiveDatabaseMigrationService();
      await service.migrate(2);
      final categoriesBox =
          Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
      final beforeOrders = {
        for (var c in categoriesBox.values) c.id: c.sortOrder
      };
      // Manually reset meta to 1 and re-migrate (simulates retry)
      final meta = Hive.box('meta');
      await meta.put('db_version', 1);
      await service.migrate(2);
      for (var c in categoriesBox.values) {
        expect(c.sortOrder, beforeOrders[c.id]);
      }
      expect(meta.get('db_version'), 2);
    });
  });
}
