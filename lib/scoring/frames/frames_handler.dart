import 'package:flutter/material.dart';
import '../../models/match_team.dart';
import '../../models/configs/frames_config.dart';
import '../../models/match/frames_match.dart';
import '../../models/match/frames_state.dart';
import '../scoring_handler.dart';

class FramesHandler
    extends ScoringHandler<FramesConfig, FramesMatch, FramesState> {
  @override
  FramesConfig getConfig(String leagueId) {
    throw UnimplementedError();
  }

  @override
  FramesMatch createMatch(String leagueId, List<MatchTeam> teams) {
    return FramesMatch(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      leagueId: leagueId,
      playedAt: DateTime.now(),
    );
  }

  @override
  void updateScore(FramesMatch match, String teamId, int delta) {
    // Logic for updating frames/scores
  }

  @override
  bool isMatchComplete(FramesMatch match) => match.isComplete;

  @override
  String? getWinnerTeamId(FramesMatch match) => match.winnerTeamId;

  @override
  Map<String, int> calculatePointsEarned(
    FramesMatch match,
    FramesConfig config,
  ) {
    return {};
  }

  @override
  Widget buildScoreTracker(FramesMatch match, VoidCallback onUpdate) {
    return const Center(child: Text('Frames Score Tracker'));
  }

  @override
  Widget buildScoreDisplay(FramesMatch match) {
    return const Text('Frames Score');
  }
}
