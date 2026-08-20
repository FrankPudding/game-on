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

    test('get should return null when player does not exist', () async {
      when(() => mockPlayerBox.get('missing')).thenReturn(null);

      final result = await repository.get('missing');

      expect(result, isNull);
    });

    test('getByLeague should return players for specific league', () async {
      final otherPlayer = LeaguePlayer(
        id: 'p2',
        userId: 'u2',
        leagueId: 'l2',
        name: 'Player 2',
        avatarColorHex: '00FF00',
      );
      final otherModel = LeaguePlayerHiveModel.fromDomain(otherPlayer);
      when(() => mockPlayerBox.values).thenReturn([tModel, otherModel]);

      final result = await repository.getByLeague('l1');

      expect(result.length, 1);
      expect(result.first.id, tPlayer.id);
    });

    test('getByUserId should return players for specific user', () async {
      final otherPlayer = LeaguePlayer(
        id: 'p2',
        userId: 'u2',
        leagueId: 'l1',
        name: 'Player 2',
        avatarColorHex: '00FF00',
      );
      final otherModel = LeaguePlayerHiveModel.fromDomain(otherPlayer);
      when(() => mockPlayerBox.values).thenReturn([tModel, otherModel]);

      final result = await repository.getByUserId('u1');

      expect(result.length, 1);
      expect(result.first.id, tPlayer.id);
    });

    test('getAll should return all players', () async {
      when(() => mockPlayerBox.values).thenReturn([tModel]);

      final result = await repository.getAll();

      expect(result.length, 1);
      expect(result.first.id, tPlayer.id);
    });

    test('put should call box.put', () async {
      when(() => mockPlayerBox.put(any(), any())).thenAnswer((_) async => {});

      await repository.put(tPlayer);

      verify(() => mockPlayerBox.put(tPlayer.id, any())).called(1);
    });

    test('delete should call box.delete', () async {
      when(() => mockPlayerBox.delete('p1')).thenAnswer((_) async => {});

      await repository.delete('p1');

      verify(() => mockPlayerBox.delete('p1')).called(1);
    });
  });
}
