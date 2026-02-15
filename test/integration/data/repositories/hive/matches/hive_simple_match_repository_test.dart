import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/data/repositories/hive/matches/hive_simple_match_repository.dart';
import 'package:game_on/data/models/hive/matches/simple_match_hive_model.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';

class MockMatchBox extends Mock implements Box<SimpleMatchHiveModel> {}

void main() {
  setUpAll(() {
    registerFallbackValue(SimpleMatchHiveModel(
        id: '',
        leagueId: '',
        playedAt: DateTime.now(),
        isComplete: false,
        isDraw: false,
        sides: []));
  });

  late HiveSimpleMatchRepository repository;
  late MockMatchBox mockMatchBox;

  setUp(() {
    mockMatchBox = MockMatchBox();
    repository = HiveSimpleMatchRepository(mockMatchBox);
  });

  group('HiveSimpleMatchRepository', () {
    final tSide1 = Side(id: 's1', playerIds: ['p1']);
    final tSide2 = Side(id: 's2', playerIds: ['p2']);
    final tMatch = SimpleMatch(
      id: 'm1',
      leagueId: 'l1',
      playedAt: DateTime(2023),
      isComplete: true,
      sides: [tSide1, tSide2],
      winnerSideId: 's1',
    );

    test('logSimpleMatch should put match', () async {
      when(() => mockMatchBox.put(any(), any())).thenAnswer((_) async => {});

      await repository.logSimpleMatch(match: tMatch);

      verify(() => mockMatchBox.put(tMatch.id, any())).called(1);
    });

    test('getByLeague should return matches for league', () async {
      final m1 = SimpleMatchHiveModel(
          id: '1',
          leagueId: 'l1',
          playedAt: DateTime.now(),
          isComplete: true,
          isDraw: false,
          sides: []);
      final m2 = SimpleMatchHiveModel(
          id: '2',
          leagueId: 'l2',
          playedAt: DateTime.now(),
          isComplete: true,
          isDraw: false,
          sides: []);
      when(() => mockMatchBox.values).thenReturn([m1, m2]);

      final result = await repository.getByLeague('l1');

      expect(result.length, 1);
      expect(result.first.id, '1');
    });
  });
}
