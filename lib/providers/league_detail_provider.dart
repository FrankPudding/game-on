import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/sorting/name_sort.dart';
import '../domain/entities/league_player.dart';
import '../domain/entities/side.dart';
import '../domain/entities/matches/simple_match.dart';
import '../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import '../domain/entities/ranking_policy.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/league_repository.dart';
import '../domain/repositories/league_player_repository.dart';
import '../domain/repositories/match/simple_match_repository.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/repositories/ranking_policy_repository.dart';
import '../domain/exceptions/duplicate_league_player_exception.dart';
import '../core/injection_container.dart';
import 'leagues_provider.dart';
import 'users_provider.dart';
import 'user_detail_provider.dart';
import 'sorted_leagues_provider.dart';

// Match Repository Provider
final simpleMatchRepositoryProvider = Provider<SimpleMatchRepository>((ref) {
  return sl<SimpleMatchRepository>();
});

final leaguePlayerRepositoryProvider = Provider<LeaguePlayerRepository>((ref) {
  return sl<LeaguePlayerRepository>();
});

/// Provides the last played date for a league, derived from its matches.
///
/// Returns `null` when the league has no completed matches (displays as "Never").
final leagueLastPlayedProvider =
    FutureProvider.family<DateTime?, String>((ref, leagueId) async {
  final matchRepo = ref.watch(simpleMatchRepositoryProvider);
  final matches = await matchRepo.getByLeague(leagueId);
  if (matches.isEmpty) return null;
  final completedMatches = matches.where((m) => m.isComplete).toList();
  if (completedMatches.isEmpty) return null;
  var latest = completedMatches.first.playedAt;
  for (final m in completedMatches) {
    if (m.playedAt.isAfter(latest)) latest = m.playedAt;
  }
  return latest;
});

// State Class
class PlayerStats {
  const PlayerStats({
    required this.points,
    required this.matchesPlayed,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });
  final int points;
  final int matchesPlayed;
  final int goalsFor;
  final int goalsAgainst;

  int get goalDifference => goalsFor - goalsAgainst;

  PlayerStats copyWith({
    int? points,
    int? matchesPlayed,
    int? goalsFor,
    int? goalsAgainst,
  }) {
    return PlayerStats(
      points: points ?? this.points,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
    );
  }
}

/// State for a single league detail view.
///
/// Invariants:
/// - [players] is the **ranked** order: points → (goal difference → goals for
///   for GD leagues) → id. It must NOT use name as a tie-breaker; only the
///   stable `id` fallback is allowed.
/// - [playersByName] is the **alphabetical** order of the same set as
///   [players], sorted by [compareNames] on [LeaguePlayer.name] then `id`.
///   The two lists always contain the same elements, only differing in order.
///
/// Ban note: pickers / selectors (e.g. match player pickers, dropdowns) must
/// use [playersByName], never [players]. Only the standings table may use
/// [players] (ranked order).
class LeagueDetailState {
  const LeagueDetailState({
    required this.players,
    required this.playersByName,
    required this.matches,
    required this.playerStats,
    this.rankingPolicy,
  });
  // Ranked order: points → GD → GF → id. Never name.
  final List<LeaguePlayer> players;
  // Alphabetical order: name (compareNames) → id. Same set as [players].
  // Use this for pickers/dropdowns; do NOT use [players] for pickers.
  final List<LeaguePlayer> playersByName;
  final List<SimpleMatch> matches;
  final Map<String, PlayerStats> playerStats;
  final RankingPolicy? rankingPolicy;

  bool get isGoalDifference => rankingPolicy is GoalDifferenceRankingPolicy;
}

// Notifier
final leagueDetailProvider = AsyncNotifierProvider.family<LeagueDetailNotifier,
    LeagueDetailState, String>(LeagueDetailNotifier.new);

class LeagueDetailNotifier extends AsyncNotifier<LeagueDetailState> {
  LeagueDetailNotifier(this._leagueId);
  final String _leagueId;
  late LeagueRepository _leagueRepo;
  late LeaguePlayerRepository _playerRepo;
  late UserRepository _userRepo;
  late SimpleMatchRepository _matchRepo;
  late RankingPolicyRepository _policyRepo;
  final _uuid = const Uuid();

