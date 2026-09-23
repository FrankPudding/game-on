class HiveBoxNames {
  static const String users = 'users';
  static const String leagues = 'leagues';
  static const String leaguePlayers = 'league_players';
  static const String leaguePlayersUniqueIndex = 'league_players_unique_index';
  static const String simpleMatches = 'simple_matches';
  static const String rankingPolicies = 'ranking_policies';
  static const String categories = 'categories';
  static const String categorySlugIndex = 'category_slug_index';
  static const String categoryParentIndex = 'category_parent_index';
  static const String categoryPolicyIndex = 'category_policy_index';
  static const String meta = 'meta';
}

/// Fallback category for migration backfill of legacy empty categoryIds.
/// Single source for 'cat_custom_league_001' references.
const String kFallbackCategoryId = 'cat_custom_league_001';

const int kMaxCategoryDepth = 1;

const String kSportsCategoryId = 'cat_sports';
const String kPubGamesCategoryId = 'cat_pubgames';
const List<String> kFargoCategoryIds = [kSportsCategoryId, kPubGamesCategoryId];
const int kFargoInitialRating = 500;
