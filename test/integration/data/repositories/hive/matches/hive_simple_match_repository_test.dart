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

    test('get should return match when it exists', () async {
      final model = SimpleMatchHiveModel.fromDomain(tMatch);
      when(() => mockMatchBox.get('m1')).thenReturn(model);

      final result = await repository.get('m1');

      expect(result?.id, tMatch.id);
      expect(result?.winnerSideId, 's1');
    });

    test('get should return null when match does not exist', () async {
      when(() => mockMatchBox.get('missing')).thenReturn(null);

      final result = await repository.get('missing');

      expect(result, isNull);
    });

    test('put should call box.put', () async {
      when(() => mockMatchBox.put(any(), any())).thenAnswer((_) async => {});

      await repository.put(tMatch);

      verify(() => mockMatchBox.put(tMatch.id, any())).called(1);
    });

    test('getAll should return all matches', () async {
      final m1 = SimpleMatchHiveModel(
          id: '1',
          leagueId: 'l1',
          playedAt: DateTime.now(),
          isComplete: true,
          isDraw: false,
          sides: []);
      when(() => mockMatchBox.values).thenReturn([m1]);

      final result = await repository.getAll();

      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('delete should call box.delete', () async {
      when(() => mockMatchBox.delete('m1')).thenAnswer((_) async => {});

      await repository.delete('m1');

      verify(() => mockMatchBox.delete('m1')).called(1);
    });

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
