import 'package:hive_ce/hive_ce.dart';
import '../../../domain/entities/ranking_policy.dart';

/// Base Hive model for ranking policies.
///
/// [categoryIds] uses defensive [List.from] copy on write. Default empty
/// exists only to read pre-v2 boxes; runtime read of empty is corruption
/// and subclasses' [toDomain] will throw [StateError]. Migration backfills
/// empty to [kFallbackCategoryId].
abstract class RankingPolicyHiveModel extends HiveObject {
  RankingPolicyHiveModel({
    required this.id,
    required this.name,
    required this.leagueId,
    List<String>? categoryIds,
  }) : categoryIds = categoryIds == null ? [] : List<String>.from(categoryIds);

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(5, defaultValue: '')
  final String? leagueId;

  @HiveField(6, defaultValue: <String>[])
  final List<String> categoryIds;

  RankingPolicy toDomain();
}
