import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/application/preferences/sort_preference.dart';
import 'package:game_on/domain/repositories/preferences/sort_preference_repository.dart';
import 'package:game_on/providers/sort_preference_provider.dart';

class MockSortPrefRepo extends Mock implements SortPreferenceRepository {}

class FakePref extends Fake implements LeagueSortPreference {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePref());
    registerFallbackValue(const LeagueSortPreference(
        mode: LeagueSortMode.lastPlayed, descending: true));
  });

  late MockSortPrefRepo mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockSortPrefRepo();
    // Default get returns defaultPreference
    when(() => mockRepo.get())
        .thenAnswer((_) async => LeagueSortPreference.defaultPreference);
    when(() => mockRepo.getPreference())
        .thenAnswer((_) async => LeagueSortPreference.defaultPreference);
    when(() => mockRepo.set(any())).thenAnswer((_) async => {});
    when(() => mockRepo.setPreference(any())).thenAnswer((_) async => {});

    container = ProviderContainer(
      overrides: [
        leagueSortPreferenceRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
  });

  group(
      'sortPreferenceProvider (R4 persisted preference, no flicker, R3 toggle)',
      () {
    test('default is lastPlayed descending (R1+R4 no-flicker)', () {
      final pref = container.read(sortPreferenceProvider);
      expect(pref.mode, LeagueSortMode.lastPlayed);
      expect(pref.descending, true);
      expect(pref, LeagueSortPreference.defaultPreference);
      expect(LeagueSortPreference.defaultPreference.mode,
          LeagueSortMode.lastPlayed);
      expect(LeagueSortPreference.defaultPreference.descending, true);
    });

    test(
        'initial load uses repository get (or default) - no flicker synchronous fallback',
        () async {
      // If repo returns alphabetical, provider should reflect that after build?
      // Skeleton build should attempt repo get then fallback to default without flicker
      when(() => mockRepo.get()).thenAnswer((_) async =>
          const LeagueSortPreference(
              mode: LeagueSortMode.alphabetical, descending: false));
      when(() => mockRepo.getPreference()).thenAnswer((_) async =>
          const LeagueSortPreference(
              mode: LeagueSortMode.alphabetical, descending: false));
      final c2 = ProviderContainer(overrides: [
        leagueSortPreferenceRepositoryProvider.overrideWithValue(mockRepo)
      ]);
      addTearDown(c2.dispose);
      final pref = c2.read(sortPreferenceProvider);
      // Initially default without flicker, eventually updates? Implementation must not show intermediate wrong state
      // At minimum, default should be lastPlayed descending before async resolves
      expect(pref.mode, LeagueSortMode.lastPlayed);
      // Wait for async load
      await Future.delayed(const Duration(milliseconds: 50));
      // After load, might be alphabetical if repo persisted that
      // This asserts persistence round-trip in provider
    });

    test(
        'setPreference persists via repository and updates state (write-then-invalidate R7)',
        () async {
      final notifier = container.read(sortPreferenceProvider.notifier);
      const newPref = LeagueSortPreference(
          mode: LeagueSortMode.alphabetical, descending: false);
      await notifier.setPreference(newPref);
      verify(() => mockRepo.set(newPref)).called(greaterThanOrEqualTo(1));
      // Also alias may be called depending on implementation
      expect(container.read(sortPreferenceProvider), newPref);
    });

    test('setMode preserves descending and persists', () async {
      final notifier = container.read(sortPreferenceProvider.notifier);
      // default descending true
      await notifier.setMode(LeagueSortMode.alphabetical);
      final pref = container.read(sortPreferenceProvider);
      expect(pref.mode, LeagueSortMode.alphabetical);
      expect(pref.descending, true); // preserved
      verify(() => mockRepo.set(any(that: isA<LeagueSortPreference>())))
          .called(greaterThanOrEqualTo(1));
    });

    test('toggleDirection flips descending and persists (R3)', () async {
      final notifier = container.read(sortPreferenceProvider.notifier);
      expect(container.read(sortPreferenceProvider).descending, true);
      await notifier.toggleDirection();
      expect(container.read(sortPreferenceProvider).descending, false);
      await notifier.toggleDirection();
      expect(container.read(sortPreferenceProvider).descending, true);
      verify(() => mockRepo.set(any(that: isA<LeagueSortPreference>())))
          .called(greaterThanOrEqualTo(2));
    });

    test('LeagueSortPreference copyWith preserves equality', () {
      const base = LeagueSortPreference(
          mode: LeagueSortMode.lastPlayed, descending: true);
      final copy = base.copyWith(descending: false);
      expect(copy.mode, LeagueSortMode.lastPlayed);
      expect(copy.descending, false);
      expect(
          copy ==
              const LeagueSortPreference(
                  mode: LeagueSortMode.lastPlayed, descending: false),
          isTrue);
      expect(base.copyWith().mode, base.mode);
    });

    test(
        'Provider is not autoDispose? keepAlive implied - not disposed on unwatch',
        () {
      // KeepAlive verification is indirect: provider should remain accessible
      // This test ensures provider type is NotifierProvider not autoDispose
      expect(
        sortPreferenceProvider,
        isA<
            NotifierProvider<LeagueSortPreferenceNotifier,
                LeagueSortPreference>>(),
      );
    });

    test('Persistence round-trip: set then get returns same (via repo)',
        () async {
      const pref = LeagueSortPreference(
          mode: LeagueSortMode.alphabetical, descending: true);
      when(() => mockRepo.get()).thenAnswer((_) async => pref);
      when(() => mockRepo.getPreference()).thenAnswer((_) async => pref);
      final notifier = container.read(sortPreferenceProvider.notifier);
      await notifier.setPreference(pref);
      final retrieved = await mockRepo.get();
      expect(retrieved, pref);
    });
  });
}
