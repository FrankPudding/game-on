import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/presentation/screens/settings/manage_users_screen.dart';
import 'package:game_on/presentation/screens/settings/user_detail_screen.dart';
import 'package:game_on/presentation/widgets/user_edit_dialog.dart';

class MockUserRepository extends Mock implements UserRepository {}
class MockDeleteUserService extends Mock implements DeleteUserService {}

class FakeUsersNotifier extends UsersNotifier {
  FakeUsersNotifier([this._users = const [], this.onBuild, this.shouldThrowOnDelete = false]);
  final List<User> _users;
  final Future<List<User>> Function()? onBuild;
  final bool shouldThrowOnDelete;
  final List<User> addedUsers = [];
  final List<User> updatedUsers = [];
  final List<String> deletedUserIds = [];

  @override
  Future<List<User>> build() async {
    if (onBuild != null) return onBuild!();
    return _users;
  }

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

  @override
  Future<void> deleteUser(String userId) async {
    deletedUserIds.add(userId);
    state = const AsyncValue.loading();
    if (shouldThrowOnDelete) {
      state = await AsyncValue.guard(() async {
        throw Exception('Delete failed');
      });
      return;
    }
    state = await AsyncValue.guard(() async {
      final updated = _users.where((u) => u.id != userId).toList();
      return updated;
    });
  }
}

class RefreshingUsersNotifier extends FakeUsersNotifier {
  RefreshingUsersNotifier(List<User> users, {this.onRefresh, Future<List<User>> Function()? onBuild, bool shouldThrowOnDelete = false}) 
      : super(users, onBuild, shouldThrowOnDelete);
  final Future<List<User>> Function()? onRefresh;
  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
    if (onRefresh != null) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(onRefresh!);
    } else {
      await super.refresh();
    }
  }
}

