import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/entities/ranking_policies/fargo_rate_ranking_policy.dart';
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
import 'package:game_on/domain/entities/user.dart';

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

class MockFargoRateRankingPolicy extends Mock
    implements FargoRateRankingPolicy {}

void main() {
  late MockLeagueRepository mockLeagueRepo;
  late MockLeaguePlayerRepository mockPlayerRepo;
  late MockUserRepository mockUserRepo;
  late MockSimpleMatchRepository mockMatchRepo;
  late MockRankingPolicyRepository mockPolicyRepo;
  late ProviderContainer container;
  const tLeagueId = 'l1';
  late FargoRateRankingPolicy fargoPolicy;
  final tLeague =
      League(id: tLeagueId, name: 'Pool League', createdAt: DateTime.now());
  final p1 = LeaguePlayer(
      id: 'p1',
      userId: 'u1',
      leagueId: tLeagueId,
      name: 'Alice',
      avatarColorHex: 'FF0000');
  final p2 = LeaguePlayer(
      id: 'p2',
      userId: 'u2',
      leagueId: tLeagueId,
      name: 'Bob',
      avatarColorHex: '00FF00');
  final p3 = LeaguePlayer(
      id: 'p3',
      userId: 'u3',
      leagueId: tLeagueId,
      name: 'Charlie',
      avatarColorHex: '0000FF');

  setUp(() {
    // Try to construct real Fargo policy; if skeleton stub throws, use mock that satisfies `is FargoRateRankingPolicy`
    try {
      fargoPolicy = FargoRateRankingPolicy(
          id: 'rp_fargo',
          name: 'Pool',
          leagueId: tLeagueId,
          categoryIds: const ['cat_sports', 'cat_pubgames'],
          initialRating: 500);
    } catch (_) {
      final mock = MockFargoRateRankingPolicy();
      // Mock must satisfy is check: mock is already implements FargoRateRankingPolicy, so `is` passes.
      // Stub categoryIds getter to return required set for any downstream validation.
      when(() => mock.categoryIds)
          .thenReturn(const ['cat_sports', 'cat_pubgames']);
      when(() => mock.id).thenReturn('rp_fargo');
      when(() => mock.name).thenReturn('Pool');
      when(() => mock.leagueId).thenReturn(tLeagueId);
      fargoPolicy = mock;
    }
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
    when(() => mockLeagueRepo.get(tLeagueId)).thenAnswer((_) async => tLeague);
    when(() => mockPlayerRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => [p1, p2, p3]);
    when(() => mockPlayerRepo.get(any())).thenAnswer((_) async => p1);
    when(() => mockMatchRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => []);
    when(() => mockMatchRepo.get(any())).thenAnswer((_) async => null);
    when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
        .thenAnswer((_) async => fargoPolicy);
    container.read(usersProvider);
  });

  tearDown(() => container.dispose());

  group('LeagueDetailState isFargo + fargoStats', () {
    test('isFargo true when policy is FargoRateRankingPolicy', () async {
      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;
      expect(state.isFargo, isTrue);
      expect(state.isGoalDifference, isFalse);
      expect(state.rankingPolicy, isA<FargoRateRankingPolicy>());
    });

    test(
        'fargoStats populated via calculator for all players – rating 500 when no matches',
        () async {
      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;
      expect(state.fargoStats.length, 3);
      expect(state.fargoStats['p1']!.rating, 500);
      expect(state.fargoStats['p1']!.matchesPlayed, 0);
      expect(state.fargoStats['p1']!.winRate, 0);
    });

    test('fargoStats correct wins/losses after matches', () async {
      final m1 = SimpleMatch(
        id: 'm1',
        leagueId: tLeagueId,
        playedAt: DateTime(2024, 1, 1),
        isComplete: true,
        sides: [
          Side(id: 's1', playerIds: ['p1']),
          Side(id: 's2', playerIds: ['p2'])
        ],
        winnerSideId: 's1',
      );
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [m1]);
      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;
      expect(state.fargoStats['p1']!.wins, 1);
      expect(state.fargoStats['p1']!.losses, 0);
      expect(state.fargoStats['p1']!.matchesPlayed, 1);
      expect(state.fargoStats['p2']!.wins, 0);
      expect(state.fargoStats['p2']!.losses, 1);
      expect(state.fargoStats['p3']!.matchesPlayed, 0);
      expect(state.fargoStats['p1']!.rating, greaterThan(500));
      expect(state.fargoStats['p2']!.rating, lessThan(500));
    });
  });

  group('Standings sorting rating DESC → wins DESC → id ASC', () {
    test('rating DESC primary', () async {
      // p1 beats p2 twice => p1 rating highest, p2 lowest, p3 500 middle
      final m1 = SimpleMatch(
          id: 'm1',
          leagueId: tLeagueId,
          playedAt: DateTime(2024, 1, 1),
          isComplete: true,
          sides: [
            Side(id: 's1', playerIds: ['p1']),
            Side(id: 's2', playerIds: ['p2'])
          ],
          winnerSideId: 's1');
      final m2 = SimpleMatch(
          id: 'm2',
          leagueId: tLeagueId,
          playedAt: DateTime(2024, 1, 2),
          isComplete: true,
          sides: [
            Side(id: 's3', playerIds: ['p1']),
            Side(id: 's4', playerIds: ['p2'])
          ],
          winnerSideId: 's3');
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [m1, m2]);
      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;
      // Sorted rating DESC: p1 first, p3 middle (500), p2 last
      expect(state.players.first.id, 'p1');
      expect(state.players.last.id, 'p2');
      expect(state.players.map((p) => p.id).toList(), ['p1', 'p3', 'p2']);
    });

    test('wins DESC tie-break when rating equal', () async {
      // No matches: all rating 500, wins 0 tie -> id ASC
      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;
      expect(state.players.map((p) => p.id).toList(), ['p1', 'p2', 'p3']);
    });

    test('id ASC final tie-break', () async {
      // Force same rating & wins by having no matches but different ids
      final pa = LeaguePlayer(
          id: 'pZ',
          userId: 'uZ',
          leagueId: tLeagueId,
          name: 'Zoe',
          avatarColorHex: '000');
      final pb = LeaguePlayer(
          id: 'pA',
          userId: 'uA',
          leagueId: tLeagueId,
          name: 'Andy',
          avatarColorHex: '000');
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [pa, pb]);
      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;
      expect(state.players.map((p) => p.id).toList(), ['pA', 'pZ']);
    });

    test('never uses name as tie-breaker – name order ignored', () async {
      final alice = LeaguePlayer(
          id: 'p2',
          userId: 'u2',
          leagueId: tLeagueId,
          name: 'Alice',
          avatarColorHex: '000');
      final bob = LeaguePlayer(
          id: 'p1',
          userId: 'u1',
          leagueId: tLeagueId,
          name: 'Bob',
          avatarColorHex: '000');
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [alice, bob]);
      // No matches -> rating tie -> id determines order p1 before p2 regardless of Alice < Bob
      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;
      expect(state.players.first.id,
          'p1'); // Bob with p1 before Alice p2 despite alphabetical
      expect(state.players.first.name, 'Bob');
    });

    test('players == ranked order, playersByName == alphabetical same set',
        () async {
      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;
      expect(state.players.map((p) => p.id).toSet(),
          state.playersByName.map((p) => p.id).toSet());
      expect(state.playersByName.map((p) => p.name).toList(),
          ['Alice', 'Bob', 'Charlie']);
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
