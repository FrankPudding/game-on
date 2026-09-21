import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/application/services/create_league_service.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
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
  late MockLeagueRepository mockLeagueRepository;
  late MockRankingPolicyRepository mockRankingPolicyRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUp(() {
    mockLeagueRepository = MockLeagueRepository();
    mockRankingPolicyRepository = MockRankingPolicyRepository();
    mockCategoryRepository = MockCategoryRepository();
    service = CreateLeagueService(
      mockLeagueRepository,
      mockRankingPolicyRepository,
      mockCategoryRepository,
    );

    registerFallbackValue(FakeLeague());
    registerFallbackValue(FakeRankingPolicy());
  });

  const tLeagueId = 'league-123';
  const tLeagueName = 'Test League';

  final tRankingPolicy = SimpleRankingPolicy(
      id: 'policy-123',
      name: 'Test Policy',
      leagueId: tLeagueId,
      pointsForWin: 3,
      pointsForDraw: 1,
      pointsForLoss: 0,
      categoryIds: const ['cat_custom_league_001']);

  test('should create league and policy when valid', () async {
    // Arrange
    when(() => mockCategoryRepository.existsAll(any()))
        .thenAnswer((_) async => true);
    when(() => mockLeagueRepository.put(any())).thenAnswer((_) async {});
    when(() => mockRankingPolicyRepository.put(any())).thenAnswer((_) async {});

    // Act
    await service.execute(
      id: tLeagueId,
      name: tLeagueName,
      rankingPolicy: tRankingPolicy,
    );

    // Assert
    verify(() => mockLeagueRepository.put(any(
          that: isA<League>()
              .having((l) => l.id, 'id', tLeagueId)
              .having((l) => l.name, 'name', tLeagueName),
        ))).called(1);

    verify(() => mockRankingPolicyRepository.put(tRankingPolicy)).called(1);
  });

  test(
      'should throw ArgumentError when policy leagueId does not match league id',
      () async {
    // Arrange
    when(() => mockCategoryRepository.existsAll(any()))
        .thenAnswer((_) async => true);
    final invalidPolicy = SimpleRankingPolicy(
        id: 'policy-123',
        name: 'Test Policy',
        leagueId: 'different-league-id',
        pointsForWin: 3,
        pointsForDraw: 1,
        pointsForLoss: 0,
        categoryIds: const ['cat_custom_league_001']);

    // Act & Assert
    expect(
      () => service.execute(
        id: tLeagueId,
        name: tLeagueName,
        rankingPolicy: invalidPolicy,
      ),
      throwsArgumentError,
    );

    verifyZeroInteractions(mockLeagueRepository);
    verifyZeroInteractions(mockRankingPolicyRepository);
  });

  group('Custom-category enforcement for Simple and GoalDifference', () {
    // Helper to create policies with given categoryIds
    SimpleRankingPolicy simpleWith(List<String> ids) => SimpleRankingPolicy(
          id: 'policy-123',
          name: 'Test Policy',
          leagueId: tLeagueId,
          pointsForWin: 3,
          pointsForDraw: 1,
          pointsForLoss: 0,
          categoryIds: ids,
        );

    GoalDifferenceRankingPolicy gdWith(List<String> ids) =>
        GoalDifferenceRankingPolicy(
          id: 'policy-123',
          name: 'Test Policy',
          leagueId: tLeagueId,
          categoryIds: ids,
        );

    final nonCustomSingletons = {
      'cat_boardgames': ['cat_boardgames'],
      'cat_sports': ['cat_sports'],
      'cat_videogames': ['cat_videogames'],
      'cat_cardgames': ['cat_cardgames'],
    };

    for (final entry in nonCustomSingletons.entries) {
      test(
          'Simple policy with single non-custom ${entry.key} should throw ArgumentError',
          () async {
        when(() => mockCategoryRepository.existsAll(any()))
            .thenAnswer((_) async => true);
        when(() => mockLeagueRepository.put(any())).thenAnswer((_) async {});
        when(() => mockRankingPolicyRepository.put(any()))
            .thenAnswer((_) async {});

        final policy = simpleWith(entry.value);
        expect(
          () => service.execute(
            id: tLeagueId,
            name: tLeagueName,
            rankingPolicy: policy,
          ),
          throwsArgumentError,
        );
        // Verify enforcement fires before any put
        verifyNever(() => mockLeagueRepository.put(any()));
        verifyNever(() => mockRankingPolicyRepository.put(any()));
      });

      test(
          'GoalDifference policy with single non-custom ${entry.key} should throw ArgumentError',
          () async {
        when(() => mockCategoryRepository.existsAll(any()))
            .thenAnswer((_) async => true);
        when(() => mockLeagueRepository.put(any())).thenAnswer((_) async {});
        when(() => mockRankingPolicyRepository.put(any()))
            .thenAnswer((_) async {});

        final policy = gdWith(entry.value);
        expect(
          () => service.execute(
            id: tLeagueId,
            name: tLeagueName,
            rankingPolicy: policy,
          ),
          throwsArgumentError,
        );
        verifyNever(() => mockLeagueRepository.put(any()));
        verifyNever(() => mockRankingPolicyRepository.put(any()));
      });

      test(
          'Simple policy with explicit categoryIds ${entry.value} via param should throw',
          () async {
        when(() => mockCategoryRepository.existsAll(any()))
            .thenAnswer((_) async => true);
        final policy = simpleWith(entry.value);
        expect(
          () => service.execute(
            id: tLeagueId,
            name: tLeagueName,
            rankingPolicy: policy,
            categoryIds: entry.value,
          ),
          throwsArgumentError,
        );
      });

      test(
          'GoalDifference policy with explicit categoryIds ${entry.value} via param should throw',
          () async {
        when(() => mockCategoryRepository.existsAll(any()))
            .thenAnswer((_) async => true);
        final policy = gdWith(entry.value);
        expect(
          () => service.execute(
            id: tLeagueId,
            name: tLeagueName,
            rankingPolicy: policy,
            categoryIds: entry.value,
          ),
          throwsArgumentError,
        );
      });
    }

    test('Simple with [custom, boardgames] should throw ArgumentError',
        () async {
      when(() => mockCategoryRepository.existsAll(any()))
          .thenAnswer((_) async => true);
      final policy = simpleWith(const ['cat_custom_league_001', 'cat_boardgames']);
      expect(
        () => service.execute(
          id: tLeagueId,
          name: tLeagueName,
          rankingPolicy: policy,
        ),
        throwsArgumentError,
      );
      verifyNever(() => mockLeagueRepository.put(any()));
    });

    test('GoalDifference with [custom, boardgames] should throw ArgumentError',
        () async {
      when(() => mockCategoryRepository.existsAll(any()))
          .thenAnswer((_) async => true);
      final policy = gdWith(const ['cat_custom_league_001', 'cat_boardgames']);
      expect(
        () => service.execute(
          id: tLeagueId,
          name: tLeagueName,
          rankingPolicy: policy,
        ),
        throwsArgumentError,
      );
      verifyNever(() => mockLeagueRepository.put(any()));
    });

    test('Simple with [custom, boardgames] via explicit param should throw',
        () async {
      when(() => mockCategoryRepository.existsAll(any()))
          .thenAnswer((_) async => true);
      final policy = simpleWith(const ['cat_custom_league_001', 'cat_boardgames']);
      expect(
        () => service.execute(
          id: tLeagueId,
          name: tLeagueName,
          rankingPolicy: policy,
          categoryIds: const ['cat_custom_league_001', 'cat_boardgames'],
        ),
        throwsArgumentError,
      );
    });

    test('Simple with only custom should succeed', () async {
      when(() => mockCategoryRepository.existsAll(any()))
          .thenAnswer((_) async => true);
      when(() => mockLeagueRepository.put(any())).thenAnswer((_) async {});
      when(() => mockRankingPolicyRepository.put(any()))
          .thenAnswer((_) async {});

      final policy = simpleWith(const ['cat_custom_league_001']);
      await service.execute(
        id: tLeagueId,
        name: tLeagueName,
        rankingPolicy: policy,
      );
      verify(() => mockLeagueRepository.put(any())).called(1);
      verify(() => mockRankingPolicyRepository.put(policy)).called(1);
    });

    test('GoalDifference with only custom should succeed', () async {
      when(() => mockCategoryRepository.existsAll(any()))
          .thenAnswer((_) async => true);
      when(() => mockLeagueRepository.put(any())).thenAnswer((_) async {});
      when(() => mockRankingPolicyRepository.put(any()))
          .thenAnswer((_) async {});

      final policy = gdWith(const ['cat_custom_league_001']);
      await service.execute(
        id: tLeagueId,
        name: tLeagueName,
        rankingPolicy: policy,
      );
      verify(() => mockLeagueRepository.put(any())).called(1);
      verify(() => mockRankingPolicyRepository.put(policy)).called(1);
    });

    test('Simple with only custom via explicit param should succeed', () async {
      when(() => mockCategoryRepository.existsAll(any()))
          .thenAnswer((_) async => true);
      when(() => mockLeagueRepository.put(any())).thenAnswer((_) async {});
      when(() => mockRankingPolicyRepository.put(any()))
          .thenAnswer((_) async {});

      final policy = simpleWith(const ['cat_custom_league_001']);
      await service.execute(
        id: tLeagueId,
        name: tLeagueName,
        rankingPolicy: policy,
        categoryIds: const ['cat_custom_league_001'],
      );
      verify(() => mockLeagueRepository.put(any())).called(1);
    });

    test('GoalDifference via explicit param custom should succeed', () async {
      when(() => mockCategoryRepository.existsAll(any()))
          .thenAnswer((_) async => true);
      when(() => mockLeagueRepository.put(any())).thenAnswer((_) async {});
      when(() => mockRankingPolicyRepository.put(any()))
          .thenAnswer((_) async {});

      final policy = gdWith(const ['cat_custom_league_001']);
      await service.execute(
        id: tLeagueId,
        name: tLeagueName,
        rankingPolicy: policy,
        categoryIds: const ['cat_custom_league_001'],
      );
      verify(() => mockLeagueRepository.put(any())).called(1);
    });
  });

  group('Empty categoryIds boundary', () {
    test('should throw ArgumentError when categoryIds param is empty',
        () async {
      when(() => mockCategoryRepository.existsAll(any()))
          .thenAnswer((_) async => true);
      expect(
        () => service.execute(
          id: tLeagueId,
          name: tLeagueName,
          rankingPolicy: tRankingPolicy,
          categoryIds: const [],
        ),
        throwsArgumentError,
      );
      verifyNever(() => mockLeagueRepository.put(any()));
      verifyNever(() => mockRankingPolicyRepository.put(any()));
    });

    test('should throw ArgumentError when policy has empty via domain ctor',
        () {
      expect(
        () => SimpleRankingPolicy(
          id: 'policy-123',
          name: 'Test',
          leagueId: tLeagueId,
          categoryIds: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => GoalDifferenceRankingPolicy(
          id: 'policy-123',
          name: 'Test',
          leagueId: tLeagueId,
          categoryIds: const [],
        ),
        throwsArgumentError,
      );
    });

    test('should throw when computed idsToValidate empty via policy mismatch',
        () async {
      // Policy with valid ids but explicit empty override -> empty check fires before existsAll
      when(() => mockCategoryRepository.existsAll(any()))
          .thenAnswer((_) async => true);
      // Need a policy with non-empty ids but we override with empty via param and bypass consistency check
      // The service checks idsToValidate = categoryIds ?? policy.categoryIds, so empty param triggers empty guard
      expect(
        () => service.execute(
          id: tLeagueId,
          name: tLeagueName,
          rankingPolicy: tRankingPolicy,
          categoryIds: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}
