import 'package:hive_ce/hive_ce.dart';
import 'package:synchronized/synchronized.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/value_objects/category_icon.dart';
import '../../../domain/repositories/category_repository.dart';
import '../../../domain/exceptions/built_in_category_exception.dart';
import '../../models/hive/category_hive_model.dart';
import '../../models/hive/ranking_policy_hive_model.dart';

class HiveCategoryRepository implements CategoryRepository {
  HiveCategoryRepository(
    this._categoriesBox,
    this._slugIndexBox,
    this._parentIndexBox,
    this._rankingPolicyBox,
    this._lock, {
    Box<String>? categoryPolicyIndexBox,
  }) : _categoryPolicyIndexBox = categoryPolicyIndexBox;

  final Box<CategoryHiveModel> _categoriesBox;
  final Box<String> _slugIndexBox;
  final Box<String> _parentIndexBox;
  final Box<RankingPolicyHiveModel> _rankingPolicyBox;
  final Box<String>? _categoryPolicyIndexBox;
  final Lock _lock;

  @override
  Future<Category?> get(String id) async {
    final model = _categoriesBox.get(id);
    return model?.toDomain();
  }

  @override
  Future<Category?> getBySlug(String slug) async {
    // Use slug index if available, fallback to scan
    final id = _slugIndexBox.get(slug);
    if (id != null) {
      final model = _categoriesBox.get(id);
      if (model != null) return model.toDomain();
    }
    // fallback scan truth
    for (final m in _categoriesBox.values) {
      if (m.slug == slug) return m.toDomain();
    }
    return null;
  }

