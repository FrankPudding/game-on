// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';

import '../../../core/constants/hive_box_names.dart';
import '../../constants/elo_constants.dart';
import '../matches/simple_match.dart';
import '../ranking_policy.dart';

/// Table Tennis Elo ranking policy.
class TableTennisEloRankingPolicy extends RankingPolicy<SimpleMatch> {
  TableTennisEloRankingPolicy({
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

  static void validateInitialRating(int v) {
    if (v < kEloMinRating || v > kEloMaxRating) {
      throw ArgumentError(
          'initialRating must be within 100..500 inclusive. Got: $v');
    }
  }

  static void validateCategoryIds(List<String> ids) {
    if (ids.length != kTableTennisCategoryIds.length ||
        !_equality.equals(ids.toSet(), kTableTennisCategoryIds.toSet())) {
      throw ArgumentError(
          'Table Tennis leagues must have categoryIds exactly $kTableTennisCategoryIds. Got: $ids');
    }
  }

  static const _equality = SetEquality<String>();

  static List<String> get tableTennisCategoryIds => kTableTennisCategoryIds;
}
