import 'package:hive_ce/hive_ce.dart';

import '../../../../domain/entities/ranking_policies/table_tennis_elo_ranking_policy.dart';
import '../ranking_policy_hive_model.dart';

part 'table_tennis_elo_ranking_policy_hive_model.g.dart';

/// Hive model for [TableTennisEloRankingPolicy].
@HiveType(typeId: 13)
class TableTennisEloRankingPolicyHiveModel extends RankingPolicyHiveModel {
  // ignore: sort_constructors_first
  TableTennisEloRankingPolicyHiveModel({
    required super.id,
    required super.name,
    required super.leagueId,
    super.categoryIds,
    this.initialRating = 400,
  });

  @HiveField(7, defaultValue: 400)
  final int initialRating;

  // ignore: sort_constructors_first
  factory TableTennisEloRankingPolicyHiveModel.fromDomain(
      TableTennisEloRankingPolicy policy) {
    return TableTennisEloRankingPolicyHiveModel(
      id: policy.id,
      name: policy.name,
      leagueId: policy.leagueId,
      categoryIds: List<String>.from(policy.categoryIds),
      initialRating: policy.initialRating,
    );
  }

  @override
  TableTennisEloRankingPolicy toDomain() {
    if (categoryIds.isEmpty) {
      throw StateError('categoryIds is empty – corruption');
    }
    TableTennisEloRankingPolicy.validateInitialRating(initialRating);
    TableTennisEloRankingPolicy.validateCategoryIds(categoryIds);
    final effectiveLeagueId = leagueId ?? '';
    return TableTennisEloRankingPolicy(
      id: id,
      name: name,
      leagueId: effectiveLeagueId,
      categoryIds: categoryIds,
      initialRating: initialRating,
    );
  }
}
