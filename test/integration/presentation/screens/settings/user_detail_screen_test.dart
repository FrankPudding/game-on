import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/providers/user_detail_provider.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/application/services/update_user_service.dart';
import 'package:game_on/presentation/screens/settings/user_detail_screen.dart';
import 'package:game_on/presentation/screens/match/log_match_screen.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockLeaguePlayerRepository extends Mock
    implements LeaguePlayerRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

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
    state = await AsyncValue.guard(() async => [..._users, user]);
  }

  @override
  Future<void> updateUser(User user) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final updated = _users.map((u) => u.id == user.id ? user : u).toList();
      return updated;
    });
  }
}

class FakeUserDetailNotifier extends UserDetailNotifier {
  FakeUserDetailNotifier(super.userId,
      {FutureOr<List<UserLeagueInfo>> Function()? onBuild})
      : _onBuild = onBuild;
  final FutureOr<List<UserLeagueInfo>> Function()? _onBuild;
  int invalidateCount = 0;

  @override
  Future<List<UserLeagueInfo>> build() async {
    if (_onBuild != null) return await _onBuild();
    return [];
  }

  @override
  Future<void> refresh() async {
    invalidateCount++;
    await super.refresh();
  }
}

void main() {
  late MockLeagueRepository mockLeagueRepo;
  late MockLeaguePlayerRepository mockPlayerRepo;
  late MockUserRepository mockUserRepo;
  late MockSimpleMatchRepository mockMatchRepo;
  late MockRankingPolicyRepository mockPolicyRepo;
  late MockDeleteUserService mockDeleteService;
  late MockUpdateUserService mockUpdateService;
  late ProviderContainer container;

  const tUserId = 'u1';
  const tLeagueId = 'l1';
  const tPlayerId = 'p1';

  final tUser = User(
    id: tUserId,
    name: 'Test User',
    avatarColorHex: 'FF0000',
    icon: '🎮',
  );

  final tLeague = League(
    id: tLeagueId,
    name: 'Test League',
    createdAt: DateTime.now(),
  );

  final tPlayer = LeaguePlayer(
    id: tPlayerId,
    userId: tUserId,
    leagueId: tLeagueId,
    name: 'Player 1',
    avatarColorHex: 'FF0000',
    icon: '👤',
  );

  final tPlayer2 = LeaguePlayer(
    id: 'p2',
    userId: 'u2',
    leagueId: tLeagueId,
    name: 'Player 2',
    avatarColorHex: '00FF00',
    icon: '🎮',
  );

  setUpAll(() {
    registerFallbackValue(SimpleMatch(
        id: '',
        leagueId: '',
        playedAt: DateTime.now(),
        isComplete: false,
        sides: []));
    registerFallbackValue(Side(id: '', playerIds: []));
    registerFallbackValue(
        User(id: '', name: '', avatarColorHex: '', icon: null));
    registerFallbackValue(LeaguePlayer(
        id: '', userId: '', leagueId: '', name: '', avatarColorHex: ''));
  });

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    mockPlayerRepo = MockLeaguePlayerRepository();
    mockUserRepo = MockUserRepository();
    mockMatchRepo = MockSimpleMatchRepository();
    mockPolicyRepo = MockRankingPolicyRepository();
    mockDeleteService = MockDeleteUserService();
    mockUpdateService = MockUpdateUserService();

    container = ProviderContainer(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
        deleteUserServiceProvider.overrideWithValue(mockDeleteService),
        updateUserServiceProvider.overrideWithValue(mockUpdateService),
      ],
    );

    when(() => mockUserRepo.getAll()).thenAnswer((_) async => [tUser]);
    when(() => mockLeagueRepo.get(tLeagueId)).thenAnswer((_) async => tLeague);
    when(() => mockPlayerRepo.getByUserId(tUserId))
        .thenAnswer((_) async => [tPlayer]);
    when(() => mockPlayerRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => [tPlayer, tPlayer2]);
    when(() => mockMatchRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => []);
    when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
        .thenAnswer((_) async => null);
    when(() => mockDeleteService.execute(any()))
        .thenAnswer((_) async => DeleteUserResult(affectedLeagueIds: {}));
    when(() => mockUpdateService.execute(any())).thenAnswer((_) async => {});
  });

  tearDown(() {
    container.dispose();
  });

  Widget createWidgetWithValue(
    AsyncValue<List<UserLeagueInfo>> value, {
    List<User>? users,
    List<dynamic> extraOverrides = const [],
  }) {
    final usersList = users ?? [tUser];
    final fakeUsersNotifier = FakeUsersNotifier(usersList);
    final fakeUserDetailNotifier = FakeUserDetailNotifier(
      tUserId,
      onBuild: () async {
        if (value is AsyncData) return value.value!;
        if (value is AsyncError) throw value.error!;
        return Completer<List<UserLeagueInfo>>().future;
      },
    );

    return ProviderScope(
      retry: (_, __) => null,
      overrides: [
        usersProvider.overrideWith(() => fakeUsersNotifier),
        userDetailProvider.overrideWith2((arg) => fakeUserDetailNotifier),
        ...extraOverrides,
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserDetailScreen(userId: tUserId),
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

  Future<void> openScreen(
    WidgetTester tester,
    AsyncValue<List<UserLeagueInfo>> value, {
    List<User>? users,
    List<dynamic> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(createWidgetWithValue(value,
        users: users, extraOverrides: extraOverrides));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('UserDetailScreen', () {
    testWidgets('should show loading indicator when loading', (tester) async {
      await openScreen(tester, const AsyncValue.loading());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error message on error', (tester) async {
      await openScreen(
          tester, const AsyncValue.error('Error occurred', StackTrace.empty));
      await tester.pump();
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('should show empty state when no leagues', (tester) async {
      await openScreen(tester, const AsyncValue.data([]));
      await tester.pump();

      expect(find.text('This user has not joined any leagues yet.'),
          findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });

    testWidgets('should show league participant with matches when populated',
        (tester) async {
      final match = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: [tPlayerId]),
          Side(id: 's2', playerIds: ['p2']),
        ],
        winnerSideId: 's1',
      );

      final leagueInfo = UserLeagueInfo(
        league: tLeague,
        player: tPlayer,
        matches: [match],
      );

      await openScreen(tester, AsyncValue.data([leagueInfo]));
      await tester.pump();

      // Expand the league tile to see matches
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('Test League'), findsOneWidget);
      expect(find.text('Nickname: Player 1'), findsOneWidget);
      expect(find.text('Won'), findsOneWidget); // tPlayer is winner
    });

    testWidgets('should show "No matches recorded in this league" when empty',
        (tester) async {
      final leagueInfo = UserLeagueInfo(
        league: tLeague,
        player: tPlayer,
        matches: [],
      );

      await openScreen(tester, AsyncValue.data([leagueInfo]));
      await tester.pump();

      // Tap to expand the league tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('No matches recorded in this league.'), findsOneWidget);
    });

    testWidgets(
        'should show correct result for ghost players (player not in match)',
        (tester) async {
      final ghostMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['ghost-winner']),
          Side(id: 's2', playerIds: ['ghost-loser']),
        ],
        winnerSideId: 's1',
      );

      final leagueInfo = UserLeagueInfo(
        league: tLeague,
        player: tPlayer,
        matches: [ghostMatch],
      );

      await openScreen(tester, AsyncValue.data([leagueInfo]));
      await tester.pump();

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // tPlayer 'p1' is not in either side, so winnerSide playerIds don't contain tPlayer
      // The code treats this as a loss since isWinner = false
      expect(find.text('Lost'), findsOneWidget);
    });

    testWidgets('should open edit user dialog from app bar', (tester) async {
      when(() => mockUpdateService.execute(any())).thenAnswer((_) async => {});

      // Use container with real notifiers and mocked services
      final fakeUserDetailNotifier = FakeUserDetailNotifier(
        tUserId,
        onBuild: () async => [],
      );

      final widget = ProviderScope(
        overrides: [
          usersProvider.overrideWith(() => UsersNotifier()),
          userDetailProvider.overrideWith2((_) => fakeUserDetailNotifier),
          userRepositoryProvider.overrideWithValue(mockUserRepo),
          updateUserServiceProvider.overrideWithValue(mockUpdateService),
          leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
          deleteUserServiceProvider.overrideWithValue(mockDeleteService),
          rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
          simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserDetailScreen(userId: tUserId),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap edit icon in app bar
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit User'), findsOneWidget);
      // TextField contains the user name - verify via TextField's controller
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Test User');

      // Update name
      await tester.enterText(find.byType(TextField), 'Updated');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      verify(() => mockUpdateService.execute(
              any(that: isA<User>().having((u) => u.name, 'name', 'Updated'))))
          .called(1);
    });

    testWidgets('should open participant edit dialog and update player',
        (tester) async {
      final fakeUserDetailNotifier = FakeUserDetailNotifier(
        tUserId,
        onBuild: () async => [
          UserLeagueInfo(
            league: tLeague,
            player: tPlayer,
            matches: [],
          ),
        ],
      );

      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.get(tPlayerId))
          .thenAnswer((_) async => tPlayer);
      when(() => mockPlayerRepo.getByLeague(tLeagueId)).thenAnswer(
          (_) async => [tPlayer.copyWith(name: 'New Nickname', icon: '🎮')]);

      // Create widget with custom userDetailNotifier to avoid duplicate override
      final widget = ProviderScope(
        overrides: [
          usersProvider.overrideWith(() => FakeUsersNotifier([tUser])),
          userDetailProvider.overrideWith2((_) => fakeUserDetailNotifier),
          leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
          leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
          userRepositoryProvider.overrideWithValue(mockUserRepo),
          simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
          rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserDetailScreen(userId: tUserId),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap to expand
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Tap edit icon
      await tester.tap(find.byIcon(Icons.edit_note));
      await tester.pumpAndSettle();

      expect(find.text('Edit League Participant'), findsOneWidget);

      // Update nickname
      await tester.enterText(find.byType(TextField), 'New Nickname');
      await tester.tap(find.text('🎮'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Verify player was updated via repository
      verify(() => mockPlayerRepo.put(any(
          that: isA<LeaguePlayer>()
              .having((p) => p.name, 'name', 'New Nickname')))).called(1);
    });

    testWidgets('should navigate to LogMatchScreen when tapping a match',
        (tester) async {
      final match = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: [tPlayerId]),
          Side(id: 's2', playerIds: ['p2']),
        ],
        winnerSideId: 's1',
      );

      final leagueInfo = UserLeagueInfo(
        league: tLeague,
        player: tPlayer,
        matches: [match],
      );

      await openScreen(tester, AsyncValue.data([leagueInfo]));
      await tester.pump();

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Tap the match list tile - use specific finder for the match result
      await tester.tap(find.widgetWithText(ListTile, 'Won'));
      await tester.pumpAndSettle();

      expect(find.byType(LogMatchScreen), findsOneWidget);
      expect(find.text('Edit Match'), findsOneWidget);
    });

    testWidgets('should display correct result for draw match', (tester) async {
      final drawMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: true,
        sides: [
          Side(id: 's1', playerIds: [tPlayerId]),
          Side(id: 's2', playerIds: ['p2']),
        ],
      );

      final leagueInfo = UserLeagueInfo(
        league: tLeague,
        player: tPlayer,
        matches: [drawMatch],
      );

      await openScreen(tester, AsyncValue.data([leagueInfo]));
      await tester.pump();

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('Draw'), findsOneWidget);
    });

    testWidgets('should display correct result for lost match', (tester) async {
      final lostMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p2']),
          Side(id: 's2', playerIds: [tPlayerId]),
        ],
        winnerSideId: 's1',
      );

      final leagueInfo = UserLeagueInfo(
        league: tLeague,
        player: tPlayer,
        matches: [lostMatch],
      );

      await openScreen(tester, AsyncValue.data([leagueInfo]));
      await tester.pump();

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('Lost'), findsOneWidget);
    });

    testWidgets('should display multiple leagues correctly', (tester) async {
      final league2 = League(
        id: 'l2',
        name: 'Second League',
        createdAt: DateTime.now(),
      );
      final player2 = LeaguePlayer(
        id: 'p3',
        userId: tUserId,
        leagueId: 'l2',
        name: 'Player 3',
        avatarColorHex: '0000FF',
        icon: '🏀',
      );

      final leagueInfo1 = UserLeagueInfo(
        league: tLeague,
        player: tPlayer,
        matches: [],
      );
      final leagueInfo2 = UserLeagueInfo(
        league: league2,
        player: player2,
        matches: [],
      );

      await openScreen(tester, AsyncValue.data([leagueInfo1, leagueInfo2]));
      await tester.pump();

      expect(find.text('Test League'), findsOneWidget);
      expect(find.text('Second League'), findsOneWidget);
      expect(find.text('Nickname: Player 1'), findsOneWidget);
      expect(find.text('Nickname: Player 3'), findsOneWidget);
    });

    testWidgets('should handle user not found in usersProvider gracefully',
        (tester) async {
      await openScreen(
        tester,
        const AsyncValue.data([]),
        users: [], // Empty users list
      );
      await tester.pump();

      // Should show error title in app bar
      expect(find.text('User Detail'), findsOneWidget);
    });
  });
}
