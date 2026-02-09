import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/league_player.dart';
import '../domain/entities/match_participant.dart';
import '../domain/entities/simple_match.dart';
import '../domain/repositories/league_repository.dart';
import '../domain/repositories/simple_match_repository.dart';
import '../core/injection_container.dart';
import 'leagues_provider.dart';

// Match Repository Provider
final simpleMatchRepositoryProvider = Provider<SimpleMatchRepository>((ref) {
  return sl<SimpleMatchRepository>();
});

// State Class
class PlayerStats {
  final int points;
  final int matchesPlayed;

  const PlayerStats({
    required this.points,
    required this.matchesPlayed,
  });

  PlayerStats copyWith({int? points, int? matchesPlayed}) {
    return PlayerStats(
      points: points ?? this.points,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
    );
  }
}

class LeagueDetailState {
  final List<LeaguePlayer> players;
  final List<SimpleMatch> matches;
  final Map<String, PlayerStats> playerStats; // leaguePlayerId -> stats

  const LeagueDetailState({
    required this.players,
    required this.matches,
    required this.playerStats,
  });
}

// Notifier
final leagueDetailProvider = AsyncNotifierProvider.family<LeagueDetailNotifier,
    LeagueDetailState, String>(() {
  return LeagueDetailNotifier();
});

class LeagueDetailNotifier
    extends FamilyAsyncNotifier<LeagueDetailState, String> {
  late final LeagueRepository _leagueRepo;
  late final SimpleMatchRepository _matchRepo;
  late String _leagueId;
  final _uuid = const Uuid();

  @override
  Future<LeagueDetailState> build(String arg) async {
    _leagueId = arg;
    _leagueRepo = ref.read(leagueRepositoryProvider);
    _matchRepo = ref.read(simpleMatchRepositoryProvider);

    return _fetchData();
  }

  Future<LeagueDetailState> _fetchData() async {
    final league = await _leagueRepo.get(_leagueId);
    if (league == null) throw Exception('League not found');

    final rawPlayers = _leagueRepo.getLeaguePlayers(_leagueId);
    final matches = await _matchRepo.getByLeague(_leagueId);
    matches.sort((a, b) => b.playedAt.compareTo(a.playedAt));

    // Dynamic stat calculation
    final playerStats = <String, PlayerStats>{};
    for (final player in rawPlayers) {
      playerStats[player.id] = const PlayerStats(points: 0, matchesPlayed: 0);
    }

    // Get all participants for these matches
    final matchIds = matches.map((m) => m.id).toList();
    final allParticipants =
        await _matchRepo.getParticipantsForMatches(matchIds);

    for (final participant in allParticipants) {
      final playerId = participant.playerId;
      if (playerStats.containsKey(playerId)) {
        final current = playerStats[playerId]!;
        playerStats[playerId] = current.copyWith(
          points: current.points + (participant.pointsEarned ?? 0).toInt(),
          matchesPlayed: current.matchesPlayed + 1,
        );
      }
    }

    // Sort players by points (descending)
    final sortedPlayers = List<LeaguePlayer>.from(rawPlayers)
      ..sort((a, b) {
        final ptsA = playerStats[a.id]?.points ?? 0;
        final ptsB = playerStats[b.id]?.points ?? 0;
        return ptsB.compareTo(ptsA);
      });

    return LeagueDetailState(
      players: sortedPlayers,
      matches: matches,
      playerStats: playerStats,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData());
  }

  Future<void> addPlayer(String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _leagueRepo.addPlayer(leagueId: _leagueId, name: name);
      return _fetchData();
    });
  }

  Future<void> logSimpleMatch({
    required String winnerId,
    required String loserId,
    required bool isDraw,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final league = await _leagueRepo.get(_leagueId);
      if (league == null) return _fetchData();

      final matchId = _uuid.v4();
      final match = SimpleMatch(
        id: matchId,
        leagueId: _leagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: isDraw,
        winnerId: isDraw ? null : winnerId,
      );

      final winnerPoints = isDraw ? league.pointsForDraw : league.pointsForWin;
      final loserPoints = isDraw ? league.pointsForDraw : league.pointsForLoss;

      final participants = [
        MatchParticipant(
          id: _uuid.v4(),
          playerId: winnerId,
          matchId: matchId,
          score: null,
          isWinner: isDraw ? null : true,
          pointsEarned: winnerPoints,
        ),
        MatchParticipant(
          id: _uuid.v4(),
          playerId: loserId,
          matchId: matchId,
          score: null,
          isWinner: isDraw ? null : false,
          pointsEarned: loserPoints,
        ),
      ];

      await _matchRepo.logSimpleMatch(match: match, participants: participants);
      return _fetchData();
    });
  }
}
