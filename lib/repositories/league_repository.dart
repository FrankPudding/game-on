import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/league.dart';
import '../models/user.dart';
import '../models/league_player.dart';
import '../models/configs/simple_config.dart';
import '../models/configs/first_to_config.dart';
import '../models/configs/timed_config.dart';
import '../models/configs/frames_config.dart';
import '../models/configs/tennis_config.dart';
import 'database_service.dart';

class LeagueRepository {
  final _uuid = const Uuid();

  Future<List<League>> getAllLeagues() async {
    return DatabaseService.leagues.values.toList();
  }

  Future<League?> getLeague(String id) async {
    return DatabaseService.leagues.get(id);
  }

  Future<void> createSimpleLeague({
    required String name,
    required int pointsForWin,
    required int pointsForDraw,
    required int pointsForLoss,
  }) async {
    final leagueId = _uuid.v4();
    final league = League(
      id: leagueId,
      name: name,
      scoringSystem: ScoringSystem.simple,
      createdAt: DateTime.now(),
    );
    final config = SimpleConfig(
      leagueId: leagueId,
      pointsForWin: pointsForWin,
      pointsForDraw: pointsForDraw,
      pointsForLoss: pointsForLoss,
    );
    await DatabaseService.leagues.put(leagueId, league);
    await DatabaseService.simpleConfigs.put(leagueId, config);
  }

  Future<void> createFirstToLeague({
    required String name,
    required int targetScore,
    required int winByMargin,
    required List<int> placementPoints,
  }) async {
    final leagueId = _uuid.v4();
    final league = League(
      id: leagueId,
      name: name,
      scoringSystem: ScoringSystem.firstTo,
      createdAt: DateTime.now(),
    );
    final config = FirstToConfig(
      leagueId: leagueId,
      targetScore: targetScore,
      winByMargin: winByMargin,
      placementPoints: placementPoints,
    );
    await DatabaseService.leagues.put(leagueId, league);
    final box = await Hive.openBox<FirstToConfig>('first_to_configs');
    await box.put(leagueId, config);
  }

  Future<void> createTimedLeague({
    required String name,
    required bool lowerScoreWins,
    required List<int> placementPoints,
  }) async {
    final leagueId = _uuid.v4();
    final league = League(
      id: leagueId,
      name: name,
      scoringSystem: ScoringSystem.timed,
      createdAt: DateTime.now(),
    );
    final config = TimedConfig(
      leagueId: leagueId,
      lowerScoreWins: lowerScoreWins,
      placementPoints: placementPoints,
    );
    await DatabaseService.leagues.put(leagueId, league);
    final box = await Hive.openBox<TimedConfig>('timed_configs');
    await box.put(leagueId, config);
  }

  Future<void> createFramesLeague({
    required String name,
    required int framesToWin,
    required String frameType,
    int? frameTargetScore,
    required List<int> placementPoints,
  }) async {
    final leagueId = _uuid.v4();
    final league = League(
      id: leagueId,
      name: name,
      scoringSystem: ScoringSystem.frames,
      createdAt: DateTime.now(),
    );
    final config = FramesConfig(
      leagueId: leagueId,
      framesToWin: framesToWin,
      frameType: frameType,
      frameTargetScore: frameTargetScore,
      placementPoints: placementPoints,
    );
    await DatabaseService.leagues.put(leagueId, league);
    final box = await Hive.openBox<FramesConfig>('frames_configs');
    await box.put(leagueId, config);
  }

  Future<void> createTennisLeague({
    required String name,
    required int setsToWin,
    required int gamesPerSet,
    required int tiebreakAt,
    required List<int> placementPoints,
  }) async {
    final leagueId = _uuid.v4();
    final league = League(
      id: leagueId,
      name: name,
      scoringSystem: ScoringSystem.tennis,
      createdAt: DateTime.now(),
    );
    final config = TennisConfig(
      leagueId: leagueId,
      setsToWin: setsToWin,
      gamesPerSet: gamesPerSet,
      tiebreakAt: tiebreakAt,
      placementPoints: placementPoints,
    );
    await DatabaseService.leagues.put(leagueId, league);
    final box = await Hive.openBox<TennisConfig>('tennis_configs');
    await box.put(leagueId, config);
  }

  Future<void> deleteLeague(String id) async {
    final league = await DatabaseService.leagues.get(id);
    if (league == null) return;

    // 1. Delete associated Players
    final playerIds = DatabaseService.leaguePlayers.values
        .where((p) => p.leagueId == id)
        .map((p) => p.id)
        .toList();
    for (final pid in playerIds) {
      await DatabaseService.leaguePlayers.delete(pid);
    }

    // 2. Delete Matches and Participants for all systems
    // We iterate through all match boxes and delete any matching this leagueId
    final allMatchBoxes = [
      DatabaseService.simpleMatches,
      DatabaseService.firstToMatches,
      DatabaseService.timedMatches,
      DatabaseService.framesMatches,
      DatabaseService.tennisMatches,
    ];

    for (final box in allMatchBoxes) {
      final matchesToDelete = box.values
          .where((m) => (m as dynamic).leagueId == id)
          .map((m) => (m as dynamic).id as String)
          .toList();

      for (final mid in matchesToDelete) {
        // Delete participants for this match
        final participantsToDelete = DatabaseService.matchParticipants.values
            .where((p) => p.matchId == mid)
            .map((p) => p.id)
            .toList();
        for (final paid in participantsToDelete) {
          await DatabaseService.matchParticipants.delete(paid);
        }
        await box.delete(mid);
      }
    }

    // 3. Delete Configs
    switch (league.scoringSystem) {
      case ScoringSystem.simple:
        await DatabaseService.simpleConfigs.delete(id);
        break;
      case ScoringSystem.firstTo:
        await DatabaseService.firstToConfigs.delete(id);
        break;
      case ScoringSystem.timed:
        await DatabaseService.timedConfigs.delete(id);
        break;
      case ScoringSystem.frames:
        await DatabaseService.framesConfigs.delete(id);
        break;
      case ScoringSystem.tennis:
        await DatabaseService.tennisConfigs.delete(id);
        break;
    }

    // 4. Finally delete the league
    await DatabaseService.leagues.delete(id);
  }

  Future<void> addPlayer({
    required String leagueId,
    required String name,
  }) async {
    final userId = _uuid.v4();
    final player = User(
      id: userId,
      name: name,
      avatarColorHex: 'FFC40C', // Default yellow for now
    );
    await DatabaseService.users.put(userId, player);

    final leaguePlayerId = _uuid.v4();
    final leaguePlayer = LeaguePlayer(
      id: leaguePlayerId,
      playerId: userId,
      leagueId: leagueId,
      name: name,
      avatarColorHex: 'FFC40C',
    );
    await DatabaseService.leaguePlayers.put(leaguePlayerId, leaguePlayer);
  }

  List<LeaguePlayer> getLeaguePlayers(String leagueId) {
    return DatabaseService.leaguePlayers.values
        .where((p) => p.leagueId == leagueId)
        .toList();
  }
}
