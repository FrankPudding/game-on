import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/data/models/hive/ranking_policy_hive_model.dart';
import 'package:game_on/data/repositories/hive/hive_ranking_policy_repository.dart';
import 'package:game_on/domain/entities/ranking_policies/fargo_rate_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/repositories/category_repository.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}
class MockBox extends Mock implements Box<RankingPolicyHiveModel> {}
class FakeRankingPolicyHiveModel extends Fake implements RankingPolicyHiveModel {}

void main() {
  late MockCategoryRepository mockCategoryRepo;
  late MockBox mockBox;

  setUp(() {
    mockCategoryRepo = MockCategoryRepository();
    mockBox = MockBox();
    registerFallbackValue(FakeRankingPolicyHiveModel());
    registerFallbackValue(FargoRateRankingPolicy(id: 'x', name: 'y', leagueId: 'z', categoryIds: const [kSportsCategoryId, kPubGamesCategoryId]));
    when(() => mockBox.put(any(), any())).thenAnswer((_) async => {});
    when(() => mockCategoryRepo.existsAll(any())).thenAnswer((_) async => true);
  });

  group('HiveRankingPolicyRepository.put – Fargo guards', () {
    test('accepts exact Fargo ids', () async {
      final repo = HiveRankingPolicyRepository(mockBox, categoryRepository: mockCategoryRepo);
      final policy = FargoRateRankingPolicy(id: 'rp1', name: 'Pool', leagueId: 'l1', categoryIds: const [kSportsCategoryId, kPubGamesCategoryId]);
      await repo.put(policy);
      verify(() => mockBox.put('rp1', any(that: isA<RankingPolicyHiveModel>()))).called(1);
    });

    test('accepts reversed order', () async {
      final repo = HiveRankingPolicyRepository(mockBox, categoryRepository: mockCategoryRepo);
      final policy = FargoRateRankingPolicy(id: 'rp1', name: 'Pool', leagueId: 'l1', categoryIds: const [kPubGamesCategoryId, kSportsCategoryId]);
      await repo.put(policy);
      verify(() => mockBox.put('rp1', any())).called(1);
    });

    test('rejects only sports', () async {
      expect(() => FargoRateRankingPolicy(id: 'rp1', name: 'Pool', leagueId: 'l1', categoryIds: const [kSportsCategoryId]), throwsArgumentError);
    });

    test('rejects duplicate', () async {
      expect(() => FargoRateRankingPolicy(id: 'rp1', name: 'Pool', leagueId: 'l1', categoryIds: const [kSportsCategoryId, kSportsCategoryId]), throwsArgumentError);
    });

    test('rejects extra', () async {
      expect(() => FargoRateRankingPolicy(id: 'rp1', name: 'Pool', leagueId: 'l1', categoryIds: const [kSportsCategoryId, kPubGamesCategoryId, 'extra']), throwsArgumentError);
    });

    test('rejects Simple with Fargo ids (Simple only custom)', () async {
      final repo = HiveRankingPolicyRepository(mockBox, categoryRepository: mockCategoryRepo);
      final simple = SimpleRankingPolicy(id: 'rp1', name: 'Simple', leagueId: 'l1', categoryIds: const [kSportsCategoryId, kPubGamesCategoryId]);
      expect(() => repo.put(simple), throwsArgumentError);
    });

    test('throws UnknownCategoryException when category does not exist', () async {
      final repo = HiveRankingPolicyRepository(mockBox, categoryRepository: mockCategoryRepo);
      when(() => mockCategoryRepo.existsAll(any())).thenAnswer((_) async => false);
      final policy = FargoRateRankingPolicy(id: 'rp1', name: 'Pool', leagueId: 'l1', categoryIds: const [kSportsCategoryId, kPubGamesCategoryId]);
      expect(() => repo.put(policy), throwsA(isA<Exception>()));
    });
  });
}
