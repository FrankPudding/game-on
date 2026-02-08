import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/league.dart';
import '../models/league_player.dart';
import '../repositories/league_repository.dart';
import '../repositories/match_repository.dart';
import 'leagues_provider.dart';

// Match Repository Provider
final matchRepositoryProvider = Provider((ref) => MatchRepository());

// State Class
class LeagueDetailState {
  final List<LeaguePlayer> players;
  final List<dynamic> matches; // Can be SimpleMatch, FirstToMatch, etc.

  const LeagueDetailState({
    required this.players,
    required this.matches,
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
  late final MatchRepository _matchRepo;
  late String _leagueId;

  @override
  Future<LeagueDetailState> build(String arg) async {
    _leagueId = arg;
    _leagueRepo = ref.read(leagueRepositoryProvider);
    _matchRepo = ref.read(matchRepositoryProvider);

    return _fetchData();
  }

  Future<LeagueDetailState> _fetchData() async {
    final league = await _leagueRepo.getLeague(_leagueId);
    if (league == null) throw Exception('League not found');

    // Fetch players sorted by points (descending)
    final players = _leagueRepo.getLeaguePlayers(_leagueId)
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    final matches =
        await _matchRepo.getMatches(_leagueId, league.scoringSystem);

    return LeagueDetailState(players: players, matches: matches);
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
      await _matchRepo.logSimpleMatch(
          leagueId: _leagueId,
          winnerId: winnerId,
          loserId: loserId,
          isDraw: isDraw);
      return _fetchData();
    });
  }
}
