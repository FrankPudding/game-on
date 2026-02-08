import 'package:flutter/material.dart';
import '../../models/match_team.dart';
import '../../models/configs/timed_config.dart';
import '../../models/match/timed_match.dart';
import '../../models/match/timed_state.dart';
import '../scoring_handler.dart';

class TimedHandler extends ScoringHandler<TimedConfig, TimedMatch, TimedState> {
  @override
  TimedConfig getConfig(String leagueId) {
    throw UnimplementedError();
  }

  @override
  TimedMatch createMatch(String leagueId, List<MatchTeam> teams) {
    return TimedMatch(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      leagueId: leagueId,
      playedAt: DateTime.now(),
    );
  }

  @override
  void updateScore(TimedMatch match, String teamId, int delta) {
    // Logic for updating finalScore in TimedState
  }

  @override
  bool isMatchComplete(TimedMatch match) => match.isComplete;

  @override
  String? getWinnerTeamId(TimedMatch match) {
    // Logic to compare scores based on lowerScoreWins
    return null;
  }

  @override
  Map<String, int> calculatePointsEarned(TimedMatch match, TimedConfig config) {
    return {};
  }

  @override
  Widget buildScoreTracker(TimedMatch match, VoidCallback onUpdate) {
    return const Center(child: Text('Timed Score Tracker'));
  }

  @override
  Widget buildScoreDisplay(TimedMatch match) {
    return const Text('Timed Score');
  }
}
