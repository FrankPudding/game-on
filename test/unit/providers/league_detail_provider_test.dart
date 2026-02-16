import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/users_provider.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockLeaguePlayerRepository extends Mock
    implements LeaguePlayerRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

void main() {
  late MockLeagueRepository mockLeagueRepo;
  late MockLeaguePlayerRepository mockPlayerRepo;
  late MockUserRepository mockUserRepo;
  late MockSimpleMatchRepository mockMatchRepo;
  late MockRankingPolicyRepository mockPolicyRepo;
  late ProviderContainer container;

  const tLeagueId = 'l1';
  final tRankingPolicy = SimpleRankingPolicy(
    id: 'rp1',
    name: 'Standard',
    leagueId: tLeagueId,
    pointsForWin: 3,
    pointsForDraw: 1,
    pointsForLoss: 0,
  );

  final tLeague = League(
    id: tLeagueId,
    name: 'Test League',
    createdAt: DateTime.now(),
  );

  final tPlayer1 = LeaguePlayer(
      id: 'p1',
      userId: 'u1',
      leagueId: tLeagueId,
      name: 'Player 1',
      avatarColorHex: 'FF0000');
  final tPlayer2 = LeaguePlayer(
      id: 'p2',
      userId: 'u2',
      leagueId: tLeagueId,
      name: 'Player 2',
      avatarColorHex: '00FF00');

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    mockPlayerRepo = MockLeaguePlayerRepository();
    mockUserRepo = MockUserRepository();
    mockMatchRepo = MockSimpleMatchRepository();
    mockPolicyRepo = MockRankingPolicyRepository();

    container = ProviderContainer(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
      ],
    );

    // Default mocks
    when(() => mockLeagueRepo.get(tLeagueId)).thenAnswer((_) async => tLeague);
    when(() => mockPlayerRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => [tPlayer1, tPlayer2]);
    when(() => mockMatchRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => []);
    when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
        .thenAnswer((_) async => tRankingPolicy);
  });

  tearDown(() {
    container.dispose();
  });

  group('LeagueDetailNotifier', () {
    test('initial state should be loading and then data', () async {
      container.listen(
          leagueDetailProvider(tLeagueId).notifier, (prev, next) {});

      expect(container.read(leagueDetailProvider(tLeagueId)).isLoading, true);

      await container.read(leagueDetailProvider(tLeagueId).future);

      final state = container.read(leagueDetailProvider(tLeagueId)).value;
      expect(state?.players.length, 2);
      expect(state?.matches.isEmpty, true);
    });

    test('should calculate stats correctly from matches and sides', () async {
      final s1 = Side(id: 's1', playerIds: ['p1']);
      final s2 = Side(id: 's2', playerIds: ['p2']);

      final m1 = SimpleMatch(
          id: 'm1',
          leagueId: tLeagueId,
          playedAt: DateTime.now(),
          isComplete: true,
          sides: [s1, s2],
          winnerSideId: 's1');

      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [m1]);

      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;

      expect(state.playerStats['p1']?.points, 3);
      expect(state.playerStats['p1']?.matchesPlayed, 1);
      expect(state.playerStats['p2']?.points, 0);
      expect(state.playerStats['p2']?.matchesPlayed, 1);

      // Player 1 should be first because they have more points
      expect(state.players.first.id, 'p1');
    });

    group('Edge Cases', () {
      test('should handle empty league with no players', () async {
        when(() => mockPlayerRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => []);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        expect(state.players, isEmpty);
        expect(state.playerStats, isEmpty);
      });

      test('should handle tied points with stable sorting', () async {
        final s1 = Side(id: 's1', playerIds: ['p1']);
        final s2 = Side(id: 's2', playerIds: ['p2']);

        final m1 = SimpleMatch(
            id: 'm1',
            leagueId: tLeagueId,
            playedAt: DateTime.now(),
            isComplete: true,
            isDraw: true,
            sides: [s1, s2]);

        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [m1]);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        expect(state.playerStats['p1']?.points, 1);
        expect(state.playerStats['p2']?.points, 1);
      });

      test('should handle match with player not in league', () async {
        final s3 = Side(id: 's3', playerIds: ['p3']);
        final s2 = Side(id: 's2', playerIds: ['p2']);

        final m1 = SimpleMatch(
            id: 'm1',
            leagueId: tLeagueId,
            playedAt: DateTime.now(),
            isComplete: true,
            sides: [s3, s2],
            winnerSideId: 's3');

        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [m1]);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        // Should not crash, and p3 statistics should be calculated
        expect(state.playerStats['p3']?.points, 3);
        expect(state.players.length,
            2); // Still just p1 and p2 in the displayed list
      });
    });

    test('addPlayer should call repository and refresh', () async {
      when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.addPlayer(name: 'New Player');

      verify(() => mockUserRepo.put(any(
              that: isA<User>().having((u) => u.name, 'name', 'New Player'))))
          .called(1);
      verify(() => mockPlayerRepo.put(any(
          that: isA<LeaguePlayer>()
              .having((p) => p.name, 'name', 'New Player')
              .having((p) => p.leagueId, 'leagueId', tLeagueId)))).called(1);
    });

    test('logSimpleMatch should create match and sides and refresh', () async {
      when(() => mockMatchRepo.logSimpleMatch(
            match: any(named: 'match'),
          )).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.logSimpleMatch(
          winnerId: 'p1', loserId: 'p2', isDraw: false);

      verify(() => mockMatchRepo.logSimpleMatch(
            match: any(named: 'match'),
          )).called(1);
    });
    group('Ranking Sort', () {
      test('should sort by points DESC, then matchesPlayed ASC', () async {
        // Player 1: 1 match, 3 points
        // Player 2: 2 matches, 3 points (P1 is ahead)
        final s1 = Side(id: 's1', playerIds: ['p1']);
        final s2 = Side(id: 's2', playerIds: ['p2']);

        // Let's do:
        // P1: 1 win (3 pts)
        // P2: 1 win + 1 loss (3 pts)
        final match = SimpleMatch(
            id: 'm1',
            leagueId: tLeagueId,
            playedAt: DateTime.now(),
            isComplete: true,
            sides: [s1, s2],
            winnerSideId: 's1');
        final s4 = Side(id: 's4', playerIds: ['p4']);
        final otherMatch = SimpleMatch(
            id: 'm2',
            leagueId: tLeagueId,
            playedAt: DateTime.now(),
            isComplete: true,
            sides: [s2, s4],
            winnerSideId: 's2');

        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [match, otherMatch]);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        expect(state.playerStats['p1']?.points, 3);
        expect(state.playerStats['p1']?.matchesPlayed, 1);
        expect(state.playerStats['p2']?.points, 3);
        expect(state.playerStats['p2']?.matchesPlayed, 2);

        expect(
            state.players.first.id, 'p1'); // P1 should be first (less matches)
      });
    });
  });

  setUpAll(() {
    registerFallbackValue(SimpleMatch(
        id: '',
        leagueId: '',
        playedAt: DateTime.now(),
        isComplete: false,
        sides: []));
    registerFallbackValue(Side(id: '', playerIds: []));
    registerFallbackValue(
        User(id: '', name: '', avatarColorHex: '', icon: null));
    registerFallbackValue(LeaguePlayer(
        id: '', userId: '', leagueId: '', name: '', avatarColorHex: ''));
  });
}
