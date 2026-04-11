import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/providers/users_provider.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockDeleteUserService extends Mock implements DeleteUserService {}

void main() {
  late MockUserRepository mockUserRepo;
  late MockDeleteUserService mockDeleteService;
  late ProviderContainer container;

  final tUser1 = User(id: 'u1', name: 'User 1', avatarColorHex: 'FF0000');
  final tUser2 = User(id: 'u2', name: 'User 2', avatarColorHex: '00FF00');

  setUp(() {
    mockUserRepo = MockUserRepository();
    mockDeleteService = MockDeleteUserService();
    container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        deleteUserServiceProvider.overrideWithValue(mockDeleteService),
      ],
    );

    registerFallbackValue(
        User(id: '', name: '', avatarColorHex: '', icon: null));
  });

  tearDown(() {
    container.dispose();
  });

  group('UsersNotifier', () {
    test('initial state should fetch users from repository', () async {
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tUser1, tUser2]);

      final users = await container.read(usersProvider.future);

      expect(users, [tUser1, tUser2]);
      verify(() => mockUserRepo.getAll()).called(1);
    });

    test('addUser should call repository and update state', () async {
      when(() => mockUserRepo.getAll()).thenAnswer((_) async => [tUser1]);
      when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});

      final notifier = container.read(usersProvider.notifier);

      // Initial build
      await container.read(usersProvider.future);

      // Add user
      final newUser = User(id: 'u3', name: 'User 3', avatarColorHex: '0000FF');
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tUser1, newUser]);

      await notifier.addUser(newUser);

      final state = container.read(usersProvider).value;
      expect(state, [tUser1, newUser]);
      verify(() => mockUserRepo.put(newUser)).called(1);
    });

    test('deleteUser should call service and update state', () async {
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tUser1, tUser2]);
      when(() => mockDeleteService.execute(any())).thenAnswer((_) async => {});

      final notifier = container.read(usersProvider.notifier);

      // Initial build
      await container.read(usersProvider.future);

      // Delete user
      when(() => mockUserRepo.getAll()).thenAnswer((_) async => [tUser2]);

      await notifier.deleteUser('u1');

      final state = container.read(usersProvider).value;
      expect(state, [tUser2]);
      verify(() => mockDeleteService.execute('u1')).called(1);
    });
  });
}
