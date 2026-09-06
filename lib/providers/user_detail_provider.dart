import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/league.dart';
import '../domain/entities/league_player.dart';
import '../domain/entities/matches/simple_match.dart';
import '../domain/repositories/league_repository.dart';
import '../domain/repositories/league_player_repository.dart';
import '../domain/repositories/match/simple_match_repository.dart';
import '../providers/league_detail_provider.dart';
import 'leagues_provider.dart';

class UserLeagueInfo {
  const UserLeagueInfo({
    required this.league,
    required this.player,
    required this.matches,
  });
  final League league;
  final LeaguePlayer player;
  final List<SimpleMatch> matches;
}

final userDetailProvider = AsyncNotifierProvider.family<UserDetailNotifier,
    List<UserLeagueInfo>, String>(UserDetailNotifier.new);

class UserDetailNotifier extends AsyncNotifier<List<UserLeagueInfo>> {
  UserDetailNotifier(this._userId);
  final String _userId;
  late LeagueRepository _leagueRepo;
  late LeaguePlayerRepository _playerRepo;
  late SimpleMatchRepository _matchRepo;

  @override
  Future<List<UserLeagueInfo>> build() async {
    _leagueRepo = ref.watch(leagueRepositoryProvider);
    _playerRepo = ref.watch(leaguePlayerRepositoryProvider);
    _matchRepo = ref.watch(simpleMatchRepositoryProvider);

    // Removed ref.watch(usersProvider) and ref.watch(leaguesProvider)
    // Use explicit invalidation instead for precise, efficient updates

    return _fetchData();
  }

  Future<List<UserLeagueInfo>> _fetchData() async {
    final participants = await _playerRepo.getByUserId(_userId);
    final List<UserLeagueInfo> userLeagues = [];

    for (final player in participants) {
      final league = await _leagueRepo.get(player.leagueId);
      if (league != null) {
        final matches = await _matchRepo.getByLeague(league.id);
        final playerMatches = matches
            .where((m) => m.sides.any((s) => s.playerIds.contains(player.id)))
            .toList();

        userLeagues.add(UserLeagueInfo(
          league: league,
          player: player,
          matches: playerMatches,
        ));
      }
    }

    return userLeagues;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData());
  }
}