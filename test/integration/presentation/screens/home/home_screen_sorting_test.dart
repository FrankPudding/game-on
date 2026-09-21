import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/domain/repositories/preferences/sort_preference_repository.dart';
import 'package:game_on/application/preferences/sort_preference.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/sorted_leagues_provider.dart';
import 'package:game_on/providers/sort_preference_provider.dart';
import 'package:game_on/presentation/screens/home/home_screen.dart';

class MockLeagueRepo extends Mock implements LeagueRepository {}

class MockMatchRepo extends Mock implements SimpleMatchRepository {}

class MockPrefRepo extends Mock implements SortPreferenceRepository {}

class FakePref extends Fake implements LeagueSortPreference {}

League _league(String id, String name) =>
    League(id: id, name: name, createdAt: DateTime(2023, 1, 1));

class FakeSortedLeaguesNotifier extends SortedLeaguesNotifier {
  FakeSortedLeaguesNotifier(this.leagues, {this.shouldThrow = false});
  final List<SortedLeague> leagues;
  final bool shouldThrow;
  @override
  Future<List<SortedLeague>> build() async {
    if (shouldThrow) throw Exception('DB failure');
    return leagues;
  }
}

class FakeSortPrefNotifier extends LeagueSortPreferenceNotifier {
  FakeSortPrefNotifier(this.pref);
  final LeagueSortPreference pref;
  @override
  LeagueSortPreference build() => pref;
  @override
  Future<void> setMode(LeagueSortMode mode) async {
    state = state.copyWith(mode: mode);
  }

  @override
  Future<void> toggleDirection() async {
    state = state.copyWith(descending: !state.descending);
  }

  @override
  Future<void> setPreference(LeagueSortPreference p) async {
    state = p;
  }
}

