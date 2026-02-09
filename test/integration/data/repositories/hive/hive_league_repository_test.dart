import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/data/repositories/hive/hive_league_repository.dart';
import 'package:game_on/data/models/hive/league_hive_model.dart';
import 'package:game_on/data/models/hive/user_hive_model.dart';
import 'package:game_on/data/models/hive/league_player_hive_model.dart';
import 'package:game_on/domain/entities/league.dart';

class MockLeagueBox extends Mock implements Box<LeagueHiveModel> {}

class MockUserBox extends Mock implements Box<UserHiveModel> {}

class MockPlayerBox extends Mock implements Box<LeaguePlayerHiveModel> {}

void main() {
  setUpAll(() {
    registerFallbackValue(LeagueHiveModel(
        id: '',
        name: '',
        createdAt: DateTime.now(),
        isArchived: false,
        pointsForWin: 0,
        pointsForDraw: 0,
        pointsForLoss: 0));
    registerFallbackValue(UserHiveModel(id: '', name: '', avatarColorHex: ''));
    registerFallbackValue(LeaguePlayerHiveModel(
        id: '', userId: '', leagueId: '', name: '', avatarColorHex: ''));
  });

  late HiveLeagueRepository repository;
  late MockLeagueBox mockLeagueBox;
  late MockUserBox mockUserBox;
  late MockPlayerBox mockPlayerBox;

  setUp(() {
    mockLeagueBox = MockLeagueBox();
    mockUserBox = MockUserBox();
    mockPlayerBox = MockPlayerBox();
    repository =
        HiveLeagueRepository(mockLeagueBox, mockUserBox, mockPlayerBox);
  });

  group('HiveLeagueRepository', () {
    final tLeague = League(
      id: '1',
      name: 'Test League',
      createdAt: DateTime(2023),
    );
    final tModel = LeagueHiveModel.fromDomain(tLeague);

    test('get should return league when it exists', () async {
      when(() => mockLeagueBox.get('1')).thenReturn(tModel);

      final result = await repository.get('1');

      expect(result?.id, tLeague.id);
      expect(result?.name, tLeague.name);
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

    group('addPlayer', () {
      test('should create new user and player if userId is null', () async {
        when(() => mockUserBox.put(any(), any())).thenAnswer((_) async => {});
        when(() => mockPlayerBox.put(any(), any())).thenAnswer((_) async => {});

        await repository.addPlayer(leagueId: 'l1', name: 'New Player');

        verify(() => mockUserBox.put(any(), any())).called(1);
        verify(() => mockPlayerBox.put(any(), any())).called(1);
      });

      test('should use existing user and create player if userId is provided',
          () async {
        final tUser = UserHiveModel(
            id: 'u1', name: 'Existing User', avatarColorHex: 'FFFAAA');
        when(() => mockUserBox.get('u1')).thenReturn(tUser);
        when(() => mockPlayerBox.put(any(), any())).thenAnswer((_) async => {});

        await repository.addPlayer(
            leagueId: 'l1', name: 'Nickname', userId: 'u1');

        verify(() => mockUserBox.get('u1')).called(1);
        verify(() => mockPlayerBox.put(
            any(),
            any(
                that: isA<LeaguePlayerHiveModel>()
                    .having((p) => p.userId, 'userId', 'u1')))).called(1);
        verifyNever(() => mockUserBox.put(any(), any()));
      });
    });
  });
}
