import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/data/repositories/hive/hive_league_repository.dart';
import 'package:game_on/data/models/hive/league_hive_model.dart';
import 'package:game_on/data/models/hive/ranking_policies/simple_ranking_policy_hive_model.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';

class MockLeagueBox extends Mock implements Box<LeagueHiveModel> {}

void main() {
  setUpAll(() {
    registerFallbackValue(LeagueHiveModel(
        id: '',
        name: '',
        createdAt: DateTime.now(),
        isArchived: false,
        rankingPolicy: SimpleRankingPolicyHiveModel(
          id: 'rp1',
          name: 'Standard',
          pointsForWin: 3,
          pointsForDraw: 1,
          pointsForLoss: 0,
        )));
  });

  late HiveLeagueRepository repository;
  late MockLeagueBox mockLeagueBox;

  setUp(() {
    mockLeagueBox = MockLeagueBox();
    repository = HiveLeagueRepository(mockLeagueBox);
  });

  group('HiveLeagueRepository', () {
    final tRankingPolicy = SimpleRankingPolicy(
      id: 'rp1',
      name: 'Standard',
      pointsForWin: 3,
      pointsForDraw: 1,
      pointsForLoss: 0,
    );
    final tLeague = League<SimpleMatch>(
      id: '1',
      name: 'Test League',
      createdAt: DateTime(2023),
      rankingPolicy: tRankingPolicy,
    );
    final tModel = LeagueHiveModel.fromDomain(tLeague);

    test('get should return league when it exists', () async {
      when(() => mockLeagueBox.get('1')).thenReturn(tModel);

      final result = await repository.get('1');

      expect(result?.id, tLeague.id);
      expect(result?.name, tLeague.name);
      final policy = result?.rankingPolicy as SimpleRankingPolicy;
      expect(policy.pointsForWin, 3);
      verify(() => mockLeagueBox.get('1')).called(1);
    });

    test('get should return null when league does not exist', () async {
      when(() => mockLeagueBox.get('any')).thenReturn(null);

      final result = await repository.get('any');

      expect(result, isNull);
    });

    test('put should call box.put', () async {
      when(() => mockLeagueBox.put(any(), any())).thenAnswer((_) async => {});

      await repository.put(tLeague);

      verify(() => mockLeagueBox.put(tLeague.id, any())).called(1);
    });

    test('getAll should return all leagues', () async {
      when(() => mockLeagueBox.values).thenReturn([tModel]);

      final result = await repository.getAll();

      expect(result.length, 1);
      expect(result.first.id, tLeague.id);
    });

    test('archiveLeague should update item if it exists', () async {
      when(() => mockLeagueBox.get('1')).thenReturn(tModel);
      when(() => mockLeagueBox.put(any(), any())).thenAnswer((_) async => {});

      await repository.archiveLeague('1');

      verify(() => mockLeagueBox.get('1')).called(1);
      verify(() => mockLeagueBox.put(
          '1',
          any(
              that: isA<LeagueHiveModel>()
                  .having((m) => m.isArchived, 'isArchived', true)))).called(1);
    });
  });
}
