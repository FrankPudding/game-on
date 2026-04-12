import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/application/services/update_user_service.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockLeaguePlayerRepository extends Mock
    implements LeaguePlayerRepository {}

void main() {
  late MockUserRepository mockUserRepo;
  late MockLeaguePlayerRepository mockPlayerRepo;
  late UpdateUserService service;

  setUpAll(() {
    registerFallbackValue(User(id: '', name: '', avatarColorHex: ''));
    registerFallbackValue(LeaguePlayer(
        id: '', userId: '', leagueId: '', name: '', avatarColorHex: ''));
  });

  setUp(() {
    mockUserRepo = MockUserRepository();
    mockPlayerRepo = MockLeaguePlayerRepository();
    service = UpdateUserService(mockUserRepo);
  });

  group('UpdateUserService', () {
    test('should update user only', () async {
      // Arrange
      final updatedUser =
          User(id: 'u1', name: 'New Name', avatarColorHex: 'new', icon: 'new');

      when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});

      // Act
      await service.execute(updatedUser);

      // Assert
      verify(() => mockUserRepo.put(updatedUser)).called(1);
      verifyNever(() => mockPlayerRepo.put(any()));
    });
  });
}
