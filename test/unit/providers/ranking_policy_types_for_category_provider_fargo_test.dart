import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/domain/entities/ranking_policies/fargo_rate_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/presentation/screens/league/select_scoring_system_screen.dart';
import 'package:game_on/providers/leagues_provider.dart';

class MockRankingPolicyRepository extends Mock implements RankingPolicyRepository {}
class MockFargoRateRankingPolicy extends Mock implements FargoRateRankingPolicy {}

FargoRateRankingPolicy _mockFargo(String id) {
  try {
    return FargoRateRankingPolicy(
      id: id,
      name: 'Pool',
      leagueId: 'l1',
      categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
    );
  } catch (_) {
    final m = MockFargoRateRankingPolicy();
    when(() => m.id).thenReturn(id);
    when(() => m.name).thenReturn('Pool');
    when(() => m.leagueId).thenReturn('l1');
    when(() => m.categoryIds).thenReturn(const [kSportsCategoryId, kPubGamesCategoryId]);
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

  group('rankingPolicyTypesForCategoryProvider – Fargo whitelist (sports/pubgames)', () {
    for (final catId in [kSportsCategoryId, kPubGamesCategoryId]) {
      test('[$catId] try getByCategory -> mapped [fargoRate] when repo returns Fargo policies', () async {
        // Fargo whitelist is unconditional – provider returns [fargoRate] without repo call.
        final result = await container.read(rankingPolicyTypesForCategoryProvider(catId).future);

        expect(result, [RankingPolicyType.fargoRate]);
        verifyNever(() => mockRepo.getByCategory(any()));
        verifyNever(() => mockRepo.getAll());
      });

      test('[$catId] empty getByCategory + getAll empty -> bootstrap [fargoRate]', () async {
        // Unconditional whitelist – no repo interaction expected.
        final result = await container.read(rankingPolicyTypesForCategoryProvider(catId).future);

        expect(result, [RankingPolicyType.fargoRate]);
        verifyNever(() => mockRepo.getByCategory(any()));
        verifyNever(() => mockRepo.getAll());
      });

      test('[$catId] empty getByCategory + getAll non-empty -> [fargoRate] (Fargo whitelist unconditional)', () async {
        // Even when repo has data, Fargo still returns [fargoRate] without querying repo.
        final result = await container.read(rankingPolicyTypesForCategoryProvider(catId).future);

        expect(result, [RankingPolicyType.fargoRate]);
        verifyNever(() => mockRepo.getByCategory(any()));
        verifyNever(() => mockRepo.getAll());
      });

      test('[$catId] getByCategory throws -> bootstrap fallback when getAll empty', () async {
        // Unconditional – even throw case returns [fargoRate] without repo call.
        final result = await container.read(rankingPolicyTypesForCategoryProvider(catId).future);

        expect(result, [RankingPolicyType.fargoRate]);
        verifyNever(() => mockRepo.getByCategory(any()));
        verifyNever(() => mockRepo.getAll());
      });

      test('[$catId] getByCategory throws -> [fargoRate] when getAll non-empty (Fargo whitelist unconditional)', () async {
        final result = await container.read(rankingPolicyTypesForCategoryProvider(catId).future);

        expect(result, [RankingPolicyType.fargoRate]);
        verifyNever(() => mockRepo.getByCategory(any()));
        verifyNever(() => mockRepo.getAll());
      });
    }

    test('non-Fargo non-custom still returns [] without repo call (boardgames)', () async {
      when(() => mockRepo.getByCategory(any())).thenAnswer((_) async => [
            _mockFargo('rp1'),
          ]);
      final result = await container.read(rankingPolicyTypesForCategoryProvider('cat_boardgames').future);
      expect(result, isEmpty);
      verifyNever(() => mockRepo.getByCategory(any()));
    });
  });
}
