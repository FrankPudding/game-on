import 'package:flutter/material.dart';
import '../../models/match_team.dart';
import '../../models/configs/tennis_config.dart';
import '../../models/match/tennis_match.dart';
import '../../models/match/tennis_state.dart';
import '../scoring_handler.dart';

class TennisHandler
    extends ScoringHandler<TennisConfig, TennisMatch, TennisState> {
  @override
  TennisConfig getConfig(String leagueId) {
    throw UnimplementedError();
  }

  @override
  TennisMatch createMatch(String leagueId, List<MatchTeam> teams) {
    return TennisMatch(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      leagueId: leagueId,
      playedAt: DateTime.now(),
    );
  }

  @override
  void updateScore(TennisMatch match, String teamId, int delta) {
    // Logic for tennis score increments
  }

  @override
  bool isMatchComplete(TennisMatch match) => match.isComplete;

  @override
  String? getWinnerTeamId(TennisMatch match) => match.winnerTeamId;

  @override
  Map<String, int> calculatePointsEarned(
    TennisMatch match,
    TennisConfig config,
  ) {
    return {};
  }

  @override
  Widget buildScoreTracker(TennisMatch match, VoidCallback onUpdate) {
    return const Center(child: Text('Tennis Score Tracker'));
  }

  @override
  Widget buildScoreDisplay(TennisMatch match) {
    return const Text('Tennis Score');
  }
}
