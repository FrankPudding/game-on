import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/data/repositories/hive/hive_league_player_repository.dart';
import 'package:game_on/data/models/hive/league_player_hive_model.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/exceptions/duplicate_league_player_exception.dart';

class MockPlayerBox extends Mock implements Box<LeaguePlayerHiveModel> {}

class MockUniqueIndexBox extends Mock implements Box<String> {}

void main() {
  setUpAll(() {
    registerFallbackValue(LeaguePlayerHiveModel(
        id: '', userId: '', leagueId: '', name: '', avatarColorHex: ''));
    registerFallbackValue('');
  });

  late HiveLeaguePlayerRepository repository;
  late MockPlayerBox mockPlayerBox;
  late MockUniqueIndexBox mockUniqueIndexBox;

  setUp(() {
    mockPlayerBox = MockPlayerBox();
    mockUniqueIndexBox = MockUniqueIndexBox();
    repository = HiveLeaguePlayerRepository(mockPlayerBox, mockUniqueIndexBox);
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

    test('delete should call box.delete and remove from unique index', () async {
      when(() => mockPlayerBox.get('p1')).thenReturn(tModel);
      when(() => mockPlayerBox.delete('p1')).thenAnswer((_) async => {});
      when(() => mockUniqueIndexBox.delete('u1_l1')).thenAnswer((_) async => {});

      await repository.delete('p1');

      verify(() => mockPlayerBox.delete('p1')).called(1);
      verify(() => mockUniqueIndexBox.delete('u1_l1')).called(1);
    });

    test('delete should not remove from index if player not found', () async {
      when(() => mockPlayerBox.get('missing')).thenReturn(null);
      when(() => mockPlayerBox.delete('missing')).thenAnswer((_) async => {});

      await repository.delete('missing');

      verify(() => mockPlayerBox.delete('missing')).called(1);
      verifyNever(() => mockUniqueIndexBox.delete(any()));
    });

    group('addPlayerIfUnique', () {
      const userId = 'u1';
      const leagueId = 'l1';
      const compositeKey = 'u1_l1';

      test('should add player successfully when unique', () async {
        String? capturedId;

        when(() => mockUniqueIndexBox.containsKey(compositeKey))
            .thenReturn(false);
        when(() => mockPlayerBox.put(any(), any())).thenAnswer((invocation) async {
          capturedId = invocation.positionalArguments[0] as String;
        });
        when(() => mockUniqueIndexBox.put(compositeKey, any()))
            .thenAnswer((_) async => {});
        when(() => mockPlayerBox.get(any())).thenAnswer((invocation) {
          final id = invocation.positionalArguments[0] as String;
          return LeaguePlayerHiveModel(
            id: id,
            userId: userId,
            leagueId: leagueId,
            name: 'New Player',
            avatarColorHex: 'FF0000',
          );
        });
        when(() => mockUniqueIndexBox.get(compositeKey))
            .thenAnswer((_) => capturedId);
        when(() => mockPlayerBox.delete(any())).thenAnswer((_) async => {});
        when(() => mockUniqueIndexBox.delete(any())).thenAnswer((_) async => {});

        final result = await repository.addPlayerIfUnique(
          userId: userId,
          leagueId: leagueId,
          name: 'New Player',
          avatarColorHex: 'FF0000',
        );

        expect(result.userId, userId);
        expect(result.leagueId, leagueId);
        expect(result.name, 'New Player');
        expect(result.avatarColorHex, 'FF0000');
        verify(() => mockPlayerBox.put(any(), any())).called(1);
        verify(() => mockUniqueIndexBox.put(compositeKey, any())).called(1);
      });

      test('should throw DuplicateLeaguePlayerException when player exists in league', () async {
        when(() => mockUniqueIndexBox.containsKey(compositeKey))
            .thenReturn(true);

        expect(
          () => repository.addPlayerIfUnique(
            userId: userId,
            leagueId: leagueId,
            name: 'New Player',
            avatarColorHex: 'FF0000',
          ),
          throwsA(isA<DuplicateLeaguePlayerException>()),
        );

        verifyNever(() => mockPlayerBox.put(any(), any()));
        verifyNever(() => mockUniqueIndexBox.put(any(), any()));
      });

      test('should allow same user in different league', () async {
        const otherLeagueId = 'l2';
        const otherCompositeKey = 'u1_l2';
        String? capturedId;

        when(() => mockUniqueIndexBox.containsKey(otherCompositeKey))
            .thenReturn(false);
        when(() => mockPlayerBox.put(any(), any())).thenAnswer((invocation) async {
          capturedId = invocation.positionalArguments[0] as String;
        });
        when(() => mockUniqueIndexBox.put(otherCompositeKey, any()))
            .thenAnswer((_) async => {});
        when(() => mockPlayerBox.get(any())).thenAnswer((invocation) {
          final id = invocation.positionalArguments[0] as String;
          return LeaguePlayerHiveModel(
            id: id,
            userId: userId,
            leagueId: otherLeagueId,
            name: 'New Player',
            avatarColorHex: 'FF0000',
          );
        });
        when(() => mockUniqueIndexBox.get(otherCompositeKey))
            .thenAnswer((_) => capturedId);
        when(() => mockPlayerBox.delete(any())).thenAnswer((_) async => {});
        when(() => mockUniqueIndexBox.delete(any())).thenAnswer((_) async => {});

        final result = await repository.addPlayerIfUnique(
          userId: userId,
          leagueId: otherLeagueId,
          name: 'New Player',
          avatarColorHex: 'FF0000',
        );

        expect(result.leagueId, otherLeagueId);
        verify(() => mockPlayerBox.put(any(), any())).called(1);
        verify(() => mockUniqueIndexBox.put(otherCompositeKey, any())).called(1);
      });

      test('should rollback index if player save fails', () async {
        when(() => mockUniqueIndexBox.containsKey(compositeKey))
            .thenReturn(false);
        when(() => mockPlayerBox.put(any(), any())).thenAnswer((_) => Future.value());
        when(() => mockUniqueIndexBox.put(compositeKey, any()))
            .thenAnswer((_) => Future.value());
        when(() => mockPlayerBox.get(any())).thenReturn(null);
        when(() => mockUniqueIndexBox.get(compositeKey)).thenReturn('generated-id');
        when(() => mockUniqueIndexBox.delete(compositeKey)).thenAnswer((_) => Future.value());
        when(() => mockPlayerBox.delete(any())).thenAnswer((_) => Future.value());

        await expectLater(
          repository.addPlayerIfUnique(
            userId: userId,
            leagueId: leagueId,
            name: 'New Player',
            avatarColorHex: 'FF0000',
          ),
          throwsA(isA<StateError>()),
        );

        verify(() => mockUniqueIndexBox.delete(compositeKey)).called(1);
      });

      test('should rollback player if index save fails', () async {
        String? capturedId;

        when(() => mockUniqueIndexBox.containsKey(compositeKey))
            .thenReturn(false);
        when(() => mockPlayerBox.put(any(), any())).thenAnswer((invocation) async {
          capturedId = invocation.positionalArguments[0] as String;
        });
        when(() => mockUniqueIndexBox.put(compositeKey, any()))
            .thenAnswer((_) => Future.value());
        when(() => mockPlayerBox.get(any())).thenAnswer((invocation) {
          final id = invocation.positionalArguments[0] as String;
          return LeaguePlayerHiveModel(
            id: id,
            userId: userId,
            leagueId: leagueId,
            name: 'New Player',
            avatarColorHex: 'FF0000',
          );
        });
        // Return a different ID than what was stored to simulate index failure
        when(() => mockUniqueIndexBox.get(compositeKey)).thenReturn('wrong-id');
        when(() => mockPlayerBox.delete(any())).thenAnswer((_) => Future.value());
        when(() => mockUniqueIndexBox.delete(any())).thenAnswer((_) => Future.value());

        await expectLater(
          repository.addPlayerIfUnique(
            userId: userId,
            leagueId: leagueId,
            name: 'New Player',
            avatarColorHex: 'FF0000',
          ),
          throwsA(isA<StateError>()),
        );

        verify(() => mockPlayerBox.delete(capturedId)).called(1);
      });
    });
  });
}