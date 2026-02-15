import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/league.dart';
import '../domain/entities/matches/simple_match.dart';
import '../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../domain/repositories/league_repository.dart';
import '../core/injection_container.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  return sl<LeagueRepository>();
});

final leaguesProvider =
    AsyncNotifierProvider<LeaguesNotifier, List<League<SimpleMatch>>>(() {
  return LeaguesNotifier();
});

class LeaguesNotifier extends AsyncNotifier<List<League<SimpleMatch>>> {
  late final LeagueRepository _repository;

  @override
  Future<List<League<SimpleMatch>>> build() async {
    _repository = ref.read(leagueRepositoryProvider);
    final leagues = await _repository.getAll();
    // Sort or filter if needed, for now just return all as SimpleMatch leagues
    return leagues.cast<League<SimpleMatch>>();
  }

  Future<void> addLeague({
    required String id,
    required String name,
    required int pointsForWin,
    required int pointsForDraw,
    required int pointsForLoss,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final league = League<SimpleMatch>(
        id: id,
        name: name,
        createdAt: DateTime.now(),
        rankingPolicy: SimpleRankingPolicy(
          id: 'simple_$id',
          name: 'Simple Ranking Policy',
          pointsForWin: pointsForWin,
          pointsForDraw: pointsForDraw,
          pointsForLoss: pointsForLoss,
        ),
      );
      await _repository.put(league);
      final leagues = await _repository.getAll();
      return leagues.cast<League<SimpleMatch>>();
    });
  }

  Future<void> deleteLeague(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.delete(id);
      final leagues = await _repository.getAll();
      return leagues.cast<League<SimpleMatch>>();
    });
  }
}
