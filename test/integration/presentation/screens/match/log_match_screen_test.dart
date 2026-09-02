import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/presentation/screens/match/log_match_screen.dart';

class FakeLeagueDetailNotifier extends LeagueDetailNotifier {
  FakeLeagueDetailNotifier({this.onBuild}) : super('test-league-id');
  final FutureOr<LeagueDetailState> Function()? onBuild;
  final List<Map<String, dynamic>> logSimpleMatchCalls = [];
  final List<Map<String, dynamic>> updateSimpleMatchCalls = [];
  final List<String> deleteMatchCalls = [];

  @override
  Future<LeagueDetailState> build() async {
    if (onBuild != null) return await onBuild!();
    return const LeagueDetailState(players: [], matches: [], playerStats: {});
  }

  @override
  Future<void> logSimpleMatch({
    required String winnerId,
    required String loserId,
    required bool isDraw,
    DateTime? playedAt,
    int? winnerScore,
    int? loserScore,
  }) async {
    logSimpleMatchCalls.add({
      'winnerId': winnerId,
      'loserId': loserId,
      'isDraw': isDraw,
      'playedAt': playedAt,
      'winnerScore': winnerScore,
      'loserScore': loserScore,
    });
  }

  @override
  Future<void> updateSimpleMatch({
    required String matchId,
    required String winnerId,
    required String loserId,
    required bool isDraw,
    DateTime? playedAt,
    int? winnerScore,
    int? loserScore,
  }) async {
    updateSimpleMatchCalls.add({
      'matchId': matchId,
      'winnerId': winnerId,
      'loserId': loserId,
      'isDraw': isDraw,
      'playedAt': playedAt,
      'winnerScore': winnerScore,
      'loserScore': loserScore,
    });
  }

  @override
  Future<void> deleteMatch(String matchId) async {
    deleteMatchCalls.add(matchId);
  }
}

