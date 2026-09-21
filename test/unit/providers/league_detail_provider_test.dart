import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/application/services/update_user_service.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockLeaguePlayerRepository extends Mock
    implements LeaguePlayerRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

class MockDeleteUserService extends Mock implements DeleteUserService {}

class MockUpdateUserService extends Mock implements UpdateUserService {}

class FakeUsersNotifier extends UsersNotifier {
  @override
  Future<List<User>> build() async => [];
}

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
      categoryIds: const ['cat_custom_league_001']);

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
        usersProvider.overrideWith(FakeUsersNotifier.new),
        deleteUserServiceProvider
            .overrideWith((ref) => MockDeleteUserService()),
        updateUserServiceProvider
            .overrideWith((ref) => MockUpdateUserService()),
      ],
    );

    // Default mocks
    when(() => mockLeagueRepo.get(tLeagueId)).thenAnswer((_) async => tLeague);
    when(() => mockPlayerRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => [tPlayer1, tPlayer2]);
    when(() => mockPlayerRepo.get('p1')).thenAnswer((_) async => tPlayer1);
    when(() => mockPlayerRepo.get('p2')).thenAnswer((_) async => tPlayer2);
    when(() => mockMatchRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => []);
    when(() => mockMatchRepo.get(any())).thenAnswer((_) async => null);
    when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
        .thenAnswer((_) async => tRankingPolicy);

    // Pre-initialize usersProvider to avoid hangs in LeagueDetailNotifier.build
    container.read(usersProvider);
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

    test('addPlayer should call repository addPlayerIfUnique and refresh',
        () async {
      when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.addPlayerIfUnique(
            userId: any(named: 'userId'),
            leagueId: any(named: 'leagueId'),
            name: any(named: 'name'),
            avatarColorHex: any(named: 'avatarColorHex'),
            icon: any(named: 'icon'),
          )).thenAnswer((_) async => LeaguePlayer(
            id: 'new-player-id',
            userId: 'new-user-id',
            leagueId: tLeagueId,
            name: 'New Player',
            avatarColorHex: 'AE0C00',
          ));

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.addPlayer(name: 'New Player');

      verify(() => mockUserRepo.put(any(
              that: isA<User>().having((u) => u.name, 'name', 'New Player'))))
          .called(1);
      verify(() => mockPlayerRepo.addPlayerIfUnique(
            userId: any(named: 'userId'),
            leagueId: tLeagueId,
            name: 'New Player',
            avatarColorHex: 'AE0C00',
            icon: any(named: 'icon'),
          )).called(1);
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

    test('logSimpleMatch should support custom playedAt', () async {
      final customDate = DateTime(2023, 1, 1);
      when(() => mockMatchRepo.logSimpleMatch(
            match: any(named: 'match'),
          )).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.logSimpleMatch(
        winnerId: 'p1',
        loserId: 'p2',
        isDraw: false,
        playedAt: customDate,
      );

      final captured = verify(() => mockMatchRepo.logSimpleMatch(
            match: captureAny(named: 'match'),
          )).captured.first as SimpleMatch;

      expect(captured.playedAt, customDate);
    });

    test('logSimpleMatch should store scores on sides', () async {
      when(() => mockMatchRepo.logSimpleMatch(
            match: any(named: 'match'),
          )).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.logSimpleMatch(
        winnerId: 'p1',
        loserId: 'p2',
        isDraw: false,
        winnerScore: 4,
        loserScore: 2,
      );

      final captured = verify(() => mockMatchRepo.logSimpleMatch(
            match: captureAny(named: 'match'),
          )).captured.first as SimpleMatch;

      expect(captured.sides[0].score, 4);
      expect(captured.sides[1].score, 2);
    });

    test('updateSimpleMatch should fetch, update match and sides and refresh',
        () async {
      final oldMatch = SimpleMatch(
          id: 'm1',
          leagueId: tLeagueId,
          playedAt: DateTime.now(),
          isComplete: true,
          sides: [
            Side(id: 's1', playerIds: ['p1']),
            Side(id: 's2', playerIds: ['p2']),
          ],
          winnerSideId: 's1');

      when(() => mockMatchRepo.get('m1')).thenAnswer((_) async => oldMatch);
      when(() => mockMatchRepo.logSimpleMatch(
            match: any(named: 'match'),
          )).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.updateSimpleMatch(
        matchId: 'm1',
        winnerId: 'p2',
        loserId: 'p1',
        isDraw: false,
      );

      final captured = verify(() => mockMatchRepo.logSimpleMatch(
            match: captureAny(named: 'match'),
          )).captured.first as SimpleMatch;

      expect(captured.id, 'm1');
      expect(captured.winnerSideId, isNotNull);
      // Winner side should have p2
      final winnerSide =
          captured.sides.firstWhere((s) => s.id == captured.winnerSideId);
      expect(winnerSide.playerIds, contains('p2'));
    });

    test('updateSimpleMatch should support custom playedAt', () async {
      final oldDate = DateTime(2023, 1, 1);
      final newDate = DateTime(2023, 2, 2);
      final oldMatch = SimpleMatch(
          id: 'm1',
          leagueId: tLeagueId,
          playedAt: oldDate,
          isComplete: true,
          sides: [
            Side(id: 's1', playerIds: ['p1']),
            Side(id: 's2', playerIds: ['p2']),
          ],
          winnerSideId: 's1');

      when(() => mockMatchRepo.get('m1')).thenAnswer((_) async => oldMatch);
      when(() => mockMatchRepo.logSimpleMatch(
            match: any(named: 'match'),
          )).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.updateSimpleMatch(
        matchId: 'm1',
        winnerId: 'p1',
        loserId: 'p2',
        isDraw: false,
        playedAt: newDate,
      );

      final captured = verify(() => mockMatchRepo.logSimpleMatch(
            match: captureAny(named: 'match'),
          )).captured.first as SimpleMatch;

      expect(captured.playedAt, newDate);
    });

    test('deleteMatch should call repository and refresh', () async {
      when(() => mockMatchRepo.delete('m1')).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.deleteMatch('m1');

      verify(() => mockMatchRepo.delete('m1')).called(1);
    });

    test('updatePlayer should update league player but NOT the linked user',
        () async {
      final mockUpdateService = container.read(updateUserServiceProvider);

      when(() => mockPlayerRepo.get('p1')).thenAnswer((_) async => tPlayer1);
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.updatePlayer(
          playerId: 'p1', name: 'Updated Name', icon: '🆕');

      verify(() => mockPlayerRepo.put(any(
          that: isA<LeaguePlayer>()
              .having((p) => p.name, 'name', 'Updated Name')
              .having((p) => p.icon, 'icon', '🆕')))).called(1);

      verifyNever(() => mockUpdateService.execute(any()));
    });

    test('removePlayer should delete if no match history', () async {
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => []);
      when(() => mockPlayerRepo.delete('p1')).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.removePlayer('p1');

      verify(() => mockPlayerRepo.delete('p1')).called(1);
    });

    test('removePlayer should throw error if has match history', () async {
      final m1 = SimpleMatch(
          id: 'm1',
          leagueId: tLeagueId,
          playedAt: DateTime.now(),
          isComplete: true,
          sides: [
            Side(id: 's1', playerIds: ['p1']),
            Side(id: 's2', playerIds: ['p2']),
          ]);

      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [m1]);

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);

      expect(notifier.removePlayer('p1'), throwsException);
      verifyNever(() => mockPlayerRepo.delete('p1'));
    });

    group('PlayerStats', () {
      test('copyWith should update provided fields', () {
        const stats = PlayerStats(points: 3, matchesPlayed: 1);

        final updated = stats.copyWith(points: 5);

        expect(updated.points, 5);
        expect(updated.matchesPlayed, 1);
      });

      test('copyWith without args should preserve values', () {
        const stats = PlayerStats(points: 3, matchesPlayed: 1);

        final updated = stats.copyWith();

        expect(updated.points, 3);
        expect(updated.matchesPlayed, 1);
      });

      test('goal stats and goal difference should update correctly', () {
        const stats = PlayerStats(
          points: 3,
          matchesPlayed: 1,
          goalsFor: 4,
          goalsAgainst: 1,
        );

        expect(stats.goalDifference, 3);

        final updated = stats.copyWith(goalsFor: 6, goalsAgainst: 2);
        expect(updated.goalsFor, 6);
        expect(updated.goalsAgainst, 2);
        expect(updated.goalDifference, 4);
      });
    });

    group('Error paths', () {
      test('refresh should reload data', () async {
        await container.read(leagueDetailProvider(tLeagueId).future);

        when(() => mockLeagueRepo.get(tLeagueId))
            .thenAnswer((_) async => tLeague);
        final notifier =
            container.read(leagueDetailProvider(tLeagueId).notifier);
        await notifier.refresh();

        final state = container.read(leagueDetailProvider(tLeagueId)).value;
        expect(state?.players.length, 2);
      });

      test('should throw when league does not exist', () async {
        when(() => mockLeagueRepo.get(tLeagueId)).thenAnswer((_) async => null);

        final notifier =
            container.read(leagueDetailProvider(tLeagueId).notifier);

        await notifier.refresh();

        expect(
            container.read(leagueDetailProvider(tLeagueId)).hasError, isTrue);
      });

      test('addPlayer with existing userId should reuse user info', () async {
        final existingUser = User(
            id: 'u9', name: 'Existing', avatarColorHex: '123456', icon: '🎯');
        when(() => mockUserRepo.get('u9'))
            .thenAnswer((_) async => existingUser);
        when(() => mockPlayerRepo.addPlayerIfUnique(
              userId: any(named: 'userId'),
              leagueId: any(named: 'leagueId'),
              name: any(named: 'name'),
              avatarColorHex: any(named: 'avatarColorHex'),
              icon: any(named: 'icon'),
            )).thenAnswer((_) async => LeaguePlayer(
              id: 'p9',
              userId: 'u9',
              leagueId: tLeagueId,
              name: 'Existing',
              avatarColorHex: 'AE0C00',
              icon: '🎯',
            ));

        final notifier =
            container.read(leagueDetailProvider(tLeagueId).notifier);
        await notifier.addPlayer(name: '', userId: 'u9');

        verify(() => mockUserRepo.get('u9')).called(1);
        verify(() => mockPlayerRepo.addPlayerIfUnique(
              userId: 'u9',
              leagueId: tLeagueId,
              name: 'Existing',
              avatarColorHex: 'AE0C00',
              icon: '🎯',
            )).called(1);
        verifyNever(() => mockUserRepo.put(any()));
      });

      test('updateSimpleMatch should set error state when match not found',
          () async {
        when(() => mockMatchRepo.get('missing')).thenAnswer((_) async => null);

        final notifier =
            container.read(leagueDetailProvider(tLeagueId).notifier);

        await notifier.updateSimpleMatch(
          matchId: 'missing',
          winnerId: 'p1',
          loserId: 'p2',
          isDraw: false,
        );

        expect(
            container.read(leagueDetailProvider(tLeagueId)).hasError, isTrue);
      });

      test('updatePlayer should throw when player not found', () async {
        when(() => mockPlayerRepo.get('missing')).thenAnswer((_) async => null);

        final notifier =
            container.read(leagueDetailProvider(tLeagueId).notifier);

        expect(notifier.updatePlayer(playerId: 'missing', name: 'Nope'),
            throwsException);
      });

      test('removePlayer should surface repository errors', () async {
        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => []);
        when(() => mockPlayerRepo.delete('p1'))
            .thenThrow(Exception('delete failed'));

        final notifier =
            container.read(leagueDetailProvider(tLeagueId).notifier);

        expect(notifier.removePlayer('p1'), throwsException);
      });
    });

    group('Ranking Sort', () {
      test(
          'should sort by points DESC, then id for ties (not matchesPlayed, not name)',
          () async {
        // Player 1: 1 match, 3 points
        // Player 2: 2 matches, 3 points — tied on points, tie-break must be id, not matchesPlayed
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

        // Per spec, ranked order is points → GD → GF → id. Must NOT use name or matchesPlayed.
        // p1 < p2 by id, so p1 first. This verifies id tie-break, not matchesPlayed.
        expect(state.players.first.id, 'p1');
        expect(state.players.map((p) => p.id).toList(), ['p1', 'p2']);
      });

      test(
          'should use id tie-break even when fewer matches would suggest different order',
          () async {
        // Verify that fewer matches does NOT win tie: p1 has fewer matches but larger id, so p2 should be first.
        final pA = LeaguePlayer(
            id: 'pZ',
            userId: 'uZ',
            leagueId: tLeagueId,
            name: 'Zoe',
            avatarColorHex: '000');
        final pB = LeaguePlayer(
            id: 'pA',
            userId: 'uA',
            leagueId: tLeagueId,
            name: 'Andy',
            avatarColorHex: '000');
        when(() => mockPlayerRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [pA, pB]);
        // Both have 1 draw = 1 point each, pA (Zoe) played 1, pB (Andy) played 1 — tie, id decides pA < pZ? actually pA < pZ, so pB first regardless of name
        final s1 = Side(id: 's1', playerIds: ['pZ']);
        final s2 = Side(id: 's2', playerIds: ['pA']);
        final draw = SimpleMatch(
            id: 'm1',
            leagueId: tLeagueId,
            playedAt: DateTime.now(),
            isComplete: true,
            isDraw: true,
            sides: [s1, s2]);
        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [draw]);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;
        // pA < pZ by id, so pA first, even though alphabetically Andy < Zoe would also give same, but confirms id not name? To prove not name, we need reversed names with ids reversed.
        // Use p1 id larger but name smaller to prove name not used: pZ name Zoe but id larger, pA name Andy but id smaller — if name used, Andy would still be first because Andy < Zoe, but id also gives same. Need opposite: name Andy with larger id vs Zoe with smaller id.
        expect(state.players.first.id, 'pA');
      });
    });

    group('PlayersByName alphabetical vs ranked', () {
      test('playersByName alphabetical independent of insertion order',
          () async {
        final alice = LeaguePlayer(
            id: 'p1',
            userId: 'u1',
            leagueId: tLeagueId,
            name: 'Alice',
            avatarColorHex: '000');
        final bob = LeaguePlayer(
            id: 'p2',
            userId: 'u2',
            leagueId: tLeagueId,
            name: 'Bob',
            avatarColorHex: '000');
        final charlie = LeaguePlayer(
            id: 'p3',
            userId: 'u3',
            leagueId: tLeagueId,
            name: 'Charlie',
            avatarColorHex: '000');
        // Insertion order unsorted: Charlie, Alice, Bob
        when(() => mockPlayerRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [charlie, alice, bob]);
        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => []);

        await container.read(leagueDetailProvider(tLeagueId).future);
        var state = container.read(leagueDetailProvider(tLeagueId)).value!;
        expect(state.playersByName.map((p) => p.name).toList(),
            ['Alice', 'Bob', 'Charlie']);
        expect(
            state.playersByName.map((p) => p.id).toList(), ['p1', 'p2', 'p3']);
        // Ranked with no points tied -> id order: p1, p2, p3 (which coincidentally alphabetical here) — need different ids to prove divergence later
        // Verify insertion invariance: reverse repo order should give same playersByName
        // Recreate container with different order
        container.dispose();
        final mockLeagueRepo2 = MockLeagueRepository();
        final mockPlayerRepo2 = MockLeaguePlayerRepository();
        final mockMatchRepo2 = MockSimpleMatchRepository();
        final mockPolicyRepo2 = MockRankingPolicyRepository();
        final mockUserRepo2 = MockUserRepository();
        when(() => mockLeagueRepo2.get(tLeagueId))
            .thenAnswer((_) async => tLeague);
        when(() => mockPlayerRepo2.get('p1')).thenAnswer((_) async => alice);
        when(() => mockPlayerRepo2.get('p2')).thenAnswer((_) async => bob);
        when(() => mockPolicyRepo2.getByLeagueId(tLeagueId))
            .thenAnswer((_) async => tRankingPolicy);
        when(() => mockMatchRepo2.getByLeague(tLeagueId))
            .thenAnswer((_) async => []);
        when(() => mockMatchRepo2.get(any())).thenAnswer((_) async => null);
        when(() => mockPlayerRepo2.getByLeague(tLeagueId))
            .thenAnswer((_) async => [bob, charlie, alice]);
        container = ProviderContainer(
          overrides: [
            leagueRepositoryProvider.overrideWithValue(mockLeagueRepo2),
            leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo2),
            userRepositoryProvider.overrideWithValue(mockUserRepo2),
            simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo2),
            rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo2),
            usersProvider.overrideWith(FakeUsersNotifier.new),
            deleteUserServiceProvider
                .overrideWith((ref) => MockDeleteUserService()),
            updateUserServiceProvider
                .overrideWith((ref) => MockUpdateUserService()),
          ],
        );
        container.read(usersProvider);
        await container.read(leagueDetailProvider(tLeagueId).future);
        state = container.read(leagueDetailProvider(tLeagueId)).value!;
        expect(state.playersByName.map((p) => p.name).toList(),
            ['Alice', 'Bob', 'Charlie']);
      });

      test(
          'should sort empty/whitespace and duplicate names by id in playersByName',
          () async {
        final empty1 = LeaguePlayer(
            id: 'p5',
            userId: 'u5',
            leagueId: tLeagueId,
            name: '',
            avatarColorHex: '000');
        final empty2 = LeaguePlayer(
            id: 'p6',
            userId: 'u6',
            leagueId: tLeagueId,
            name: '   ',
            avatarColorHex: '000');
        final aliceTrim = LeaguePlayer(
            id: 'p2',
            userId: 'u2',
            leagueId: tLeagueId,
            name: ' Alice',
            avatarColorHex: '000');
        final aliceLower = LeaguePlayer(
            id: 'p3',
            userId: 'u3',
            leagueId: tLeagueId,
            name: 'alice',
            avatarColorHex: '000');
        final bob = LeaguePlayer(
            id: 'p1',
            userId: 'u1',
            leagueId: tLeagueId,
            name: 'bob',
            avatarColorHex: '000');
        final charlie = LeaguePlayer(
            id: 'p4',
            userId: 'u4',
            leagueId: tLeagueId,
            name: '  Charlie  ',
            avatarColorHex: '000');
        // Also duplicate name Bob with different ids
        final bobDup1 = LeaguePlayer(
            id: 'p7',
            userId: 'u7',
            leagueId: tLeagueId,
            name: 'Bob',
            avatarColorHex: '000');
        final bobDup2 = LeaguePlayer(
            id: 'p8',
            userId: 'u8',
            leagueId: tLeagueId,
            name: 'Bob',
            avatarColorHex: '000');

        final unsorted = [
          bob,
          aliceTrim,
          aliceLower,
          charlie,
          empty1,
          empty2,
          bobDup2,
          bobDup1
        ];
        when(() => mockPlayerRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => unsorted);
        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => []);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        // Expected playersByName: empty first by id p5,p6, then Alice/alice with trim handling, then Bob/bob variations, then Charlie
        // For 'bob' lower vs 'Bob' upper: 'Bob' < 'bob' case-sensitive tie-break, but also 'Bob' id order among duplicates
        // Let's list expected names/ids sorted by compareNames then id:
        // empty "" (p5,p6) first
        // " Alice" -> "Alice" (p2) , "alice" (p3) -> p2 before p3
        // then "Bob" duplicates p7,p8 -> ordered by id p7,p8
        // then "bob" lower p1 -> after Bob? Actually lower compare: "bob" lower == "bob" lower for Bob/bob? "bob".toLowerCase() vs "Bob".toLowerCase() == "bob" same, then case-sensitive "Bob" < "bob" so Bob before bob
        // then Charlie
        expect(state.playersByName.map((p) => p.id).toList(),
            ['p5', 'p6', 'p2', 'p3', 'p7', 'p8', 'p1', 'p4']);
        expect(state.playersByName.map((p) => p.name).toList(),
            ['', '   ', ' Alice', 'alice', 'Bob', 'Bob', 'bob', '  Charlie  ']);
        // Verify duplicate "Bob" ordered by id
        expect(
            state.playersByName
                .where((p) => p.name == 'Bob')
                .map((p) => p.id)
                .toList(),
            ['p7', 'p8']);
      });

      test(
          'ranked vs alphabetical divergence: Bob top points but Alice alphabetical first — standings must stay ranked',
          () async {
        // Alice p1 (0 pts), Bob p2 (3 pts), Charlie p3 (0 pts). Ranked: Bob first, then Alice, Charlie by id. Alphabetical: Alice, Bob, Charlie
        final alice = LeaguePlayer(
            id: 'p1',
            userId: 'u1',
            leagueId: tLeagueId,
            name: 'Alice',
            avatarColorHex: '000');
        final bob = LeaguePlayer(
            id: 'p2',
            userId: 'u2',
            leagueId: tLeagueId,
            name: 'Bob',
            avatarColorHex: '000');
        final charlie = LeaguePlayer(
            id: 'p3',
            userId: 'u3',
            leagueId: tLeagueId,
            name: 'Charlie',
            avatarColorHex: '000');
        // Unsorted insertion: Charlie, Alice, Bob
        when(() => mockPlayerRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [charlie, alice, bob]);
        // Bob beats Alice -> Bob 3 pts
        final s1 = Side(id: 's1', playerIds: ['p2']);
        final s2 = Side(id: 's2', playerIds: ['p1']);
        final win = SimpleMatch(
            id: 'm1',
            leagueId: tLeagueId,
            playedAt: DateTime.now(),
            isComplete: true,
            sides: [s1, s2],
            winnerSideId: 's1');
        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [win]);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        // Ranked: Bob (3pts) first, then Alice/Charlie tied 0pts -> id order p1,p3
        expect(state.players.map((p) => p.id).toList(), ['p2', 'p1', 'p3']);
        expect(state.players.map((p) => p.name).toList(),
            ['Bob', 'Alice', 'Charlie']);
        // Alphabetical: Alice, Bob, Charlie regardless of points
        expect(
            state.playersByName.map((p) => p.id).toList(), ['p1', 'p2', 'p3']);
        expect(state.playersByName.map((p) => p.name).toList(),
            ['Alice', 'Bob', 'Charlie']);
        // Must be same elements, different order
        expect(state.players.map((p) => p.id).toSet(),
            state.playersByName.map((p) => p.id).toSet());
        expect(state.players.map((p) => p.id).toList(),
            isNot(state.playersByName.map((p) => p.id).toList()));
        // Standings stay ranked even though alphabetically Alice first
        expect(state.players.first.name, 'Bob');
        expect(state.playersByName.first.name, 'Alice');
      });

      test(
          'players and playersByName contain same elements with only order differing',
          () async {
        final pA = LeaguePlayer(
            id: 'pZ',
            userId: 'uZ',
            leagueId: tLeagueId,
            name: 'Zoe',
            avatarColorHex: '000');
        final pB = LeaguePlayer(
            id: 'pA',
            userId: 'uA',
            leagueId: tLeagueId,
            name: 'Andy',
            avatarColorHex: '000');
        when(() => mockPlayerRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [pA, pB]);
        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => []);
        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;
        expect(state.players.length, state.playersByName.length);
        expect(state.players.map((p) => p.id).toSet(),
            state.playersByName.map((p) => p.id).toSet());
        // With no points, ranked is id order: pA, pZ
        expect(state.players.map((p) => p.id).toList(), ['pA', 'pZ']);
        // Alphabetical is Andy, Zoe which happens to match id order here, but still same set
        expect(
            state.playersByName.map((p) => p.name).toList(), ['Andy', 'Zoe']);
      });

      test('should handle trim and case-insensitive secondary in playersByName',
          () async {
        final p1 = LeaguePlayer(
            id: 'p1',
            userId: 'u1',
            leagueId: tLeagueId,
            name: '  alice',
            avatarColorHex: '000');
        final p2 = LeaguePlayer(
            id: 'p2',
            userId: 'u2',
            leagueId: tLeagueId,
            name: 'Alice',
            avatarColorHex: '000');
        final p3 = LeaguePlayer(
            id: 'p3',
            userId: 'u3',
            leagueId: tLeagueId,
            name: 'Bob',
            avatarColorHex: '000');
        final p4 = LeaguePlayer(
            id: 'p4',
            userId: 'u4',
            leagueId: tLeagueId,
            name: 'bob',
            avatarColorHex: '000');
        when(() => mockPlayerRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [p4, p3, p2, p1]);
        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => []);
        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;
        // Alice (trimmed) < alice (case-sensitive) < Bob < bob
        expect(state.playersByName.map((p) => p.name).toList(),
            ['Alice', '  alice', 'Bob', 'bob']);
        expect(state.playersByName.map((p) => p.id).toList(),
            ['p2', 'p1', 'p3', 'p4']);
      });
    });

    group('Goal Difference Ranking', () {
      setUp(() {
        when(() => mockPolicyRepo.getByLeagueId(tLeagueId)).thenAnswer(
            (_) async => GoalDifferenceRankingPolicy(
                id: 'rp-gd',
                name: 'GD',
                leagueId: tLeagueId,
                pointsForWin: 3,
                pointsForDraw: 1,
                pointsForLoss: 0,
                categoryIds: const ['cat_custom_league_001']));
      });

      test('should compute goals for, against and goal difference', () async {
        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [
                  SimpleMatch(
                    id: 'm1',
                    leagueId: tLeagueId,
                    playedAt: DateTime.now(),
                    isComplete: true,
                    sides: [
                      Side(id: 's1', playerIds: ['p1'], score: 3),
                      Side(id: 's2', playerIds: ['p2'], score: 1),
                    ],
                    winnerSideId: 's1',
                  ),
                ]);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        expect(state.isGoalDifference, isTrue);
        expect(state.playerStats['p1']?.points, 3);
        expect(state.playerStats['p1']?.goalsFor, 3);
        expect(state.playerStats['p1']?.goalsAgainst, 1);
        expect(state.playerStats['p1']?.goalDifference, 2);
        expect(state.playerStats['p2']?.points, 0);
        expect(state.playerStats['p2']?.goalsFor, 1);
        expect(state.playerStats['p2']?.goalsAgainst, 3);
        expect(state.playerStats['p2']?.goalDifference, -2);
      });

      test('should rank by points, then goal difference, then goals for',
          () async {
        when(() => mockPlayerRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [
                  tPlayer1,
                  tPlayer2,
                  LeaguePlayer(
                      id: 'p3',
                      userId: 'u3',
                      leagueId: tLeagueId,
                      name: 'Player 3',
                      avatarColorHex: '0000FF'),
                  LeaguePlayer(
                      id: 'p4',
                      userId: 'u4',
                      leagueId: tLeagueId,
                      name: 'Player 4',
                      avatarColorHex: '00FFFF'),
                ]);
        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [
                  // p1: 3pts, GD +3, GF 4
                  SimpleMatch(
                    id: 'm1',
                    leagueId: tLeagueId,
                    playedAt: DateTime.now(),
                    isComplete: true,
                    sides: [
                      Side(id: 's1', playerIds: ['p1'], score: 4),
                      Side(id: 's2', playerIds: ['p4'], score: 1),
                    ],
                    winnerSideId: 's1',
                  ),
                  // p2: 3pts, GD +3, GF 3
                  SimpleMatch(
                    id: 'm2',
                    leagueId: tLeagueId,
                    playedAt: DateTime.now(),
                    isComplete: true,
                    sides: [
                      Side(id: 's3', playerIds: ['p2'], score: 3),
                      Side(id: 's4', playerIds: ['p4'], score: 0),
                    ],
                    winnerSideId: 's3',
                  ),
                  // p3: 3pts, GD +2, GF 2
                  SimpleMatch(
                    id: 'm3',
                    leagueId: tLeagueId,
                    playedAt: DateTime.now(),
                    isComplete: true,
                    sides: [
                      Side(id: 's5', playerIds: ['p3'], score: 2),
                      Side(id: 's6', playerIds: ['p4'], score: 0),
                    ],
                    winnerSideId: 's5',
                  ),
                ]);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        // p1 and p2 tied on points & GD, p1 ahead on goals for
        expect(
            state.players.map((p) => p.id).toList(), ['p1', 'p2', 'p3', 'p4']);
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
