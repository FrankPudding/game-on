import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/league.dart';

import '../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../domain/repositories/league_repository.dart';
import '../core/injection_container.dart';

import '../domain/repositories/ranking_policy_repository.dart';

import '../application/services/create_league_service.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  return sl<LeagueRepository>();
});

final rankingPolicyRepositoryProvider =
    Provider<RankingPolicyRepository>((ref) {
  return sl<RankingPolicyRepository>();
});

final createLeagueServiceProvider = Provider<CreateLeagueService>((ref) {
  return sl<CreateLeagueService>();
});

final leaguesProvider =
    AsyncNotifierProvider<LeaguesNotifier, List<League>>(() {
  return LeaguesNotifier();
});

class LeaguesNotifier extends AsyncNotifier<List<League>> {
  late final LeagueRepository _leagueRepository;
  late final CreateLeagueService _createLeagueService;

  @override
  Future<List<League>> build() async {
    _leagueRepository = ref.read(leagueRepositoryProvider);
    _createLeagueService = ref.read(createLeagueServiceProvider);
    final leagues = await _leagueRepository.getAll();
    return leagues;
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
      final rankingPolicy = SimpleRankingPolicy(
        id: 'simple_$id',
        name: 'Simple Ranking Policy',
        leagueId: id,
        pointsForWin: pointsForWin,
        pointsForDraw: pointsForDraw,
        pointsForLoss: pointsForLoss,
      );

      await _createLeagueService.execute(
        id: id,
        name: name,
        rankingPolicy: rankingPolicy,
      );

      final leagues = await _leagueRepository.getAll();
      return leagues;
    });
  }

  Future<void> deleteLeague(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _leagueRepository.delete(id);
      // We might want to delete the ranking policy too, but for now we follow domain logic
      // Ideally we should delete related entities or have cascading delete.
      // But let's just delete the league for now as requested.

      final leagues = await _leagueRepository.getAll();
      return leagues;
    });
  }
}
