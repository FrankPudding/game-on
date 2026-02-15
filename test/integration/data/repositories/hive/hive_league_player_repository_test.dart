import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/data/repositories/hive/hive_league_player_repository.dart';
import 'package:game_on/data/models/hive/league_player_hive_model.dart';
import 'package:game_on/domain/entities/league_player.dart';

class MockPlayerBox extends Mock implements Box<LeaguePlayerHiveModel> {}

void main() {
  setUpAll(() {
    registerFallbackValue(LeaguePlayerHiveModel(
        id: '', userId: '', leagueId: '', name: '', avatarColorHex: ''));
  });

  late HiveLeaguePlayerRepository repository;
  late MockPlayerBox mockPlayerBox;

  setUp(() {
    mockPlayerBox = MockPlayerBox();
    repository = HiveLeaguePlayerRepository(mockPlayerBox);
  });

  group('HiveLeaguePlayerRepository', () {
    final tPlayer = LeaguePlayer(
      id: 'p1',
      userId: 'u1',
      leagueId: 'l1',
      name: 'Player 1',
      avatarColorHex: 'FF0000',
    );
    final tModel = LeaguePlayerHiveModel.fromDomain(tPlayer);

    test('get should return player when it exists', () async {
      when(() => mockPlayerBox.get('p1')).thenReturn(tModel);

      final result = await repository.get('p1');

      expect(result?.id, tPlayer.id);
      expect(result?.name, tPlayer.name);
    });

    test('getByLeague should return players for specific league', () async {
      when(() => mockPlayerBox.values).thenReturn([tModel]);

      final result = await repository.getByLeague('l1');

      expect(result.length, 1);
      expect(result.first.id, tPlayer.id);
    });

    test('put should call box.put', () async {
      when(() => mockPlayerBox.put(any(), any())).thenAnswer((_) async => {});

      await repository.put(tPlayer);

      verify(() => mockPlayerBox.put(tPlayer.id, any())).called(1);
    });
  });
}
