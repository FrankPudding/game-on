import 'package:flutter/material.dart';
import '../../models/match_team.dart';
import '../scoring_handler.dart';
import '../../models/configs/first_to_config.dart';
import '../../models/match/first_to_match.dart';
import '../../models/match/first_to_state.dart';

class FirstToHandler
    extends ScoringHandler<FirstToConfig, FirstToMatch, FirstToState> {
  @override
  FirstToConfig getConfig(String leagueId) {
    // This would typically involve a repository call
    throw UnimplementedError();
  }

  @override
  FirstToMatch createMatch(String leagueId, List<MatchTeam> teams) {
    return FirstToMatch(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      leagueId: leagueId,
      playedAt: DateTime.now(),
    );
  }

  @override
  void updateScore(FirstToMatch match, String teamId, int delta) {
    // Logic for updating scores in FirstToState
  }

  @override
  bool isMatchComplete(FirstToMatch match) => match.isComplete;

  @override
  String? getWinnerTeamId(FirstToMatch match) => match.winnerTeamId;

  @override
  Map<String, int> calculatePointsEarned(
    FirstToMatch match,
    FirstToConfig config,
  ) {
    // Logic based on placement points in config
    return {};
  }

  @override
  Widget buildScoreTracker(FirstToMatch match, VoidCallback onUpdate) {
    return const Center(child: Text('First-To Score Tracker'));
  }

  @override
  Widget buildScoreDisplay(FirstToMatch match) {
    return const Text('First-To Score');
  }
}
