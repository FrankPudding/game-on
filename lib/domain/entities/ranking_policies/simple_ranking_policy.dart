import 'package:game_on/domain/entities/match.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';

sealed class RankingPolicy<M extends Match> {
  RankingPolicy({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class SimpleRankingPolicy extends RankingPolicy<SimpleMatch> {
  SimpleRankingPolicy({
    required super.id,
    required super.name,
    this.pointsForWin = 3,
    this.pointsForDraw = 1,
    this.pointsForLoss = 0,
  });

  final int pointsForWin;
  final int pointsForDraw;
  final int pointsForLoss;
}
