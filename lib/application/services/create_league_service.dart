import '../../core/constants/hive_box_names.dart';
import '../../domain/entities/league.dart';
import '../../domain/entities/ranking_policy.dart';
import '../../domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import '../../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../../domain/repositories/league_repository.dart';
import '../../domain/repositories/ranking_policy_repository.dart';
import '../../domain/repositories/category_repository.dart';

class CreateLeagueService {
  CreateLeagueService(
    this._leagueRepository,
    this._rankingPolicyRepository,
    this._categoryRepository,
  );

  final LeagueRepository _leagueRepository;
  final RankingPolicyRepository _rankingPolicyRepository;
  final CategoryRepository _categoryRepository;

  Future<void> execute({
    required String id,
    required String name,
    required RankingPolicy rankingPolicy,
    List<String>? categoryIds,
  }) async {
    final league = League(
      id: id,
      name: name,
      createdAt: DateTime.now(),
    );

    // Ensure the ranking policy belongs to this league
    if (rankingPolicy.leagueId != id) {
      throw ArgumentError(
          'Ranking policy leagueId does not match the league id');
    }

    // Validate categoryIds: if provided use it, else use policy's categoryIds
    final idsToValidate = categoryIds ?? rankingPolicy.categoryIds;
    if (idsToValidate.isEmpty) {
      throw ArgumentError('categoryIds must not be empty');
    }
    final exists = await _categoryRepository.existsAll(idsToValidate);
    if (!exists) {
      throw ArgumentError('One or more categoryIds do not exist');
    }
    // Restriction: Simple and Goal Difference are only allowed in custom category.
    final isCustomOnlyPolicy = rankingPolicy is SimpleRankingPolicy ||
        rankingPolicy is GoalDifferenceRankingPolicy;
    if (isCustomOnlyPolicy) {
      if (idsToValidate.length != 1 ||
          idsToValidate.first != kFallbackCategoryId) {
        throw ArgumentError(
            'Simple and Goal Difference leagues are only allowed in the Custom category ($kFallbackCategoryId). Got: $idsToValidate');
      }
    }
    // If categoryIds param differs, ensure policy matches (propagation)
    if (categoryIds != null) {
      // rankingPolicy already validated to have same ids? Ensure consistency
      if (rankingPolicy.categoryIds.length != categoryIds.length ||
          !rankingPolicy.categoryIds.toSet().containsAll(categoryIds)) {
        throw ArgumentError(
            'RankingPolicy categoryIds must match provided categoryIds');
      }
    }

    await _leagueRepository.put(league);
    await _rankingPolicyRepository.put(rankingPolicy);
  }
}
