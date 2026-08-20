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
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/presentation/screens/league/league_detail_screen.dart';
import 'package:game_on/presentation/screens/match/log_match_screen.dart';

class MockLeagueDetailNotifier
    extends FamilyAsyncNotifier<LeagueDetailState, String>
    with Mock
    implements LeagueDetailNotifier {}

class MockLeaguesNotifier extends LeaguesNotifier with Mock {}

class FakeLeaguesNotifier extends LeaguesNotifier {
  final deletedIds = <String>[];

  @override
  Future<List<League>> build() async => [];

  @override
  Future<void> deleteLeague(String id) async {
    deletedIds.add(id);
  }
}

class FakeUsersNotifier extends UsersNotifier {
  FakeUsersNotifier(this._users);
  final List<User> _users;

  @override
  Future<List<User>> build() async => _users;
}

void main() {
  late League tLeague;
  late LeagueDetailState tState;
  late MockLeagueDetailNotifier notifier;

  setUpAll(() {
    registerFallbackValue(const AsyncValue.data(
        LeagueDetailState(players: [], matches: [], playerStats: {})));
  });

  setUp(() {
    tLeague = League(
      id: 'l1',
      name: 'Test League',
      createdAt: DateTime.now(),
    );

    tState = LeagueDetailState(
      players: [
        LeaguePlayer(
            id: 'p1',
            userId: 'u1',
            leagueId: 'l1',
            name: 'Player 1',
            avatarColorHex: 'FF0000'),
      ],
      matches: [],
      playerStats: {
        'p1': const PlayerStats(points: 3, matchesPlayed: 1),
      },
    );
  });

  Widget createWidgetWithValue(
    AsyncValue<LeagueDetailState> value, {
    List<Override> extraOverrides = const [],
  }) {
    notifier = MockLeagueDetailNotifier();
    when(() => notifier.build(any())).thenAnswer((invocation) async {
      if (value is AsyncData) return value.value!;
      if (value is AsyncError) throw value.error!;
      return Completer<LeagueDetailState>().future;
    });

    return ProviderScope(
      overrides: [
        leagueDetailProvider.overrideWith(() => notifier),
        ...extraOverrides,
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeagueDetailScreen(league: tLeague),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openScreen(
      WidgetTester tester, AsyncValue<LeagueDetailState> value,
      {List<Override> extraOverrides = const []}) async {
    await tester.pumpWidget(
        createWidgetWithValue(value, extraOverrides: extraOverrides));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('LeagueDetailScreen', () {
    testWidgets('should show loading indicator when loading', (tester) async {
      await openScreen(tester, const AsyncValue.loading());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error message on error', (tester) async {
      await openScreen(
          tester, const AsyncValue.error('Error occurred', StackTrace.empty));
      await tester.pump();
      expect(find.textContaining('Error occurred'), findsOneWidget);
    });

    testWidgets('should show standings when data is loaded', (tester) async {
      await openScreen(tester, AsyncValue.data(tState));
      await tester.pump();

      expect(find.text('Test League'), findsOneWidget);
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Points
      // Position 1 and matches played 1 both show '1'
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets('should show empty state when no players', (tester) async {
      const emptyState =
          LeagueDetailState(players: [], matches: [], playerStats: {});
      await openScreen(tester, const AsyncValue.data(emptyState));
      await tester.pump();

      expect(find.text('No players yet'), findsOneWidget);
      expect(find.text('Add Player'), findsOneWidget);
    });

    testWidgets('should switch tabs', (tester) async {
      await openScreen(tester, AsyncValue.data(tState));
      await tester.pump();

      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();

      expect(find.text('No matches played yet'), findsOneWidget);
    });

    testWidgets('should show match results in correct format', (tester) async {
      final p1 = tState.players.first.copyWith(icon: '🥇');
      final p2 = LeaguePlayer(
          id: 'p2',
          userId: 'u2',
          leagueId: 'l1',
          name: 'Player 2',
          icon: '🥈',
          avatarColorHex: '00FF00');

      final matchWin = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: DateTime.now(),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2']),
        ],
        winnerSideId: 's1',
      );

      final matchDraw = SimpleMatch(
        id: 'm2',
        leagueId: 'l1',
        playedAt: DateTime.now(),
        isComplete: true,
        sides: [
          Side(id: 's4', playerIds: ['p2']),
          Side(id: 's3', playerIds: ['p1']),
        ],
        isDraw: true,
      );

      final stateWithMatches = LeagueDetailState(
        players: [p1, p2],
        matches: [matchWin, matchDraw],
        playerStats: tState.playerStats,
      );

      await openScreen(tester, AsyncValue.data(stateWithMatches));
      await tester.pump();

      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();

      expect(find.text('🥇 Player 1 vs 🥈 Player 2'), findsOneWidget);
      expect(find.text('🥈 Player 2 vs 🥇 Player 1'), findsOneWidget);
    });

    testWidgets('should handle unknown players in match results',
        (tester) async {
      final matchWin = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: DateTime.now(),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['ghost-winner']),
          Side(id: 's2', playerIds: ['ghost-loser']),
        ],
        winnerSideId: 's1',
      );

      final stateWithMatches = LeagueDetailState(
        players: tState.players,
        matches: [matchWin],
        playerStats: tState.playerStats,
      );

      await openScreen(tester, AsyncValue.data(stateWithMatches));
      await tester.pump();

      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unknown vs Unknown'), findsOneWidget);
    });

    testWidgets('should navigate to LogMatchScreen via FAB', (tester) async {
      await openScreen(tester, AsyncValue.data(tState));
      await tester.pump();

      await tester.tap(find.text('Log Match'));
      await tester.pumpAndSettle();

      expect(find.byType(LogMatchScreen), findsOneWidget);
      expect(find.text('Log Match'), findsOneWidget);
    });

    testWidgets('should navigate to edit match when tapping a match',
        (tester) async {
      final matchWin = SimpleMatch(
        id: 'm1',
        leagueId: 'l1',
        playedAt: DateTime.now(),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['ghost']),
        ],
        winnerSideId: 's1',
      );

      final stateWithMatches = LeagueDetailState(
        players: tState.players,
        matches: [matchWin],
        playerStats: tState.playerStats,
      );

      await openScreen(tester, AsyncValue.data(stateWithMatches));
      await tester.pump();

      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(LogMatchScreen), findsOneWidget);
      expect(find.text('Edit Match'), findsOneWidget);
    });

    testWidgets('should delete league after confirmation', (tester) async {
      final fakeLeaguesNotifier = FakeLeaguesNotifier();

      await openScreen(
        tester,
        AsyncValue.data(tState),
        extraOverrides: [
          leaguesProvider.overrideWith(() => fakeLeaguesNotifier),
        ],
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete League'));
      await tester.pumpAndSettle();

      expect(find.text('Delete League?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(fakeLeaguesNotifier.deletedIds, ['l1']);
    });

    testWidgets('should cancel league deletion', (tester) async {
      final fakeLeaguesNotifier = FakeLeaguesNotifier();

      await openScreen(
        tester,
        AsyncValue.data(tState),
        extraOverrides: [
          leaguesProvider.overrideWith(() => fakeLeaguesNotifier),
        ],
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete League'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(fakeLeaguesNotifier.deletedIds, isEmpty);
    });

    testWidgets('should add a new player via dialog', (tester) async {
      when(() => notifier.addPlayer(
            name: any(named: 'name'),
            userId: any(named: 'userId'),
            icon: any(named: 'icon'),
          )).thenAnswer((_) async => {});

      await openScreen(
        tester,
        AsyncValue.data(tState),
        extraOverrides: [
          usersProvider.overrideWith(() => FakeUsersNotifier([])),
        ],
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      expect(find.text('Add Player'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Newbie');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to League'));
      await tester.pumpAndSettle();

      verify(() => notifier.addPlayer(
            name: 'Newbie',
            userId: null,
            icon: any(named: 'icon'),
          )).called(1);
    });

    testWidgets('should add an existing user via dialog', (tester) async {
      when(() => notifier.addPlayer(
            name: any(named: 'name'),
            userId: any(named: 'userId'),
            icon: any(named: 'icon'),
          )).thenAnswer((_) async => {});

      final existingUser = User(
          id: 'u9', name: 'Existing', avatarColorHex: '123456', icon: '🎯');

      await openScreen(
        tester,
        AsyncValue.data(tState),
        extraOverrides: [
          usersProvider.overrideWith(() => FakeUsersNotifier([existingUser])),
        ],
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      // Switch to Existing user
      await tester.tap(find.text('Existing'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🎯 Existing').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to League'));
      await tester.pumpAndSettle();

      verify(() => notifier.addPlayer(
            name: '',
            userId: 'u9',
            icon: any(named: 'icon'),
          )).called(1);
    });

    testWidgets('should edit a player via dialog', (tester) async {
      when(() => notifier.updatePlayer(
            playerId: any(named: 'playerId'),
            name: any(named: 'name'),
            icon: any(named: 'icon'),
          )).thenAnswer((_) async => {});

      await openScreen(tester, AsyncValue.data(tState));
      await tester.pump();

      await tester.tap(find.text('Player 1'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Player'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Renamed');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      verify(() => notifier.updatePlayer(
            playerId: 'p1',
            name: 'Renamed',
            icon: any(named: 'icon'),
          )).called(1);
    });

    testWidgets('should remove a player after confirmation', (tester) async {
      when(() => notifier.removePlayer(any())).thenAnswer((_) async => {});

      await openScreen(tester, AsyncValue.data(tState));
      await tester.pump();

      await tester.tap(find.text('Player 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove from League'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Player?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
      await tester.pumpAndSettle();

      verify(() => notifier.removePlayer('p1')).called(1);
    });

    testWidgets('should cancel removing a player', (tester) async {
      await openScreen(tester, AsyncValue.data(tState));
      await tester.pump();

      await tester.tap(find.text('Player 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove from League'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();

      verifyNever(() => notifier.removePlayer(any()));
    });
  });
}
