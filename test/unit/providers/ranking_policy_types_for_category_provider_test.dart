import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/presentation/screens/league/select_scoring_system_screen.dart';
import 'package:game_on/providers/leagues_provider.dart';

class MockRankingPolicyRepository extends Mock implements RankingPolicyRepository {}

class FakeRankingPolicy extends RankingPolicy<SimpleMatch> {
  FakeRankingPolicy({
    required super.id,
    required super.name,
    required super.leagueId,
    required super.categoryIds,
  });
}

void main() {
  late MockRankingPolicyRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockRankingPolicyRepository();
    container = ProviderContainer(
      overrides: [
        rankingPolicyRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('rankingPolicyTypesForCategoryProvider', () {
    final nonCustomIds = [
      'cat_boardgames',
      'cat_cardgames',
      'cat_sports',
      'cat_videogames',
    ];

    for (final id in nonCustomIds) {
      test('should return [] for non-custom $id without calling repo', () async {
        // Even if repo would return data, provider should short-circuit to []
        when(() => mockRepo.getByCategory(any()))
            .thenAnswer((_) async => [
                  SimpleRankingPolicy(
                    id: 'rp1',
                    name: 'Std',
                    leagueId: 'l1',
                    categoryIds: const ['cat_custom_league_001'],
                  )
                ]);

        final result =
            await container.read(rankingPolicyTypesForCategoryProvider(id).future);

        expect(result, isEmpty, reason: '$id should yield empty list');
        // Verify repo not called for non-custom (early return)
        verifyNever(() => mockRepo.getByCategory(any()));
      });
    }

    test('should return [] for unknown category (not custom) without repo call', () async {
      final result = await container
          .read(rankingPolicyTypesForCategoryProvider('cat_unknown').future);
      expect(result, isEmpty);
      verifyNever(() => mockRepo.getByCategory(any()));
    });

    test('should return [] for empty categoryId without repo call', () async {
      final result =
          await container.read(rankingPolicyTypesForCategoryProvider('').future);
      expect(result, isEmpty);
      verifyNever(() => mockRepo.getByCategory(any()));
    });

    group('custom category (kFallbackCategoryId)', () {
      test('should return fallback values when repo returns empty (seed fallback)', () async {
        when(() => mockRepo.getByCategory(kFallbackCategoryId))
            .thenAnswer((_) async => []);

        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(kFallbackCategoryId).future);

        expect(result, containsAll(RankingPolicyType.values));
        expect(result.length, RankingPolicyType.values.length);
        verify(() => mockRepo.getByCategory(kFallbackCategoryId)).called(1);
      });

      test('should return fallback values when repo throws', () async {
        when(() => mockRepo.getByCategory(kFallbackCategoryId))
            .thenThrow(Exception('db failure'));

        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(kFallbackCategoryId).future);

        expect(result, containsAll(RankingPolicyType.values));
        expect(result.length, RankingPolicyType.values.length);
        verify(() => mockRepo.getByCategory(kFallbackCategoryId)).called(1);
      });

      test('should return fallback values when repo returns unsupported policy types only', () async {
        when(() => mockRepo.getByCategory(kFallbackCategoryId)).thenAnswer(
            (_) async => [
                  FakeRankingPolicy(
                    id: 'fake1',
                    name: 'Fake',
                    leagueId: 'l1',
                    categoryIds: const ['cat_custom_league_001'],
                  )
                ]);

        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(kFallbackCategoryId).future);

        expect(result, containsAll(RankingPolicyType.values));
        expect(result.length, RankingPolicyType.values.length);
      });

      test('should return [simple] when repo has only Simple policies (populated)', () async {
        when(() => mockRepo.getByCategory(kFallbackCategoryId)).thenAnswer(
            (_) async => [
                  SimpleRankingPolicy(
                    id: 'rp_simple',
                    name: 'Std',
                    leagueId: 'l1',
                    categoryIds: const ['cat_custom_league_001'],
                  )
                ]);

        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(kFallbackCategoryId).future);

        expect(result, [RankingPolicyType.simple]);
      });

      test('should return [goalDifference] when repo has only GD policies (populated)', () async {
        when(() => mockRepo.getByCategory(kFallbackCategoryId)).thenAnswer(
            (_) async => [
                  GoalDifferenceRankingPolicy(
                    id: 'rp_gd',
                    name: 'GD',
                    leagueId: 'l1',
                    categoryIds: const ['cat_custom_league_001'],
                  )
                ]);

        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(kFallbackCategoryId).future);

        expect(result, [RankingPolicyType.goalDifference]);
      });

      test('should return both types when repo has both Simple and GD (populated)', () async {
        when(() => mockRepo.getByCategory(kFallbackCategoryId)).thenAnswer(
            (_) async => [
                  SimpleRankingPolicy(
                    id: 'rp_simple',
                    name: 'Std',
                    leagueId: 'l1',
                    categoryIds: const ['cat_custom_league_001'],
                  ),
                  GoalDifferenceRankingPolicy(
                    id: 'rp_gd',
                    name: 'GD',
                    leagueId: 'l2',
                    categoryIds: const ['cat_custom_league_001'],
                  ),
                ]);

        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(kFallbackCategoryId).future);

        expect(result, contains(RankingPolicyType.simple));
        expect(result, contains(RankingPolicyType.goalDifference));
        expect(result.length, 2);
      });

      test('should deduplicate types when multiple policies of same type (populated)', () async {
        when(() => mockRepo.getByCategory(kFallbackCategoryId)).thenAnswer(
            (_) async => [
                  SimpleRankingPolicy(
                    id: 'rp_s1',
                    name: 'Std1',
                    leagueId: 'l1',
                    categoryIds: const ['cat_custom_league_001'],
                  ),
                  SimpleRankingPolicy(
                    id: 'rp_s2',
                    name: 'Std2',
                    leagueId: 'l2',
                    categoryIds: const ['cat_custom_league_001'],
                  ),
                ]);

        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(kFallbackCategoryId).future);

        expect(result, [RankingPolicyType.simple]);
        expect(result.length, 1);
      });

      test('should call repo exactly once for custom and return values', () async {
        when(() => mockRepo.getByCategory(kFallbackCategoryId))
            .thenAnswer((_) async => []);

        await container
            .read(rankingPolicyTypesForCategoryProvider(kFallbackCategoryId).future);

        verify(() => mockRepo.getByCategory(kFallbackCategoryId)).called(1);
      });
    });
  });
}
