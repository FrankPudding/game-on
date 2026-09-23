import '../../domain/entities/ranking_policy_type.dart';

/// Seed-only map of categoryId to allowed RankingPolicyTypes.
/// Not used as runtime truth; runtime filtering is repo-driven via
/// RankingPolicyRepository.getByCategory(categoryId). Kept for seeding/migration only.
///
/// Simple and Goal Difference scoring systems are only allowed in the
/// custom category. Other built-in categories intentionally have no allowed
/// types until future scoring systems are added.
const Map<String, List<RankingPolicyType>> kSeedCategoryPolicyTypes = {
  'cat_boardgames': [],
  'cat_cardgames': [],
  'cat_sports': [RankingPolicyType.fargoRate],
  'cat_videogames': [],
  'cat_pubgames': [RankingPolicyType.fargoRate],
  'cat_custom_league_001': [
    RankingPolicyType.simple,
    RankingPolicyType.goalDifference
  ],
};
