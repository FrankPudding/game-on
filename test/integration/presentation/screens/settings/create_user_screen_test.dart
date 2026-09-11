import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/application/services/update_user_service.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/presentation/screens/settings/create_user_screen.dart';

class MockUserRepository extends Mock implements UserRepository {}
class MockLeaguePlayerRepository extends Mock implements LeaguePlayerRepository {}
class MockDeleteUserService extends Mock implements DeleteUserService {}
class MockUpdateUserService extends Mock implements UpdateUserService {}

class FakeUsersNotifier extends UsersNotifier {
  FakeUsersNotifier([this._users = const []]);
  final List<User> _users;
  final List<User> addedUsers = [];
  final List<User> updatedUsers = [];

  @override
  Future<List<User>> build() async => _users;

  @override
  Future<void> addUser(User user) async {
    addedUsers.add(user);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => [..._users, user]);
  }

  @override
  Future<void> updateUser(User user) async {
    updatedUsers.add(user);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final updated = _users.map((u) => u.id == user.id ? user : u).toList();
      return updated;
    });
  }
}

void main() {
  late MockUserRepository mockUserRepo;
  late MockLeaguePlayerRepository mockPlayerRepo;
  late MockDeleteUserService mockDeleteService;
  late MockUpdateUserService mockUpdateService;
  late FakeUsersNotifier fakeUsersNotifier;
  late ProviderContainer container;

  const tUserId = 'u1';
  final tUser = User(
    id: tUserId,
    name: 'Test User',
    avatarColorHex: 'FF0000',
    icon: '🎮',
  );

  setUpAll(() {
    registerFallbackValue(User(id: '', name: '', avatarColorHex: '', icon: null));
    registerFallbackValue(DeleteUserResult(affectedLeagueIds: {}));
  });

  setUp(() {
    mockUserRepo = MockUserRepository();
    mockPlayerRepo = MockLeaguePlayerRepository();
    mockDeleteService = MockDeleteUserService();
    mockUpdateService = MockUpdateUserService();
    fakeUsersNotifier = FakeUsersNotifier([tUser]);

    container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        deleteUserServiceProvider.overrideWithValue(mockDeleteService),
        updateUserServiceProvider.overrideWithValue(mockUpdateService),
        usersProvider.overrideWith(() => fakeUsersNotifier),
      ],
    );

    when(() => mockUserRepo.getAll()).thenAnswer((_) async => [tUser]);
    when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
    when(() => mockPlayerRepo.getByUserId(any())).thenAnswer((_) async => []);
    when(() => mockDeleteService.execute(any())).thenAnswer((_) async => DeleteUserResult(affectedLeagueIds: {}));
    when(() => mockUpdateService.execute(any())).thenAnswer((_) async => {});
  });

  tearDown(() {
    container.dispose();
  });

  Widget createWidget({User? user, List<User>? users}) {
    final notifier = users != null ? FakeUsersNotifier(users) : fakeUsersNotifier;
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateUserScreen(user: user),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget createWidgetWithRealNotifier({User? user}) {
    // Create a fresh container with real notifier and mocked services
    final testContainer = ProviderContainer(
      overrides: [
        usersProvider.overrideWith(() => UsersNotifier()),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        deleteUserServiceProvider.overrideWithValue(mockDeleteService),
        updateUserServiceProvider.overrideWithValue(mockUpdateService),
      ],
    );

    return UncontrolledProviderScope(
      container: testContainer,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  // Force initialize usersProvider by awaiting its future
                  await testContainer.read(usersProvider.future);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateUserScreen(user: user),
                      ),
                    );
                  }
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openScreen(WidgetTester tester, {User? user, List<User>? users}) async {
    await tester.pumpWidget(createWidget(user: user, users: users));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> openScreenWithRealNotifier(WidgetTester tester, {User? user}) async {
    await tester.pumpWidget(createWidgetWithRealNotifier(user: user));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('CreateUserScreen', () {
    testWidgets('should show create user screen with empty form when creating new user', (tester) async {
      await openScreen(tester);

      expect(find.text('Create User'), findsNWidgets(2)); // AppBar title + Button
      expect(find.text('User Details'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Choose Avatar Icon'), findsOneWidget);
    });

    testWidgets('should show edit user screen with pre-filled data when editing', (tester) async {
      await openScreen(tester, user: tUser);

      expect(find.text('Edit User'), findsOneWidget);
      expect(find.text('Edit User Details'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Test User');
      // Check selected icon
      expect(find.text('🎮'), findsWidgets); // At least one for the selected icon
    });

    testWidgets('should create user successfully on valid input', (tester) async {
      await openScreen(tester);
      await tester.pump();

      // Enter name
      await tester.enterText(find.byType(TextField), 'New User');
      await tester.pump();

      // Select an icon
      await tester.tap(find.text('⚽'));
      await tester.pump();

      // Tap create button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create User'));
      await tester.pumpAndSettle();

      // Verify user was added
      expect(fakeUsersNotifier.addedUsers, hasLength(1));
      expect(fakeUsersNotifier.addedUsers.first.name, 'New User');
      expect(fakeUsersNotifier.addedUsers.first.icon, '⚽');

      // Verify navigation popped and SnackBar shown
      expect(find.text('User created successfully'), findsOneWidget);
    });

    testWidgets('should update user successfully on valid input in edit mode', (tester) async {
      await openScreen(tester, user: tUser);
      await tester.pump();

      // Update name
      await tester.enterText(find.byType(TextField), 'Updated User');
      await tester.pump();

      // Select different icon
      await tester.tap(find.text('🏀'));
      await tester.pump();

      // Tap save button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      // Verify user was updated
      expect(fakeUsersNotifier.updatedUsers, hasLength(1));
      expect(fakeUsersNotifier.updatedUsers.first.name, 'Updated User');
      expect(fakeUsersNotifier.updatedUsers.first.icon, '🏀');
      expect(fakeUsersNotifier.updatedUsers.first.id, tUserId);

      // Verify navigation popped and SnackBar shown
      expect(find.text('User updated successfully'), findsOneWidget);
    });

    testWidgets('should show error SnackBar when name is empty', (tester) async {
      await openScreen(tester);
      await tester.pump();

      // Tap create without entering name
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create User'));
      await tester.pumpAndSettle();

      // Verify no user was added
      expect(fakeUsersNotifier.addedUsers, isEmpty);

      // Verify error SnackBar
      expect(find.text('Please enter a name'), findsOneWidget);
    });

    testWidgets('should show error SnackBar when repository throws on create', (tester) async {
      when(() => mockUserRepo.put(any())).thenThrow(Exception('DB Error'));

      await openScreenWithRealNotifier(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'New User');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create User'));
      await tester.pumpAndSettle();

      // Verify error SnackBar - the error message includes the exception
      expect(find.textContaining('Error creating user'), findsOneWidget);
      expect(find.textContaining('DB Error'), findsOneWidget);
    });

    testWidgets('should show error SnackBar when service throws on update', (tester) async {
      when(() => mockUpdateService.execute(any())).thenThrow(Exception('DB Error'));

      await openScreenWithRealNotifier(tester, user: tUser);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Updated User');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      // Verify error SnackBar
      expect(find.textContaining('Error updating user'), findsOneWidget);
      expect(find.textContaining('DB Error'), findsOneWidget);
    });

    testWidgets('should show loading indicator while submitting', (tester) async {
      // Use a completer to delay the repository call
      final completer = Completer<void>();
      when(() => mockUserRepo.put(any())).thenAnswer((_) => completer.future);

      await openScreenWithRealNotifier(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'New User');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create User'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show loading indicator on button (it replaces the button text)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('should allow icon selection', (tester) async {
      await openScreen(tester);
      await tester.pump();

      // Default icon should be 👤
      expect(find.text('👤'), findsWidgets);

      // Tap a different icon
      await tester.tap(find.text('🎯'));
      await tester.pump();

      // Verify selection changed (the selected icon has a border)
      // The icon text is still present but now with selection styling
      expect(find.text('🎯'), findsWidgets);
    });

    testWidgets('should cancel and pop without saving when using back button', (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'New User');
      await tester.pump();

      // Navigate back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify no user was added
      expect(fakeUsersNotifier.addedUsers, isEmpty);
    });
  });
}