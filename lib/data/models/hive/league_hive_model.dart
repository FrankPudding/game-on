import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/league.dart';
import '../../../../domain/entities/matches/simple_match.dart';
import '../../../../domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'ranking_policy_hive_model.dart';
import 'ranking_policies/simple_ranking_policy_hive_model.dart';

part 'league_hive_model.g.dart';

@HiveType(typeId: 3)
class LeagueHiveModel extends HiveObject {
  LeagueHiveModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isArchived,
    this.rankingPolicy,
  });

  factory LeagueHiveModel.fromDomain(League league) {
    final policyModel = switch (league.rankingPolicy) {
      SimpleRankingPolicy p => SimpleRankingPolicyHiveModel.fromDomain(p),
    };

    return LeagueHiveModel(
      id: league.id,
      name: league.name,
      createdAt: league.createdAt,
      isArchived: league.isArchived,
      rankingPolicy: policyModel,
    );
  }
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final bool isArchived;

  @HiveField(10)
  final RankingPolicyHiveModel? rankingPolicy;

  League<SimpleMatch> toDomain() {
    return League<SimpleMatch>(
      id: id,
      name: name,
      createdAt: createdAt,
      isArchived: isArchived,
      rankingPolicy: (rankingPolicy ??
              SimpleRankingPolicyHiveModel(
                id: 'default_policy',
                name: 'Standard Policy',
              ))
          .toDomain() as SimpleRankingPolicy,
    );
  }
}