void main() {
  late MockUserRepository mockUserRepo;
  late MockDeleteUserService mockDeleteService;
  late FakeUsersNotifier fakeUsersNotifier;

  const tUserId1 = 'u1';
  const tUserId2 = 'u2';
  final tUser1 = User(
    id: tUserId1,
    name: 'User One',
    avatarColorHex: 'FF0000',
    icon: '🎮',
  );
  final tUser2 = User(
    id: tUserId2,
    name: 'User Two',
    avatarColorHex: '00FF00',
    icon: '🏀',
  );

  setUpAll(() {
    registerFallbackValue(User(id: '', name: '', avatarColorHex: '', icon: null));
  });

  setUp(() {
    mockUserRepo = MockUserRepository();
    mockDeleteService = MockDeleteUserService();
    fakeUsersNotifier = FakeUsersNotifier([tUser1, tUser2]);
    when(() => mockUserRepo.getAll()).thenAnswer((_) async => [tUser1, tUser2]);
    when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
    when(() => mockDeleteService.execute(any())).thenAnswer((_) async => DeleteUserResult(affectedLeagueIds: {}));
  });

  Widget createWidget({
    List<User>? users,
    Future<List<User>> Function()? onBuild,
    Future<List<User>> Function()? onRefresh,
    bool shouldThrowOnDelete = false,
  }) {
    late final FakeUsersNotifier notifier;
    if (onRefresh != null) {
      notifier = RefreshingUsersNotifier(users ?? [], onRefresh: onRefresh, shouldThrowOnDelete: shouldThrowOnDelete);
    } else if (onBuild != null) {
      notifier = FakeUsersNotifier(users ?? [], onBuild, shouldThrowOnDelete);
    } else if (users != null) {
      notifier = FakeUsersNotifier(users, null, shouldThrowOnDelete);
    } else {
      notifier = FakeUsersNotifier(fakeUsersNotifier._users, fakeUsersNotifier.onBuild, shouldThrowOnDelete);
    }
    fakeUsersNotifier = notifier;
    return ProviderScope(
      retry: (_, __) => null,
      overrides: [
        usersProvider.overrideWith(() => notifier),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        deleteUserServiceProvider.overrideWithValue(mockDeleteService),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManageUsersScreen(),
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

  Future<void> openScreen(WidgetTester tester, {
    List<User>? users,
    Future<List<User>> Function()? onBuild,
    Future<List<User>> Function()? onRefresh,
    bool shouldThrowOnDelete = false,
  }) async {
    await tester.pumpWidget(createWidget(
      users: users,
      onBuild: onBuild,
      onRefresh: onRefresh,
      shouldThrowOnDelete: shouldThrowOnDelete,
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    // Extra pump to ensure async provider resolves
    await tester.pump();
  }

  group('ManageUsersScreen', () {
    testWidgets('should show loading indicator when loading', (tester) async {
      final completer = Completer<List<User>>();
      await tester.pumpWidget(createWidget(onBuild: () => completer.future));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error message on error', (tester) async {
      await tester.pumpWidget(createWidget(onBuild: () => throw Exception('Error occurred')));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('should show empty state when no users', (tester) async {
      await openScreen(tester, users: []);
      await tester.pump();

      expect(find.text('No users created yet'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('should list users with name and icon', (tester) async {
      await openScreen(tester);
      await tester.pump();

      expect(find.text('User One'), findsOneWidget);
      expect(find.text('User Two'), findsOneWidget);
      expect(find.text('🎮'), findsOneWidget);
      expect(find.text('🏀'), findsOneWidget);
      expect(find.text('Global User'), findsNWidgets(2));
    });

    testWidgets('should navigate to UserDetailScreen when tapping a user', (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.tap(find.text('User One'));
      await tester.pumpAndSettle();

      expect(find.byType(UserDetailScreen), findsOneWidget);
      // UserDetailScreen shows "User One's Leagues" in app bar
      expect(find.text("User One's Leagues"), findsOneWidget);
    });

    testWidgets('should open UserEditDialog for create when tapping FAB', (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create User'), findsOneWidget);
      expect(find.byType(UserEditDialog), findsOneWidget);
    });

    testWidgets('should create new user via FAB dialog', (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'New User');
      await tester.pump();

      await tester.tap(find.text('🎯'));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
      await tester.pumpAndSettle();

      expect(fakeUsersNotifier.addedUsers, hasLength(1));
      expect(fakeUsersNotifier.addedUsers.first.name, 'New User');
      expect(fakeUsersNotifier.addedUsers.first.icon, '🎯');
      expect(find.text('User created successfully'), findsOneWidget);
    });

    testWidgets('should open UserEditDialog for edit when tapping edit icon', (tester) async {
      await openScreen(tester);
      await tester.pump();

      // Find the edit icon for User One and tap it
      final editButtons = find.byIcon(Icons.edit_outlined);
      expect(editButtons, findsNWidgets(2));
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Edit User'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'User One');
    });

    testWidgets('should update user via edit dialog', (tester) async {
      await openScreen(tester);
      await tester.pump();

      // Tap edit icon for User One
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Updated One');
      await tester.pump();

      await tester.tap(find.text('🏎️'));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(fakeUsersNotifier.updatedUsers, hasLength(1));
      expect(fakeUsersNotifier.updatedUsers.first.name, 'Updated One');
      expect(fakeUsersNotifier.updatedUsers.first.icon, '🏎️');
      expect(fakeUsersNotifier.updatedUsers.first.id, tUserId1);
      expect(find.text('User updated successfully'), findsOneWidget);
    });

    testWidgets('should cancel edit dialog without saving', (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(fakeUsersNotifier.updatedUsers, isEmpty);
      expect(find.text('Edit User'), findsNothing);
    });

    testWidgets('should show delete confirmation dialog when tapping delete icon', (tester) async {
      await openScreen(tester);
      await tester.pump();

      // Tap delete icon for User One
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Delete User?'), findsOneWidget);
      // Use a more specific finder for the dialog content
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('User One')), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Delete'), findsOneWidget);
    });

    testWidgets('should delete user after confirmation', (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(fakeUsersNotifier.deletedUserIds, [tUserId1]);
      expect(find.text('User One'), findsNothing);
    });

    testWidgets('should cancel delete dialog without deleting', (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(fakeUsersNotifier.deletedUserIds, isEmpty);
      expect(find.text('User One'), findsOneWidget);
    });

    testWidgets('should show error in body when delete fails', (tester) async {
      await openScreen(tester, shouldThrowOnDelete: true);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      // Error is shown in the body via usersAsync.when(error: ...)
      expect(find.textContaining('Error'), findsOneWidget);
    });

    testWidgets('should handle pull-to-refresh drag without RefreshIndicator', (tester) async {
      int refreshCount = 0;
      final refreshingNotifier = RefreshingUsersNotifier(
        [tUser1],
        onRefresh: () async {
          refreshCount++;
          if (refreshCount == 1) return [tUser1];
          return [tUser1, tUser2];
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            usersProvider.overrideWith(() => refreshingNotifier),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            deleteUserServiceProvider.overrideWithValue(mockDeleteService),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.pump();

      // Verify initial state
      expect(find.text('User One'), findsOneWidget);
      expect(find.text('User Two'), findsNothing);

      // Drag on ListView (no RefreshIndicator in UI, so this won't trigger refresh)
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      // List should remain unchanged since no RefreshIndicator exists
      expect(find.text('User One'), findsOneWidget);
      expect(find.text('User Two'), findsNothing);
      expect(refreshCount, 0);
    });
  });
}