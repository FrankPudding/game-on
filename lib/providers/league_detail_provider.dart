import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/league_player.dart';
import '../domain/entities/side.dart';
import '../domain/entities/matches/simple_match.dart';
import '../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/league_repository.dart';
import '../domain/repositories/league_player_repository.dart';
import '../domain/repositories/match/simple_match_repository.dart';
import '../domain/repositories/user_repository.dart';
import '../core/injection_container.dart';
import 'leagues_provider.dart';
import 'users_provider.dart';

// Match Repository Provider
final simpleMatchRepositoryProvider = Provider<SimpleMatchRepository>((ref) {
  return sl<SimpleMatchRepository>();
});

final leaguePlayerRepositoryProvider = Provider<LeaguePlayerRepository>((ref) {
  return sl<LeaguePlayerRepository>();
});

// State Class
class PlayerStats {
  const PlayerStats({
    required this.points,
    required this.matchesPlayed,
  });
  final int points;
  final int matchesPlayed;

  PlayerStats copyWith({int? points, int? matchesPlayed}) {
    return PlayerStats(
      points: points ?? this.points,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
    );
  }
}

class LeagueDetailState {
  const LeagueDetailState({
    required this.players,
    required this.matches,
    required this.playerStats,
  });
  final List<LeaguePlayer> players;
  final List<SimpleMatch> matches;
  final Map<String, PlayerStats> playerStats;
}

// Notifier
final leagueDetailProvider = AsyncNotifierProvider.family<LeagueDetailNotifier,
    LeagueDetailState, String>(() {
  return LeagueDetailNotifier();
});

class LeagueDetailNotifier
    extends FamilyAsyncNotifier<LeagueDetailState, String> {
  late final LeagueRepository _leagueRepo;
  late final LeaguePlayerRepository _playerRepo;
  late final UserRepository _userRepo;
  late final SimpleMatchRepository _matchRepo;
  late String _leagueId;
  final _uuid = const Uuid();

  @override
  Future<LeagueDetailState> build(String arg) async {
    _leagueId = arg;
    _leagueRepo = ref.read(leagueRepositoryProvider);
    _playerRepo = ref.read(leaguePlayerRepositoryProvider);
    _userRepo = ref.read(userRepositoryProvider);
    _matchRepo = ref.read(simpleMatchRepositoryProvider);

    return _fetchData();
  }

  Future<LeagueDetailState> _fetchData() async {
    final league = await _leagueRepo.get(_leagueId);
    if (league == null) throw Exception('League not found');

    final rawPlayers = await _playerRepo.getByLeague(_leagueId);
    final matches = await _matchRepo.getByLeague(_leagueId);
    matches.sort((a, b) => b.playedAt.compareTo(a.playedAt));

    // Dynamic stat calculation using the league's ranking policy if possible
    final playerStats = <String, PlayerStats>{};
    for (final player in rawPlayers) {
      playerStats[player.id] = const PlayerStats(points: 0, matchesPlayed: 0);
    }

    final policy = league.rankingPolicy;
    if (policy is SimpleRankingPolicy) {
      for (final match in matches) {
        if (!match.isComplete) continue;

        for (final side in match.sides) {
          final isWinner = !match.isDraw && match.winnerSideId == side.id;
          final points = match.isDraw
              ? policy.pointsForDraw
              : (isWinner ? policy.pointsForWin : policy.pointsForLoss);

          for (final playerId in side.playerIds) {
            final current = playerStats[playerId] ??
                const PlayerStats(points: 0, matchesPlayed: 0);
            playerStats[playerId] = current.copyWith(
              points: current.points + points,
              matchesPlayed: current.matchesPlayed + 1,
            );
          }
        }
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

  Future<void> addPlayer({
    required String name,
    String? userId,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      String finalUserId;
      String finalName = name;
      String? finalIcon = icon;

      if (userId != null) {
        finalUserId = userId;
        final user = await _userRepo.get(userId);
        if (user != null) {
          if (finalName.isEmpty) finalName = user.name;
          finalIcon ??= user.icon;
        }
      } else {
        finalUserId = _uuid.v4();
        final user = User(
          id: finalUserId,
          name: name,
          avatarColorHex: 'AE0C00', // Brand Red
          icon: icon,
        );
        await _userRepo.put(user);
      }

      final leaguePlayer = LeaguePlayer(
        id: _uuid.v4(),
        userId: finalUserId,
        leagueId: _leagueId,
        name: finalName,
        avatarColorHex: 'AE0C00',
        icon: finalIcon,
      );

      await _playerRepo.put(leaguePlayer);
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
      final winnerSide = Side(
        id: _uuid.v4(),
        playerIds: [winnerId],
      );
      final loserSide = Side(
        id: _uuid.v4(),
        playerIds: [loserId],
      );

      final match = SimpleMatch(
        id: _uuid.v4(),
        leagueId: _leagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: isDraw,
        sides: [winnerSide, loserSide],
        winnerSideId: isDraw ? null : winnerSide.id,
      );

      await _matchRepo.logSimpleMatch(match: match);
      return _fetchData();
    });
  }
}
