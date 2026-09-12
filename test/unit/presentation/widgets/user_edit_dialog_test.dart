import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/application/services/update_user_service.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/presentation/widgets/user_edit_dialog.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockDeleteUserService extends Mock implements DeleteUserService {}

class MockUpdateUserService extends Mock implements UpdateUserService {}

class FakeUsersNotifier extends UsersNotifier {
  FakeUsersNotifier([this._users = const []]);
  final List<User> _users;

  @override
  Future<List<User>> build() async => _users;

  @override
  Future<void> addUser(User user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(userRepositoryProvider);
      await repo.put(user);
      return _repo.getAll();
    });
  }

  @override
  Future<void> updateUser(User user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(updateUserServiceProvider);
      await service.execute(user);
      return _repo.getAll();
    });
  }

  UserRepository get _repo => ref.read(userRepositoryProvider);
}

void main() {
  late MockUserRepository mockUserRepo;
  late MockDeleteUserService mockDeleteService;
  late MockUpdateUserService mockUpdateService;
  late ProviderContainer container;

  final tExistingUser = User(
    id: 'u1',
    name: 'Existing User',
    avatarColorHex: 'FF0000',
    icon: '🎮',
  );

  setUpAll(() {
    registerFallbackValue(
        User(id: '', name: '', avatarColorHex: '', icon: null));
  });

  setUp(() {
    mockUserRepo = MockUserRepository();
    mockDeleteService = MockDeleteUserService();
    mockUpdateService = MockUpdateUserService();

    container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        deleteUserServiceProvider.overrideWithValue(mockDeleteService),
        updateUserServiceProvider.overrideWithValue(mockUpdateService),
        usersProvider.overrideWith(() => FakeUsersNotifier([])),
      ],
    );

    when(() => mockUserRepo.getAll()).thenAnswer((_) async => []);
  });

  tearDown(() {
    container.dispose();
  });

  Widget createDialogWidget({User? user}) {
    return ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        deleteUserServiceProvider.overrideWithValue(mockDeleteService),
        updateUserServiceProvider.overrideWithValue(mockUpdateService),
        usersProvider.overrideWith(() => FakeUsersNotifier([])),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => UserEditDialog.show(context, user: user),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester, {User? user}) async {
    await tester.pumpWidget(createDialogWidget(user: user));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
  }

  group('UserEditDialog - Create User', () {
    testWidgets('should show create dialog with empty fields',
        (WidgetTester tester) async {
      await openDialog(tester);

      expect(find.text('Create User'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('👤'), findsOneWidget); // Default icon selected
    });

    testWidgets('should create user successfully with valid input',
        (WidgetTester tester) async {
      when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockUserRepo.getAll()).thenAnswer((_) async =>
          [User(id: 'new-id', name: 'New User', avatarColorHex: 'AE0C00')]);

      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'New User');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      verify(() => mockUserRepo.put(
              any(that: isA<User>().having((u) => u.name, 'name', 'New User'))))
          .called(1);
      expect(find.text('User created successfully'), findsOneWidget);
    });

    testWidgets('should show error when name is empty',
        (WidgetTester tester) async {
      await openDialog(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a name'), findsOneWidget);
      verifyNever(() => mockUserRepo.put(any()));
    });

    testWidgets('should show error snackbar when repository fails',
        (WidgetTester tester) async {
      when(() => mockUserRepo.put(any()))
          .thenThrow(Exception('Repository error'));

      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'New User');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should select custom icon when creating user',
        (WidgetTester tester) async {
      when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockUserRepo.getAll()).thenAnswer((_) async => [
            User(
                id: 'new-id',
                name: 'Gamer',
                avatarColorHex: 'AE0C00',
                icon: '🎮')
          ]);

      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'Gamer');
      await tester.tap(find.text('🎮'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      verify(() => mockUserRepo
              .put(any(that: isA<User>().having((u) => u.icon, 'icon', '🎮'))))
          .called(1);
    });
  });

  group('UserEditDialog - Edit User', () {
    testWidgets('should show edit dialog pre-filled with user data',
        (WidgetTester tester) async {
      await openDialog(tester, user: tExistingUser);

      expect(find.text('Edit User'), findsOneWidget);
      expect(find.text('Existing User'), findsOneWidget);
      expect(find.text('🎮'), findsOneWidget); // User's icon selected
    });

    testWidgets('should update user successfully with valid input',
        (WidgetTester tester) async {
      when(() => mockUpdateService.execute(any())).thenAnswer((_) async => {});
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tExistingUser.copyWith(name: 'Updated')]);

      await openDialog(tester, user: tExistingUser);

      await tester.enterText(find.byType(TextField), 'Updated');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      verify(() => mockUpdateService.execute(
              any(that: isA<User>().having((u) => u.name, 'name', 'Updated'))))
          .called(1);
      expect(find.text('User updated successfully'), findsOneWidget);
    });

    testWidgets('should show error when name is empty on edit',
        (WidgetTester tester) async {
      await openDialog(tester, user: tExistingUser);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a name'), findsOneWidget);
      verifyNever(() => mockUpdateService.execute(any()));
    });

    testWidgets('should show error snackbar when update service fails',
        (WidgetTester tester) async {
      when(() => mockUpdateService.execute(any()))
          .thenThrow(Exception('Update failed'));

      await openDialog(tester, user: tExistingUser);

      await tester.enterText(find.byType(TextField), 'Updated');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should select custom icon when editing user',
        (WidgetTester tester) async {
      when(() => mockUpdateService.execute(any())).thenAnswer((_) async => {});
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tExistingUser.copyWith(icon: '⚽')]);

      await openDialog(tester, user: tExistingUser);

      await tester.tap(find.text('⚽'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      verify(() => mockUpdateService.execute(
          any(that: isA<User>().having((u) => u.icon, 'icon', '⚽')))).called(1);
    });
  });
}
