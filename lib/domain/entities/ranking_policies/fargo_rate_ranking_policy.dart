// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import '../../../core/constants/hive_box_names.dart';
import '../matches/simple_match.dart';
import '../ranking_policy.dart';

/// FargoRate ranking policy for Pool.
///
/// Invariant: [categoryIds] must be exactly {cat_sports, cat_pubgames}
/// (set-equality via [kSportsCategoryId]/[kPubGamesCategoryId]/[kFargoCategoryIds]
/// constants, SetEquality + length guard).
class FargoRateRankingPolicy extends RankingPolicy<SimpleMatch> {
  FargoRateRankingPolicy({
    required super.id,
    required super.name,
    required super.leagueId,
    required super.categoryIds,
  }) {
    validateCategoryIds(categoryIds);
  }

  /// Validates that [categoryIds] is exactly the Fargo set.
  static void validateCategoryIds(List<String> ids) {
    if (ids.length != kFargoCategoryIds.length) {
      throw ArgumentError(
          'FargoRate leagues must have categoryIds exactly $kFargoCategoryIds. Got: $ids');
    }
    if (!_equality.equals(ids.toSet(), kFargoCategoryIds.toSet())) {
      throw ArgumentError(
          'FargoRate leagues must have categoryIds exactly $kFargoCategoryIds. Got: $ids');
    }
  }

  static const _equality = SetEquality<String>();
  static List<String> get fargoCategoryIds => kFargoCategoryIds;
}
