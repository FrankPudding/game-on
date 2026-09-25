import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/league.dart';

import '../domain/entities/ranking_policy.dart';
import '../domain/repositories/league_repository.dart';
import '../core/injection_container.dart';

import '../domain/repositories/ranking_policy_repository.dart';
import 'league_detail_provider.dart';

import '../application/services/create_league_service.dart';

import 'sorted_leagues_provider.dart';

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
  late LeagueRepository _leagueRepository;
  late CreateLeagueService _createLeagueService;

  void _invalidateSorted() => ref.invalidate(sortedLeaguesProvider);

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
    required RankingPolicy rankingPolicy,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _createLeagueService.execute(
        id: id,
        name: name,
        rankingPolicy: rankingPolicy,
      );

      // No self-invalidation - explicit fetch updates our state
      // Dependent providers (leagueDetailProvider) are invalidated separately
      // when their league is deleted
      _invalidateSorted();

      final leagues = await _leagueRepository.getAll();
      return leagues;
    });
  }

  Future<void> deleteLeague(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _leagueRepository.delete(id);

      // Invalidate the specific league detail (dependent provider)
      ref.invalidate(leagueDetailProvider(id));
      _invalidateSorted();

      final leagues = await _leagueRepository.getAll();
      return leagues;
    });
  }

  Future<void> archiveLeague(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _leagueRepository.archiveLeague(id);
      _invalidateSorted();
      return _leagueRepository.getAll();
    });
  }

  Future<void> renameLeague(String id, String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final league = await _leagueRepository.get(id);
      if (league != null) {
        await _leagueRepository.put(league.copyWith(name: name));
      }
      _invalidateSorted();
      return _leagueRepository.getAll();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final leagues = await _leagueRepository.getAll();
      return leagues;
    });
    // Refresh is explicit fetch; if needed, sorted will be invalidated via next build
    // but we also invalidate to ensure sorted reflects latest
    _invalidateSorted();
  }
}
