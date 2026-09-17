import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/user_detail_provider.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/presentation/screens/league/widgets/player_edit_dialog.dart';
import 'package:game_on/presentation/theme/app_theme.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockLeaguePlayerRepository extends Mock
    implements LeaguePlayerRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

class FakeLeagueDetailNotifier extends LeagueDetailNotifier {
  FakeLeagueDetailNotifier({required String leagueId, this.onBuild})
      : super(leagueId);
  final FutureOr<LeagueDetailState> Function()? onBuild;
  final List<Map<String, dynamic>> updatePlayerCalls = [];
  final List<String> removePlayerCalls = [];

  @override
  Future<LeagueDetailState> build() async {
    if (onBuild != null) return await onBuild!();
    return const LeagueDetailState(players: [], matches: [], playerStats: {});
  }

  @override
  Future<void> updatePlayer({
    required String playerId,
    required String name,
    String? icon,
  }) async {
    updatePlayerCalls.add({'playerId': playerId, 'name': name, 'icon': icon});
    final repo = ref.read(leaguePlayerRepositoryProvider);
    final player = await repo.get(playerId);
    if (player == null) throw Exception('Player not found');
    final updatedPlayer = player.copyWith(name: name, icon: icon);
    await repo.put(updatedPlayer);
    if (onBuild != null) {
      state = AsyncValue.data(await onBuild!());
    }
  }

  @override
  Future<void> removePlayer(String playerId) async {
    removePlayerCalls.add(playerId);
    final repo = ref.read(leaguePlayerRepositoryProvider);
    await repo.delete(playerId);
    if (onBuild != null) {
      state = AsyncValue.data(await onBuild!());
    }
  }
}

class FakeUsersNotifier extends UsersNotifier {
  FakeUsersNotifier(this.users, {this.isLoading = false, this.error});
  final List<User> users;
  final bool isLoading;
  final Object? error;
  @override
  Future<List<User>> build() async {
    if (error != null) {
      // Avoid Riverpod retry (which keeps provider in AsyncLoading with
      // 'retrying') by emitting an initial empty data then transitioning
      // to error on next event loop. Requires an extra pump in error tests.
      Future.delayed(const Duration(milliseconds: 10),
          () => state = AsyncValue.error(error!, StackTrace.current));
      return [];
    }
    if (isLoading) return Completer<List<User>>().future;
    return users;
  }
}

class FakeUserDetailNotifier extends UserDetailNotifier {
  FakeUserDetailNotifier(super.userId);
  int invalidateCount = 0;

  @override
  Future<List<UserLeagueInfo>> build() async => [];

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
  late ProviderContainer container;

  const tLeagueId = 'l1';
  const tPlayerId = 'p1';
  const tUserId = 'u1';

  final tPlayer = LeaguePlayer(
    id: tPlayerId,
    userId: tUserId,
    leagueId: tLeagueId,
    name: 'Test Player',
    avatarColorHex: 'FF0000',
    icon: '👤',
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

    container = ProviderContainer(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
      ],
    );

