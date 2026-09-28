// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';

// ignore: unused_import
import '../../../core/constants/hive_box_names.dart';
// ignore: unused_import
import '../../constants/elo_constants.dart';
import '../matches/simple_match.dart';
import '../ranking_policy.dart';

/// Elo ranking policy for Pool.
///
/// Invariant: [categoryIds] must be exactly {cat_sports, cat_pubgames}
/// (set-equality via [kSportsCategoryId]/[kPubGamesCategoryId]/[kEloCategoryIds]
/// constants, SetEquality + length guard).
/// Invariant: [initialRating] must be within 100..500 inclusive.
class EloRankingPolicy extends RankingPolicy<SimpleMatch> {
  EloRankingPolicy({
    required super.id,
    required super.name,
    required super.leagueId,
    required super.categoryIds,
    required this.initialRating,
  }) {
    validateCategoryIds(categoryIds);
    validateInitialRating(initialRating);
  }

  final int initialRating;

  /// Validates [v] is within 100..500 inclusive.
  static void validateInitialRating(int v) {
    // TODO: Builder to implement validation logic — throw ArgumentError if outside 100..500
    if (v < kEloMinRating || v > kEloMaxRating) {
      throw ArgumentError(
          'initialRating must be within 100..500 inclusive. Got: $v');
    }
  }

  /// Validates that [categoryIds] is exactly the Elo set.
  static void validateCategoryIds(List<String> ids) {
    // TODO: Builder to implement SetEquality + length guard, error message must be "Elo leagues must have categoryIds exactly $kEloCategoryIds. Got: $ids"
    if (ids.length != kEloCategoryIds.length ||
        !_equality.equals(ids.toSet(), kEloCategoryIds.toSet())) {
      throw ArgumentError(
          'Elo leagues must have categoryIds exactly $kEloCategoryIds. Got: $ids');
    }
  }

  static const _equality = SetEquality<String>();

  static List<String> get eloCategoryIds => kEloCategoryIds;
}