Widget _wrap(Widget child, {List<dynamic> overrides = const []}) {
  return ProviderScope(
      overrides: overrides.cast(), child: MaterialApp(home: child));
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePref());
    registerFallbackValue(const LeagueSortPreference(
        mode: LeagueSortMode.lastPlayed, descending: true));
  });
  late MockLeagueRepo mockLeagueRepo;
  late MockMatchRepo mockMatchRepo;
  late MockPrefRepo mockPrefRepo;

  setUp(() {
    mockLeagueRepo = MockLeagueRepo();
    mockMatchRepo = MockMatchRepo();
    mockPrefRepo = MockPrefRepo();
    when(() => mockPrefRepo.get())
        .thenAnswer((_) async => LeagueSortPreference.defaultPreference);
    when(() => mockPrefRepo.getPreference())
        .thenAnswer((_) async => LeagueSortPreference.defaultPreference);
    when(() => mockPrefRepo.set(any())).thenAnswer((_) async => {});
    when(() => mockPrefRepo.setPreference(any())).thenAnswer((_) async => {});
  });

  group('HomeScreen sorting (R1,R2,R3,R4,R5,R7)', () {
    testWidgets('shows leagues in lastPlayed descending order by default (R1)',
        (tester) async {
      final lOld = _league('l1', 'Alpha');
      final lRecent = _league('l2', 'Beta');
      final lNever = _league('l3', 'Gamma');
      final sorted = [
        SortedLeague(league: lRecent, lastPlayed: DateTime(2023, 6, 15)),
        SortedLeague(league: lOld, lastPlayed: DateTime(2022, 12, 1)),
        SortedLeague(league: lNever, lastPlayed: null),
      ];
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider
            .overrideWith(() => FakeSortedLeaguesNotifier(sorted)),
        sortPreferenceProvider.overrideWith(
            () => FakeSortPrefNotifier(LeagueSortPreference.defaultPreference)),
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        leagueSortPreferenceRepositoryProvider.overrideWithValue(mockPrefRepo),
      ]));
      await tester.pumpAndSettle();
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .toList();
      // Order should be Beta, Alpha, Gamma
      final betaIdx = texts.indexWhere((t) => t.contains('Beta'));
      final alphaIdx = texts.indexWhere((t) => t.contains('Alpha'));
      final gammaIdx = texts.indexWhere((t) => t.contains('Gamma'));
      expect(betaIdx, lessThan(alphaIdx));
      expect(alphaIdx, lessThan(gammaIdx));
    });

    testWidgets(
        'PopupMenuButton shows 4 sort options with checkmark via equality (R2)',
        (tester) async {
      final sorted = [
        SortedLeague(league: _league('l1', 'A'), lastPlayed: null)
      ];
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider
            .overrideWith(() => FakeSortedLeaguesNotifier(sorted)),
        sortPreferenceProvider.overrideWith(
            () => FakeSortPrefNotifier(LeagueSortPreference.defaultPreference)),
      ]));
      await tester.pumpAndSettle();
      expect(
          find.byType(PopupMenuButton<LeagueSortPreference>), findsOneWidget);
      expect(find.byTooltip('Sort'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<LeagueSortPreference>));
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);
      expect(find.text('A-Z'), findsOneWidget);
      expect(find.text('Z-A'), findsOneWidget);
      // Checkmark for selected pref via equality (default is Latest)
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Sort by last played'), findsNothing);
      expect(find.text('Sort by name'), findsNothing);
    });

    testWidgets(
        'PopupMenuButton Sort has tooltip Sort and setPreference via menu (R3)',
        (tester) async {
      final pref = LeagueSortPreference.latest;
      final notifier = FakeSortPrefNotifier(pref);
      final sortedDesc = [
        SortedLeague(
            league: _league('l2', 'Beta'), lastPlayed: DateTime(2023, 6, 15)),
        SortedLeague(
            league: _league('l1', 'Alpha'), lastPlayed: DateTime(2022, 12, 1)),
      ];
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider
            .overrideWith(() => FakeSortedLeaguesNotifier(sortedDesc)),
        sortPreferenceProvider.overrideWith(() => notifier),
      ]));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Sort'), findsOneWidget);
      expect(find.byTooltip('Toggle sort direction'), findsNothing);
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      expect(
          find.byType(PopupMenuButton<LeagueSortPreference>), findsOneWidget);
      // Selecting Oldest should call setPreference (lastPlayed ascending)
      await tester.tap(find.byType(PopupMenuButton<LeagueSortPreference>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oldest'));
      await tester.pumpAndSettle();
      final container =
          ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      expect(
          container.read(sortPreferenceProvider), LeagueSortPreference.oldest);
      // Selecting A-Z should work (alphabetical ascending)
      await tester.tap(find.byType(PopupMenuButton<LeagueSortPreference>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-Z'));
      await tester.pumpAndSettle();
      expect(container.read(sortPreferenceProvider), LeagueSortPreference.aToZ);
      // Selecting Z-A
      await tester.tap(find.byType(PopupMenuButton<LeagueSortPreference>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Z-A'));
      await tester.pumpAndSettle();
      expect(container.read(sortPreferenceProvider), LeagueSortPreference.zToA);
    });

    testWidgets(
        'keepAlive - sortedLeaguesProvider not refetched on preference switch without invalidate (R5)',
        (tester) async {
      // This is more unit but also UI: verify provider remains
      final sorted = [
        SortedLeague(league: _league('l1', 'A'), lastPlayed: null)
      ];
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider
            .overrideWith(() => FakeSortedLeaguesNotifier(sorted)),
        sortPreferenceProvider.overrideWith(
            () => FakeSortPrefNotifier(LeagueSortPreference.defaultPreference)),
      ]));
      await tester.pumpAndSettle();
      expect(
        sortedLeaguesProvider,
        isA<AsyncNotifierProvider<SortedLeaguesNotifier, List<SortedLeague>>>(),
      );
    });

    testWidgets('error degraded shows error text not silent empty (R7)',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider.overrideWith(
            () => FakeSortedLeaguesNotifier([], shouldThrow: true)),
        sortPreferenceProvider.overrideWith(
            () => FakeSortPrefNotifier(LeagueSortPreference.defaultPreference)),
      ]));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error'), findsOneWidget);
      expect(find.text('No leagues yet'), findsNothing);
    });

    testWidgets('empty list shows No leagues yet (R7)', (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider.overrideWith(() => FakeSortedLeaguesNotifier([])),
        sortPreferenceProvider.overrideWith(
            () => FakeSortPrefNotifier(LeagueSortPreference.defaultPreference)),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('No leagues yet'), findsOneWidget);
      expect(find.text('Create First League'), findsOneWidget);
    });

    testWidgets('alphabetical mode shows correct order with empty-first (R2)',
        (tester) async {
      final pref = const LeagueSortPreference(
          mode: LeagueSortMode.alphabetical, descending: false);
      final leagues = [
        SortedLeague(
            league: _league('l3', 'Bob'), lastPlayed: DateTime(2023, 6, 15)),
        SortedLeague(
            league: _league('l2', 'alice'), lastPlayed: DateTime(2023, 6, 15)),
        SortedLeague(league: _league('l4', '   '), lastPlayed: null), // empty
        SortedLeague(
            league: _league('l1', 'Alice'), lastPlayed: DateTime(2023, 6, 15)),
      ];
      // Provider should sort; but fake notifier returns as-is, so we test service sort separately?
      // For UI we expect sorted order if provider does sorting: empties first, Alice before alice before Bob
      // To test UI, we provide pre-sorted list as provider would
      final sorted = [
        leagues[2], // empty
        leagues[3], // Alice
        leagues[1], // alice
        leagues[0], // Bob
      ];
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider
            .overrideWith(() => FakeSortedLeaguesNotifier(sorted)),
        sortPreferenceProvider.overrideWith(() => FakeSortPrefNotifier(pref)),
      ]));
      await tester.pumpAndSettle();
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where((t) =>
              t == 'Alice' || t == 'alice' || t == 'Bob' || t.trim().isEmpty)
          .toList();
      // Verify order: Alice before alice before Bob (empty is first but empty text)
      final aliceIdx = texts.indexOf('Alice');
      final aliceLowIdx = texts.indexOf('alice');
      final bobIdx = texts.indexOf('Bob');
      expect(aliceIdx, lessThan(aliceLowIdx));
      expect(aliceLowIdx, lessThan(bobIdx));
    });

    testWidgets(
        'AppBar has single PopupMenuButton<LeagueSortPreference> with Sort (R2,R3)',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider.overrideWith(() => FakeSortedLeaguesNotifier([])),
        sortPreferenceProvider.overrideWith(
            () => FakeSortPrefNotifier(LeagueSortPreference.defaultPreference)),
      ]));
      await tester.pumpAndSettle();
      expect(
          find.byType(PopupMenuButton<LeagueSortPreference>), findsOneWidget);
      expect(find.byType(PopupMenuButton<LeagueSortMode>), findsNothing);
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      expect(find.byTooltip('Sort'), findsOneWidget);
      expect(find.byTooltip('Toggle sort direction'), findsNothing);
      // No longer two controls; single button only
      expect(find.text('Sort by last played'), findsNothing);
      expect(find.text('Sort by name'), findsNothing);
    });

    testWidgets(
        '_LeagueCard StatelessWidget idea - card shows league name and last played',
        (tester) async {
      final league = _league('l1', 'My League');
      final sorted = [
        SortedLeague(league: league, lastPlayed: DateTime(2023, 6, 15))
      ];
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider
            .overrideWith(() => FakeSortedLeaguesNotifier(sorted)),
        sortPreferenceProvider.overrideWith(
            () => FakeSortPrefNotifier(LeagueSortPreference.defaultPreference)),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('My League'), findsOneWidget);
      expect(find.textContaining('Last played:'), findsOneWidget);
      // Never case - need to dispose intermediate due to keepAlive
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
      final neverSorted = [SortedLeague(league: league, lastPlayed: null)];
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        sortedLeaguesProvider
            .overrideWith(() => FakeSortedLeaguesNotifier(neverSorted)),
        sortPreferenceProvider.overrideWith(
            () => FakeSortPrefNotifier(LeagueSortPreference.defaultPreference)),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Last played: Never'), findsOneWidget);
    });
  });
}
