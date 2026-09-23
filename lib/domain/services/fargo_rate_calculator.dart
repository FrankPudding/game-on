import 'dart:math' as math;
import '../entities/league_player.dart';
import '../entities/matches/simple_match.dart';
import '../value_objects/fargo_player_stats.dart';
import '../../core/constants/hive_box_names.dart';

/// Pure domain service for FargoRate calculations.
///
/// No Flutter/Hive imports. Filters where(isComplete) before sort,
/// then sorts playedAt ASC + id ASC, throws ArgumentError on
/// isDraw==true || sides.length!=2 || any playerIds.length!=1,
/// updates ratings Elo-like with initial 500 and K factor,
/// returns stats for all players.
class FargoRateCalculator {
  const FargoRateCalculator();

  Map<String, FargoPlayerStats> calculate({
    required List<SimpleMatch> matches,
    required List<LeaguePlayer> players,
  }) {
    // Filter incomplete before sort
    final complete = matches.where((m) => m.isComplete).toList();
    // Sort playedAt ASC + id ASC
    complete.sort((a, b) {
      final c = a.playedAt.compareTo(b.playedAt);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });

    // Mutable state
    final ratings = <String, int>{};
    final wins = <String, int>{};
    final losses = <String, int>{};
    final played = <String, int>{};
    for (final p in players) {
      ratings[p.id] = kFargoInitialRating;
      wins[p.id] = 0;
      losses[p.id] = 0;
      played[p.id] = 0;
    }

    const kFactor = 32;

    for (final m in complete) {
      if (m.isDraw) {
        throw ArgumentError('FargoRate does not support draws: ${m.id}');
      }
      if (m.sides.length != 2) {
        throw ArgumentError('FargoRate requires exactly 2 sides: ${m.id}');
      }
      for (final side in m.sides) {
        if (side.playerIds.length != 1) {
          throw ArgumentError(
              'FargoRate requires exactly 1 player per side: ${m.id} side ${side.id}');
        }
      }
      // Determine winner/loser
      final winnerSideId = m.winnerSideId;
      if (winnerSideId == null) {
        throw ArgumentError('FargoRate requires winnerSideId: ${m.id}');
      }
      final winnerSide = m.sides.firstWhere((s) => s.id == winnerSideId,
          orElse: () => throw ArgumentError('winnerSideId not found: ${m.id}'));
      final loserSide = m.sides.firstWhere((s) => s.id != winnerSideId,
          orElse: () => m.sides[1]);

      final winnerId = winnerSide.playerIds.first;
      final loserId = loserSide.playerIds.first;

      // Ensure both players are tracked (even if not in initial list, still handle)
      ratings.putIfAbsent(winnerId, () => kFargoInitialRating);
      ratings.putIfAbsent(loserId, () => kFargoInitialRating);
      wins.putIfAbsent(winnerId, () => 0);
      wins.putIfAbsent(loserId, () => 0);
      losses.putIfAbsent(winnerId, () => 0);
      losses.putIfAbsent(loserId, () => 0);
      played.putIfAbsent(winnerId, () => 0);
      played.putIfAbsent(loserId, () => 0);

      final winnerRating = ratings[winnerId]!;
      final loserRating = ratings[loserId]!;

      final expectedWinner =
          1 / (1 + math.pow(10, (loserRating - winnerRating) / 400));
      final expectedLoser = 1 - expectedWinner;

      final newWinnerRating =
          (winnerRating + kFactor * (1 - expectedWinner)).round();
      final newLoserRating =
          (loserRating + kFactor * (0 - expectedLoser)).round();

      ratings[winnerId] = newWinnerRating;
      ratings[loserId] = newLoserRating;

      played[winnerId] = played[winnerId]! + 1;
      played[loserId] = played[loserId]! + 1;
      wins[winnerId] = wins[winnerId]! + 1;
      losses[loserId] = losses[loserId]! + 1;
    }

    final result = <String, FargoPlayerStats>{};
    for (final p in players) {
      result[p.id] = FargoPlayerStats(
        matchesPlayed: played[p.id] ?? 0,
        wins: wins[p.id] ?? 0,
        losses: losses[p.id] ?? 0,
        rating: ratings[p.id] ?? kFargoInitialRating,
      );
    }
    return result;
  }
}
