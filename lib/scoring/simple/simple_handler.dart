import 'package:flutter/material.dart';
import '../../models/match_team.dart';
import '../../models/configs/simple_config.dart';
import '../../models/match/simple_match.dart';
import '../scoring_handler.dart';

class SimpleHandler extends ScoringHandler<SimpleConfig, SimpleMatch, void> {
  @override
  SimpleConfig getConfig(String leagueId) {
    // This will be managed by a repository/service
    throw UnimplementedError();
  }

  @override
  SimpleMatch createMatch(String leagueId, List<MatchTeam> teams) {
    return SimpleMatch(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .toString(), // Simplified ID for now
      leagueId: leagueId,
      isComplete: false,
      playedAt: DateTime.now(),
    );
  }

  @override
  void updateScore(SimpleMatch match, String teamId, int delta) {
    if (delta > 0) {
      match.winnerId = teamId;
      match.isDraw = false;
    } else if (delta == 0) {
      match.isDraw = true;
      match.winnerId = null;
    }
  }

  @override
  bool isMatchComplete(SimpleMatch match) => match.isComplete;

  @override
  String? getWinnerTeamId(SimpleMatch match) => match.winnerId;

  @override
  Map<String, int> calculatePointsEarned(
    SimpleMatch match,
    SimpleConfig config,
  ) {
    // Note: This logic assumes match.winnerId is populated if not a draw
    // Actually, handling this globally in repository for now,
    // but this method should return what the config dictates.

    // We don't have the player IDs here easily without passing them.
    // Let's refine the handler to be more specific.
    return {};
  }

  @override
  Widget buildScoreTracker(SimpleMatch match, VoidCallback onUpdate) {
    return const SizedBox.shrink(); // Simple match uses LogMatchScreen (static)
  }

  @override
  Widget buildScoreDisplay(SimpleMatch match) {
    if (match.isDraw) return const Text('Draw');
    return Text('Winner: ${match.winnerId}');
  }
}