  @override
  Future<LeagueDetailState> build() async {
    _leagueRepo = ref.read(leagueRepositoryProvider);
    _playerRepo = ref.read(leaguePlayerRepositoryProvider);
    _userRepo = ref.read(userRepositoryProvider);
    _matchRepo = ref.read(simpleMatchRepositoryProvider);
    _policyRepo = ref.read(rankingPolicyRepositoryProvider);

    // Removed ref.watch(usersProvider) - use invalidation instead

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

    final policy = await _policyRepo.getByLeagueId(_leagueId);

    if (policy is GoalDifferenceRankingPolicy) {
      for (final match in matches) {
        if (!match.isComplete) continue;

        for (final side in match.sides) {
          final otherSide = match.sides.firstWhere(
            (s) => s.id != side.id,
            orElse: () => side,
          );
          final isWinner = !match.isDraw && match.winnerSideId == side.id;
          final points = match.isDraw
              ? policy.pointsForDraw
              : (isWinner ? policy.pointsForWin : policy.pointsForLoss);
          final goalsFor = side.score ?? 0;
          final goalsAgainst = otherSide.score ?? 0;

          for (final playerId in side.playerIds) {
            final current = playerStats[playerId] ??
                const PlayerStats(points: 0, matchesPlayed: 0);
            playerStats[playerId] = current.copyWith(
              points: current.points + points,
              matchesPlayed: current.matchesPlayed + 1,
              goalsFor: current.goalsFor + goalsFor,
              goalsAgainst: current.goalsAgainst + goalsAgainst,
            );
          }
        }
      }
    } else if (policy is SimpleRankingPolicy) {
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

    // Ranked order: points → GD → GF → id. Never use name as tie-breaker.
    final sortedPlayers = List<LeaguePlayer>.from(rawPlayers)
      ..sort((a, b) {
        final statsA = playerStats[a.id];
        final statsB = playerStats[b.id];
        var result = (statsB?.points ?? 0).compareTo(statsA?.points ?? 0);
        if (result == 0 && policy is GoalDifferenceRankingPolicy) {
          result = (statsB?.goalDifference ?? 0)
              .compareTo(statsA?.goalDifference ?? 0);
        }
        if (result == 0 && policy is GoalDifferenceRankingPolicy) {
          result = (statsB?.goalsFor ?? 0).compareTo(statsA?.goalsFor ?? 0);
        }
        if (result == 0) {
          result = a.id.compareTo(b.id);
        }
        return result;
      });

    // Alphabetical order for pickers: name (compareNames) → id. Same set as sortedPlayers.
    final sortedByName = List<LeaguePlayer>.from(rawPlayers)
      ..sort((a, b) {
        final c = compareNames(a.name, b.name);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });

    return LeagueDetailState(
      players: sortedPlayers,
      playersByName: sortedByName,
      matches: matches,
      playerStats: playerStats,
      rankingPolicy: policy,
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

      bool createdNewUser = false;

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
        createdNewUser = true;
      }

      // Use addPlayerIfUnique which enforces uniqueness per (userId, leagueId)
      try {
        await _playerRepo.addPlayerIfUnique(
          userId: finalUserId,
          leagueId: _leagueId,
          name: finalName,
          avatarColorHex: 'AE0C00',
          icon: finalIcon,
        );
      } on DuplicateLeaguePlayerException {
        // Re-throw with a user-friendly message
        throw Exception(
          'This user is already a player in this league.',
        );
      }

      // Invalidate related providers (but NOT self - we update state directly)
      if (createdNewUser) {
        ref.invalidate(usersProvider);
      }
      ref.invalidate(userDetailProvider(finalUserId));

      return _fetchData();
    });
  }

  Future<void> logSimpleMatch({
    required String winnerId,
    required String loserId,
    required bool isDraw,
    DateTime? playedAt,
    int? winnerScore,
    int? loserScore,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final winnerSide = Side(
        id: _uuid.v4(),
        playerIds: [winnerId],
        score: winnerScore,
      );
      final loserSide = Side(
        id: _uuid.v4(),
        playerIds: [loserId],
        score: loserScore,
      );

      final now = DateTime.now();
      final match = SimpleMatch(
        id: _uuid.v4(),
        leagueId: _leagueId,
        playedAt: playedAt ?? DateTime(now.year, now.month, now.day),
        isComplete: true,
        isDraw: isDraw,
        sides: [winnerSide, loserSide],
        winnerSideId: isDraw ? null : winnerSide.id,
      );

      await _matchRepo.logSimpleMatch(match: match);

      // Invalidate related providers (but NOT self - we update state directly)
      // winnerId and loserId are LeaguePlayer IDs; we need userIds for userDetailProvider
      final winnerPlayer = await _playerRepo.get(winnerId);
      final loserPlayer = await _playerRepo.get(loserId);
      if (winnerPlayer != null) {
        ref.invalidate(userDetailProvider(winnerPlayer.userId));
      }
      if (loserPlayer != null) {
        ref.invalidate(userDetailProvider(loserPlayer.userId));
      }
      ref.invalidate(leagueLastPlayedProvider(_leagueId));
      ref.invalidate(sortedLeaguesProvider);

      return _fetchData();
    });
  }

  Future<void> updateSimpleMatch({
    required String matchId,
    required String winnerId,
    required String loserId,
    required bool isDraw,
    DateTime? playedAt,
    int? winnerScore,
    int? loserScore,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final match = await _matchRepo.get(matchId);
      if (match == null) throw Exception('Match not found');

      final winnerSide = Side(
        id: _uuid.v4(),
        playerIds: [winnerId],
        score: winnerScore,
      );
      final loserSide = Side(
        id: _uuid.v4(),
        playerIds: [loserId],
        score: loserScore,
      );

      final updatedMatch = match.copyWith(
        isDraw: isDraw,
        sides: [winnerSide, loserSide],
        winnerSideId: isDraw ? null : winnerSide.id,
        playedAt: playedAt,
      );

      await _matchRepo.logSimpleMatch(match: updatedMatch);

      // Invalidate related providers (but NOT self - we update state directly)
      // winnerId and loserId are LeaguePlayer IDs; we need userIds for userDetailProvider
      final winnerPlayer = await _playerRepo.get(winnerId);
      final loserPlayer = await _playerRepo.get(loserId);
      if (winnerPlayer != null) {
        ref.invalidate(userDetailProvider(winnerPlayer.userId));
      }
      if (loserPlayer != null) {
        ref.invalidate(userDetailProvider(loserPlayer.userId));
      }
      ref.invalidate(leagueLastPlayedProvider(_leagueId));
      ref.invalidate(sortedLeaguesProvider);

      return _fetchData();
    });
  }

  Future<void> deleteMatch(String matchId) async {
    // Fetch match first to get player IDs for invalidation
    final match = await _matchRepo.get(matchId);
    final userIds = <String>{};
    if (match != null) {
      for (final side in match.sides) {
        for (final playerId in side.playerIds) {
          final player = await _playerRepo.get(playerId);
          if (player != null) {
            userIds.add(player.userId);
          }
        }
      }
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _matchRepo.delete(matchId);

      // Invalidate related providers (but NOT self - we update state directly)
      for (final userId in userIds) {
        ref.invalidate(userDetailProvider(userId));
      }
      ref.invalidate(leagueLastPlayedProvider(_leagueId));
      ref.invalidate(sortedLeaguesProvider);

      return _fetchData();
    });
  }

  Future<void> updatePlayer({
    required String playerId,
    required String name,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    try {
      final player = await _playerRepo.get(playerId);
      if (player == null) throw Exception('Player not found');
      final userId = player.userId;

      final updatedPlayer = player.copyWith(
        name: name,
        icon: icon,
      );
      await _playerRepo.put(updatedPlayer);

      // Invalidate related providers (but NOT self - we update state directly)
      ref.invalidate(userDetailProvider(userId));

      state = AsyncValue.data(await _fetchData());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> removePlayer(String playerId) async {
    state = const AsyncValue.loading();
    try {
      // Get player info before deletion for invalidation
      final player = await _playerRepo.get(playerId);
      final userId = player?.userId;

      // Don't allow removing if they have played matches
      final matches = await _matchRepo.getByLeague(_leagueId);
      final hasPlayed = matches
          .any((m) => m.sides.any((s) => s.playerIds.contains(playerId)));

      if (hasPlayed) {
        throw Exception(
            'Cannot remove player with match history. Delete their matches first.');
      }

      await _playerRepo.delete(playerId);

      // Invalidate related providers (but NOT self - we update state directly)
      ref.invalidate(usersProvider);
      if (userId != null) {
        ref.invalidate(userDetailProvider(userId));
      }

      state = AsyncValue.data(await _fetchData());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