  @override
  Future<List<Category>> getAllOrdered() async {
    final list = _categoriesBox.values.map((m) => m.toDomain()).toList();
    list.sort((a, b) {
      final parentCmp = (a.parentId ?? '').compareTo(b.parentId ?? '');
      if (parentCmp != 0) return parentCmp;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return list;
  }

  @override
  Future<List<Category>> getByIds(List<String> ids) async {
    final result = <Category>[];
    for (final id in ids) {
      final model = _categoriesBox.get(id);
      if (model != null) result.add(model.toDomain());
    }
    return result;
  }

  @override
  Future<List<Category>> getChildren(String parentId) async {
    final list = _categoriesBox.values
        .where((m) => m.parentId == parentId)
        .map((m) => m.toDomain())
        .toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<List<Category>> getRoots() async {
    final list = _categoriesBox.values
        .where((m) => m.parentId == null)
        .map((m) => m.toDomain())
        .toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// Returns true if all [ids] exist in the categories box.
  /// Throws [ArgumentError] if [ids] is empty (programmer error).
  @override
  Future<bool> existsAll(List<String> ids) async {
    if (ids.isEmpty) {
      throw ArgumentError('categoryIds must not be empty');
    }
    for (final id in ids) {
      if (!_categoriesBox.containsKey(id)) return false;
    }
    return true;
  }

  @override
  Future<void> put(Category category) async {
    await _lock.synchronized(() async {
      // Validate parent exists
      if (category.parentId != null) {
        final parent = _categoriesBox.get(category.parentId);
        if (parent == null) {
          throw ArgumentError(
              'Parent category ${category.parentId} does not exist');
        }
      }

      // Validate depth and cycle using all categories including this one
      final allModels = _categoriesBox.values.map((m) => m.toDomain()).toList();
      // Remove existing if updating
      allModels.removeWhere((c) => c.id == category.id);
      allModels.add(category);
      Category.validateNoCycleAndDepth(allModels, maxDepth: kCategoryMaxDepth);

      // isBuiltIn guard: only sort/icon mutable for built-ins
      final existingModel = _categoriesBox.get(category.id);
      if (existingModel != null && existingModel.isBuiltIn) {
        final existing = existingModel.toDomain();
        // Only sortOrder and icon mutable
        if (existing.name != category.name ||
            existing.slug.value != category.slug.value ||
            existing.parentId != category.parentId ||
            existing.isBuiltIn != category.isBuiltIn ||
            existing.createdAt != category.createdAt) {
          throw BuiltInCategoryException(category.id);
        }
      }

      // Slug uniqueness via truth scan + slug_index putIfAbsent double-checked locking inside Lock
      // Truth scan
      for (final m in _categoriesBox.values) {
        if (m.id != category.id && m.slug == category.slug.value) {
          throw ArgumentError('Slug ${category.slug.value} already exists');
        }
      }
      // Check slug index
      final existingIdForSlug = _slugIndexBox.get(category.slug.value);
      if (existingIdForSlug != null && existingIdForSlug != category.id) {
        throw ArgumentError(
            'Slug ${category.slug.value} already exists (index)');
      }

      // Sort per parent midpoint normalize
      int sortOrder = category.sortOrder;
      final siblings = _categoriesBox.values
          .where((m) => m.parentId == category.parentId && m.id != category.id)
          .toList();
      // If duplicate sortOrder, apply midpoint logic
      final usedSorts = siblings.map((e) => e.sortOrder).toSet();
      if (usedSorts.contains(sortOrder)) {
        siblings.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        // Find neighbors
        int? prev;
        int? next;
        for (final s in siblings) {
          if (s.sortOrder < sortOrder) prev = s.sortOrder;
          if (s.sortOrder > sortOrder && next == null) next = s.sortOrder;
        }
        if (prev != null && next != null) {
          final midpoint = (prev + next) ~/ 2;
          if (midpoint != prev && midpoint != next) {
            sortOrder = midpoint;
          } else {
            // need normalize: reassign spaced orders
            await _normalizeSortOrders(category.parentId);
            // recompute after normalize
            sortOrder = category.sortOrder;
          }
        } else if (prev != null) {
          sortOrder = prev + 1000;
        } else if (next != null) {
          sortOrder = next - 1000;
        } else {
          // only collision, keep
        }
      }

      // Handle slug change: remove old index entry
      if (existingModel != null && existingModel.slug != category.slug.value) {
        await _slugIndexBox.delete(existingModel.slug);
      }

      // Put with rollback support
      final modelToStore = CategoryHiveModel(
        id: category.id,
        name: category.name,
        slug: category.slug.value,
        iconName: category.icon.iconName,
        sortOrder: sortOrder,
        isBuiltIn: category.isBuiltIn,
        parentId: category.parentId,
        createdAt: category.createdAt,
        updatedAt: category.updatedAt,
      );

      // Backup for rollback
      CategoryHiveModel? backup;
      if (existingModel != null) {
        backup = CategoryHiveModel(
          id: existingModel.id,
          name: existingModel.name,
          slug: existingModel.slug,
          iconName: existingModel.iconName,
          sortOrder: existingModel.sortOrder,
          isBuiltIn: existingModel.isBuiltIn,
          parentId: existingModel.parentId,
          createdAt: existingModel.createdAt,
          updatedAt: existingModel.updatedAt,
        );
      }
      final oldSlug = existingModel?.slug;

      try {
        await _categoriesBox.put(category.id, modelToStore);
        // putIfAbsent double-checked
        final after = _slugIndexBox.get(category.slug.value);
        if (after != null && after != category.id) {
          throw ArgumentError(
              'Slug conflict after put: ${category.slug.value}');
        }
        await _slugIndexBox.put(category.slug.value, category.id);

        // Update parent index
        await _rebuildParentIndexForParent(category.parentId);
        if (existingModel != null &&
            existingModel.parentId != category.parentId) {
          await _rebuildParentIndexForParent(existingModel.parentId);
        }
      } catch (e) {
        // rollback delete+flush style
        if (backup != null) {
          await _categoriesBox.put(backup.id, backup);
          if (oldSlug != null) {
            await _slugIndexBox.put(oldSlug, backup.id);
            if (oldSlug != category.slug.value) {
              await _slugIndexBox.delete(category.slug.value);
            }
          }
        } else {
          await _categoriesBox.delete(category.id);
          await _slugIndexBox.delete(category.slug.value);
        }
        rethrow;
      }
    });
  }

  Future<void> _normalizeSortOrders(String? parentId) async {
    final siblings =
        _categoriesBox.values.where((m) => m.parentId == parentId).toList();
    siblings.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    int order = 0;
    for (final m in siblings) {
      if (m.sortOrder != order) {
        final updated = CategoryHiveModel(
          id: m.id,
          name: m.name,
          slug: m.slug,
          iconName: m.iconName,
          sortOrder: order,
          isBuiltIn: m.isBuiltIn,
          parentId: m.parentId,
          createdAt: m.createdAt,
          updatedAt: m.updatedAt,
        );
        await _categoriesBox.put(m.id, updated);
      }
      order += 1000;
    }
  }

  Future<void> _rebuildParentIndexForParent(String? parentId) async {
    final key = parentId ?? '__roots__';
    final ids = _categoriesBox.values
        .where((m) => m.parentId == parentId)
        .map((m) => m.id)
        .toList();
    if (ids.isEmpty) {
      await _parentIndexBox.delete(key);
    } else {
      await _parentIndexBox.put(key, ids.join(','));
    }
  }

  @override
  Future<void> delete(String id) async {
    await _lock.synchronized(() async {
      final model = _categoriesBox.get(id);
      if (model == null) return;

      // isBuiltIn guard must be first (before children/inUse) per spec F1
      if (model.isBuiltIn) {
        throw BuiltInCategoryException(id);
      }

      // RESTRICT checks inside Lock via truth scans
      final hasChildren = _categoriesBox.values.any((m) => m.parentId == id);
      if (hasChildren) {
        throw ArgumentError('Cannot delete category $id: has children');
      }
      final inUse =
          _rankingPolicyBox.values.any((rp) => rp.categoryIds.contains(id));
      if (inUse) {
        throw ArgumentError(
            'Cannot delete category $id: in use by ranking policy');
      }

      // Backup for rollback
      final backup = CategoryHiveModel(
        id: model.id,
        name: model.name,
        slug: model.slug,
        iconName: model.iconName,
        sortOrder: model.sortOrder,
        isBuiltIn: model.isBuiltIn,
        parentId: model.parentId,
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
      );

      try {
        await _categoriesBox.delete(id);
        await _slugIndexBox.delete(model.slug);
        await _rebuildParentIndexForParent(model.parentId);

        // Optional policy index cleanup
        if (_categoryPolicyIndexBox != null) {
          await _categoryPolicyIndexBox.delete(id);
        }
      } catch (e) {
        // rollback delete+flush
        await _categoriesBox.put(backup.id, backup);
        await _slugIndexBox.put(backup.slug, backup.id);
        await _rebuildParentIndexForParent(backup.parentId);
        rethrow;
      }
    });
  }

  @override
  Future<void> rebuildIndexes() async {
    await _lock.synchronized(() async {
      await _parentIndexBox.clear();
      await _slugIndexBox.clear();
      final Map<String, List<String>> byParent = {};
      for (final c in _categoriesBox.values) {
        await _slugIndexBox.put(c.slug, c.id);
        final key = c.parentId ?? '__roots__';
        byParent.putIfAbsent(key, () => []).add(c.id);
      }
      for (final entry in byParent.entries) {
        await _parentIndexBox.put(entry.key, entry.value.join(','));
      }
      if (_categoryPolicyIndexBox != null && _categoryPolicyIndexBox.isOpen) {
        await _categoryPolicyIndexBox.clear();
        final Map<String, List<String>> byCat = {};
        for (final rp in _rankingPolicyBox.values) {
          for (final catId in rp.categoryIds) {
            byCat.putIfAbsent(catId, () => []).add(rp.id);
          }
        }
        for (final entry in byCat.entries) {
          await _categoryPolicyIndexBox.put(entry.key, entry.value.join(','));
        }
      }
    });
  }
}
