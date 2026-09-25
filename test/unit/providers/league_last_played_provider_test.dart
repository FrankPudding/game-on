import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/providers/league_detail_provider.dart';

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

SimpleMatch makeMatch({
  required String id,
  required String leagueId,
  required DateTime playedAt,
  required bool isComplete,
}) {
  return SimpleMatch(
    id: id,
    leagueId: leagueId,
    playedAt: playedAt,
    isComplete: isComplete,
    isDraw: false,
    sides: [
      Side(id: 's1-$id', playerIds: ['p1']),
      Side(id: 's2-$id', playerIds: ['p2'])
    ],
  );
}

void main() {
  late MockSimpleMatchRepository mockMatchRepo;
  late ProviderContainer container;
  const leagueId = 'l1';

  setUp(() {
    mockMatchRepo = MockSimpleMatchRepository();
    container = ProviderContainer(
      overrides: [
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('leagueLastPlayedProvider', () {
    test('returns null when repository returns empty list', () async {
      when(() => mockMatchRepo.getByLeague(leagueId))
          .thenAnswer((_) async => []);

      final result =
          await container.read(leagueLastPlayedProvider(leagueId).future);

      expect(result, isNull);
      verify(() => mockMatchRepo.getByLeague(leagueId)).called(1);
    });

    test('returns null when only incomplete matches exist', () async {
      final incomplete = [
        makeMatch(
            id: 'm1',
            leagueId: leagueId,
            playedAt: DateTime(2023, 6, 15),
            isComplete: false),
        makeMatch(
            id: 'm2',
            leagueId: leagueId,
            playedAt: DateTime(2023, 7, 20),
            isComplete: false),
      ];
      when(() => mockMatchRepo.getByLeague(leagueId))
          .thenAnswer((_) async => incomplete);

      final result =
          await container.read(leagueLastPlayedProvider(leagueId).future);

      expect(result, isNull);
    });

    test('returns that date when single completed match exists', () async {
      final date = DateTime(2023, 6, 15);
      final match = makeMatch(
          id: 'm1', leagueId: leagueId, playedAt: date, isComplete: true);
      when(() => mockMatchRepo.getByLeague(leagueId))
          .thenAnswer((_) async => [match]);

      final result =
          await container.read(leagueLastPlayedProvider(leagueId).future);

      expect(result, equals(date));
    });

    test(
        'returns newest complete max even when unsorted and incomplete newest is later',
        () async {
      final oldComplete = makeMatch(
          id: 'm1',
          leagueId: leagueId,
          playedAt: DateTime(2023, 1, 10),
          isComplete: true);
      final newestComplete = makeMatch(
          id: 'm2',
          leagueId: leagueId,
          playedAt: DateTime(2023, 6, 15),
          isComplete: true);
      final middleComplete = makeMatch(
          id: 'm3',
          leagueId: leagueId,
          playedAt: DateTime(2023, 3, 5),
          isComplete: true);
      final incompleteNewest = makeMatch(
          id: 'm4',
          leagueId: leagueId,
          playedAt: DateTime(2023, 8, 1),
          isComplete: false);
      final oldestComplete = makeMatch(
          id: 'm5',
          leagueId: leagueId,
          playedAt: DateTime(2022, 12, 31),
          isComplete: true);

      // Provide unsorted order deliberately: middle, oldest, newest, incomplete, old
      final unsorted = [
        middleComplete,
        oldestComplete,
        newestComplete,
        incompleteNewest,
        oldComplete
      ];
      when(() => mockMatchRepo.getByLeague(leagueId))
          .thenAnswer((_) async => unsorted);

      final result =
          await container.read(leagueLastPlayedProvider(leagueId).future);

      expect(result, equals(DateTime(2023, 6, 15)));
    });

    test('hasError when repository throws', () async {
      when(() => mockMatchRepo.getByLeague('l1'))
          .thenAnswer((_) async => throw Exception('DB failure'));
      final sub = container.listen(
          leagueLastPlayedProvider(leagueId), (_, __) {},
          fireImmediately: true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final state = container.read(leagueLastPlayedProvider(leagueId));
      // Provider may be AsyncLoading with error (retrying) or AsyncError; both have hasError true
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('DB failure'));
      // UI fallback maps both loading and error to Never, so verify production logic yields Never
      expect(
          state.when(
              data: (_) => 'data',
              loading: () => 'Never',
              error: (_, __) => 'Never'),
          'Never');
      verify(() => mockMatchRepo.getByLeague('l1'))
          .called(greaterThanOrEqualTo(1));
      sub.close();
    });

    test('re-fetches after invalidate returns updated date', () async {
      final firstDate = DateTime(2023, 1, 1);
      final secondDate = DateTime(2023, 6, 15);
      when(() => mockMatchRepo.getByLeague(leagueId)).thenAnswer(
        (_) async => [
          makeMatch(
              id: 'm1',
              leagueId: leagueId,
              playedAt: firstDate,
              isComplete: true)
        ],
      );

      final first =
          await container.read(leagueLastPlayedProvider(leagueId).future);
      expect(first, firstDate);

      when(() => mockMatchRepo.getByLeague(leagueId)).thenAnswer(
        (_) async => [
          makeMatch(
              id: 'm1',
              leagueId: leagueId,
              playedAt: firstDate,
              isComplete: true),
          makeMatch(
              id: 'm2',
              leagueId: leagueId,
              playedAt: secondDate,
              isComplete: true),
        ],
      );

      container.invalidate(leagueLastPlayedProvider(leagueId));
      final second =
          await container.read(leagueLastPlayedProvider(leagueId).future);
      expect(second, secondDate);
      verify(() => mockMatchRepo.getByLeague(leagueId))
          .called(greaterThanOrEqualTo(2));
    });
  });
}
