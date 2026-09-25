import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/application/services/create_league_service.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/fargo_rate_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/domain/repositories/category_repository.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class FakeLeague extends Fake implements League {}

class FakeRankingPolicy extends Fake implements RankingPolicy {}

void main() {
  late CreateLeagueService service;
  late MockLeagueRepository mockLeagueRepo;
  late MockRankingPolicyRepository mockPolicyRepo;
  late MockCategoryRepository mockCategoryRepo;
  const tLeagueId = 'league-123';
  const tName = 'Pool League';

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    mockPolicyRepo = MockRankingPolicyRepository();
    mockCategoryRepo = MockCategoryRepository();
    service =
        CreateLeagueService(mockLeagueRepo, mockPolicyRepo, mockCategoryRepo);
    registerFallbackValue(FakeLeague());
    registerFallbackValue(FakeRankingPolicy());
  });

  FargoRateRankingPolicy fargoWith(List<String> ids) => FargoRateRankingPolicy(
      id: 'policy-123',
      name: 'Pool',
      leagueId: tLeagueId,
      categoryIds: ids,
      initialRating: 500);

  group('CreateLeagueService – FargoRate guards', () {
    test('Fargo with exact [sports, pubgames] succeeds', () async {
      when(() => mockCategoryRepo.existsAll(any()))
          .thenAnswer((_) async => true);
      when(() => mockLeagueRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPolicyRepo.put(any())).thenAnswer((_) async => {});
      final policy = fargoWith(const [kSportsCategoryId, kPubGamesCategoryId]);
      await service.execute(id: tLeagueId, name: tName, rankingPolicy: policy);
      verify(() => mockLeagueRepo.put(any())).called(1);
      verify(() => mockPolicyRepo.put(policy)).called(1);
    });

    test('Fargo reversed order [pubgames, sports] succeeds (order-insensitive)',
        () async {
      when(() => mockCategoryRepo.existsAll(any()))
          .thenAnswer((_) async => true);
      when(() => mockLeagueRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPolicyRepo.put(any())).thenAnswer((_) async => {});
      final policy = fargoWith(const [kPubGamesCategoryId, kSportsCategoryId]);
      await service.execute(id: tLeagueId, name: tName, rankingPolicy: policy);
      verify(() => mockLeagueRepo.put(any())).called(1);
    });

    test('Fargo with only [sports] throws ArgumentError', () async {
      when(() => mockCategoryRepo.existsAll(any()))
          .thenAnswer((_) async => true);
      // ctor itself throws, so we catch ctor failure separately – but if ctor allowed it, service should throw
      expect(() => fargoWith(const [kSportsCategoryId]), throwsArgumentError);
    });

    test('Fargo with only [pubgames] throws ArgumentError', () async {
      expect(() => fargoWith(const [kPubGamesCategoryId]), throwsArgumentError);
    });

    test('Fargo with [sports, pubgames, custom] extra throws ArgumentError',
        () async {
      expect(
          () => fargoWith(const [
                kSportsCategoryId,
                kPubGamesCategoryId,
                kFallbackCategoryId
              ]),
          throwsArgumentError);
    });

    test('Fargo with [sports, sports] duplicate throws ArgumentError',
        () async {
      expect(() => fargoWith(const [kSportsCategoryId, kSportsCategoryId]),
          throwsArgumentError);
    });

    test('Fargo with empty throws ArgumentError', () async {
      expect(() => fargoWith(const []), throwsArgumentError);
    });

    test('CreateLeagueService rejects mismatched categoryIds param vs policy',
        () async {
      when(() => mockCategoryRepo.existsAll(any()))
          .thenAnswer((_) async => true);
      final policy = fargoWith(const [kSportsCategoryId, kPubGamesCategoryId]);
      expect(
        () => service.execute(
            id: tLeagueId,
            name: tName,
            rankingPolicy: policy,
            categoryIds: const [kSportsCategoryId]),
        throwsArgumentError,
      );
      verifyNever(() => mockLeagueRepo.put(any()));
    });

    test('CreateLeagueService rejects Fargo with categoryIds param [custom]',
        () async {
      when(() => mockCategoryRepo.existsAll(any()))
          .thenAnswer((_) async => true);
      // Policy itself would throw if constructed with custom, so we test via explicit param mismatch:
      // Create a valid Fargo policy then try to override with custom via param – service should reject because idsToValidate != policy.categoryIds length guard
      final policy = fargoWith(const [kSportsCategoryId, kPubGamesCategoryId]);
      expect(
        () => service.execute(
            id: tLeagueId,
            name: tName,
            rankingPolicy: policy,
            categoryIds: const [kFallbackCategoryId]),
        throwsArgumentError,
      );
    });

    test('Simple policy with Fargo ids should be rejected (Simple only custom)',
        () async {
      when(() => mockCategoryRepo.existsAll(any()))
          .thenAnswer((_) async => true);
      final simple = SimpleRankingPolicy(
          id: 'p1',
          name: 'Simple',
          leagueId: tLeagueId,
          categoryIds: const [kSportsCategoryId, kPubGamesCategoryId]);
      expect(
          () => service.execute(
              id: tLeagueId, name: tName, rankingPolicy: simple),
          throwsArgumentError);
    });

    test(
        'existsAll false throws ArgumentError for Fargo valid ids but unknown category',
        () async {
      when(() => mockCategoryRepo.existsAll(any()))
          .thenAnswer((_) async => false);
      final policy = fargoWith(const [kSportsCategoryId, kPubGamesCategoryId]);
      expect(
          () => service.execute(
              id: tLeagueId, name: tName, rankingPolicy: policy),
          throwsArgumentError);
    });
  });
}
