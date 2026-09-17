import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/application/services/update_user_service.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/providers/league_detail_provider.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockLeaguePlayerRepository extends Mock
    implements LeaguePlayerRepository {}

class MockDeleteUserService extends Mock implements DeleteUserService {}

class MockUpdateUserService extends Mock implements UpdateUserService {}

class FakeUsersNotifier extends UsersNotifier {
  @override
  Future<List<User>> build() async => [];
}

void main() {
  late MockUserRepository mockUserRepo;
  late MockLeaguePlayerRepository mockPlayerRepo;
  late MockDeleteUserService mockDeleteService;
  late ProviderContainer container;

  final tUser1 = User(id: 'u1', name: 'User 1', avatarColorHex: 'FF0000');
  final tUser2 = User(id: 'u2', name: 'User 2', avatarColorHex: '00FF00');

  setUp(() {
    mockUserRepo = MockUserRepository();
    mockPlayerRepo = MockLeaguePlayerRepository();
    mockDeleteService = MockDeleteUserService();
    container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        deleteUserServiceProvider.overrideWithValue(mockDeleteService),
        updateUserServiceProvider
            .overrideWith((ref) => MockUpdateUserService()),
      ],
    );

    registerFallbackValue(
        User(id: '', name: '', avatarColorHex: '', icon: null));
    registerFallbackValue(LeaguePlayer(
        id: '', userId: '', leagueId: '', name: '', avatarColorHex: ''));
  });

  tearDown(() {
    container.dispose();
  });

  group('UsersNotifier', () {
    test('initial state should fetch users from repository', () async {
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tUser1, tUser2]);
      when(() => mockPlayerRepo.getByUserId(any())).thenAnswer((_) async => []);

      final users = await container.read(usersProvider.future);

      expect(users, [tUser1, tUser2]);
      verify(() => mockUserRepo.getAll()).called(1);
    });

    test('addUser should call repository and update state', () async {
      when(() => mockUserRepo.getAll()).thenAnswer((_) async => [tUser1]);
      when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByUserId(any())).thenAnswer((_) async => []);

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
      when(() => mockPlayerRepo.getByUserId(any())).thenAnswer((_) async => []);
      when(() => mockDeleteService.execute(any()))
          .thenAnswer((_) async => DeleteUserResult(affectedLeagueIds: {}));

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

    test('updateUser should call service and update state', () async {
      final mockUpdateService = container.read(updateUserServiceProvider);
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tUser1, tUser2]);
      when(() => mockPlayerRepo.getByUserId(any())).thenAnswer((_) async => []);
      when(() => mockUpdateService.execute(any())).thenAnswer((_) async => {});

      final notifier = container.read(usersProvider.notifier);

      // Initial build
      await container.read(usersProvider.future);

      // Update user
      final updatedUser = tUser1.copyWith(name: 'Updated Name', icon: '🆕');
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [updatedUser, tUser2]);

      await notifier.updateUser(updatedUser);

      final state = container.read(usersProvider).value;
      expect(state, [updatedUser, tUser2]);
      verify(() => mockUpdateService.execute(updatedUser)).called(1);
    });

    test('refresh should reload users from repository', () async {
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tUser1, tUser2]);
      when(() => mockPlayerRepo.getByUserId(any())).thenAnswer((_) async => []);

      await container.read(usersProvider.future);

      when(() => mockUserRepo.getAll()).thenAnswer((_) async => [tUser1]);

      await container.read(usersProvider.notifier).refresh();

      final state = container.read(usersProvider).value;
      expect(state, [tUser1]);
    });

    group('Alphabetical sorting contract', () {
      test(
          'should sort by name: trim, empty-first, case-insensitive primary + case-sensitive secondary, then id',
          () async {
        // Repo returns unsorted: bob, " Alice", alice, "  Charlie  ", "", "   "
        final unsorted = [
          User(id: 'u1', name: 'bob', avatarColorHex: '000'),
          User(id: 'u2', name: ' Alice', avatarColorHex: '000'),
          User(id: 'u3', name: 'alice', avatarColorHex: '000'),
          User(id: 'u4', name: '  Charlie  ', avatarColorHex: '000'),
          User(id: 'u5', name: '', avatarColorHex: '000'),
          User(id: 'u6', name: '   ', avatarColorHex: '000'),
        ];
        when(() => mockUserRepo.getAll()).thenAnswer((_) async => unsorted);
        when(() => mockPlayerRepo.getByUserId(any()))
            .thenAnswer((_) async => []);

        final users = await container.read(usersProvider.future);

        // Expected: empty/whitespace first ordered by id, then Alice < alice (case-sensitive tie-break), then bob, then Charlie
        // IDs: u5 ("") , u6 ("   ") first (both empty after trim, ordered by id)
        // then u2 (" Alice" -> "Alice"), u3 ("alice"), u1 ("bob"), u4 ("Charlie")
        expect(users.map((u) => u.id).toList(),
            ['u5', 'u6', 'u2', 'u3', 'u1', 'u4']);
        expect(users.map((u) => u.name).toList(),
            ['', '   ', ' Alice', 'alice', 'bob', '  Charlie  ']);
      });

      test('should order duplicate names by id', () async {
        final dup = [
          User(id: 'u2', name: 'Alice', avatarColorHex: '000'),
          User(id: 'u1', name: 'Alice', avatarColorHex: '000'),
          User(id: 'u3', name: 'Alice', avatarColorHex: '000'),
        ];
        when(() => mockUserRepo.getAll()).thenAnswer((_) async => dup);
        when(() => mockPlayerRepo.getByUserId(any()))
            .thenAnswer((_) async => []);

        final users = await container.read(usersProvider.future);
        expect(users.map((u) => u.id).toList(), ['u1', 'u2', 'u3']);
      });

      test('should treat whitespace-trimmed names equal and then id', () async {
        final usersWithTrim = [
          User(id: 'u2', name: 'Alice', avatarColorHex: '000'),
          User(id: 'u1', name: ' Alice ', avatarColorHex: '000'),
          User(id: 'u3', name: '  Alice', avatarColorHex: '000'),
        ];
        when(() => mockUserRepo.getAll())
            .thenAnswer((_) async => usersWithTrim);
        when(() => mockPlayerRepo.getByUserId(any()))
            .thenAnswer((_) async => []);

        final users = await container.read(usersProvider.future);
        // All names trim to "Alice", so ordered by id
        expect(users.map((u) => u.id).toList(), ['u1', 'u2', 'u3']);
      });

      test(
          'should handle case-insensitive primary with case-sensitive secondary',
          () async {
        // Alice < alice < Bob < bob
        final caseVariants = [
          User(id: 'u4', name: 'bob', avatarColorHex: '000'),
          User(id: 'u3', name: 'Bob', avatarColorHex: '000'),
          User(id: 'u2', name: 'alice', avatarColorHex: '000'),
          User(id: 'u1', name: 'Alice', avatarColorHex: '000'),
        ];
        when(() => mockUserRepo.getAll()).thenAnswer((_) async => caseVariants);
        when(() => mockPlayerRepo.getByUserId(any()))
            .thenAnswer((_) async => []);

        final users = await container.read(usersProvider.future);
        expect(users.map((u) => u.name).toList(),
            ['Alice', 'alice', 'Bob', 'bob']);
        expect(users.map((u) => u.id).toList(), ['u1', 'u2', 'u3', 'u4']);
      });

      test('should be insertion-order invariant regardless of repo order',
          () async {
        final setA = [
          User(id: 'u1', name: 'Charlie', avatarColorHex: '000'),
          User(id: 'u2', name: 'Alice', avatarColorHex: '000'),
          User(id: 'u3', name: 'Bob', avatarColorHex: '000'),
        ];
        final setB = [
          User(id: 'u3', name: 'Bob', avatarColorHex: '000'),
          User(id: 'u1', name: 'Charlie', avatarColorHex: '000'),
          User(id: 'u2', name: 'Alice', avatarColorHex: '000'),
        ];
        // First order
        when(() => mockUserRepo.getAll()).thenAnswer((_) async => setA);
        when(() => mockPlayerRepo.getByUserId(any()))
            .thenAnswer((_) async => []);
        final usersA = await container.read(usersProvider.future);
        // Reset container for second order (need new container because provider cached)
        container.dispose();
        container = ProviderContainer(
          overrides: [
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
            deleteUserServiceProvider.overrideWithValue(mockDeleteService),
            updateUserServiceProvider
                .overrideWith((ref) => MockUpdateUserService()),
          ],
        );
        when(() => mockUserRepo.getAll()).thenAnswer((_) async => setB);
        final usersB = await container.read(usersProvider.future);

        expect(usersA.map((u) => u.id).toList(), ['u2', 'u3', 'u1']);
        expect(usersB.map((u) => u.id).toList(), ['u2', 'u3', 'u1']);
        expect(usersA.map((u) => u.name).toList(), ['Alice', 'Bob', 'Charlie']);
        expect(usersB.map((u) => u.name).toList(), ['Alice', 'Bob', 'Charlie']);
      });

      test('should keep alphabetical after addUser regardless of repo order',
          () async {
        when(() => mockUserRepo.getAll())
            .thenAnswer((_) async => [tUser1, tUser2]);
        when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
        when(() => mockPlayerRepo.getByUserId(any()))
            .thenAnswer((_) async => []);

        await container.read(usersProvider.future);

        // Repo now returns unsorted after add: bob, Alice
        final bob = User(id: 'uB', name: 'bob', avatarColorHex: '000');
        final alice = User(id: 'uA', name: 'Alice', avatarColorHex: '000');
        when(() => mockUserRepo.getAll())
            .thenAnswer((_) async => [bob, alice, tUser1, tUser2]);

        await container.read(usersProvider.notifier).addUser(bob);

        final state = container.read(usersProvider).value!;
        // Verify alphabetical: Alice before bob
        final names = state.map((u) => u.name).toList();
        final aliceIdx = names.indexOf('Alice');
        final bobIdx = names.indexOf('bob');
        expect(aliceIdx, lessThan(bobIdx));
      });

      test('should keep alphabetical after updateUser and refresh', () async {
        final mockUpdateService = container.read(updateUserServiceProvider);
        when(() => mockUserRepo.getAll())
            .thenAnswer((_) async => [tUser1, tUser2]);
        when(() => mockPlayerRepo.getByUserId(any()))
            .thenAnswer((_) async => []);
        when(() => mockUpdateService.execute(any()))
            .thenAnswer((_) async => {});

        await container.read(usersProvider.future);

        // After update, repo returns unsorted: User 2, Updated, User 1 etc but provider should sort
        final updated = User(id: 'u1', name: 'alice', avatarColorHex: 'FF0000');
        final other = User(id: 'u2', name: 'Bob', avatarColorHex: '00FF00');
        final charlie =
            User(id: 'u3', name: '  Charlie  ', avatarColorHex: '000');
        when(() => mockUserRepo.getAll())
            .thenAnswer((_) async => [other, charlie, updated]);

        await container.read(usersProvider.notifier).updateUser(updated);
        var state = container.read(usersProvider).value!;
        expect(
            state.map((u) => u.name).toList(), ['alice', 'Bob', '  Charlie  ']);

        // Refresh with different unsorted order should stay sorted
        when(() => mockUserRepo.getAll())
            .thenAnswer((_) async => [charlie, updated, other]);
        await container.read(usersProvider.notifier).refresh();
        state = container.read(usersProvider).value!;
        expect(
            state.map((u) => u.name).toList(), ['alice', 'Bob', '  Charlie  ']);
      });
    });
  });
}
