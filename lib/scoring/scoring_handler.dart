import 'package:flutter/material.dart';
import '../../models/match_team.dart';

abstract class ScoringHandler<TConfig, TMatch, TState> {
  // Config
  TConfig getConfig(String leagueId);

  // Match lifecycle
  TMatch createMatch(String leagueId, List<MatchTeam> teams);
  void updateScore(TMatch match, String teamId, int delta);
  bool isMatchComplete(TMatch match);
  String? getWinnerTeamId(TMatch match);

  // Points
  Map<String, int> calculatePointsEarned(TMatch match, TConfig config);

  // UI components (optional or to be implemented by subclasses)
  Widget buildScoreTracker(TMatch match, VoidCallback onUpdate);
  Widget buildScoreDisplay(TMatch match);
}
