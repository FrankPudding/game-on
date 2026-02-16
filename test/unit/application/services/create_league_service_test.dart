import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/application/services/create_league_service.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

class FakeLeague extends Fake implements League {}

class FakeRankingPolicy extends Fake implements RankingPolicy {}

void main() {
  late CreateLeagueService service;
  late MockLeagueRepository mockLeagueRepository;
  late MockRankingPolicyRepository mockRankingPolicyRepository;

  setUp(() {
    mockLeagueRepository = MockLeagueRepository();
    mockRankingPolicyRepository = MockRankingPolicyRepository();
    service = CreateLeagueService(
      mockLeagueRepository,
      mockRankingPolicyRepository,
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
  );

  test('should create league and policy when valid', () async {
    // Arrange
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
    final invalidPolicy = SimpleRankingPolicy(
      id: 'policy-123',
      name: 'Test Policy',
      leagueId: 'different-league-id',
      pointsForWin: 3,
      pointsForDraw: 1,
      pointsForLoss: 0,
    );

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
}