void main() {
  const tLeagueId = 'l1';

  late LeagueDetailState tState;
  late FakeLeagueDetailNotifier fakeNotifier;

  setUp(() {
    tState = LeagueDetailState(
      players: [
        LeaguePlayer(
            id: 'p1',
            userId: 'u1',
            leagueId: tLeagueId,
            name: 'Player 1',
            avatarColorHex: 'FF0000'),
        LeaguePlayer(
            id: 'p2',
            userId: 'u2',
            leagueId: tLeagueId,
            name: 'Player 2',
            avatarColorHex: '00FF00'),
      ],
      matches: [],
      playerStats: const {},
    );
  });

  Widget createApp(Widget screen,
      {required AsyncValue<LeagueDetailState> value}) {
    fakeNotifier = FakeLeagueDetailNotifier(
      onBuild: () async {
        if (value is AsyncData) return value.value!;
        if (value is AsyncError) throw value.error!;
        return Completer<LeagueDetailState>().future;
      },
    );

    return ProviderScope(
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
                    builder: (_) => screen,
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

  Future<void> openScreen(WidgetTester tester, Widget screen,
      {required AsyncValue<LeagueDetailState> value}) async {
    await tester.pumpWidget(createApp(screen, value: value));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('LogMatchScreen', () {
    testWidgets('should show loading indicator when loading', (tester) async {
      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: const AsyncValue.loading(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error message on error', (tester) async {
      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: const AsyncValue.error('Boom', StackTrace.empty),
      );
      await tester.pump();

      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('should show message when fewer than 2 players',
        (tester) async {
      final onePlayer = LeagueDetailState(
        players: [
          LeaguePlayer(
              id: 'p1',
              userId: 'u1',
              leagueId: tLeagueId,
              name: 'Player 1',
              avatarColorHex: 'FF0000'),
        ],
        matches: const [],
        playerStats: const {},
      );

      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(onePlayer),
      );
      await tester.pump();

      expect(
          find.text('Need at least 2 players to log a match'), findsOneWidget);
    });

    testWidgets('should auto-select the two players and log a draw',
        (tester) async {
      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(tState),
      );
      await tester.pump();
      await tester.pump();

      // Both player names should now be visible (auto-selected)
      expect(find.text('Player 1'), findsWidgets);
      expect(find.text('Player 2'), findsWidgets);

      // Winner dropdown should be present
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Draw').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Match Result'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.logSimpleMatchCalls, hasLength(1));
      expect(fakeNotifier.logSimpleMatchCalls.first['winnerId'], 'p1');
      expect(fakeNotifier.logSimpleMatchCalls.first['loserId'], 'p2');
      expect(fakeNotifier.logSimpleMatchCalls.first['isDraw'], true);
    });

    testWidgets('should show snackbar when players are not selected',
        (tester) async {
      final threePlayers = LeagueDetailState(
        players: [
          LeaguePlayer(
              id: 'p1',
              userId: 'u1',
              leagueId: tLeagueId,
              name: 'Player 1',
              avatarColorHex: 'FF0000'),
          LeaguePlayer(
              id: 'p2',
              userId: 'u2',
              leagueId: tLeagueId,
              name: 'Player 2',
              avatarColorHex: '00FF00'),
          LeaguePlayer(
              id: 'p3',
              userId: 'u3',
              leagueId: tLeagueId,
              name: 'Player 3',
              avatarColorHex: '0000FF'),
        ],
        matches: const [],
        playerStats: const {},
      );

      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(threePlayers),
      );
      await tester.pump();

      await tester.tap(find.text('Confirm Match Result'));
      await tester.pump();

      expect(find.text('Please select players and a winner'), findsWidgets);
    });

    testWidgets('should pick players via the bottom sheet', (tester) async {
      final threePlayers = LeagueDetailState(
        players: [
          LeaguePlayer(
              id: 'p1',
              userId: 'u1',
              leagueId: tLeagueId,
              name: 'Player 1',
              avatarColorHex: 'FF0000'),
          LeaguePlayer(
              id: 'p2',
              userId: 'u2',
              leagueId: tLeagueId,
              name: 'Player 2',
              avatarColorHex: '00FF00'),
          LeaguePlayer(
              id: 'p3',
              userId: 'u3',
              leagueId: tLeagueId,
              name: 'Player 3',
              avatarColorHex: '0000FF'),
        ],
        matches: const [],
        playerStats: const {},
      );

      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(threePlayers),
      );
      await tester.pump();

      await tester.tap(find.text('Select').first);
      await tester.pumpAndSettle();

      expect(find.text('Pick a Player'), findsOneWidget);

      await tester.tap(find.text('Player 1'));
      await tester.pumpAndSettle();

      expect(find.text('Player 1'), findsWidgets);
      expect(find.text('Select'), findsOneWidget); // Only one unselected left
    });

    testWidgets('should log a win with a custom winner', (tester) async {
      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(tState),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Player 2').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Match Result'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.logSimpleMatchCalls, hasLength(1));
      expect(fakeNotifier.logSimpleMatchCalls.first['winnerId'], 'p2');
      expect(fakeNotifier.logSimpleMatchCalls.first['loserId'], 'p1');
      expect(fakeNotifier.logSimpleMatchCalls.first['isDraw'], false);
    });

    testWidgets('should show title and update button in edit mode',
        (tester) async {
      final match = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime(2023, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2']),
        ],
        winnerSideId: 's1',
      );

      await openScreen(
        tester,
        LogMatchScreen(leagueId: tLeagueId, match: match),
        value: AsyncValue.data(tState),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Edit Match'), findsOneWidget);
      expect(find.text('Update Match'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('should delete match after confirmation', (tester) async {
      final match = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime(2023, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2']),
        ],
        winnerSideId: 's1',
      );

      await openScreen(
        tester,
        LogMatchScreen(leagueId: tLeagueId, match: match),
        value: AsyncValue.data(tState),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Match?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.deleteMatchCalls, ['m1']);
    });

    testWidgets('should cancel deleting a match', (tester) async {
      final match = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime(2023, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2']),
        ],
        winnerSideId: 's1',
      );

      await openScreen(
        tester,
        LogMatchScreen(leagueId: tLeagueId, match: match),
        value: AsyncValue.data(tState),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.deleteMatchCalls, isEmpty);
    });

    testWidgets('should update an existing match', (tester) async {
      final match = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime(2023, 1, 1),
        isComplete: true,
        isDraw: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2']),
        ],
      );

      await openScreen(
        tester,
        LogMatchScreen(leagueId: tLeagueId, match: match),
        value: AsyncValue.data(tState),
      );
      await tester.pump();
      await tester.pump();

      // Draw is pre-selected for the draw match; submit the update.
      await tester.tap(find.text('Update Match'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.updateSimpleMatchCalls, hasLength(1));
      expect(fakeNotifier.updateSimpleMatchCalls.first['matchId'], 'm1');
      expect(fakeNotifier.updateSimpleMatchCalls.first['winnerId'], 'p1');
      expect(fakeNotifier.updateSimpleMatchCalls.first['loserId'], 'p2');
      expect(fakeNotifier.updateSimpleMatchCalls.first['isDraw'], true);
    });

    testWidgets('should pre-select winner when editing a decided match',
        (tester) async {
      final match = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime(2023, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2']),
        ],
        winnerSideId: 's1',
      );

      await openScreen(
        tester,
        LogMatchScreen(leagueId: tLeagueId, match: match),
        value: AsyncValue.data(tState),
      );
      await tester.pump();
      await tester.pump();

      // The winner dropdown should show Player 1 as selected value.
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>));
      expect(dropdown.initialValue, 'p1');
    });

    testWidgets('should update the selected date via the date picker',
        (tester) async {
      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(tState),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('should pick the second player via its bottom sheet',
        (tester) async {
      final threePlayers = LeagueDetailState(
        players: [
          LeaguePlayer(
              id: 'p1',
              userId: 'u1',
              leagueId: tLeagueId,
              name: 'Player 1',
              avatarColorHex: 'FF0000'),
          LeaguePlayer(
              id: 'p2',
              userId: 'u2',
              leagueId: tLeagueId,
              name: 'Player 2',
              avatarColorHex: '00FF00'),
          LeaguePlayer(
              id: 'p3',
              userId: 'u3',
              leagueId: tLeagueId,
              name: 'Player 3',
              avatarColorHex: '0000FF'),
        ],
        matches: const [],
        playerStats: const {},
      );

      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(threePlayers),
      );
      await tester.pump();

      await tester.tap(find.text('Select').last);
      await tester.pumpAndSettle();

      expect(find.text('Pick a Player'), findsOneWidget);

      await tester.tap(find.text('Player 3'));
      await tester.pumpAndSettle();

      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('should update the selected date via text input',
        (tester) async {
      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(tState),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '2023-06-15');
      await tester.pump();

      expect(find.text('2023-06-15'), findsOneWidget);
    });

    testWidgets(
        'should show score inputs instead of winner dropdown for goal difference leagues',
        (tester) async {
      final gdState = LeagueDetailState(
        players: tState.players,
        matches: const [],
        playerStats: const {},
        rankingPolicy: GoalDifferenceRankingPolicy(
          id: 'rp-gd',
          name: 'GD',
          leagueId: tLeagueId,
        ),
      );

      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(gdState),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('SCORE'), findsOneWidget);
      // Date field + two score fields
      expect(find.byType(TextFormField), findsNWidgets(3));

      await tester.enterText(find.byType(TextFormField).at(1), '4');
      await tester.enterText(find.byType(TextFormField).at(2), '2');
      await tester.tap(find.text('Confirm Match Result'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.logSimpleMatchCalls, hasLength(1));
      expect(fakeNotifier.logSimpleMatchCalls.first['winnerId'], 'p1');
      expect(fakeNotifier.logSimpleMatchCalls.first['loserId'], 'p2');
      expect(fakeNotifier.logSimpleMatchCalls.first['isDraw'], false);
      expect(fakeNotifier.logSimpleMatchCalls.first['winnerScore'], 4);
      expect(fakeNotifier.logSimpleMatchCalls.first['loserScore'], 2);
    });

    testWidgets('should log a draw when scores are equal for goal difference',
        (tester) async {
      final gdState = LeagueDetailState(
        players: tState.players,
        matches: const [],
        playerStats: const {},
        rankingPolicy: GoalDifferenceRankingPolicy(
          id: 'rp-gd',
          name: 'GD',
          leagueId: tLeagueId,
        ),
      );

      await openScreen(
        tester,
        const LogMatchScreen(leagueId: tLeagueId),
        value: AsyncValue.data(gdState),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tester.enterText(find.byType(TextFormField).at(2), '2');
      await tester.tap(find.text('Confirm Match Result'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.logSimpleMatchCalls, hasLength(1));
      expect(fakeNotifier.logSimpleMatchCalls.first['winnerId'], 'p1');
      expect(fakeNotifier.logSimpleMatchCalls.first['loserId'], 'p2');
      expect(fakeNotifier.logSimpleMatchCalls.first['isDraw'], true);
      expect(fakeNotifier.logSimpleMatchCalls.first['winnerScore'], 2);
      expect(fakeNotifier.logSimpleMatchCalls.first['loserScore'], 2);
    });

    testWidgets('should pre-fill scores when editing a goal difference match',
        (tester) async {
      final gdState = LeagueDetailState(
        players: tState.players,
        matches: const [],
        playerStats: const {},
        rankingPolicy: GoalDifferenceRankingPolicy(
          id: 'rp-gd',
          name: 'GD',
          leagueId: tLeagueId,
        ),
      );

      final match = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime(2023, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1'], score: 5),
          Side(id: 's2', playerIds: ['p2'], score: 3),
        ],
        winnerSideId: 's1',
      );

      await openScreen(
        tester,
        LogMatchScreen(leagueId: tLeagueId, match: match),
        value: AsyncValue.data(gdState),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
