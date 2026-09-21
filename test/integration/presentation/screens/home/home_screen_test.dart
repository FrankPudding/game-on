import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:intl/intl.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/sorted_leagues_provider.dart';
import 'package:game_on/providers/sort_preference_provider.dart';
import 'package:game_on/application/preferences/sort_preference.dart';
import 'package:game_on/presentation/screens/home/home_screen.dart';
import 'package:game_on/presentation/screens/league/league_detail_screen.dart';
import 'package:game_on/presentation/screens/league/select_ranking_policy_screen.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

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

class FakeSortedLeaguesNotifier extends SortedLeaguesNotifier {
  FakeSortedLeaguesNotifier(this.sortedLeagues, {this.shouldThrow = false, this.onBuild});
  final List<SortedLeague> sortedLeagues;
  final bool shouldThrow;
  final Future<List<SortedLeague>> Function()? onBuild;
  @override
  Future<List<SortedLeague>> build() async {
    if (onBuild != null) return onBuild!();
    if (shouldThrow) throw Exception('Load failed');
    return sortedLeagues;
  }
}

class FakeSortPrefNotifier extends LeagueSortPreferenceNotifier {
  @override
  LeagueSortPreference build() => LeagueSortPreference.defaultPreference;
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
    registerFallbackValue(SimpleMatch(
        id: '',
        leagueId: '',
        playedAt: DateTime.now(),
        isComplete: false,
        sides: []));
    registerFallbackValue(Side(id: '', playerIds: []));
    Intl.defaultLocale = 'en_US';
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
    final sortedLeagues = (leagues ?? fakeLeaguesNotifier.leagues).map((l) => SortedLeague(league: l, lastPlayed: null)).toList();
    late final FakeSortedLeaguesNotifier sortedNotifier;
    if (onBuild != null) {
      sortedNotifier = FakeSortedLeaguesNotifier([], onBuild: () async {
        final result = await onBuild();
        return result.map((l) => SortedLeague(league: l, lastPlayed: null)).toList();
      });
    } else {
      sortedNotifier = FakeSortedLeaguesNotifier(sortedLeagues, shouldThrow: shouldThrow);
    }
    return ProviderScope(
      retry: (_, __) => null,
      overrides: [
        leaguesProvider.overrideWith(() => notifier),
        sortedLeaguesProvider.overrideWith(() => sortedNotifier),
        sortPreferenceProvider.overrideWith(FakeSortPrefNotifier.new),
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
            sortedLeaguesProvider.overrideWith(() => FakeSortedLeaguesNotifier([SortedLeague(league: tLeague1, lastPlayed: null)])),
            sortPreferenceProvider.overrideWith(FakeSortPrefNotifier.new),
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

  group('HomeScreen Last Played with explicit simpleMatchRepositoryProvider (deprecated bulk R5)', skip: true,
      () {
    testWidgets(
        'with 2 leagues, one with completed match shows formatted date and other shows Never (proves bug fixed)',
        (tester) async {
      final mockMatchRepo = MockSimpleMatchRepository();
      // League One has a completed match on 2023-06-15
      final completedMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId1,
        playedAt: DateTime(2023, 6, 15),
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      when(() => mockMatchRepo.getByLeague(tLeagueId1))
          .thenAnswer((_) async => [completedMatch]);
      when(() => mockMatchRepo.getByLeague(tLeagueId2))
          .thenAnswer((_) async => []);

      final notifier = FakeLeaguesNotifier(leagues: [tLeague1, tLeague2]);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            leaguesProvider.overrideWith(() => notifier),
            leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
            simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
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

      expect(find.text('League One'), findsOneWidget);
      expect(find.text('League Two'), findsOneWidget);
      // Explicit date formatting must match HomeScreen's DateFormat('MMM d, yyyy')
      final expectedDate =
          DateFormat('MMM d, yyyy').format(DateTime(2023, 6, 15));
      expect(find.text('Last played: $expectedDate'), findsOneWidget);
      expect(find.text('Last played: Never'), findsOneWidget);
      // Verify repository was actually queried for both leagues (not hidden error fallback)
      verify(() => mockMatchRepo.getByLeague(tLeagueId1))
          .called(greaterThanOrEqualTo(1));
      verify(() => mockMatchRepo.getByLeague(tLeagueId2))
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets(
        'only incomplete matches shows Never (explicit mock, not error fallback)',
        (tester) async {
      final mockMatchRepo = MockSimpleMatchRepository();
      final incompleteMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId1,
        playedAt: DateTime(2023, 6, 15),
        isComplete: false,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
      );
      when(() => mockMatchRepo.getByLeague(tLeagueId1))
          .thenAnswer((_) async => [incompleteMatch]);
      when(() => mockMatchRepo.getByLeague(tLeagueId2))
          .thenAnswer((_) async => []);
      // Even though there is an incomplete match with a date, UI must show Never
      final notifier = FakeLeaguesNotifier(leagues: [tLeague1, tLeague2]);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            leaguesProvider.overrideWith(() => notifier),
            leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
            simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
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

      expect(find.text('Last played: Never'), findsNWidgets(2));
      final unexpectedDate =
          DateFormat('MMM d, yyyy').format(DateTime(2023, 6, 15));
      expect(find.text('Last played: $unexpectedDate'), findsNothing);
    });

    testWidgets(
        'error from repository shows Never fallback (explicit error mock)',
        (tester) async {
      final mockMatchRepo = MockSimpleMatchRepository();
      when(() => mockMatchRepo.getByLeague(any()))
          .thenThrow(Exception('DB failure'));
      final notifier = FakeLeaguesNotifier(leagues: [tLeague1, tLeague2]);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            leaguesProvider.overrideWith(() => notifier),
            leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
            simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
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

      // Both cards fallback to Never on error
      expect(find.text('Last played: Never'), findsNWidgets(2));
    });

    testWidgets(
        'invalidation updates displayed date (pump, change mock, invalidate, pump)',
        (tester) async {
      final mockMatchRepo = MockSimpleMatchRepository();
      final firstDate = DateTime(2023, 1, 10);
      final secondDate = DateTime(2023, 6, 15);
      final firstMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId1,
        playedAt: firstDate,
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      final secondMatch = SimpleMatch(
        id: 'm2',
        leagueId: tLeagueId1,
        playedAt: secondDate,
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's3', playerIds: ['p1']),
          Side(id: 's4', playerIds: ['p2'])
        ],
        winnerSideId: 's3',
      );
      when(() => mockMatchRepo.getByLeague(tLeagueId1))
          .thenAnswer((_) async => [firstMatch]);
      when(() => mockMatchRepo.getByLeague(tLeagueId2))
          .thenAnswer((_) async => []);

      final notifier = FakeLeaguesNotifier(leagues: [tLeague1, tLeague2]);
      final container = ProviderContainer(
        overrides: [
          leaguesProvider.overrideWith(() => notifier),
          leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
          simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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

      expect(
          find.text(
              'Last played: ${DateFormat('MMM d, yyyy').format(firstDate)}'),
          findsOneWidget);
      expect(find.text('Last played: Never'), findsOneWidget);

      // Change mock to return newer match
      when(() => mockMatchRepo.getByLeague(tLeagueId1))
          .thenAnswer((_) async => [firstMatch, secondMatch]);

      container.invalidate(leagueLastPlayedProvider(tLeagueId1));
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.pump();

      expect(
          find.text(
              'Last played: ${DateFormat('MMM d, yyyy').format(secondDate)}'),
          findsOneWidget);
      expect(find.text('Last played: Never'), findsOneWidget);
      verify(() => mockMatchRepo.getByLeague(tLeagueId1))
          .called(greaterThanOrEqualTo(2));
    });

    testWidgets(
        'multiple leagues each show own newest complete date (unsorted + incomplete newest ignored)',
        (tester) async {
      final mockMatchRepo = MockSimpleMatchRepository();
      // League 1: unsorted completes + incomplete newest should yield Jun 15
      final l1Old = SimpleMatch(
          id: 'm1',
          leagueId: tLeagueId1,
          playedAt: DateTime(2023, 1, 10),
          isComplete: true,
          isDraw: false,
          sides: [
            Side(id: 's1', playerIds: ['p1']),
            Side(id: 's2', playerIds: ['p2'])
          ],
          winnerSideId: 's1');
      final l1NewestComplete = SimpleMatch(
          id: 'm2',
          leagueId: tLeagueId1,
          playedAt: DateTime(2023, 6, 15),
          isComplete: true,
          isDraw: false,
          sides: [
            Side(id: 's3', playerIds: ['p1']),
            Side(id: 's4', playerIds: ['p2'])
          ],
          winnerSideId: 's3');
      final l1IncompleteNewest = SimpleMatch(
          id: 'm3',
          leagueId: tLeagueId1,
          playedAt: DateTime(2023, 8, 1),
          isComplete: false,
          isDraw: false,
          sides: [
            Side(id: 's5', playerIds: ['p1']),
            Side(id: 's6', playerIds: ['p2'])
          ]);
      // League 2: single complete Dec 1 2022
      final l2Match = SimpleMatch(
          id: 'm4',
          leagueId: tLeagueId2,
          playedAt: DateTime(2022, 12, 1),
          isComplete: true,
          isDraw: false,
          sides: [
            Side(id: 's7', playerIds: ['p1']),
            Side(id: 's8', playerIds: ['p2'])
          ],
          winnerSideId: 's7');

      when(() => mockMatchRepo.getByLeague(tLeagueId1)).thenAnswer(
          (_) async => [l1IncompleteNewest, l1Old, l1NewestComplete]);
      when(() => mockMatchRepo.getByLeague(tLeagueId2))
          .thenAnswer((_) async => [l2Match]);

      final notifier = FakeLeaguesNotifier(leagues: [tLeague1, tLeague2]);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            leaguesProvider.overrideWith(() => notifier),
            leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
            simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
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

      expect(
          find.text(
              'Last played: ${DateFormat('MMM d, yyyy').format(DateTime(2023, 6, 15))}'),
          findsOneWidget);
      expect(
          find.text(
              'Last played: ${DateFormat('MMM d, yyyy').format(DateTime(2022, 12, 1))}'),
          findsOneWidget);
      expect(find.text('Last played: Never'), findsNothing);
    });
  });
}
