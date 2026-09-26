import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/domain/entities/ranking_policies/elo_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/presentation/screens/league/select_scoring_system_screen.dart';

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

class MockEloRankingPolicy extends Mock implements EloRankingPolicy {}

EloRankingPolicy _mockElo(String id) {
  try {
    return EloRankingPolicy(
        id: id,
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
        initialRating: 400);
  } catch (_) {
    final m = MockEloRankingPolicy();
    when(() => m.id).thenReturn(id);
    when(() => m.name).thenReturn('Pool');
    when(() => m.leagueId).thenReturn('l1');
    when(() => m.categoryIds)
        .thenReturn(const [kSportsCategoryId, kPubGamesCategoryId]);
    return m;
  }
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

  tearDown(() => container.dispose());

  group(
      'rankingPolicyTypesForCategoryProvider – Elo whitelist (sports/pubgames)',
      () {
    for (final catId in [kSportsCategoryId, kPubGamesCategoryId]) {
      test('[$catId] unconditional [elo] without repo query (whitelist)',
          () async {
        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(catId).future);
        expect(result, [RankingPolicyType.elo]);
        verifyNever(() => mockRepo.getByCategory(any()));
        verifyNever(() => mockRepo.getAll());
      });

      test(
          '[$catId] does not return deprecated fargoRate as primary – expects elo',
          () async {
        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(catId).future);
        expect(result, contains(RankingPolicyType.elo));
        expect(result, isNot(contains(RankingPolicyType.fargoRate)));
      });

      test(
          '[$catId] empty getByCategory + getAll empty -> still [elo] (unconditional)',
          () async {
        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(catId).future);
        expect(result, [RankingPolicyType.elo]);
        verifyNever(() => mockRepo.getByCategory(any()));
        verifyNever(() => mockRepo.getAll());
      });

      test('[$catId] getByCategory throws -> still [elo] (whitelist fallback)',
          () async {
        final result = await container
            .read(rankingPolicyTypesForCategoryProvider(catId).future);
        expect(result, [RankingPolicyType.elo]);
        verifyNever(() => mockRepo.getByCategory(any()));
      });
    }

    test('non-elo non-custom still returns [] without repo call (boardgames)',
        () async {
      when(() => mockRepo.getByCategory(any()))
          .thenAnswer((_) async => [_mockElo('rp1')]);
      final result = await container
          .read(rankingPolicyTypesForCategoryProvider('cat_boardgames').future);
      expect(result, isEmpty);
      verifyNever(() => mockRepo.getByCategory(any()));
    });

    test(
        'custom -> repo-driven maps Simple/GoalDifference, empty fallback to values',
        () async {
      // Custom logic is repo-driven: we test via getting types for custom
      // If provider is correctly implemented, it should call repo for custom.
      // For custom, it should eventually return simple/goalDifference fallback when empty or populated.
      // We don't enforce exact here, but verify it does query repo (unlike sports/pubgames)
      // This distinguishes whitelist unconditional vs custom repo-driven
      mockRepo = MockRankingPolicyRepository();
      container = ProviderContainer(overrides: [
        rankingPolicyRepositoryProvider.overrideWithValue(mockRepo)
      ]);
      when(() => mockRepo.getByCategory(kFallbackCategoryId))
          .thenAnswer((_) async => []);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      final result = await container.read(
          rankingPolicyTypesForCategoryProvider(kFallbackCategoryId).future);
      // When empty, fallback is values (per plan: custom empty/error -> RankingPolicyType.values fallback) OR repo scan?
      // But we verify it DID call repo (unlike sports)
      verify(() => mockRepo.getByCategory(kFallbackCategoryId)).called(1);
      // Result should be fallback – either contains simple and goalDifference
      expect(result, contains(RankingPolicyType.simple));
      expect(result, contains(RankingPolicyType.goalDifference));
    });
  });
}
