import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/league.dart';
import '../repositories/league_repository.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  return LeagueRepository();
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
    return _repository.getAllLeagues();
  }

  Future<void> addSimpleLeague({
    required String name,
    required int pointsForWin,
    required int pointsForDraw,
    required int pointsForLoss,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createSimpleLeague(
        name: name,
        pointsForWin: pointsForWin,
        pointsForDraw: pointsForDraw,
        pointsForLoss: pointsForLoss,
      );
      return _repository.getAllLeagues();
    });
  }

  Future<void> addFirstToLeague({
    required String name,
    required int targetScore,
    required int winByMargin,
    required List<int> placementPoints,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createFirstToLeague(
        name: name,
        targetScore: targetScore,
        winByMargin: winByMargin,
        placementPoints: placementPoints,
      );
      return _repository.getAllLeagues();
    });
  }

  Future<void> addTimedLeague({
    required String name,
    required bool lowerScoreWins,
    required List<int> placementPoints,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createTimedLeague(
        name: name,
        lowerScoreWins: lowerScoreWins,
        placementPoints: placementPoints,
      );
      return _repository.getAllLeagues();
    });
  }

  Future<void> addFramesLeague({
    required String name,
    required int framesToWin,
    required String frameType,
    int? frameTargetScore,
    required List<int> placementPoints,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createFramesLeague(
        name: name,
        framesToWin: framesToWin,
        frameType: frameType,
        frameTargetScore: frameTargetScore,
        placementPoints: placementPoints,
      );
      return _repository.getAllLeagues();
    });
  }

  Future<void> addTennisLeague({
    required String name,
    required int setsToWin,
    required int gamesPerSet,
    required int tiebreakAt,
    required List<int> placementPoints,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createTennisLeague(
        name: name,
        setsToWin: setsToWin,
        gamesPerSet: gamesPerSet,
        tiebreakAt: tiebreakAt,
        placementPoints: placementPoints,
      );
      return _repository.getAllLeagues();
    });
  }

  Future<void> deleteLeague(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteLeague(id);
      return _repository.getAllLeagues();
    });
  }
}
