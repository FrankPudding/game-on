import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../models/match_participant.dart';
import '../models/league.dart';
import '../models/match/simple_match.dart';
import '../models/match/first_to_match.dart';
import '../models/match/timed_match.dart';
import '../models/match/frames_match.dart';
import '../models/match/tennis_match.dart';
import 'database_service.dart';

class MatchRepository {
  final _uuid = const Uuid();

  List<SimpleMatch> getSimpleMatches(String leagueId) {
    return DatabaseService.simpleMatches.values
        .where((m) => m.leagueId == leagueId)
        .toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  Future<List<dynamic>> getMatches(
      String leagueId, ScoringSystem system) async {
    switch (system) {
      case ScoringSystem.simple:
        return getSimpleMatches(leagueId);
      case ScoringSystem.firstTo:
        final box = await Hive.openBox<FirstToMatch>('first_to_matches');
        return box.values.where((m) => m.leagueId == leagueId).toList()
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
      case ScoringSystem.timed:
        final box = await Hive.openBox<TimedMatch>('timed_matches');
        return box.values.where((m) => m.leagueId == leagueId).toList()
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
      case ScoringSystem.frames:
        final box = await Hive.openBox<FramesMatch>('frames_matches');
        return box.values.where((m) => m.leagueId == leagueId).toList()
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
      case ScoringSystem.tennis:
        final box = await Hive.openBox<TennisMatch>('tennis_matches');
        return box.values.where((m) => m.leagueId == leagueId).toList()
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    }
  }

  Future<void> logSimpleMatch({
    required String leagueId,
    required String winnerId, // LeaguePlayer ID
    required String loserId, // LeaguePlayer ID
    required bool isDraw,
  }) async {
    // 1. Get Config
    final config = DatabaseService.simpleConfigs.values
        .firstWhere((c) => c.leagueId == leagueId);

    // 2. Create Match
    final matchId = _uuid.v4();
    final match = SimpleMatch(
      id: matchId,
      leagueId: leagueId,
      playedAt: DateTime.now(),
      isComplete: true,
      isDraw: isDraw,
      winnerId: isDraw ? null : winnerId,
    );
    await DatabaseService.simpleMatches.put(matchId, match);

    // 3. Calculate Points
    final winnerPoints = isDraw ? config.pointsForDraw : config.pointsForWin;
    final loserPoints = isDraw ? config.pointsForDraw : config.pointsForLoss;

    // 4. Create Participants
    final winnerParticipant = MatchParticipant(
      id: _uuid.v4(),
      playerId: winnerId,
      matchId: matchId,
      score: null,
      isWinner: isDraw ? null : true,
      pointsEarned: winnerPoints,
    );

    final loserParticipant = MatchParticipant(
      id: _uuid.v4(),
      playerId: loserId,
      matchId: matchId,
      score: null,
      isWinner: isDraw ? null : false,
      pointsEarned: loserPoints,
    );

    await DatabaseService.matchParticipants
        .put(winnerParticipant.id, winnerParticipant);
    await DatabaseService.matchParticipants
        .put(loserParticipant.id, loserParticipant);

    // 5. Update Player Stats is no longer needed as stats are calculated dynamically
  }
}
