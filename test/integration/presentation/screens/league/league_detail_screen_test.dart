import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/presentation/screens/league/league_detail_screen.dart';

class MockLeagueDetailNotifier
    extends FamilyAsyncNotifier<LeagueDetailState, String>
    with Mock
    implements LeagueDetailNotifier {}

void main() {
  late League<SimpleMatch> tLeague;
  late LeagueDetailState tState;

  setUpAll(() {
    registerFallbackValue(const AsyncValue.data(
        LeagueDetailState(players: [], matches: [], playerStats: {})));
  });

  setUp(() {
    tLeague = League<SimpleMatch>(
      id: 'l1',
      name: 'Test League',
      createdAt: DateTime.now(),
      rankingPolicy: SimpleRankingPolicy(
        id: 'rp1',
        name: 'Standard',
        pointsForWin: 3,
        pointsForDraw: 1,
        pointsForLoss: 0,
      ),
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

  Widget createWidgetWithValue(AsyncValue<LeagueDetailState> value) {
    return ProviderScope(
      overrides: [
        leagueDetailProvider.overrideWith(() {
          final notifier = MockLeagueDetailNotifier();
          when(() => notifier.build(any())).thenAnswer((invocation) async {
            if (value is AsyncData) return value.value!;
            if (value is AsyncError) throw value.error!;
            return Completer<LeagueDetailState>().future;
          });
          return notifier;
        }),
      ],
      child: MaterialApp(
        home: LeagueDetailScreen(league: tLeague),
      ),
    );
  }

  group('LeagueDetailScreen', () {
    testWidgets('should show loading indicator when loading', (tester) async {
      await tester
          .pumpWidget(createWidgetWithValue(const AsyncValue.loading()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error message on error', (tester) async {
      await tester.pumpWidget(createWidgetWithValue(
          const AsyncValue.error('Error occurred', StackTrace.empty)));
      await tester.pump();
      expect(find.textContaining('Error occurred'), findsOneWidget);
    });

    testWidgets('should show standings when data is loaded', (tester) async {
      await tester.pumpWidget(createWidgetWithValue(AsyncValue.data(tState)));
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
      await tester
          .pumpWidget(createWidgetWithValue(const AsyncValue.data(emptyState)));
      await tester.pump();

      expect(find.text('No players yet'), findsOneWidget);
      expect(find.text('Add Player'), findsOneWidget);
    });

    testWidgets('should switch tabs', (tester) async {
      await tester.pumpWidget(createWidgetWithValue(AsyncValue.data(tState)));
      await tester.pump();

      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();

      expect(find.text('No matches played yet'), findsOneWidget);
    });
  });
}
