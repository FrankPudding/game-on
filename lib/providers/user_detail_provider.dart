import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/league.dart';
import '../domain/entities/league_player.dart';
import '../domain/entities/matches/simple_match.dart';
import '../domain/repositories/league_repository.dart';
import '../domain/repositories/league_player_repository.dart';
import '../domain/repositories/match/simple_match_repository.dart';
import 'leagues_provider.dart';
import 'users_provider.dart';
import 'league_detail_provider.dart';

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
    List<UserLeagueInfo>, String>(() {
  return UserDetailNotifier();
});

class UserDetailNotifier
    extends FamilyAsyncNotifier<List<UserLeagueInfo>, String> {
  late LeagueRepository _leagueRepo;
  late LeaguePlayerRepository _playerRepo;
  late SimpleMatchRepository _matchRepo;
  late String _userId;

  @override
  Future<List<UserLeagueInfo>> build(String arg) async {
    _userId = arg;
    _leagueRepo = ref.watch(leagueRepositoryProvider);
    _playerRepo = ref.watch(leaguePlayerRepositoryProvider);
    _matchRepo = ref.watch(simpleMatchRepositoryProvider);

    // Watch for changes in users or leagues to refresh
    ref.watch(usersProvider);
    ref.watch(leaguesProvider);

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
