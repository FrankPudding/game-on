import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockLeaguePlayerRepository extends Mock
    implements LeaguePlayerRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

void main() {
  late MockUserRepository mockUserRepo;
  late MockLeaguePlayerRepository mockPlayerRepo;
  late MockSimpleMatchRepository mockMatchRepo;
  late DeleteUserService service;

  const tUserId = 'u1';

  setUp(() {
    mockUserRepo = MockUserRepository();
    mockPlayerRepo = MockLeaguePlayerRepository();
    mockMatchRepo = MockSimpleMatchRepository();
    service = DeleteUserService(mockUserRepo, mockPlayerRepo, mockMatchRepo);
  });

  group('DeleteUserService', () {
    test('should delete user, their players, and associated matches', () async {
      // Arrange
      final p1 = LeaguePlayer(
          id: 'p1',
          userId: tUserId,
          leagueId: 'l1',
          name: 'P1',
          avatarColorHex: 'A');
      final p2 = LeaguePlayer(
          id: 'p2',
          userId: tUserId,
          leagueId: 'l2',
          name: 'P2',
          avatarColorHex: 'B');

      final m1 = SimpleMatch(
          id: 'm1',
          leagueId: 'l1',
          playedAt: DateTime.now(),
          isComplete: true,
          sides: [
            Side(id: 's1', playerIds: ['p1']), // p1 is here
            Side(id: 's2', playerIds: ['p3']),
          ]);
      final m2 = SimpleMatch(
          id: 'm2',
          leagueId: 'l2',
          playedAt: DateTime.now(),
          isComplete: true,
          sides: [
            Side(id: 's3', playerIds: ['p4']),
            Side(id: 's4', playerIds: ['p5']),
          ]);

      when(() => mockPlayerRepo.getAll()).thenAnswer((_) async => [p1, p2]);
      when(() => mockMatchRepo.getAll()).thenAnswer((_) async => [m1, m2]);
      when(() => mockMatchRepo.delete(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.delete(any())).thenAnswer((_) async => {});
      when(() => mockUserRepo.delete(any())).thenAnswer((_) async => {});

      // Act
      final result = await service.execute(tUserId);

      // Assert
      verify(() => mockMatchRepo.delete('m1')).called(1);
      verifyNever(() => mockMatchRepo.delete('m2'));
      verify(() => mockPlayerRepo.delete('p1')).called(1);
      verify(() => mockPlayerRepo.delete('p2')).called(1);
      verify(() => mockUserRepo.delete(tUserId)).called(1);
      expect(result.affectedLeagueIds, {'l1', 'l2'});
    });

    test('should handle user with no players or matches', () async {
      when(() => mockPlayerRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockMatchRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockUserRepo.delete(any())).thenAnswer((_) async => {});

      final result = await service.execute(tUserId);

      verify(() => mockUserRepo.delete(tUserId)).called(1);
      verifyNever(() => mockMatchRepo.delete(any()));
      verifyNever(() => mockPlayerRepo.delete(any()));
      expect(result.affectedLeagueIds, isEmpty);
    });
  });
}
