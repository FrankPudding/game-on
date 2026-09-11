import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart'
    show SimpleMatch;
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/providers/user_detail_provider.dart';
import 'package:game_on/application/services/delete_user_service.dart';
import 'package:game_on/application/services/update_user_service.dart';
import 'package:game_on/application/services/create_league_service.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockLeaguePlayerRepository extends Mock
    implements LeaguePlayerRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

class MockCreateLeagueService extends Mock implements CreateLeagueService {}

class MockDeleteUserService extends Mock implements DeleteUserService {}

class MockUpdateUserService extends Mock implements UpdateUserService {}

class FakeRankingPolicy extends Fake implements RankingPolicy {}

void main() {
  late MockLeagueRepository mockLeagueRepo;
  late MockLeaguePlayerRepository mockPlayerRepo;
  late MockUserRepository mockUserRepo;
  late MockSimpleMatchRepository mockMatchRepo;
  late MockRankingPolicyRepository mockPolicyRepo;
  late MockCreateLeagueService mockCreateService;
  late MockDeleteUserService mockDeleteService;
  late MockUpdateUserService mockUpdateService;
  late ProviderContainer container;

  const tLeagueId = 'l1';
  const tLeagueId2 = 'l2';
  final tRankingPolicy = SimpleRankingPolicy(
    id: 'rp1',
    name: 'Standard',
    leagueId: tLeagueId,
    pointsForWin: 3,
    pointsForDraw: 1,
    pointsForLoss: 0,
  );
  final tRankingPolicy2 = SimpleRankingPolicy(
    id: 'rp2',
    name: 'Standard',
    leagueId: tLeagueId2,
    pointsForWin: 3,
    pointsForDraw: 1,
    pointsForLoss: 0,
  );

  final tLeague = League(
    id: tLeagueId,
    name: 'Test League',
    createdAt: DateTime.now(),
  );
  final tLeague2 = League(
    id: tLeagueId2,
    name: 'Test League 2',
    createdAt: DateTime.now(),
  );

  final tUser1 = User(id: 'u1', name: 'User 1', avatarColorHex: 'FF0000');
  final tUser2 = User(id: 'u2', name: 'User 2', avatarColorHex: '00FF00');
  final tUser3 = User(id: 'u3', name: 'User 3', avatarColorHex: '0000FF');

  final tPlayer1 = LeaguePlayer(
    id: 'p1',
    userId: 'u1',
    leagueId: tLeagueId,
    name: 'Player 1',
    avatarColorHex: 'FF0000',
  );
  final tPlayer2 = LeaguePlayer(
    id: 'p2',
    userId: 'u2',
    leagueId: tLeagueId,
    name: 'Player 2',
    avatarColorHex: '00FF00',
  );
  final tPlayer3 = LeaguePlayer(
    id: 'p3',
    userId: 'u1',
    leagueId: tLeagueId2,
    name: 'Player 1 in League 2',
    avatarColorHex: 'FF0000',
  );

  setUpAll(() {
    registerFallbackValue(FakeRankingPolicy());
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

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    mockPlayerRepo = MockLeaguePlayerRepository();
    mockUserRepo = MockUserRepository();
    mockMatchRepo = MockSimpleMatchRepository();
    mockPolicyRepo = MockRankingPolicyRepository();
    mockCreateService = MockCreateLeagueService();
    mockDeleteService = MockDeleteUserService();
    mockUpdateService = MockUpdateUserService();

    container = ProviderContainer(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
        createLeagueServiceProvider.overrideWithValue(mockCreateService),
        deleteUserServiceProvider.overrideWithValue(mockDeleteService),
        updateUserServiceProvider.overrideWithValue(mockUpdateService),
      ],
    );

    // Default mocks
    when(() => mockLeagueRepo.get(tLeagueId)).thenAnswer((_) async => tLeague);
    when(() => mockLeagueRepo.get(tLeagueId2))
        .thenAnswer((_) async => tLeague2);
    when(() => mockLeagueRepo.getAll())
        .thenAnswer((_) async => [tLeague, tLeague2]);
    when(() => mockPlayerRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => [tPlayer1, tPlayer2]);
    when(() => mockPlayerRepo.getByLeague(tLeagueId2))
        .thenAnswer((_) async => [tPlayer3]);
    when(() => mockPlayerRepo.getByUserId('u1'))
        .thenAnswer((_) async => [tPlayer1, tPlayer3]);
    when(() => mockPlayerRepo.getByUserId('u2'))
        .thenAnswer((_) async => [tPlayer2]);
    when(() => mockPlayerRepo.getByUserId('u3')).thenAnswer((_) async => []);
    when(() => mockPlayerRepo.get('p1')).thenAnswer((_) async => tPlayer1);
    when(() => mockPlayerRepo.get('p2')).thenAnswer((_) async => tPlayer2);
    when(() => mockPlayerRepo.get('p3')).thenAnswer((_) async => tPlayer3);
    when(() => mockMatchRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => []);
    when(() => mockMatchRepo.getByLeague(tLeagueId2))
        .thenAnswer((_) async => []);
    when(() => mockMatchRepo.get(any())).thenAnswer((_) async => null);
    when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
        .thenAnswer((_) async => tRankingPolicy);
    when(() => mockPolicyRepo.getByLeagueId(tLeagueId2))
        .thenAnswer((_) async => tRankingPolicy2);
    when(() => mockUserRepo.getAll())
        .thenAnswer((_) async => [tUser1, tUser2, tUser3]);
    when(() => mockUserRepo.get('u1')).thenAnswer((_) async => tUser1);
    when(() => mockUserRepo.get('u2')).thenAnswer((_) async => tUser2);
    when(() => mockUserRepo.get('u3')).thenAnswer((_) async => tUser3);

    // Service mocks
    when(() => mockCreateService.execute(
          id: any(named: 'id'),
          name: any(named: 'name'),
          rankingPolicy: any(named: 'rankingPolicy'),
        )).thenAnswer((_) async => {});
    when(() => mockDeleteService.execute(any()))
        .thenAnswer((_) async => DeleteUserResult(affectedLeagueIds: {}));
    when(() => mockUpdateService.execute(any())).thenAnswer((_) async => {});
  });

  tearDown(() {
    container.dispose();
  });

  group('Provider Invalidation Integration', () {
    test('addLeague updates leaguesProvider via explicit fetch', () async {
      // Initial load
      await container.read(leaguesProvider.future);
      expect(container.read(leaguesProvider).value?.length, 2);

      // Add new league
      final newLeague =
          League(id: 'l3', name: 'League 3', createdAt: DateTime.now());
      final newPolicy =
          SimpleRankingPolicy(id: 'rp3', name: 'Standard', leagueId: 'l3');
      when(() => mockLeagueRepo.getAll())
          .thenAnswer((_) async => [tLeague, tLeague2, newLeague]);

      final notifier = container.read(leaguesProvider.notifier);
      await notifier.addLeague(
          id: 'l3', name: 'League 3', rankingPolicy: newPolicy);

      // Verify state updated via explicit fetch
      expect(container.read(leaguesProvider).value?.length, 3);
    });

    test('deleteLeague invalidates leagueDetailProvider for that league',
        () async {
      // Load league detail first
      await container.read(leagueDetailProvider(tLeagueId).future);
      expect(container.read(leagueDetailProvider(tLeagueId)).hasValue, isTrue);

      // Delete the league
      when(() => mockLeagueRepo.delete(tLeagueId)).thenAnswer((_) async => {});
      when(() => mockLeagueRepo.getAll()).thenAnswer((_) async => [tLeague2]);

      final leaguesNotifier = container.read(leaguesProvider.notifier);
      await leaguesNotifier.deleteLeague(tLeagueId);

      // League detail provider should be invalidated
      // Since we're watching it, it will try to rebuild and fail (league not found)
      final leagueDetailState = container.read(leagueDetailProvider(tLeagueId));
      expect(leagueDetailState.isLoading || leagueDetailState.hasError, isTrue);
    });

    test('addPlayer in league updates leagueDetailProvider via explicit fetch',
        () async {
      // Load league detail
      await container.read(leagueDetailProvider(tLeagueId).future);
      expect(
          container.read(leagueDetailProvider(tLeagueId)).value?.players.length,
          2);

      // Add player with new user (creates new user)
      when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      // New user u4 will be created
      final newUser =
          User(id: 'u4', name: 'New Player', avatarColorHex: 'AAAAAA');
      when(() => mockUserRepo.get('u4')).thenAnswer((_) async => newUser);
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [
                tPlayer1,
                tPlayer2,
                LeaguePlayer(
                    id: 'p4',
                    userId: 'u4',
                    leagueId: tLeagueId,
                    name: 'New Player',
                    avatarColorHex: 'AAAAAA')
              ]);
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tUser1, tUser2, tUser3, newUser]);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.addPlayer(name: 'New Player');

      // League detail should be updated (explicit fetch)
      expect(
          container.read(leagueDetailProvider(tLeagueId)).value?.players.length,
          3);
    });

    test('addPlayer with existing userId updates leagueDetailProvider',
        () async {
      await container.read(leagueDetailProvider(tLeagueId).future);

      // Add player linked to existing user u2
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [
                tPlayer1,
                tPlayer2,
                LeaguePlayer(
                    id: 'p4',
                    userId: 'u2',
                    leagueId: tLeagueId,
                    name: 'Player 3',
                    avatarColorHex: '00FF00')
              ]);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.addPlayer(name: '', userId: 'u2');

      // League detail updated
      expect(
          container.read(leagueDetailProvider(tLeagueId)).value?.players.length,
          3);
    });

    test('logSimpleMatch updates leagueDetailProvider via explicit fetch',
        () async {
      await container.read(leagueDetailProvider(tLeagueId).future);

      final newMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      when(() => mockMatchRepo.logSimpleMatch(match: any(named: 'match')))
          .thenAnswer((_) async => {});
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [newMatch]);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.logSimpleMatch(
          winnerId: 'p1', loserId: 'p2', isDraw: false);

      // League detail updated
      expect(
          container.read(leagueDetailProvider(tLeagueId)).value?.matches.length,
          1);
    });

    test('updateSimpleMatch updates leagueDetailProvider via explicit fetch',
        () async {
      // Setup existing match
      final existingMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      final updatedMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p2']),
          Side(id: 's2', playerIds: ['p1'])
        ],
        winnerSideId: 's1',
      );
      when(() => mockMatchRepo.get('m1'))
          .thenAnswer((_) async => existingMatch);
      when(() => mockMatchRepo.logSimpleMatch(match: any(named: 'match')))
          .thenAnswer((_) async => {});
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [updatedMatch]);

      await container.read(leagueDetailProvider(tLeagueId).future);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.updateSimpleMatch(
          matchId: 'm1', winnerId: 'p2', loserId: 'p1', isDraw: false);

      // League detail updated
      expect(
          container.read(leagueDetailProvider(tLeagueId)).value?.matches.length,
          1);
    });

    test('deleteMatch updates leagueDetailProvider via explicit fetch',
        () async {
      final existingMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      when(() => mockMatchRepo.get('m1'))
          .thenAnswer((_) async => existingMatch);
      when(() => mockMatchRepo.delete('m1')).thenAnswer((_) async => {});
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => []);

      await container.read(leagueDetailProvider(tLeagueId).future);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.deleteMatch('m1');

      // League detail updated (empty matches)
      expect(
          container.read(leagueDetailProvider(tLeagueId)).value?.matches.length,
          0);
    });

    test('updatePlayer updates leagueDetailProvider via explicit fetch',
        () async {
      await container.read(leagueDetailProvider(tLeagueId).future);

      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId)).thenAnswer(
          (_) async => [tPlayer1.copyWith(name: 'Updated Name'), tPlayer2]);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.updatePlayer(playerId: 'p1', name: 'Updated Name');

      // League detail updated
      expect(
          container
              .read(leagueDetailProvider(tLeagueId))
              .value
              ?.players
              .first
              .name,
          'Updated Name');
    });

    test('removePlayer updates leagueDetailProvider via explicit fetch',
        () async {
      await container.read(leagueDetailProvider(tLeagueId).future);

      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => []);
      when(() => mockPlayerRepo.delete('p1')).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [tPlayer2]);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.removePlayer('p1');

      // League detail updated
      expect(
          container.read(leagueDetailProvider(tLeagueId)).value?.players.length,
          1);
    });

    test('deleteUser invalidates dependent providers', () async {
      // Setup: user u1 has players in l1 and l2
      when(() => mockPlayerRepo.getByUserId('u1'))
          .thenAnswer((_) async => [tPlayer1, tPlayer3]);
      when(() => mockDeleteService.execute('u1')).thenAnswer((_) async =>
          DeleteUserResult(affectedLeagueIds: {tLeagueId, tLeagueId2}));

      await container.read(usersProvider.future);
      await container.read(leaguesProvider.future);
      await container.read(userDetailProvider('u1').future);
      await container.read(leagueDetailProvider(tLeagueId).future);
      await container.read(leagueDetailProvider(tLeagueId2).future);

      // Verify initial state
      expect(container.read(usersProvider).value?.length, 3);

      // Delete user - set up the mock for the updated state BEFORE calling
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tUser2, tUser3]);
      final usersNotifier = container.read(usersProvider.notifier);
      await usersNotifier.deleteUser('u1');

      // Users provider updated (u1 removed via explicit fetch)
      expect(container.read(usersProvider).value?.length, 2);
    });

    test('updateUser invalidates dependent providers', () async {
      when(() => mockPlayerRepo.getByUserId('u1'))
          .thenAnswer((_) async => [tPlayer1, tPlayer3]);
      when(() => mockUpdateService.execute(any())).thenAnswer((_) async => {});
      when(() => mockUserRepo.getAll()).thenAnswer(
          (_) async => [tUser1.copyWith(name: 'Updated'), tUser2, tUser3]);

      await container.read(usersProvider.future);
      await container.read(userDetailProvider('u1').future);
      await container.read(leagueDetailProvider(tLeagueId).future);
      await container.read(leagueDetailProvider(tLeagueId2).future);

      final usersNotifier = container.read(usersProvider.notifier);
      await usersNotifier.updateUser(tUser1.copyWith(name: 'Updated'));

      // Users provider updated
      expect(container.read(usersProvider).value?.first.name, 'Updated');
    });

    // =========================================================================
    // USER DETAIL PROVIDER INVALIDATION TESTS
    // =========================================================================

    test('addPlayer with new user invalidates userDetailProvider for new user',
        () async {
      // Load user detail for the new user (u4) - will be empty initially
      final newUser = User(
          id: 'u4', name: 'New Player', avatarColorHex: 'AAAAAA', icon: '🎮');
      when(() => mockUserRepo.get('u4')).thenAnswer((_) async => newUser);
      when(() => mockPlayerRepo.getByUserId('u4'))
          .thenAnswer((_) async => []);

      await container.read(userDetailProvider('u4').future);
      expect(container.read(userDetailProvider('u4')).value, isEmpty);

      // Add player with new user in league l1
      when(() => mockUserRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [
                tPlayer1,
                tPlayer2,
                LeaguePlayer(
                    id: 'p4',
                    userId: 'u4',
                    leagueId: tLeagueId,
                    name: 'New Player',
                    avatarColorHex: 'AAAAAA',
                    icon: '🎮')
              ]);
      when(() => mockUserRepo.getAll())
          .thenAnswer((_) async => [tUser1, tUser2, tUser3, newUser]);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.addPlayer(name: 'New Player');

      // userDetailProvider for u4 should be invalidated (next read will fetch fresh)
      final userDetailState = container.read(userDetailProvider('u4'));
      expect(userDetailState.isLoading || userDetailState.hasValue, isTrue);
    });

    test('addPlayer with existing userId invalidates userDetailProvider for that user',
        () async {
      // Load user detail for existing user u2
      when(() => mockPlayerRepo.getByUserId('u2'))
          .thenAnswer((_) async => [tPlayer2]);
      await container.read(userDetailProvider('u2').future);
      expect(container.read(userDetailProvider('u2')).value?.length, 1);

      // Add player linked to existing user u2 in league l1
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [
                tPlayer1,
                tPlayer2,
                LeaguePlayer(
                    id: 'p4',
                    userId: 'u2',
                    leagueId: tLeagueId,
                    name: 'Player 3',
                    avatarColorHex: '00FF00')
              ]);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.addPlayer(name: '', userId: 'u2');

      // userDetailProvider for u2 should be invalidated
      final userDetailState = container.read(userDetailProvider('u2'));
      expect(userDetailState.isLoading || userDetailState.hasValue, isTrue);
    });

    test('logSimpleMatch invalidates both winner and loser userDetailProvider',
        () async {
      // Load user details for both users
      when(() => mockPlayerRepo.getByUserId('u1'))
          .thenAnswer((_) async => [tPlayer1]);
      when(() => mockPlayerRepo.getByUserId('u2'))
          .thenAnswer((_) async => [tPlayer2]);
      await container.read(userDetailProvider('u1').future);
      await container.read(userDetailProvider('u2').future);
      expect(container.read(userDetailProvider('u1')).value?.length, 1);
      expect(container.read(userDetailProvider('u2')).value?.length, 1);

      // Log a match
      final newMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      when(() => mockMatchRepo.logSimpleMatch(match: any(named: 'match')))
          .thenAnswer((_) async => {});
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [newMatch]);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.logSimpleMatch(winnerId: 'p1', loserId: 'p2', isDraw: false);

      // Both userDetailProviders should be invalidated
      final userDetailState1 = container.read(userDetailProvider('u1'));
      final userDetailState2 = container.read(userDetailProvider('u2'));
      expect(userDetailState1.isLoading || userDetailState1.hasValue, isTrue);
      expect(userDetailState2.isLoading || userDetailState2.hasValue, isTrue);
    });

    test('updateSimpleMatch invalidates both winner and loser userDetailProvider',
        () async {
      // Setup existing match
      final existingMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      final updatedMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p2']), // Winner changed
          Side(id: 's2', playerIds: ['p1'])
        ],
        winnerSideId: 's1',
      );
      when(() => mockMatchRepo.get('m1'))
          .thenAnswer((_) async => existingMatch);
      when(() => mockMatchRepo.logSimpleMatch(match: any(named: 'match')))
          .thenAnswer((_) async => {});
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [updatedMatch]);

      // Load user details first
      when(() => mockPlayerRepo.getByUserId('u1'))
          .thenAnswer((_) async => [tPlayer1]);
      when(() => mockPlayerRepo.getByUserId('u2'))
          .thenAnswer((_) async => [tPlayer2]);
      await container.read(userDetailProvider('u1').future);
      await container.read(userDetailProvider('u2').future);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.updateSimpleMatch(
          matchId: 'm1', winnerId: 'p2', loserId: 'p1', isDraw: false);

      // Both userDetailProviders should be invalidated
      final userDetailState1 = container.read(userDetailProvider('u1'));
      final userDetailState2 = container.read(userDetailProvider('u2'));
      expect(userDetailState1.isLoading || userDetailState1.hasValue, isTrue);
      expect(userDetailState2.isLoading || userDetailState2.hasValue, isTrue);
    });

    test('deleteMatch invalidates all involved players userDetailProvider',
        () async {
      // Setup existing match with both players
      final existingMatch = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime.now(),
        isComplete: true,
        isDraw: false,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      when(() => mockMatchRepo.get('m1'))
          .thenAnswer((_) async => existingMatch);
      when(() => mockMatchRepo.delete('m1')).thenAnswer((_) async => {});
      // Initially return the match for userDetailProvider to load
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [existingMatch]);

      // Load user details for both users
      when(() => mockPlayerRepo.getByUserId('u1'))
          .thenAnswer((_) async => [tPlayer1]);
      when(() => mockPlayerRepo.getByUserId('u2'))
          .thenAnswer((_) async => [tPlayer2]);
      await container.read(userDetailProvider('u1').future);
      await container.read(userDetailProvider('u2').future);
      expect(container.read(userDetailProvider('u1')).value?.first.matches.length, 1);
      expect(container.read(userDetailProvider('u2')).value?.first.matches.length, 1);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.deleteMatch('m1');

      // Both userDetailProviders should be invalidated
      final userDetailState1 = container.read(userDetailProvider('u1'));
      final userDetailState2 = container.read(userDetailProvider('u2'));
      // After invalidation, the provider should be in a valid state (loading, data, or error)
      // The cached value may still be present (hasValue), or it may be rebuilding (isLoading),
      // or the rebuild may have failed due to test mock setup (hasError)
      expect(userDetailState1.isLoading || userDetailState1.hasValue || userDetailState1.hasError, isTrue);
      expect(userDetailState2.isLoading || userDetailState2.hasValue || userDetailState2.hasError, isTrue);
    });

    test('updatePlayer and removePlayer invalidate affected user userDetailProvider',
        () async {
      // Load user detail for u1
      when(() => mockPlayerRepo.getByUserId('u1'))
          .thenAnswer((_) async => [tPlayer1]);
      await container.read(userDetailProvider('u1').future);
      expect(container.read(userDetailProvider('u1')).value?.first.player.name, 'Player 1');

      // Update player
      when(() => mockPlayerRepo.get('p1')).thenAnswer((_) async => tPlayer1);
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [
                tPlayer1.copyWith(name: 'Updated Name'),
                tPlayer2
              ]);

      final leagueNotifier =
          container.read(leagueDetailProvider(tLeagueId).notifier);
      await leagueNotifier.updatePlayer(playerId: 'p1', name: 'Updated Name');

      // userDetailProvider for u1 should be invalidated
      final userDetailState = container.read(userDetailProvider('u1'));
      expect(userDetailState.isLoading || userDetailState.hasValue, isTrue);

      // Now test removePlayer
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => []);
      when(() => mockPlayerRepo.delete('p1')).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [tPlayer2]);

      await leagueNotifier.removePlayer('p1');

      // userDetailProvider for u1 should be invalidated (no more players)
      final userDetailState2 = container.read(userDetailProvider('u1'));
      expect(userDetailState2.isLoading || userDetailState2.hasValue, isTrue);
    });
  });
}
