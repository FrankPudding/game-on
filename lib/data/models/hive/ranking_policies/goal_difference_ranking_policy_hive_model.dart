import 'package:hive_ce/hive_ce.dart';
import '../../../../core/constants/hive_box_names.dart';
import '../../../../domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import '../ranking_policy_hive_model.dart';

part 'goal_difference_ranking_policy_hive_model.g.dart';

/// Hive model for [GoalDifferenceRankingPolicy].
///
/// Defensive copies via [List.from] on write. [toDomain] rejects empty
/// [categoryIds] as corruption — legacy empty is backfilled only by
/// [HiveDatabaseMigrationService._migrateToV2] to [kFallbackCategoryId].
@HiveType(typeId: 10)
class GoalDifferenceRankingPolicyHiveModel extends RankingPolicyHiveModel {
  GoalDifferenceRankingPolicyHiveModel({
    required super.id,
    required super.name,
    required super.leagueId,
    super.categoryIds,
    this.pointsForWin = 3,
    this.pointsForDraw = 1,
    this.pointsForLoss = 0,
  });

  factory GoalDifferenceRankingPolicyHiveModel.fromDomain(
      GoalDifferenceRankingPolicy policy) {
    return GoalDifferenceRankingPolicyHiveModel(
      id: policy.id,
      name: policy.name,
      leagueId: policy.leagueId,
      categoryIds: List<String>.from(policy.categoryIds),
      pointsForWin: policy.pointsForWin,
      pointsForDraw: policy.pointsForDraw,
      pointsForLoss: policy.pointsForLoss,
    );
  }

  @HiveField(2)
  final int pointsForWin;

  @HiveField(3)
  final int pointsForDraw;

  @HiveField(4)
  final int pointsForLoss;

  @override
  GoalDifferenceRankingPolicy toDomain() {
    if (categoryIds.isEmpty) {
      throw StateError(
        'Corrupted RankingPolicyHiveModel $id: categoryIds empty. '
        'Expected migration backfill to $kFallbackCategoryId. Run HiveDatabaseMigrationService._migrateToV2',
      );
    }
    final ids = List<String>.from(categoryIds);
    return GoalDifferenceRankingPolicy(
      id: id,
      name: name,
      leagueId: leagueId ?? '',
      categoryIds: List.unmodifiable(ids),
      pointsForWin: pointsForWin,
      pointsForDraw: pointsForDraw,
      pointsForLoss: pointsForLoss,
    );
  }
}
