import 'package:hive_ce/hive_ce.dart';
import '../../../core/constants/hive_box_names.dart';
import '../../models/hive/category_hive_model.dart';
import '../../models/hive/ranking_policy_hive_model.dart';

class CategoryIndexRebuilder {
  CategoryIndexRebuilder();

  Future<void> rebuildIfNeeded() async {
    if (!Hive.isBoxOpen(HiveBoxNames.categories) ||
        !Hive.isBoxOpen(HiveBoxNames.categorySlugIndex) ||
        !Hive.isBoxOpen(HiveBoxNames.categoryParentIndex)) {
      return;
    }
    final categoriesBox = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
    final slugIndex = Hive.box<String>(HiveBoxNames.categorySlugIndex);
    final parentIndex = Hive.box<String>(HiveBoxNames.categoryParentIndex);

    // Drift check: sizes or missing entries
    bool needsRebuild = false;
    if (slugIndex.length != categoriesBox.length) {
      needsRebuild = true;
    } else {
      for (final c in categoriesBox.values) {
        final indexedId = slugIndex.get(c.slug);
        if (indexedId != c.id) {
          needsRebuild = true;
          break;
        }
      }
    }
    // Parent index drift: check each parentId mapping
    if (!needsRebuild) {
      // parentIndex stores parentId -> comma joined ids? Actually spec says parent index optional.
      // We store as key = parentId (or '__roots__'), value = comma separated ids.
      // Quick drift check: count roots
      final roots =
          categoriesBox.values.where((c) => c.parentId == null).length;
      final indexedRootsRaw = parentIndex.get('__roots__');
      final indexedRootsCount =
          indexedRootsRaw == null || indexedRootsRaw.isEmpty
              ? 0
              : indexedRootsRaw.split(',').where((e) => e.isNotEmpty).length;
      if (roots != indexedRootsCount) {
        needsRebuild = true;
      }
    }

    if (needsRebuild) {
      await rebuild();
    }

    // Also rebuild category_policy_index if open
    if (Hive.isBoxOpen(HiveBoxNames.categoryPolicyIndex) &&
        Hive.isBoxOpen(HiveBoxNames.rankingPolicies)) {
      await rebuildPolicyIndex();
    }
  }

  Future<void> rebuild() async {
    final categoriesBox = Hive.box<CategoryHiveModel>(HiveBoxNames.categories);
    final slugIndex = Hive.box<String>(HiveBoxNames.categorySlugIndex);
    final parentIndex = Hive.box<String>(HiveBoxNames.categoryParentIndex);

    await slugIndex.clear();
    await parentIndex.clear();

    final Map<String, List<String>> byParent = {};
    for (final c in categoriesBox.values) {
      await slugIndex.put(c.slug, c.id);
      final key = c.parentId ?? '__roots__';
      byParent.putIfAbsent(key, () => []).add(c.id);
    }
    for (final entry in byParent.entries) {
      await parentIndex.put(entry.key, entry.value.join(','));
    }
  }

  Future<void> rebuildPolicyIndex() async {
    final rankingBox =
        Hive.box<RankingPolicyHiveModel>(HiveBoxNames.rankingPolicies);
    final policyIndex = Hive.box<String>(HiveBoxNames.categoryPolicyIndex);

    await policyIndex.clear();
    final Map<String, List<String>> byCategory = {};
    for (final rp in rankingBox.values) {
      for (final catId in rp.categoryIds) {
        byCategory.putIfAbsent(catId, () => []).add(rp.id);
      }
    }
    for (final entry in byCategory.entries) {
      await policyIndex.put(entry.key, entry.value.join(','));
    }
  }
}
