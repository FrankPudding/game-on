import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';

class GoalDifferenceRankingPolicy extends RankingPolicy<SimpleMatch> {
  GoalDifferenceRankingPolicy({
    required super.id,
    required super.name,
    required super.leagueId,
    this.pointsForWin = 3,
    this.pointsForDraw = 1,
    this.pointsForLoss = 0,
  });

  final int pointsForWin;
  final int pointsForDraw;
  final int pointsForLoss;
}
