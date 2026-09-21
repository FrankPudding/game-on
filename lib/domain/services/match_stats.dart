// ignore_for_file: public_member_api_docs

import '../entities/matches/simple_match.dart';

/// Pure domain helper for match statistics.
///
/// Contract:
/// - Returns the maximum [SimpleMatch.playedAt] among completed matches
///   ([SimpleMatch.isComplete] == true).
/// - Returns `null` when there are no completed matches (maps to "Never").
/// - Pure: no DTO, no Hive, no framework imports.
/// - Intended use: grouped per league via `groupBy` for O(M) derivation.
///
/// Skeleton: structure only, no business logic implementation.
DateTime? maxCompletePlayedAt(Iterable<SimpleMatch> matches) {
  DateTime? max;
  for (final m in matches) {
    if (!m.isComplete) continue;
    if (max == null || m.playedAt.isAfter(max)) {
      max = m.playedAt;
    }
  }
  return max;
}
