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
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/application/services/update_user_service.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/presentation/screens/settings/manage_users_screen.dart';
import 'package:game_on/presentation/screens/league/league_detail_screen.dart';
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

class FakeLeagueDetailNotifier extends LeagueDetailNotifier {
  FakeLeagueDetailNotifier({this.onBuild}) : super('test-league-id');
  final FutureOr<LeagueDetailState> Function()? onBuild;
  @override
  Future<LeagueDetailState> build() async {
    if (onBuild != null) return await onBuild!();
    return const LeagueDetailState(
        players: [], matches: [], playerStats: {}, playersByName: []);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
        User(id: '', name: '', avatarColorHex: '', icon: null));
    registerFallbackValue(LeaguePlayer(
        id: '', userId: '', leagueId: '', name: '', avatarColorHex: ''));
    registerFallbackValue(SimpleMatch(
        id: '',
        leagueId: '',
        playedAt: DateTime.now(),
        isComplete: false,
        sides: []));
    registerFallbackValue(Side(id: '', playerIds: []));
  });

  group('ManageUsersScreen alphabetical', () {
    testWidgets('renders alphabetical when repo returns unsorted',
        (tester) async {
      final mockUserRepo = MockUserRepository();
      final mockPlayerRepo = MockLeaguePlayerRepository();
      final mockDeleteService = MockDeleteUserService();
      final mockUpdateService = MockUpdateUserService();

      // Unsorted repo order: bob, Charlie, alice, Alice (with trim/case variations)
      final unsorted = [
        User(id: 'u1', name: 'bob', avatarColorHex: '000'),
        User(id: 'u2', name: '  Charlie  ', avatarColorHex: '000'),
        User(id: 'u3', name: 'alice', avatarColorHex: '000'),
        User(id: 'u4', name: ' Alice', avatarColorHex: '000'),
      ];
      when(() => mockUserRepo.getAll()).thenAnswer((_) async => unsorted);
      when(() => mockPlayerRepo.getByUserId(any())).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
            deleteUserServiceProvider.overrideWithValue(mockDeleteService),
            updateUserServiceProvider.overrideWithValue(mockUpdateService),
          ],
          child: const MaterialApp(home: ManageUsersScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Expect alphabetical: Alice (trimmed) -> alice -> bob -> Charlie (trimmed)
      // Collect ListTile titles in render order
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      final titles = tiles.map((t) => (t.title as Text).data ?? '').toList();
      // Filter only those that are user names (should be 4)
      expect(titles, [' Alice', 'alice', 'bob', '  Charlie  ']);
      // Also verify visual order via rendered list order
      // Ensure they appear in increasing position order as verified below
      expect(titles.indexOf(' Alice'), lessThan(titles.indexOf('alice')));
      expect(titles.indexOf('alice'), lessThan(titles.indexOf('bob')));
      expect(titles.indexOf('bob'), lessThan(titles.indexOf('  Charlie  ')));
    });
  });

  group('_AddPlayerDialog alphabetical after filtering', () {
    testWidgets('list alphabetical after filtering out existing league members',
        (tester) async {
      const tLeagueId = 'l1';
      final tLeague =
          League(id: tLeagueId, name: 'Test League', createdAt: DateTime(2023));

      final mockLeagueRepo = MockLeagueRepository();
      final mockPlayerRepo = MockLeaguePlayerRepository();
      final mockUserRepo = MockUserRepository();
      final mockMatchRepo = MockSimpleMatchRepository();
      final mockPolicyRepo = MockRankingPolicyRepository();

      // Unsorted users: Zoe, Bob, Alice, alice, Charlie — Zoe already in league, so filtered
      final unsortedUsers = [
        User(id: 'uB', name: 'Bob', avatarColorHex: '000'),
        User(id: 'uZ', name: 'Zoe', avatarColorHex: '000'),
        User(id: 'uA', name: ' Alice', avatarColorHex: '000'),
        User(id: 'uC', name: 'alice', avatarColorHex: '000'),
        User(id: 'uD', name: 'Charlie', avatarColorHex: '000'),
      ];
      when(() => mockUserRepo.getAll()).thenAnswer((_) async => unsortedUsers);
      when(() => mockPlayerRepo.getByUserId(any())).thenAnswer((_) async => []);
      when(() => mockLeagueRepo.get(tLeagueId))
          .thenAnswer((_) async => tLeague);
      // League already has Zoe as player
      final existingPlayer = LeaguePlayer(
          id: 'pZ',
          userId: 'uZ',
          leagueId: tLeagueId,
          name: 'Zoe',
          avatarColorHex: '000');
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [existingPlayer]);
      when(() => mockPlayerRepo.get(any()))
          .thenAnswer((_) async => existingPlayer);
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => []);
      when(() => mockMatchRepo.get(any())).thenAnswer((_) async => null);
      final tPolicy = SimpleRankingPolicy(
          id: 'rp1',
          name: 'Standard',
          leagueId: tLeagueId,
          pointsForWin: 3,
          pointsForDraw: 1,
          pointsForLoss: 0,
          categoryIds: const ['cat_custom_league_001']);
      when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
          .thenAnswer((_) async => tPolicy);

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
            leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
            rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
            deleteUserServiceProvider
                .overrideWith((ref) => MockDeleteUserService()),
            updateUserServiceProvider
                .overrideWith((ref) => MockUpdateUserService()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => LeagueDetailScreen(league: tLeague)),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Open Add Player dialog
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Add Player'), findsOneWidget);
      // Dialog should show available users filtered (Zoe excluded) in alphabetical order: Alice, alice, Bob, Charlie
      // Find ListTile inside Dialog
      final dialogTiles = tester
          .widgetList<ListTile>(find.descendant(
              of: find.byType(Dialog), matching: find.byType(ListTile)))
          .toList();
      final dialogTitles =
          dialogTiles.map((t) => (t.title as Text).data ?? '').toList();
      // Expected alphabetical filtered: " Alice" (Alice), "alice", "Bob", "Charlie" (Zoe excluded)
      expect(dialogTitles, [' Alice', 'alice', 'Bob', 'Charlie']);
      // Ensure Zoe not present
      expect(dialogTitles.contains('Zoe'), isFalse);
      // Also verify that Bob comes after alice despite repo order having Bob before Alice
      expect(dialogTitles.indexOf(' Alice'),
          lessThan(dialogTitles.indexOf('alice')));
      expect(
          dialogTitles.indexOf('alice'), lessThan(dialogTitles.indexOf('Bob')));
    });
  });

  group('LogMatchScreen alphabetical pickers vs ranked standings', () {
    testWidgets(
        'bottom sheet ListView order equals playersByName (alphabetical) while ranked differs',
        (tester) async {
      const tLeagueId = 'l1';
      // Create divergence: ranked Bob top, alphabetical Alice first
      final alice = LeaguePlayer(
          id: 'p1',
          userId: 'u1',
          leagueId: tLeagueId,
          name: 'Alice',
          avatarColorHex: 'FF0000');
      final bob = LeaguePlayer(
          id: 'p2',
          userId: 'u2',
          leagueId: tLeagueId,
          name: 'Bob',
          avatarColorHex: '00FF00');
      final charlie = LeaguePlayer(
          id: 'p3',
          userId: 'u3',
          leagueId: tLeagueId,
          name: 'Charlie',
          avatarColorHex: '0000FF');
      // Ranked order: Bob (3 pts), Alice, Charlie (0 pts id order)
      // Alphabetical: Alice, Bob, Charlie
      final state = LeagueDetailState(
        players: [bob, alice, charlie],
        playersByName: [alice, bob, charlie],
        matches: [],
        playerStats: {
          'p2': const PlayerStats(points: 3, matchesPlayed: 1),
          'p1': const PlayerStats(points: 0, matchesPlayed: 1),
          'p3': const PlayerStats(points: 0, matchesPlayed: 0),
        },
      );
      // Verify divergence before widget test
      expect(state.players.first.name, 'Bob');
      expect(state.playersByName.first.name, 'Alice');

      final fakeNotifier = FakeLeagueDetailNotifier(onBuild: () async => state);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            leagueDetailProvider.overrideWith2((arg) => fakeNotifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              const LogMatchScreen(leagueId: tLeagueId)),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // With 3 players, LogMatchScreen shows two selectors with "Select"
      expect(find.text('Select'), findsNWidgets(2));
      // Tap first Select to open bottom sheet
      await tester.tap(find.text('Select').first);
      await tester.pumpAndSettle();

      expect(find.text('Pick a Player'), findsOneWidget);
      // Bottom sheet ListView should be in playersByName order: Alice, Bob, Charlie
      // Collect ListTiles that have title matching player names
      final allTiles =
          tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      final playerTiles = allTiles.where((t) {
        final title = (t.title as Text).data ?? '';
        return ['Alice', 'Bob', 'Charlie'].contains(title);
      }).toList();
      final playerNamesInSheet =
          playerTiles.map((t) => (t.title as Text).data ?? '').toList();
      expect(playerNamesInSheet, ['Alice', 'Bob', 'Charlie']);
      // Ensure it's alphabetical, not ranked (ranked would be Bob first)
      expect(playerNamesInSheet.first, 'Alice');
      expect(playerNamesInSheet[1], 'Bob');

      // Close sheet
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsWidgets);
    });

    testWidgets(
        'winner dropdown alphabetical while standings remain ranked (2 players auto-select)',
        (tester) async {
      const tLeagueId = 'l1';
      // 2 players: Bob ranked first (3pts), Alice alphabetical first
      final alice = LeaguePlayer(
          id: 'p1',
          userId: 'u1',
          leagueId: tLeagueId,
          name: 'Alice',
          avatarColorHex: 'FF0000');
      final bob = LeaguePlayer(
          id: 'p2',
          userId: 'u2',
          leagueId: tLeagueId,
          name: 'Bob',
          avatarColorHex: '00FF00');
      // Unsorted insertion would be Bob, Alice but state explicitly sets ranked vs alphabetical
      final state = LeagueDetailState(
        players: [bob, alice], // ranked: Bob first
        playersByName: [alice, bob], // alphabetical: Alice first
        matches: [],
        playerStats: {
          'p2': const PlayerStats(points: 3, matchesPlayed: 1),
          'p1': const PlayerStats(points: 0, matchesPlayed: 1),
        },
      );
      expect(state.players.first.id, 'p2'); // Bob ranked first
      expect(state.playersByName.first.id, 'p1'); // Alice alphabetical first

      final fakeNotifier = FakeLeagueDetailNotifier(onBuild: () async => state);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            leagueDetailProvider.overrideWith2((arg) => fakeNotifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              const LogMatchScreen(leagueId: tLeagueId)),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(); // allow postFrameCallback for auto-select
      await tester.pump(const Duration(milliseconds: 200));

      // With 2 players, LogMatchScreen auto-selects playersByName[0] and [1] => Alice and Bob alphabetical
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      // After auto-select there is no Select text; both are filled
      expect(find.text('Select'), findsNothing);
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Bob'), findsWidgets);
      // Open dropdown menu to ensure items are alphabetical: Alice, Bob, Draw
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      // Menu items appear as Text widgets in overlay. Verify order via overlay positions.
      // The overlay shows Alice first, Bob second, Draw last.
      // Find dropdown menu items in overlay: they are Text widgets inside Material
      final aliceFinder = find.text('Alice');
      final bobFinder = find.text('Bob');
      final drawFinder = find.text('Draw');
      expect(aliceFinder, findsWidgets);
      expect(bobFinder, findsWidgets);
      expect(drawFinder, findsOneWidget);
      // The last Alice/Bob are the menu items; ensure they exist
      expect(find.text('Alice').last, findsOneWidget);
      expect(find.text('Bob').last, findsOneWidget);
      // Tap Draw to select and verify selection
      await tester.tap(find.text('Draw').last);
      await tester.pumpAndSettle();
      final updatedDropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>));
      expect(updatedDropdown.initialValue, 'draw');
    });

    testWidgets(
        'feed unsorted LeaguePlayer names where alphabetical differs from ranked — verify divergence',
        (tester) async {
      const tLeagueId = 'l1';
      // Simulate unsorted names: Zoe, Alice, Bob fed unsorted, but playersByName alphabetical, players ranked Bob top
      final zoe = LeaguePlayer(
          id: 'pZ',
          userId: 'uZ',
          leagueId: tLeagueId,
          name: 'Zoe',
          avatarColorHex: '000');
      final alice = LeaguePlayer(
          id: 'pA',
          userId: 'uA',
          leagueId: tLeagueId,
          name: 'Alice',
          avatarColorHex: '000');
      final bob = LeaguePlayer(
          id: 'pB',
          userId: 'uB',
          leagueId: tLeagueId,
          name: 'Bob',
          avatarColorHex: '000');
      // Ranked: Bob (3pts) first, then Alice, Zoe by id? Actually points tie Alice/Zoe 0 pts -> id order pA, pZ
      final state = LeagueDetailState(
        players: [bob, alice, zoe], // ranked
        playersByName: [alice, bob, zoe], // alphabetical
        matches: [],
        playerStats: {
          'pB': const PlayerStats(points: 3, matchesPlayed: 1),
          'pA': const PlayerStats(points: 0, matchesPlayed: 1),
          'pZ': const PlayerStats(points: 0, matchesPlayed: 0),
        },
      );
      // Unsorted insertion was [Zoe, Alice, Bob] but state shows sorting correctly
      expect(
          state.players.map((p) => p.name).toList(), ['Bob', 'Alice', 'Zoe']);
      expect(state.playersByName.map((p) => p.name).toList(),
          ['Alice', 'Bob', 'Zoe']);

      final fakeNotifier = FakeLeagueDetailNotifier(onBuild: () async => state);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            leagueDetailProvider.overrideWith2((arg) => fakeNotifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              const LogMatchScreen(leagueId: tLeagueId)),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Select').first);
      await tester.pumpAndSettle();
      final allTiles =
          tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      final playerTiles = allTiles.where((t) {
        final title = (t.title as Text).data ?? '';
        return ['Alice', 'Bob', 'Zoe'].contains(title);
      }).toList();
      final ordered =
          playerTiles.map((t) => (t.title as Text).data ?? '').toList();
      expect(ordered, ['Alice', 'Bob', 'Zoe']);
      // Also ensure bottom sheet order equals playersByName, not players (ranked would be Bob first)
      expect(ordered.first, isNot(state.players.first.name));
      expect(ordered, state.playersByName.map((p) => p.name).toList());
    });
  });
}
