import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/league.dart';
import '../domain/repositories/league_repository.dart';
import '../core/injection_container.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  return sl<LeagueRepository>();
});

final leaguesProvider =
    AsyncNotifierProvider<LeaguesNotifier, List<League>>(() {
  return LeaguesNotifier();
});

class LeaguesNotifier extends AsyncNotifier<List<League>> {
  late final LeagueRepository _repository;

  @override
  Future<List<League>> build() async {
    _repository = ref.read(leagueRepositoryProvider);
    return _repository.getAll();
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
      final league = League(
        id: id,
        name: name,
        createdAt: DateTime.now(),
        pointsForWin: pointsForWin,
        pointsForDraw: pointsForDraw,
        pointsForLoss: pointsForLoss,
      );
      await _repository.put(league);
      return _repository.getAll();
    });
  }

  Future<void> deleteLeague(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.delete(id);
      return _repository.getAll();
    });
  }
}
