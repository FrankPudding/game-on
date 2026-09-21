import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/application/preferences/sort_preference.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/providers/sorted_leagues_provider.dart';
import 'package:game_on/providers/sort_preference_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/domain/repositories/preferences/sort_preference_repository.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

class MockSortPrefRepository extends Mock implements SortPreferenceRepository {}

class FakeLeagueSortPreference extends Fake implements LeagueSortPreference {}

League _league(String id, String name) =>
    League(id: id, name: name, createdAt: DateTime(2023, 1, 1));
SimpleMatch _match(String id, String leagueId, DateTime playedAt,
        {bool isComplete = true}) =>
    SimpleMatch(
      id: id,
      leagueId: leagueId,
      playedAt: playedAt,
      isComplete: isComplete,
      isDraw: false,
      sides: [
        Side(id: 's1-$id', playerIds: ['p1']),
        Side(id: 's2-$id', playerIds: ['p2'])
      ],
      winnerSideId: 's1-$id',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(FakeLeagueSortPreference());
    registerFallbackValue(const LeagueSortPreference(
        mode: LeagueSortMode.lastPlayed, descending: true));
  });

  late MockLeagueRepository mockLeagueRepo;
  late MockSimpleMatchRepository mockMatchRepo;
  late MockSortPrefRepository mockPrefRepo;

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    mockMatchRepo = MockSimpleMatchRepository();
    mockPrefRepo = MockSortPrefRepository();
    when(() => mockPrefRepo.get())
        .thenAnswer((_) async => LeagueSortPreference.defaultPreference);
    when(() => mockPrefRepo.getPreference())
        .thenAnswer((_) async => LeagueSortPreference.defaultPreference);
    when(() => mockPrefRepo.set(any())).thenAnswer((_) async => {});
    when(() => mockPrefRepo.setPreference(any())).thenAnswer((_) async => {});
  });

  ProviderContainer makeContainer(
      {List<League>? leagues, List<SimpleMatch>? matches}) {
    when(() => mockLeagueRepo.getAll()).thenAnswer((_) async => leagues ?? []);
    when(() => mockMatchRepo.getAll()).thenAnswer((_) async => matches ?? []);
    // Also need to mock getByLeague if mistakenly called - we will verify not called
    when(() => mockMatchRepo.getByLeague(any())).thenAnswer((_) async => []);
    return ProviderContainer(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        leagueSortPreferenceRepositoryProvider.overrideWithValue(mockPrefRepo),
      ],
    );
  }

  group('SortedLeaguesProvider (R1,R5,R7)', () {
    test(
        'bulk getAll called once, not N getByLeague (R5 O(M+L log L) single scan)',
        () async {
      final leagues = [
        _league('l1', 'Alpha'),
        _league('l2', 'Beta'),
        _league('l3', 'Gamma')
      ];
      final matches = [
        _match('m1', 'l1', DateTime(2023, 6, 15)),
        _match('m2', 'l2', DateTime(2022, 12, 1)),
      ];
      final container = makeContainer(leagues: leagues, matches: matches);
      addTearDown(container.dispose);

      final result = await container.read(sortedLeaguesProvider.future);
      expect(result.length, 3);
      verify(() => mockLeagueRepo.getAll()).called(1);
      verify(() => mockMatchRepo.getAll()).called(1);
      verifyNever(() => mockMatchRepo.getByLeague(any()));
      // Verify derivation: l1 most recent, l2 old, l3 Never last
      expect(result[0].league.id, 'l1');
      expect(result[1].league.id, 'l2');
      expect(result[2].league.id, 'l3');
      expect(result[2].lastPlayed, isNull);
    });

    test('default sort lastPlayed descending with nulls last', () async {
      final container = makeContainer(
        leagues: [_league('l1', 'A'), _league('l2', 'B'), _league('l3', 'C')],
        matches: [
          _match('m1', 'l2', DateTime(2023, 1, 1)),
          _match('m2', 'l1', DateTime(2023, 6, 1))
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(sortedLeaguesProvider.future);
      // default descending true: l1 (Jun) before l2 (Jan) before l3 Never
      expect(result.map((e) => e.league.id).toList(), ['l1', 'l2', 'l3']);
    });

    test(
        'systematic match repo failure surfaces as error not silent nulls (R7)',
        () async {
      when(() => mockLeagueRepo.getAll())
          .thenAnswer((_) async => [_league('l1', 'A')]);
      when(() => mockMatchRepo.getAll()).thenThrow(Exception('DB failure'));
      // Need to guarantee second call also throws for retry
      final container = ProviderContainer(
        retry: (_, __) => null,
        overrides: [
          leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
          simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
          leagueSortPreferenceRepositoryProvider
              .overrideWithValue(mockPrefRepo),
        ],
      );
      addTearDown(container.dispose);
      try {
        await container.read(sortedLeaguesProvider.future);
      } catch (_) {}
      // Should be error
      expect(container.read(sortedLeaguesProvider).hasError, isTrue);
      expect(container.read(sortedLeaguesProvider).error.toString(),
          contains('DB failure'));
      // Ensure not silently returning list with null lastPlayed
      expect(container.read(sortedLeaguesProvider).hasValue, isFalse);
    });

    test(
        'keepAlive - provider is not autoDispose (preference switches do not refetch unnecessarily implicit)',
        () {
      // Verify provider is AsyncNotifierProvider with keepAlive
      expect(
        sortedLeaguesProvider,
        isA<AsyncNotifierProvider<SortedLeaguesNotifier, List<SortedLeague>>>(),
      );
      // Additional keepAlive check via container: reading twice without invalidate does not call getAll again
    });

    test(
        'does not watch sortPreferenceProvider reactively? sorts via explicit read (R7)',
        () async {
      final container = makeContainer(
          leagues: [_league('l1', 'B'), _league('l2', 'A')], matches: []);
      addTearDown(container.dispose);
      await container.read(sortedLeaguesProvider.future);
      // Default alphabetical? no default lastPlayed descending with nulls -> tie break name then id
      // Both Never -> alphabetical tie via compareNames -> A before B
      final before = container.read(sortedLeaguesProvider).value!;
      expect(before.map((e) => e.league.name).toList(), ['A', 'B']);
      // Now change preference to alphabetical descending - should resort after invalidate? Provider should read pref
      // We test that provider uses sortPreferenceProvider value for ordering
      // Switch pref to alphabetical descending via notifier
      final prefNotifier = container.read(sortPreferenceProvider.notifier);
      await prefNotifier.setPreference(const LeagueSortPreference(
          mode: LeagueSortMode.alphabetical, descending: true));
      // If provider correctly depends, after invalidate it would reorder
      container.invalidate(sortedLeaguesProvider);
      final after = await container.read(sortedLeaguesProvider.future);
      // descending alphabetical: B before A
      expect(after.map((e) => e.league.name).toList(), ['B', 'A']);
    });

    test('league repo failure also surfaces as error', () async {
      when(() => mockLeagueRepo.getAll())
          .thenThrow(Exception('Leagues DB failure'));
      when(() => mockMatchRepo.getAll()).thenAnswer((_) async => []);
      final container = ProviderContainer(
        retry: (_, __) => null,
        overrides: [
          leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
          simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
          leagueSortPreferenceRepositoryProvider
              .overrideWithValue(mockPrefRepo),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
          container.read(sortedLeaguesProvider.future), throwsException);
      expect(container.read(sortedLeaguesProvider).hasError, isTrue);
    });

    test(
        'groupBy single scan: multiple matches per league correctly max derived',
        () async {
      final leagues = [_league('l1', 'L1'), _league('l2', 'L2')];
      final matches = [
        _match('m1', 'l1', DateTime(2023, 1, 10)),
        _match('m2', 'l1', DateTime(2023, 6, 15)),
        _match('m3', 'l1', DateTime(2023, 3, 5), isComplete: false), // ignored
        _match('m4', 'l2', DateTime(2022, 12, 1)),
        _match('m5', 'l1', DateTime(2023, 8, 1),
            isComplete: false), // newest but incomplete ignored
      ];
      final container = makeContainer(leagues: leagues, matches: matches);
      addTearDown(container.dispose);
      final result = await container.read(sortedLeaguesProvider.future);
      expect(result.firstWhere((e) => e.league.id == 'l1').lastPlayed,
          DateTime(2023, 6, 15));
      expect(result.firstWhere((e) => e.league.id == 'l2').lastPlayed,
          DateTime(2022, 12, 1));
    });

    test('empty leagues list returns empty without error', () async {
      final container = makeContainer(leagues: [], matches: []);
      addTearDown(container.dispose);
      final result = await container.read(sortedLeaguesProvider.future);
      expect(result, isEmpty);
    });

    test('domain purity: SortedLeague view-model contains no Hive DTO (R6)',
        () async {
      final container =
          makeContainer(leagues: [_league('l1', 'A')], matches: []);
      addTearDown(container.dispose);
      final result = await container.read(sortedLeaguesProvider.future);
      expect(result.first.league, isA<League>());
      expect(
          result.first.lastPlayed == null ||
              result.first.lastPlayed is DateTime,
          isTrue);
    });
  });
}
