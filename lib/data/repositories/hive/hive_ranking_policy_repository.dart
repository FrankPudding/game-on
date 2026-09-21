import 'package:hive_ce/hive_ce.dart';
import 'package:synchronized/synchronized.dart';
import '../../../../domain/entities/ranking_policy.dart';
import '../../../../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../../../../domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import '../../../../domain/repositories/ranking_policy_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../core/constants/hive_box_names.dart';
import '../../../domain/exceptions/unknown_category_exception.dart';
import '../../models/hive/ranking_policy_hive_model.dart';
import '../../models/hive/ranking_policies/simple_ranking_policy_hive_model.dart';
import '../../models/hive/ranking_policies/goal_difference_ranking_policy_hive_model.dart';

class HiveRankingPolicyRepository implements RankingPolicyRepository {
  HiveRankingPolicyRepository(
    this._box, {
    CategoryRepository? categoryRepository,
    Lock? lock,
    Box<String>? categoryPolicyIndexBox,
  })  : _categoryRepository = categoryRepository,
        _lock = lock,
        _categoryPolicyIndexBox = categoryPolicyIndexBox;

  final Box<RankingPolicyHiveModel> _box;
  final CategoryRepository? _categoryRepository;
  final Lock? _lock;
  final Box<String>? _categoryPolicyIndexBox;

  @override
  Future<RankingPolicy?> get(String id) async {
    final model = _box.get(id);
    return model?.toDomain();
  }

  @override
  Future<List<RankingPolicy>> getAll() async {
    return _box.values.map((model) => model.toDomain()).toList();
  }

  /// Puts [item] with referential integrity checks.
  ///
  /// Throws [ArgumentError] if [item.categoryIds] is empty or has duplicates.
  /// Throws [UnknownCategoryException] if any categoryId does not exist.
  /// Defensive copies via [List.from] and [List.unmodifiable] per domain invariant.
  @override
  Future<void> put(RankingPolicy item) async {
    // Defensive copy
    final ids = List<String>.from(item.categoryIds);
    if (ids.isEmpty) {
      throw ArgumentError('categoryIds must not be empty');
    }
    if (ids.length != ids.toSet().length) {
      throw ArgumentError('categoryIds must not contain duplicates: $ids');
    }
    // Restriction: Simple and Goal Difference only in custom category.
    final isCustomOnlyPolicy =
        item is SimpleRankingPolicy || item is GoalDifferenceRankingPolicy;
    if (isCustomOnlyPolicy) {
      if (ids.length != 1 || ids.first != kFallbackCategoryId) {
        throw ArgumentError(
            'Simple and Goal Difference leagues are only allowed in the Custom category ($kFallbackCategoryId). Got: $ids');
      }
    }
    // Validate categoryIds existsAll via CategoryRepository
    if (_categoryRepository != null) {
      final exists = await _categoryRepository.existsAll(ids);
      if (!exists) {
        throw UnknownCategoryException(ids);
      }
    }
    final model = _convertToHiveModel(item);
    if (_lock != null) {
      await _lock.synchronized(() async {
        await _box.put(item.id, model);
        // share same Lock for category_policy_index if used
        if (_categoryPolicyIndexBox != null) {
          // Update index for each category
          for (final catId in item.categoryIds) {
            final existingRaw = _categoryPolicyIndexBox.get(catId);
            final ids = existingRaw == null || existingRaw.isEmpty
                ? <String>[]
                : existingRaw.split(',').where((e) => e.isNotEmpty).toList();
            if (!ids.contains(item.id)) {
              ids.add(item.id);
              await _categoryPolicyIndexBox.put(catId, ids.join(','));
            }
          }
          // Remove stale entries where cat removed
          final allKeys = _categoryPolicyIndexBox.keys.cast<String>().toList();
          for (final key in allKeys) {
            final raw = _categoryPolicyIndexBox.get(key) ?? '';
            final ids = raw.split(',').where((e) => e.isNotEmpty).toList();
            // if this policy previously indexed under key but now not in categoryIds, remove
            if (!item.categoryIds.contains(key) && ids.contains(item.id)) {
              ids.remove(item.id);
              if (ids.isEmpty) {
                await _categoryPolicyIndexBox.delete(key);
              } else {
                await _categoryPolicyIndexBox.put(key, ids.join(','));
              }
            }
          }
        }
      });
    } else {
      await _box.put(item.id, model);
    }
  }

  @override
  Future<void> delete(String id) async {
    if (_lock != null) {
      await _lock.synchronized(() async {
        final existing = _box.get(id);
        await _box.delete(id);
        if (existing != null && _categoryPolicyIndexBox != null) {
          for (final catId in existing.categoryIds) {
            final raw = _categoryPolicyIndexBox.get(catId);
            if (raw != null) {
              final ids = raw.split(',').where((e) => e.isNotEmpty).toList();
              ids.remove(id);
              if (ids.isEmpty) {
                await _categoryPolicyIndexBox.delete(catId);
              } else {
                await _categoryPolicyIndexBox.put(catId, ids.join(','));
              }
            }
          }
        }
      });
    } else {
      await _box.delete(id);
    }
  }

  @override
  Future<RankingPolicy?> getByLeagueId(String leagueId) async {
    try {
      final model = _box.values.firstWhere(
        (model) => model.leagueId == leagueId,
      );
      return model.toDomain();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<RankingPolicy>> getByCategory(String categoryId) async {
    // Use index if available, else scan truth
    if (_categoryPolicyIndexBox != null && _categoryPolicyIndexBox.isOpen) {
      final raw = _categoryPolicyIndexBox.get(categoryId);
      if (raw != null && raw.isNotEmpty) {
        final ids = raw.split(',').where((e) => e.isNotEmpty).toList();
        final result = <RankingPolicy>[];
        for (final id in ids) {
          final m = _box.get(id);
          if (m != null) result.add(m.toDomain());
        }
        if (result.isNotEmpty) return result;
      }
    }
    // fallback scan truth
    return _box.values
        .where((m) => m.categoryIds.contains(categoryId))
        .map((m) => m.toDomain())
        .toList();
  }

  RankingPolicyHiveModel _convertToHiveModel(RankingPolicy policy) {
    if (policy is SimpleRankingPolicy) {
      return SimpleRankingPolicyHiveModel.fromDomain(policy);
    }
    if (policy is GoalDifferenceRankingPolicy) {
      return GoalDifferenceRankingPolicyHiveModel.fromDomain(policy);
    }
    throw UnimplementedError(
        'Ranking policy type not supported: ${policy.runtimeType}');
  }
}
