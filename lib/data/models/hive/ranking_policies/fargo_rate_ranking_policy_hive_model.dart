import 'package:hive_ce/hive_ce.dart';
import '../../../../core/constants/hive_box_names.dart';
import '../../../../domain/entities/ranking_policies/fargo_rate_ranking_policy.dart';
import '../ranking_policy_hive_model.dart';

part 'fargo_rate_ranking_policy_hive_model.g.dart';

/// Hive model for [FargoRateRankingPolicy].
///
/// Defensive copies via [List.from] on write. [toDomain] rejects empty
/// [categoryIds] as corruption — legacy empty is backfilled only by migration.
@HiveType(typeId: 12)
class FargoRateRankingPolicyHiveModel extends RankingPolicyHiveModel {
  FargoRateRankingPolicyHiveModel({
    required super.id,
    required super.name,
    required super.leagueId,
    super.categoryIds,
  });

  factory FargoRateRankingPolicyHiveModel.fromDomain(
      FargoRateRankingPolicy policy) {
    return FargoRateRankingPolicyHiveModel(
      id: policy.id,
      name: policy.name,
      leagueId: policy.leagueId,
      categoryIds: List<String>.from(policy.categoryIds),
    );
  }

  @override
  FargoRateRankingPolicy toDomain() {
    if (categoryIds.isEmpty) {
      throw StateError(
        'Corrupted RankingPolicyHiveModel $id: categoryIds empty. '
        'Expected migration backfill to $kFargoCategoryIds.',
      );
    }
    final ids = List<String>.from(categoryIds);
    return FargoRateRankingPolicy(
      id: id,
      name: name,
      leagueId: leagueId ?? '',
      categoryIds: List.unmodifiable(ids),
    );
  }
}
