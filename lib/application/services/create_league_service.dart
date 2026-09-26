import '../../core/constants/hive_box_names.dart';
import '../../domain/entities/league.dart';
import '../../domain/entities/ranking_policy.dart';
import '../../domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import '../../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../../domain/entities/ranking_policies/elo_ranking_policy.dart';
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
    // TODO: Builder to implement validation — Elo initialRating + categoryIds guards
    if (rankingPolicy is EloRankingPolicy) {
      EloRankingPolicy.validateInitialRating(rankingPolicy.initialRating);
    }

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
    // Restriction: Elo only in sports+pubgames
    if (rankingPolicy is EloRankingPolicy) {
      if (idsToValidate.length != kEloCategoryIds.length ||
          !idsToValidate.toSet().containsAll(kEloCategoryIds)) {
        throw ArgumentError(
            'Elo leagues must have categoryIds exactly $kEloCategoryIds. Got: $idsToValidate');
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

    // Compensation delete league on policy put failure
    await _leagueRepository.put(league);
    try {
      await _rankingPolicyRepository.put(rankingPolicy);
    } catch (e) {
      // Compensation: delete league if policy put fails
      try {
        await _leagueRepository.delete(league.id);
      } catch (_) {}
      rethrow;
    }
  }
}
