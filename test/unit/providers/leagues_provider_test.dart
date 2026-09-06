import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/application/services/create_league_service.dart';
import 'package:game_on/providers/leagues_provider.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

class MockCreateLeagueService extends Mock implements CreateLeagueService {}

void main() {
  late MockLeagueRepository mockLeagueRepo;
  late MockRankingPolicyRepository mockPolicyRepo;
  late MockCreateLeagueService mockCreateService;
  late ProviderContainer container;

  final tLeague1 =
      League(id: 'l1', name: 'League 1', createdAt: DateTime(2023, 1, 1));
  final tLeague2 =
      League(id: 'l2', name: 'League 2', createdAt: DateTime(2023, 2, 2));

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    mockPolicyRepo = MockRankingPolicyRepository();
    mockCreateService = MockCreateLeagueService();

    container = ProviderContainer(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
        createLeagueServiceProvider.overrideWithValue(mockCreateService),
      ],
    );

    registerFallbackValue(
        SimpleRankingPolicy(id: 'rp1', name: 'Standard', leagueId: 'l1'));
  });

  tearDown(() {
    container.dispose();
  });

  group('LeaguesNotifier', () {
    test('initial state should fetch leagues from repository', () async {
      when(() => mockLeagueRepo.getAll())
          .thenAnswer((_) async => [tLeague1, tLeague2]);

      final leagues = await container.read(leaguesProvider.future);

      expect(leagues, [tLeague1, tLeague2]);
      verify(() => mockLeagueRepo.getAll()).called(1);
    });

    test('addLeague should call create service and refresh state', () async {
      when(() => mockLeagueRepo.getAll()).thenAnswer((_) async => [tLeague1]);
      when(() => mockCreateService.execute(
            id: any(named: 'id'),
            name: any(named: 'name'),
            rankingPolicy: any(named: 'rankingPolicy'),
          )).thenAnswer((_) async => {});

      final notifier = container.read(leaguesProvider.notifier);

      await container.read(leaguesProvider.future);

      final newLeague =
          League(id: 'l3', name: 'League 3', createdAt: DateTime(2023, 3, 3));
      final newPolicy =
          SimpleRankingPolicy(id: 'rp3', name: 'Standard', leagueId: 'l3');
      // Return the updated list for all subsequent calls (including invalidation rebuild)
      when(() => mockLeagueRepo.getAll())
          .thenAnswer((_) async => [tLeague1, newLeague]);

      await notifier.addLeague(
          id: 'l3', name: 'League 3', rankingPolicy: newPolicy);

      final state = container.read(leaguesProvider).value;
      expect(state, [tLeague1, newLeague]);
      verify(() => mockCreateService.execute(
            id: 'l3',
            name: 'League 3',
            rankingPolicy: newPolicy,
          )).called(1);
    });

    test('deleteLeague should call repository and refresh state', () async {
      when(() => mockLeagueRepo.getAll())
          .thenAnswer((_) async => [tLeague1, tLeague2]);
      when(() => mockLeagueRepo.delete('l1')).thenAnswer((_) async => {});

      final notifier = container.read(leaguesProvider.notifier);

      await container.read(leaguesProvider.future);

      // Return the updated list for all subsequent calls (including invalidation rebuild)
      when(() => mockLeagueRepo.getAll()).thenAnswer((_) async => [tLeague2]);

      await notifier.deleteLeague('l1');

      final state = container.read(leaguesProvider).value;
      expect(state, [tLeague2]);
      verify(() => mockLeagueRepo.delete('l1')).called(1);
    });

    test('addLeague should surface errors in state', () async {
      when(() => mockLeagueRepo.getAll()).thenAnswer((_) async => [tLeague1]);
      when(() => mockCreateService.execute(
            id: any(named: 'id'),
            name: any(named: 'name'),
            rankingPolicy: any(named: 'rankingPolicy'),
          )).thenThrow(Exception('Failed to create'));

      final notifier = container.read(leaguesProvider.notifier);

      await container.read(leaguesProvider.future);

      await notifier.addLeague(
        id: 'l3',
        name: 'League 3',
        rankingPolicy:
            SimpleRankingPolicy(id: 'rp3', name: 'Standard', leagueId: 'l3'),
      );

      expect(container.read(leaguesProvider).hasError, isTrue);
      expect(container.read(leaguesProvider).error.toString(),
          contains('Failed to create'));
    });
  });
}
