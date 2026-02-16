import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../ranking_policy_hive_model.dart';

part 'simple_ranking_policy_hive_model.g.dart';

@HiveType(typeId: 9)
class SimpleRankingPolicyHiveModel extends RankingPolicyHiveModel {
  SimpleRankingPolicyHiveModel({
    required super.id,
    required super.name,
    required super.leagueId,
    this.pointsForWin = 3,
    this.pointsForDraw = 1,
    this.pointsForLoss = 0,
  });

  factory SimpleRankingPolicyHiveModel.fromDomain(SimpleRankingPolicy policy) {
    return SimpleRankingPolicyHiveModel(
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
  SimpleRankingPolicy toDomain() {
    return SimpleRankingPolicy(
      id: id,
      name: name,
      leagueId: leagueId ?? '',
      pointsForWin: pointsForWin,
      pointsForDraw: pointsForDraw,
      pointsForLoss: pointsForLoss,
    );
  }
}