    when(() => mockLeagueRepo.get(tLeagueId)).thenAnswer((_) async => League(
          id: tLeagueId,
          name: 'Test League',
          createdAt: DateTime.now(),
        ));
    when(() => mockPlayerRepo.get(tPlayerId)).thenAnswer((_) async => tPlayer);
    when(() => mockPlayerRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => [tPlayer]);
    when(() => mockMatchRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => []);
    when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
        .thenAnswer((_) async => null);
    when(() => mockUserRepo.getAll()).thenAnswer((_) async => [
          User(
              id: tUserId,
              name: 'Linked User Name',
              avatarColorHex: 'AE0C00',
              icon: '🎮'),
        ]);
    when(() => mockPlayerRepo.delete(any())).thenAnswer((_) async => {});
  });

  tearDown(() {
    container.dispose();
  });

  Widget createDialogWidget({
    required FakeLeagueDetailNotifier fakeLeagueNotifier,
    required FakeUserDetailNotifier fakeUserDetailNotifier,
    bool showRemoveAction = false,
    List<User>? users,
    bool usersLoading = false,
    Object? usersError,
  }) {
    final effectiveUsers = users ??
        [
          User(
              id: tUserId,
              name: 'Linked User Name',
              avatarColorHex: 'AE0C00',
              icon: '🐯'),
        ];
    return ProviderScope(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
        leagueDetailProvider.overrideWith2((arg) => fakeLeagueNotifier),
        userDetailProvider.overrideWith2((arg) => fakeUserDetailNotifier),
        usersProvider.overrideWith(() => FakeUsersNotifier(effectiveUsers,
            isLoading: usersLoading, error: usersError)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => PlayerEditDialog.show(
                  context,
                  leagueId: tLeagueId,
                  player: tPlayer,
                  showRemoveAction: showRemoveAction,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
  }

  group('PlayerEditDialog', () {
    late FakeLeagueDetailNotifier fakeLeagueNotifier;
    late FakeUserDetailNotifier fakeUserDetailNotifier;

    setUp(() {
      fakeLeagueNotifier = FakeLeagueDetailNotifier(
        leagueId: tLeagueId,
        onBuild: () async => LeagueDetailState(
          players: [tPlayer],
          matches: [],
          playerStats: {
            tPlayerId: const PlayerStats(points: 0, matchesPlayed: 0)
          },
        ),
      );
      fakeUserDetailNotifier = FakeUserDetailNotifier(tUserId);
    });

    testWidgets(
        'should show edit dialog with player data pre-filled and bracket title',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      // Title bracket for linked user — prefix + suffix are separate Texts (Row + Flexible)
      expect(find.text('Edit Player'), findsOneWidget);
      expect(find.text(' (Linked User Name)'), findsOneWidget);
      expect(find.text('Nickname'), findsOneWidget);
      expect(find.text('Changes only affect this league.'), findsOneWidget);
      // TextField pre-filled
      expect(
          find.widgetWithText(TextField, 'Test Player').evaluate().isNotEmpty ||
              find.text('Test Player').evaluate().isNotEmpty,
          isTrue);
      // No LinkedUserHeader card — only bracket title
      expect(find.text('Linked User'), findsNothing);
    });

    testWidgets('shows bracket title with truncated name for long user name',
        (WidgetTester tester) async {
      const longName = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_extra_long';
      // 22 chars = ABCDEFGHIJKLMNOPQRSTUV + …
      const expectedTruncated = 'ABCDEFGHIJKLMNOPQRSTUV…';
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(
                  id: tUserId,
                  name: longName,
                  avatarColorHex: 'AE0C00',
                  icon: '🎮'),
            ],
          ));

      expect(find.text(' ($expectedTruncated)'), findsOneWidget);
      // Prefix never truncates — Edit Player always visible
      expect(find.text('Edit Player'), findsOneWidget);
      // Full long name should not appear
      expect(find.textContaining(longName), findsNothing);
    });

    testWidgets('should update player name and icon successfully',
        (WidgetTester tester) async {
      when(() => mockPlayerRepo.get(tPlayerId))
          .thenAnswer((_) async => tPlayer);
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId)).thenAnswer(
          (_) async => [tPlayer.copyWith(name: 'Updated Name', icon: '🎮')]);

      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.enterText(find.byType(TextField), 'Updated Name');
      await tester.tap(find.text('🎮'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(fakeLeagueNotifier.updatePlayerCalls, hasLength(1));
      expect(fakeLeagueNotifier.updatePlayerCalls.first['playerId'], tPlayerId);
      expect(
          fakeLeagueNotifier.updatePlayerCalls.first['name'], 'Updated Name');
      expect(fakeLeagueNotifier.updatePlayerCalls.first['icon'], '🎮');
    });

    testWidgets('should not submit when nickname is empty',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(fakeLeagueNotifier.updatePlayerCalls, isEmpty);
      expect(fakeUserDetailNotifier.invalidateCount, 0);
    });

    testWidgets('should show error snackbar when repository fails',
        (WidgetTester tester) async {
      when(() => mockPlayerRepo.get(tPlayerId))
          .thenAnswer((_) async => tPlayer);
      when(() => mockPlayerRepo.put(any()))
          .thenThrow(Exception('Repository error'));

      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.enterText(find.byType(TextField), 'Updated Name');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should select custom icon', (WidgetTester tester) async {
      when(() => mockPlayerRepo.get(tPlayerId))
          .thenAnswer((_) async => tPlayer);
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId)).thenAnswer(
          (_) async => [tPlayer.copyWith(name: 'Test Player', icon: '⚽')]);

      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.tap(find.text('⚽'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(fakeLeagueNotifier.updatePlayerCalls, hasLength(1));
      expect(fakeLeagueNotifier.updatePlayerCalls.first['icon'], '⚽');
    });

    testWidgets('should cancel and not call updatePlayer',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(fakeLeagueNotifier.updatePlayerCalls, isEmpty);
      expect(fakeUserDetailNotifier.invalidateCount, 0);
    });

    testWidgets('should show Remove button when showRemoveAction true',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            showRemoveAction: true,
          ));

      expect(find.text('Remove from League'), findsOneWidget);
    });

    testWidgets('should hide Remove button when showRemoveAction false',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            showRemoveAction: false,
          ));

      expect(find.text('Remove from League'), findsNothing);
    });

    testWidgets(
        'should show Unknown user in bracket title when linked user not found',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [],
          ));

      expect(find.text(' (Unknown user)'), findsOneWidget);
      expect(find.text('Edit Player'), findsOneWidget);
      // Should be italic textTertiary style — verify no LinkedUserHeader
      expect(find.byIcon(Icons.person_off), findsNothing);
      // Style: italic + textTertiary for orphan
      final suffixText = tester.widget<Text>(find.text(' (Unknown user)'));
      expect(suffixText.style?.fontStyle, FontStyle.italic);
      expect(suffixText.style?.color, AppTheme.textTertiary);
      expect(suffixText.overflow, TextOverflow.ellipsis);
      // Semantics header + ExcludeSemantics invariants also hold for orphan
      final headerSemantics = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.header == true);
      expect(headerSemantics, findsOneWidget);
      expect(
          find.descendant(
              of: headerSemantics, matching: find.byType(ExcludeSemantics)),
          findsOneWidget);
    });

    testWidgets(
        'loading state shows plain Edit Player without brackets or spinner',
        (WidgetTester tester) async {
      final widget = createDialogWidget(
        fakeLeagueNotifier: fakeLeagueNotifier,
        fakeUserDetailNotifier: fakeUserDetailNotifier,
        usersLoading: true,
      );
      await tester.pumpWidget(widget);
      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Title is plain Edit Player, no brackets
      expect(find.text('Edit Player'), findsOneWidget);
      expect(find.textContaining('('), findsNothing);
      expect(find.textContaining('Unknown user'), findsNothing);
      // No spinner for linked user loading
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Semantics still announces loading
      expect(find.bySemanticsLabel('Edit Player, loading linked user'),
          findsOneWidget);
    });

    testWidgets(
        'shows Unknown user in bracket when usersProvider errors (orphan fallback)',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            usersError: Exception('failed to load users'),
          ));
      // Allow error Future.delayed to transition from initial empty data to AsyncError
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      expect(find.text(' (Unknown user)'), findsOneWidget);
      expect(find.text('Edit Player'), findsOneWidget);
      expect(find.byIcon(Icons.person_off), findsNothing);
      // style italic + textTertiary for error/unknown state
      final suffixText = tester.widget<Text>(find.text(' (Unknown user)'));
      expect(suffixText.style?.fontStyle, FontStyle.italic);
      expect(suffixText.style?.color, AppTheme.textTertiary);
      expect(suffixText.overflow, TextOverflow.ellipsis);
      // bracket title is Row with separate prefix, so plain Edit Player text still exists as first child
      // Error semantics
      expect(
          find.bySemanticsLabel(
              'Edit Player, Unknown user — failed to load linked user'),
          findsOneWidget);
      // ExcludeSemantics + header invariants
      final headerSemantics = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.header == true);
      expect(headerSemantics, findsOneWidget);
      expect(
          find.descendant(
              of: headerSemantics, matching: find.byType(ExcludeSemantics)),
          findsOneWidget);
    });

    testWidgets('bracket title semantics for linked user',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(
                  id: tUserId,
                  name: 'Alice',
                  avatarColorHex: 'AE0C00',
                  icon: '🎮'),
            ],
          ));

      expect(find.text(' (Alice)'), findsOneWidget);
      expect(find.text('Edit Player'), findsOneWidget);
      expect(find.bySemanticsLabel('Edit Player, linked to Alice'),
          findsOneWidget);
      // Known user suffix should NOT be italic
      final suffixText = tester.widget<Text>(find.text(' (Alice)'));
      expect(suffixText.style?.fontStyle, isNot(FontStyle.italic));
      expect(suffixText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('orphan semantics announces missing account',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [],
          ));

      expect(
          find.bySemanticsLabel(
              'Edit Player, Unknown user — linked account missing'),
          findsOneWidget);
    });

    testWidgets('long name truncation appears in semantic label',
        (WidgetTester tester) async {
      const longName = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_extra_long';
      const expectedTruncated = 'ABCDEFGHIJKLMNOPQRSTUV…';
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(
                  id: tUserId,
                  name: longName,
                  avatarColorHex: 'AE0C00',
                  icon: '🎮'),
            ],
          ));

      expect(find.bySemanticsLabel('Edit Player, linked to $expectedTruncated'),
          findsOneWidget);
    });

    testWidgets(
        'title prefix Edit Player never truncates, suffix is Flexible with ellipsis',
        (WidgetTester tester) async {
      const longName = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_extra_long';
      const expectedTruncated = 'ABCDEFGHIJKLMNOPQRSTUV…';
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(
                  id: tUserId,
                  name: longName,
                  avatarColorHex: 'AE0C00',
                  icon: '🎮'),
            ],
          ));

      // Locate the title Row via ancestor of suffix text
      final rowFinder = find.ancestor(
          of: find.text(' ($expectedTruncated)'), matching: find.byType(Row));
      expect(rowFinder, findsOneWidget);
      final rowWidget = tester.widget<Row>(rowFinder);
      expect(rowWidget.mainAxisSize, MainAxisSize.min);

      // Prefix Edit Player exists and is NOT inside Flexible
      expect(find.descendant(of: rowFinder, matching: find.text('Edit Player')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(Flexible), matching: find.text('Edit Player')),
          findsNothing);

      // Suffix is inside Flexible and has ellipsis
      expect(find.descendant(of: rowFinder, matching: find.byType(Flexible)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(Flexible),
              matching: find.text(' ($expectedTruncated)')),
          findsOneWidget);
      final suffixText =
          tester.widget<Text>(find.text(' ($expectedTruncated)'));
      expect(suffixText.overflow, TextOverflow.ellipsis);

      // Also verify overall Row/Flexible still exist for backward compat
      expect(find.byType(Flexible), findsWidgets);
    });

    testWidgets('uses Nickname label consistently',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      expect(find.text('Nickname'), findsOneWidget);
      expect(find.text('Player Name'), findsNothing);
      expect(find.text('Display Name'), findsNothing);
    });

    // --- Strengthened coverage: empty/trims/boundary/semantics/style ---

    testWidgets('shows Unknown user italic when user name is empty string',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(id: tUserId, name: '', avatarColorHex: 'AE0C00', icon: '🎮'),
            ],
          ));

      expect(find.text(' (Unknown user)'), findsOneWidget);
      expect(find.text('Edit Player'), findsOneWidget);
      final suffixText = tester.widget<Text>(find.text(' (Unknown user)'));
      expect(suffixText.style?.fontStyle, FontStyle.italic);
      expect(suffixText.style?.color, AppTheme.textTertiary);
      expect(suffixText.overflow, TextOverflow.ellipsis);
      expect(find.bySemanticsLabel('Edit Player, linked to Unknown user'),
          findsOneWidget);
    });

    testWidgets('shows Unknown user italic when user name is whitespace only',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(
                  id: tUserId,
                  name: '   ',
                  avatarColorHex: 'AE0C00',
                  icon: '🎮'),
            ],
          ));

      expect(find.text(' (Unknown user)'), findsOneWidget);
      final suffixText = tester.widget<Text>(find.text(' (Unknown user)'));
      expect(suffixText.style?.fontStyle, FontStyle.italic);
      expect(suffixText.style?.color, AppTheme.textTertiary);
      expect(suffixText.overflow, TextOverflow.ellipsis);
      expect(find.bySemanticsLabel('Edit Player, linked to Unknown user'),
          findsOneWidget);
    });

    testWidgets('trims whitespace from user name', (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(
                  id: tUserId,
                  name: '  Alice  ',
                  avatarColorHex: 'AE0C00',
                  icon: '🎮'),
            ],
          ));

      expect(find.text(' (Alice)'), findsOneWidget);
      expect(find.text(' (  Alice  )'), findsNothing);
      expect(find.textContaining('Alice'), findsWidgets);
      final suffixText = tester.widget<Text>(find.text(' (Alice)'));
      expect(suffixText.style?.fontStyle, isNot(FontStyle.italic));
      expect(find.bySemanticsLabel('Edit Player, linked to Alice'),
          findsOneWidget);
    });

    testWidgets('22-char name not truncated (boundary)',
        (WidgetTester tester) async {
      const name22 = '1234567890123456789012'; // exactly 22
      expect(name22.length, 22);
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(
                  id: tUserId,
                  name: name22,
                  avatarColorHex: 'AE0C00',
                  icon: '🎮'),
            ],
          ));

      expect(find.text(' ($name22)'), findsOneWidget);
      expect(find.textContaining('…'), findsNothing);
      expect(find.bySemanticsLabel('Edit Player, linked to $name22'),
          findsOneWidget);
      final suffixText = tester.widget<Text>(find.text(' ($name22)'));
      expect(suffixText.overflow, TextOverflow.ellipsis);
      expect(suffixText.style?.fontStyle, isNot(FontStyle.italic));
    });

    testWidgets('23-char name truncated with ellipsis (boundary)',
        (WidgetTester tester) async {
      const name23 = '12345678901234567890123'; // 23
      expect(name23.length, 23);
      const expected = '1234567890123456789012…'; // 22 + …
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(
                  id: tUserId,
                  name: name23,
                  avatarColorHex: 'AE0C00',
                  icon: '🎮'),
            ],
          ));

      expect(find.text(' ($expected)'), findsOneWidget);
      expect(find.textContaining(name23), findsNothing);
      expect(find.bySemanticsLabel('Edit Player, linked to $expected'),
          findsOneWidget);
      // Truncated name still not Unknown => not italic
      final suffixText = tester.widget<Text>(find.text(' ($expected)'));
      expect(suffixText.style?.fontStyle, isNot(FontStyle.italic));
      expect(suffixText.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
        'title Semantics uses header:true and ExcludeSemantics wraps title',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [
              User(
                  id: tUserId,
                  name: 'Alice',
                  avatarColorHex: 'AE0C00',
                  icon: '🎮'),
            ],
          ));

      // Semantics with header:true should exist and be ancestor of title
      final headerSemantics = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.header == true);
      expect(headerSemantics, findsOneWidget);
      // Verify ExcludeSemantics is descendant of header Semantics
      expect(
          find.descendant(
              of: headerSemantics, matching: find.byType(ExcludeSemantics)),
          findsOneWidget);
      // Verify label
      expect(find.bySemanticsLabel('Edit Player, linked to Alice'),
          findsOneWidget);
    });

    testWidgets(
        'orphan title Semantics header and style invariants hold together',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
            users: [],
          ));

      // Semantics header
      final headerSemantics = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.header == true);
      expect(headerSemantics, findsOneWidget);
      expect(
          find.descendant(
              of: headerSemantics, matching: find.byType(ExcludeSemantics)),
          findsOneWidget);
      // Row min + Flexible invariants even for Unknown user orphan
      final rowFinder = find.ancestor(
          of: find.text(' (Unknown user)'), matching: find.byType(Row));
      expect(rowFinder, findsOneWidget);
      expect(tester.widget<Row>(rowFinder).mainAxisSize, MainAxisSize.min);
      expect(
          find.descendant(
              of: find.byType(Flexible), matching: find.text('Edit Player')),
          findsNothing);
      expect(
          find.descendant(
              of: find.byType(Flexible),
              matching: find.text(' (Unknown user)')),
          findsOneWidget);
      final suffixText = tester.widget<Text>(find.text(' (Unknown user)'));
      expect(suffixText.overflow, TextOverflow.ellipsis);
      expect(suffixText.style?.fontStyle, FontStyle.italic);
      expect(suffixText.style?.color, AppTheme.textTertiary);
    });
  });
}
