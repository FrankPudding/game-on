import 'package:hive_ce/hive_ce.dart';

// ignore: unused_import
import '../../../../core/constants/hive_box_names.dart';
import '../../../../domain/entities/ranking_policies/elo_ranking_policy.dart';
import '../ranking_policy_hive_model.dart';

part 'elo_ranking_policy_hive_model.g.dart';

/// Hive model for [EloRankingPolicy].
///
/// Defensive copies via [List.from] on write. [toDomain] rejects empty
/// [categoryIds] as corruption — legacy empty is backfilled only by migration.
/// [initialRating] persisted at field 7 with literal defaultValue 500 for codegen.
@HiveType(typeId: 12)
class EloRankingPolicyHiveModel extends RankingPolicyHiveModel {
  // ignore: sort_constructors_first
  @HiveField(7, defaultValue: 500)
  final int initialRating;

  // ignore: sort_constructors_first
  EloRankingPolicyHiveModel({
    required super.id,
    required super.name,
    required super.leagueId,
    super.categoryIds,
    this.initialRating = 500,
  });

  // ignore: sort_constructors_first
  factory EloRankingPolicyHiveModel.fromDomain(EloRankingPolicy policy) {
    return EloRankingPolicyHiveModel(
      id: policy.id,
      name: policy.name,
      leagueId: policy.leagueId,
      categoryIds: List<String>.from(policy.categoryIds),
      initialRating: policy.initialRating,
    );
  }

  @override
  EloRankingPolicy toDomain() {
    if (categoryIds.isEmpty) {
      throw StateError('categoryIds is empty – corruption');
    }
    EloRankingPolicy.validateInitialRating(initialRating);
    EloRankingPolicy.validateCategoryIds(categoryIds);
    // leagueId may be null from Hive defaultValue '' handling
    final effectiveLeagueId = leagueId ?? '';
    return EloRankingPolicy(
      id: id,
      name: name,
      leagueId: effectiveLeagueId,
      categoryIds: categoryIds,
      initialRating: initialRating,
    );
  }
}

@Deprecated('Use EloRankingPolicyHiveModel')
typedef FargoRateRankingPolicyHiveModel = EloRankingPolicyHiveModel;

@Deprecated('Use EloRankingPolicyHiveModelAdapter')
typedef FargoRateRankingPolicyHiveModelAdapter
    = EloRankingPolicyHiveModelAdapter;
