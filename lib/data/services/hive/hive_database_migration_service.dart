import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../../core/constants/hive_box_names.dart';
import '../../models/hive/category_hive_model.dart';
import '../../models/hive/ranking_policy_hive_model.dart';
import '../../models/hive/ranking_policies/simple_ranking_policy_hive_model.dart';
import '../../models/hive/ranking_policies/goal_difference_ranking_policy_hive_model.dart';
import '../../models/hive/ranking_policies/fargo_rate_ranking_policy_hive_model.dart';

class HiveDatabaseMigrationService {
  static const String _metaBoxName = 'meta';
  static const String _versionKey = 'db_version';

  late final Map<int, Future<void> Function()> _migrations = {
    2: _migrateToV2,
    3: _migrateToV3,
  };

  /// Idempotent v2: upsert 5 built-in categories (preserves sortOrder),
  /// rebuild slug/parent indexes, backfill empty rankingPolicies to [kFallbackCategoryId],
  /// rebuild categoryPolicyIndex.
  Future<void> _migrateToV2() async {
    // Ensure adapters registered for migration test (Hive.init without DI)
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(CategoryHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(SimpleRankingPolicyHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(GoalDifferenceRankingPolicyHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      // No need for user etc but ensure not failing on box open
    }
    final seeds = [
      {
        'id': 'cat_boardgames',
        'name': 'Board Games',
        'slug': 'board-games',
        'iconName': 'chess',
        'sortOrder': 0,
      },
      {
        'id': 'cat_cardgames',
        'name': 'Card Games',
        'slug': 'card-games',
        'iconName': 'playing_cards',
        'sortOrder': 1000,
      },
      {
        'id': 'cat_sports',
        'name': 'Sports',
        'slug': 'sports',
        'iconName': 'sports_soccer',
        'sortOrder': 2000,
      },
      {
        'id': 'cat_videogames',
        'name': 'Video Games',
        'slug': 'video-games',
        'iconName': 'sports_esports',
        'sortOrder': 3000,
      },
      {
        'id': 'cat_custom_league_001',
        'name': 'Custom',
        'slug': 'custom',
        'iconName': 'category_other',
        'sortOrder': 4000,
      },
    ];

    Box<CategoryHiveModel> categoriesBox;
    if (Hive.isBoxOpen(HiveBoxNames.categories)) {
      categoriesBox = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
    } else {
      categoriesBox =
          await Hive.openBox<CategoryHiveModel>(HiveBoxNames.categories);
    }

    Box<String> slugIndexBox;
    if (Hive.isBoxOpen(HiveBoxNames.categorySlugIndex)) {
      slugIndexBox = Hive.box<String>(HiveBoxNames.categorySlugIndex);
    } else {
      slugIndexBox = await Hive.openBox<String>(HiveBoxNames.categorySlugIndex);
    }

    Box<String> parentIndexBox;
    if (Hive.isBoxOpen(HiveBoxNames.categoryParentIndex)) {
      parentIndexBox = Hive.box<String>(HiveBoxNames.categoryParentIndex);
    } else {
      parentIndexBox =
          await Hive.openBox<String>(HiveBoxNames.categoryParentIndex);
    }

    Box<RankingPolicyHiveModel> rankingBox;
    if (Hive.isBoxOpen(HiveBoxNames.rankingPolicies)) {
      rankingBox =
          Hive.box<RankingPolicyHiveModel>(HiveBoxNames.rankingPolicies);
    } else {
      rankingBox = await Hive.openBox<RankingPolicyHiveModel>(
          HiveBoxNames.rankingPolicies);
    }

    Box<String>? policyIndexBox;
    if (Hive.isBoxOpen(HiveBoxNames.categoryPolicyIndex)) {
      policyIndexBox = Hive.box<String>(HiveBoxNames.categoryPolicyIndex);
    } else {
      try {
        policyIndexBox =
            await Hive.openBox<String>(HiveBoxNames.categoryPolicyIndex);
      } catch (_) {
        policyIndexBox = null;
      }
    }

    final now = DateTime.now();

    for (final seed in seeds) {
      final id = seed['id'] as String;
      final existing = categoriesBox.get(id);
      if (existing != null) {
        if (existing.name != seed['name'] ||
            existing.slug != seed['slug'] ||
            existing.iconName != seed['iconName'] ||
            existing.isBuiltIn != true ||
            existing.parentId != null) {
          final updated = CategoryHiveModel(
            id: id,
            name: seed['name'] as String,
            slug: seed['slug'] as String,
            iconName: seed['iconName'] as String,
            sortOrder: existing.sortOrder,
            isBuiltIn: true,
            parentId: null,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          );
          await categoriesBox.put(id, updated);
        }
      } else {
        final model = CategoryHiveModel(
          id: id,
          name: seed['name'] as String,
          slug: seed['slug'] as String,
          iconName: seed['iconName'] as String,
          sortOrder: seed['sortOrder'] as int,
          isBuiltIn: true,
          parentId: null,
          createdAt: now,
          updatedAt: now,
        );
        await categoriesBox.put(id, model);
      }
    }

    await slugIndexBox.clear();
    await parentIndexBox.clear();
    final Map<String, List<String>> byParent = {};
    for (final c in categoriesBox.values) {
      await slugIndexBox.put(c.slug, c.id);
      final key = c.parentId ?? '__roots__';
      byParent.putIfAbsent(key, () => []).add(c.id);
    }
    for (final entry in byParent.entries) {
      await parentIndexBox.put(entry.key, entry.value.join(','));
    }

    for (final key in rankingBox.keys.toList()) {
      final model = rankingBox.get(key);
      if (model != null && model.categoryIds.isEmpty) {
        final id = model.id;
        final name = model.name;
        final leagueId = model.leagueId;
        final dyn = model as dynamic;
        final pointsForWin = (dyn.pointsForWin as int?) ?? 3;
        final pointsForDraw = (dyn.pointsForDraw as int?) ?? 1;
        final pointsForLoss = (dyn.pointsForLoss as int?) ?? 0;
        final isGoal = model is GoalDifferenceRankingPolicyHiveModel;
        RankingPolicyHiveModel newModel;
        if (isGoal) {
          newModel = GoalDifferenceRankingPolicyHiveModel(
            id: id,
            name: name,
            leagueId: leagueId,
            categoryIds: const [kFallbackCategoryId],
            pointsForWin: pointsForWin,
            pointsForDraw: pointsForDraw,
            pointsForLoss: pointsForLoss,
          );
        } else {
          newModel = SimpleRankingPolicyHiveModel(
            id: id,
            name: name,
            leagueId: leagueId,
            categoryIds: const [kFallbackCategoryId],
            pointsForWin: pointsForWin,
            pointsForDraw: pointsForDraw,
            pointsForLoss: pointsForLoss,
          );
        }
        await rankingBox.put(key, newModel);
      }
    }

    if (policyIndexBox != null) {
      await policyIndexBox.clear();
      final Map<String, List<String>> byCategory = {};
      for (final rp in rankingBox.values) {
        for (final catId in rp.categoryIds) {
          byCategory.putIfAbsent(catId, () => []).add(rp.id);
        }
      }
      for (final entry in byCategory.entries) {
        await policyIndexBox.put(entry.key, entry.value.join(','));
      }
    }
  }

  /// Idempotent v3: upsert cat_pubgames (sortOrder 3500 midpoint (prev+next)~/2 gap<2 normalize),
  /// preserve sortOrder if exists, rebuild slug/parent/categoryPolicy indexes from truth,
  /// meta bump only after success. Adapter typeId 12 guard included.
  Future<void> _migrateToV3() async {
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(FargoRateRankingPolicyHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(CategoryHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(SimpleRankingPolicyHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(GoalDifferenceRankingPolicyHiveModelAdapter());
    }

    Box<CategoryHiveModel> categoriesBox;
    if (Hive.isBoxOpen(HiveBoxNames.categories)) {
      categoriesBox = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
    } else {
      categoriesBox =
          await Hive.openBox<CategoryHiveModel>(HiveBoxNames.categories);
    }

    Box<String> slugIndexBox;
    if (Hive.isBoxOpen(HiveBoxNames.categorySlugIndex)) {
      slugIndexBox = Hive.box<String>(HiveBoxNames.categorySlugIndex);
    } else {
      slugIndexBox = await Hive.openBox<String>(HiveBoxNames.categorySlugIndex);
    }

    Box<String> parentIndexBox;
    if (Hive.isBoxOpen(HiveBoxNames.categoryParentIndex)) {
      parentIndexBox = Hive.box<String>(HiveBoxNames.categoryParentIndex);
    } else {
      parentIndexBox =
          await Hive.openBox<String>(HiveBoxNames.categoryParentIndex);
    }

    Box<RankingPolicyHiveModel> rankingBox;
    if (Hive.isBoxOpen(HiveBoxNames.rankingPolicies)) {
      rankingBox =
          Hive.box<RankingPolicyHiveModel>(HiveBoxNames.rankingPolicies);
    } else {
      rankingBox = await Hive.openBox<RankingPolicyHiveModel>(
          HiveBoxNames.rankingPolicies);
    }

    Box<String>? policyIndexBox;
    if (Hive.isBoxOpen(HiveBoxNames.categoryPolicyIndex)) {
      policyIndexBox = Hive.box<String>(HiveBoxNames.categoryPolicyIndex);
    } else {
      try {
        policyIndexBox =
            await Hive.openBox<String>(HiveBoxNames.categoryPolicyIndex);
      } catch (_) {
        policyIndexBox = null;
      }
    }

    final now = DateTime.now();
    const targetId = 'cat_pubgames';
    const targetName = 'Pub Games';
    const targetSlug = 'pub-games';
    const targetIcon = 'category_other';

    final existing = categoriesBox.get(targetId);
    if (existing != null) {
      if (existing.name != targetName ||
          existing.slug != targetSlug ||
          existing.iconName != targetIcon ||
          existing.isBuiltIn != true ||
          existing.parentId != null) {
        final updated = CategoryHiveModel(
          id: targetId,
          name: targetName,
          slug: targetSlug,
          iconName: targetIcon,
          sortOrder: existing.sortOrder,
          isBuiltIn: true,
          parentId: null,
          createdAt: existing.createdAt,
          updatedAt: existing.updatedAt,
        );
        await categoriesBox.put(targetId, updated);
      }
    } else {
      // Compute midpoint (prev+next)~/2: find surrounding sortOrders
      // Default to 3500 between videogames (3000) and custom (4000)
      int insertionSortOrder = 3500;
      final sortedBefore = categoriesBox.values.toList()
        ..sort((a, b) {
          final c = a.sortOrder.compareTo(b.sortOrder);
          if (c != 0) return c;
          return a.id.compareTo(b.id);
        });
      // Try to compute midpoint between neighbors where pubgames should be inserted
      // For deterministic, if sortedBefore contains videogames and custom, use their values
      CategoryHiveModel? video;
      CategoryHiveModel? custom;
      for (final c in sortedBefore) {
        if (c.id == 'cat_videogames') video = c;
        if (c.id == 'cat_custom_league_001') custom = c;
      }
      if (video != null && custom != null) {
        insertionSortOrder = (video.sortOrder + custom.sortOrder) ~/ 2;
        // ensure distinct and not equal to neighbors; if midpoint equals one of them, fallback to 3500
        if (insertionSortOrder == video.sortOrder ||
            insertionSortOrder == custom.sortOrder) {
          insertionSortOrder = 3500;
        }
      }
      final model = CategoryHiveModel(
        id: targetId,
        name: targetName,
        slug: targetSlug,
        iconName: targetIcon,
        sortOrder: insertionSortOrder,
        isBuiltIn: true,
        parentId: null,
        createdAt: now,
        updatedAt: now,
      );
      await categoriesBox.put(targetId, model);
    }

    // Gap<2 normalize to 0,1000,2000… sorted by current order then id
    final allCats = categoriesBox.values.toList()
      ..sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
    bool needsNormalize = false;
    for (int i = 1; i < allCats.length; i++) {
      if (allCats[i].sortOrder - allCats[i - 1].sortOrder < 2) {
        needsNormalize = true;
        break;
      }
    }
    if (needsNormalize) {
      final sortedForNorm = categoriesBox.values.toList()
        ..sort((a, b) {
          final c = a.sortOrder.compareTo(b.sortOrder);
          if (c != 0) return c;
          return a.id.compareTo(b.id);
        });
      for (int i = 0; i < sortedForNorm.length; i++) {
        final cat = sortedForNorm[i];
        final target = i * 1000;
        if (cat.sortOrder != target) {
          final updated = CategoryHiveModel(
            id: cat.id,
            name: cat.name,
            slug: cat.slug,
            iconName: cat.iconName,
            sortOrder: target,
            isBuiltIn: cat.isBuiltIn,
            parentId: cat.parentId,
            createdAt: cat.createdAt,
            updatedAt: DateTime.now(),
          );
          await categoriesBox.put(cat.id, updated);
        }
      }
    }

    // Rebuild slug/parent indexes
    await slugIndexBox.clear();
    await parentIndexBox.clear();
    final Map<String, List<String>> byParent = {};
    for (final c in categoriesBox.values) {
      await slugIndexBox.put(c.slug, c.id);
      final key = c.parentId ?? '__roots__';
      byParent.putIfAbsent(key, () => []).add(c.id);
    }
    for (final entry in byParent.entries) {
      await parentIndexBox.put(entry.key, entry.value.join(','));
    }

    if (policyIndexBox != null) {
      await policyIndexBox.clear();
      final Map<String, List<String>> byCategory = {};
      for (final rp in rankingBox.values) {
        for (final catId in rp.categoryIds) {
          byCategory.putIfAbsent(catId, () => []).add(rp.id);
        }
      }
      for (final entry in byCategory.entries) {
        await policyIndexBox.put(entry.key, entry.value.join(','));
      }
    }
  }

  /// Migrates from [currentVersion] to [targetVersion] step-wise.
  /// If current >= target, no-op (idempotent guard). The underlying
  /// _migrateToV* implementations are individually idempotent and
  /// retry-safe if version bump not yet persisted (crash).
  /// For explicit repair when already at target, call [_migrateToV2]
  /// directly or [rebuildIndexes] — not via migrate().
  ///
  /// Tests: 0→2 fresh, 1→2 upgrade, 2→2 no-op, crash-retry (throw before bump then re-migrate succeeds).
  Future<void> migrate(int targetVersion) async {
    final metaBox = await Hive.openBox(_metaBoxName);
    int currentVersion = metaBox.get(_versionKey, defaultValue: 0) as int;

    debugPrint(
        'Current DB version: $currentVersion. Target version: $targetVersion');

    if (currentVersion >= targetVersion) {
      debugPrint('Database is up to date.');
      return;
    }

    for (var version = currentVersion + 1;
        version <= targetVersion;
        version++) {
      if (_migrations.containsKey(version)) {
        debugPrint('Migrating to version $version...');
        try {
          await _migrations[version]!();
          await metaBox.put(_versionKey, version);
          debugPrint('Successfully migrated to version $version.');
        } catch (e) {
          debugPrint('Error migrating to version $version: $e');
          rethrow;
        }
      } else {
        debugPrint(
            'No migration script for version $version. Bumping version.');
        await metaBox.put(_versionKey, version);
      }
    }
  }
}
