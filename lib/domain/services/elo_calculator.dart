import 'dart:math' as math;

import '../entities/league_player.dart';
import '../entities/matches/simple_match.dart';
import '../value_objects/elo_player_stats.dart';

/// Pure domain service for Elo calculations.
///
/// No Flutter/Hive imports. Filters where(isComplete) before sort,
/// then sorts playedAt ASC + id ASC, throws ArgumentError on
/// isDraw==true || sides.length!=2 || any playerIds.length!=1,
/// updates ratings Elo-like with required initialRating and K factor,
/// returns stats for all players.
class EloCalculator {
  const EloCalculator();

  static const int _kFactor = 20;

  Map<String, EloPlayerStats> calculate({
    required List<SimpleMatch> matches,
    required List<LeaguePlayer> players,
    required int initialRating,
  }) {
    // Filter where(isComplete) before sort
    final filtered = matches.where((m) => m.isComplete).toList();

    // Sort playedAt ASC + id ASC
    filtered.sort((a, b) {
      final cmp = a.playedAt.compareTo(b.playedAt);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    // Seed all players at initialRating
    final Map<String, int> ratings = {};
    final Map<String, int> wins = {};
    final Map<String, int> losses = {};
    final Map<String, int> matchesPlayed = {};

    for (final p in players) {
      ratings[p.id] = initialRating;
      wins[p.id] = 0;
      losses[p.id] = 0;
      matchesPlayed[p.id] = 0;
    }

    for (final match in filtered) {
      // Validation – throws ArgumentError
      if (match.isDraw) {
        throw ArgumentError('isDraw must be false for Elo');
      }
      if (match.sides.length != 2) {
        throw ArgumentError(
            'sides.length must be 2, got ${match.sides.length}');
      }
      for (final side in match.sides) {
        if (side.playerIds.length != 1) {
          throw ArgumentError(
              'each side must have exactly 1 playerId, got ${side.playerIds.length}');
        }
      }
      if (match.winnerSideId == null) {
        throw ArgumentError('winnerSideId missing');
      }
      final winnerSide =
          match.sides.where((s) => s.id == match.winnerSideId).toList();
      if (winnerSide.isEmpty) {
        throw ArgumentError('winnerSideId not found in sides');
      }
      final loserSide =
          match.sides.firstWhere((s) => s.id != match.winnerSideId);

      final winnerId = winnerSide.first.playerIds.first;
      final loserId = loserSide.playerIds.first;

      // Ghost seeding
      ratings.putIfAbsent(winnerId, () => initialRating);
      ratings.putIfAbsent(loserId, () => initialRating);
      wins.putIfAbsent(winnerId, () => 0);
      wins.putIfAbsent(loserId, () => 0);
      losses.putIfAbsent(winnerId, () => 0);
      losses.putIfAbsent(loserId, () => 0);
      matchesPlayed.putIfAbsent(winnerId, () => 0);
      matchesPlayed.putIfAbsent(loserId, () => 0);

      final winnerRating = ratings[winnerId]!;
      final loserRating = ratings[loserId]!;

      final expectedWinner =
          1 / (1 + math.pow(10, (loserRating - winnerRating) / 400));
      final expectedLoser =
          1 / (1 + math.pow(10, (winnerRating - loserRating) / 400));

      final newWinnerRating =
          (winnerRating + _kFactor * (1 - expectedWinner)).round();
      final newLoserRating =
          (loserRating + _kFactor * (0 - expectedLoser)).round();

      ratings[winnerId] = newWinnerRating;
      ratings[loserId] = newLoserRating;

      matchesPlayed[winnerId] = matchesPlayed[winnerId]! + 1;
      matchesPlayed[loserId] = matchesPlayed[loserId]! + 1;
      wins[winnerId] = wins[winnerId]! + 1;
      losses[loserId] = losses[loserId]! + 1;
    }

    // Build result map for all players + ghosts
    final result = <String, EloPlayerStats>{};
    for (final entry in ratings.entries) {
      final id = entry.key;
      result[id] = EloPlayerStats(
        matchesPlayed: matchesPlayed[id] ?? 0,
        wins: wins[id] ?? 0,
        losses: losses[id] ?? 0,
        rating: entry.value,
      );
    }
    return result;
  }
}
