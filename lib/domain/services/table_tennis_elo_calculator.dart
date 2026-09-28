import 'dart:math' as math;

import '../entities/league_player.dart';
import '../entities/matches/simple_match.dart';
import '../value_objects/elo_player_stats.dart';

/// Pure domain service for Table Tennis Elo calculations.
class TableTennisEloCalculator {
  const TableTennisEloCalculator();

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
      if (match.isDraw) {
        throw ArgumentError('isDraw must be false for Table Tennis Elo');
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
      final winnerSides =
          match.sides.where((s) => s.id == match.winnerSideId).toList();
      if (winnerSides.isEmpty) {
        throw ArgumentError('winnerSideId not found in sides');
      }
      final winnerSide = winnerSides.first;
      final loserSide =
          match.sides.firstWhere((s) => s.id != match.winnerSideId);

      if (winnerSide.score == null || loserSide.score == null) {
        throw ArgumentError('scores cannot be null');
      }
      if (winnerSide.score! < 0 || loserSide.score! < 0) {
        throw ArgumentError('scores cannot be negative');
      }
      if (winnerSide.score == loserSide.score) {
        throw ArgumentError('scores cannot be equal');
      }
      final winnerScore = winnerSide.score!;
      final loserScore = loserSide.score!;
      final margin = winnerScore - loserScore;
      if (margin < 2) {
        throw ArgumentError('winning margin must be at least 2, got $margin');
      }

      final winnerId = winnerSide.playerIds.first;
      final loserId = loserSide.playerIds.first;

      ratings.putIfAbsent(winnerId, () => initialRating);
      ratings.putIfAbsent(loserId, () => initialRating);
      wins.putIfAbsent(winnerId, () => 0);
      wins.putIfAbsent(loserId, () => 0);
      losses.putIfAbsent(winnerId, () => 0);
      losses.putIfAbsent(loserId, () => 0);
      matchesPlayed.putIfAbsent(winnerId, () => 0);
      matchesPlayed.putIfAbsent(loserId, () => 0);

      double multiplier;
      if (loserScore == 0 || margin >= 21) {
        multiplier = 2.0;
      } else if (margin <= 2) {
        multiplier = 1.0;
      } else {
        multiplier = 1.0 + (margin - 2) / 19.0;
      }

      final winnerRating = ratings[winnerId]!;
      final loserRating = ratings[loserId]!;

      final expectedWinner =
          1 / (1 + math.pow(10, (loserRating - winnerRating) / 400));
      final expectedLoser =
          1 / (1 + math.pow(10, (winnerRating - loserRating) / 400));

      final newWinnerRating =
          (winnerRating + _kFactor * multiplier * (1 - expectedWinner)).round();
      final newLoserRating =
          (loserRating + _kFactor * multiplier * (0 - expectedLoser)).round();

      ratings[winnerId] = newWinnerRating;
      ratings[loserId] = newLoserRating;

      matchesPlayed[winnerId] = matchesPlayed[winnerId]! + 1;
      matchesPlayed[loserId] = matchesPlayed[loserId]! + 1;
      wins[winnerId] = wins[winnerId]! + 1;
      losses[loserId] = losses[loserId]! + 1;
    }

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
