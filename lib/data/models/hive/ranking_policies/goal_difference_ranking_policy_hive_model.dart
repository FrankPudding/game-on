import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import '../ranking_policy_hive_model.dart';

part 'goal_difference_ranking_policy_hive_model.g.dart';

@HiveType(typeId: 10)
class GoalDifferenceRankingPolicyHiveModel extends RankingPolicyHiveModel {
  GoalDifferenceRankingPolicyHiveModel({
    required super.id,
    required super.name,
    required super.leagueId,
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
    return GoalDifferenceRankingPolicy(
      id: id,
      name: name,
      leagueId: leagueId ?? '',
      pointsForWin: pointsForWin,
      pointsForDraw: pointsForDraw,
      pointsForLoss: pointsForLoss,
    );
  }
}
