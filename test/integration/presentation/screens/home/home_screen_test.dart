import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/presentation/screens/home/home_screen.dart';
import 'package:game_on/presentation/screens/league/league_detail_screen.dart';
import 'package:game_on/presentation/screens/league/select_ranking_policy_screen.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class FakeLeaguesNotifier extends LeaguesNotifier {
  FakeLeaguesNotifier(
      {this.leagues = const [], this.shouldThrow = false, this.onBuild});
  final List<League> leagues;
  final bool shouldThrow;
  final Future<List<League>> Function()? onBuild;
  final List<String> deletedLeagueIds = [];

  @override
  Future<List<League>> build() async {
    if (onBuild != null) return onBuild!();
    if (shouldThrow) throw Exception('Load failed');
    return leagues;
  }

  @override
  Future<void> deleteLeague(String id) async {
    deletedLeagueIds.add(id);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final updated = leagues.where((l) => l.id != id).toList();
      return updated;
    });
  }
}

class RefreshingLeaguesNotifier extends FakeLeaguesNotifier {
  RefreshingLeaguesNotifier(
      {required super.leagues, this.onRefresh, super.shouldThrow});
  final Future<List<League>> Function()? onRefresh;
  int refreshCount = 0;

  Future<void> refresh() async {
    refreshCount++;
    if (onRefresh != null) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(onRefresh!);
    }
  }
}

void main() {
  late MockLeagueRepository mockLeagueRepo;
  late FakeLeaguesNotifier fakeLeaguesNotifier;

  const tLeagueId1 = 'l1';
  const tLeagueId2 = 'l2';
  final tLeague1 = League(
    id: tLeagueId1,
    name: 'League One',
    createdAt: DateTime.now(),
  );
  final tLeague2 = League(
    id: tLeagueId2,
    name: 'League Two',
    createdAt: DateTime.now(),
  );

  setUpAll(() {
    registerFallbackValue(League(id: '', name: '', createdAt: DateTime.now()));
  });

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    fakeLeaguesNotifier = FakeLeaguesNotifier(leagues: [tLeague1, tLeague2]);
    when(() => mockLeagueRepo.getAll())
        .thenAnswer((_) async => [tLeague1, tLeague2]);
    when(() => mockLeagueRepo.delete(any())).thenAnswer((_) async => {});
  });

  Widget createWidget({
    List<League>? leagues,
    bool shouldThrow = false,
    Future<List<League>> Function()? onBuild,
    Future<List<League>> Function()? onRefresh,
  }) {
    late final FakeLeaguesNotifier notifier;
    if (onRefresh != null) {
      notifier = RefreshingLeaguesNotifier(
        leagues: leagues ?? [],
        shouldThrow: shouldThrow,
        onRefresh: onRefresh,
      );
    } else if (onBuild != null || shouldThrow) {
      notifier = FakeLeaguesNotifier(
        leagues: leagues ?? [],
        shouldThrow: shouldThrow,
        onBuild: onBuild,
      );
    } else if (leagues != null) {
      notifier = FakeLeaguesNotifier(leagues: leagues);
    } else {
      notifier = fakeLeaguesNotifier;
    }
    return ProviderScope(
      retry: (_, __) => null,
      overrides: [
        leaguesProvider.overrideWith(() => notifier),
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HomeScreen(),
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
    WidgetTester tester, {
    List<League>? leagues,
    bool shouldThrow = false,
    Future<List<League>> Function()? onBuild,
    Future<List<League>> Function()? onRefresh,
  }) async {
    await tester.pumpWidget(createWidget(
      leagues: leagues,
      shouldThrow: shouldThrow,
      onBuild: onBuild,
      onRefresh: onRefresh,
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    // Extra pump to ensure async provider resolves
    await tester.pump();
  }

  group('HomeScreen', () {
    testWidgets('should show loading indicator when loading', (tester) async {
      final completer = Completer<List<League>>();
      await tester.pumpWidget(createWidget(onBuild: () => completer.future));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error state on error', (tester) async {
      await tester.pumpWidget(
          createWidget(onBuild: () => throw Exception('Error occurred')));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets(
        'should show empty state with Create First League button when no leagues',
        (tester) async {
      await openScreen(tester, leagues: []);
      await tester.pump();

      expect(find.text('No leagues yet'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Create First League'),
          findsOneWidget);
    });

    testWidgets(
        'should navigate to SelectRankingPolicyScreen when tapping Create First League button',
        (tester) async {
      await openScreen(tester, leagues: []);
      await tester.pump();

      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Create First League'));
      await tester.pumpAndSettle();

      expect(find.byType(SelectRankingPolicyScreen), findsOneWidget);
      expect(find.text('Select Scoring System'), findsOneWidget);
    });

    testWidgets('should show FAB that navigates to SelectRankingPolicyScreen',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(SelectRankingPolicyScreen), findsOneWidget);
    });

    testWidgets('should display league list when leagues exist',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      expect(find.text('League One'), findsOneWidget);
      expect(find.text('League Two'), findsOneWidget);
      expect(find.text('Last played: Never'), findsNWidgets(2));
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      expect(find.byIcon(Icons.sports_esports), findsNWidgets(2));
    });

    testWidgets('should navigate to LeagueDetailScreen when tapping a league',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.tap(find.text('League One'));
      await tester.pumpAndSettle();

      expect(find.byType(LeagueDetailScreen), findsOneWidget);
      expect(find.text('League One'), findsOneWidget);
    });

    testWidgets('should handle multiple leagues correctly', (tester) async {
      final league3 = League(
        id: 'l3',
        name: 'League Three',
        createdAt: DateTime.now(),
      );

      await openScreen(tester, leagues: [tLeague1, tLeague2, league3]);
      await tester.pump();

      expect(find.text('League One'), findsOneWidget);
      expect(find.text('League Two'), findsOneWidget);
      expect(find.text('League Three'), findsOneWidget);
    });

    testWidgets('should handle pull-to-refresh drag without RefreshIndicator',
        (tester) async {
      int refreshCount = 0;
      final refreshingNotifier = RefreshingLeaguesNotifier(
        leagues: [tLeague1],
        onRefresh: () async {
          refreshCount++;
          if (refreshCount == 1) return [tLeague1];
          return [tLeague1, tLeague2];
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            leaguesProvider.overrideWith(() => refreshingNotifier),
            leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
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
      expect(find.text('League One'), findsOneWidget);
      expect(find.text('League Two'), findsNothing);

      // Drag on ListView (no RefreshIndicator in UI, so this won't trigger refresh)
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      // List should remain unchanged since no RefreshIndicator exists
      expect(find.text('League One'), findsOneWidget);
      expect(find.text('League Two'), findsNothing);
      expect(refreshCount, 0);
    });
  });
}
