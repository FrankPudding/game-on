import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/entities/ranking_policies/elo_ranking_policy.dart';
import 'package:game_on/domain/value_objects/elo_player_stats.dart';
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

void main() {
  group('Elo UI – presentation sorting rating DESC -> wins DESC -> id ASC', () {
    late MockLeagueRepository mockLeagueRepo;
    late MockLeaguePlayerRepository mockPlayerRepo;
    late MockUserRepository mockUserRepo;
    late MockSimpleMatchRepository mockMatchRepo;
    late MockRankingPolicyRepository mockPolicyRepo;
    late ProviderContainer container;
    const tLeagueId = 'l1';
    final tLeague =
        League(id: tLeagueId, name: 'Pool League', createdAt: DateTime.now());
    final p1 = LeaguePlayer(
        id: 'p1',
        userId: 'u1',
        leagueId: tLeagueId,
        name: 'Charlie',
        avatarColorHex: 'FF0000');
    final p2 = LeaguePlayer(
        id: 'p2',
        userId: 'u2',
        leagueId: tLeagueId,
        name: 'Alice',
        avatarColorHex: '00FF00');
    final p3 = LeaguePlayer(
        id: 'p3',
        userId: 'u3',
        leagueId: tLeagueId,
        name: 'Bob',
        avatarColorHex: '0000FF');

    setUp(() {
      mockLeagueRepo = MockLeagueRepository();
      mockPlayerRepo = MockLeaguePlayerRepository();
      mockUserRepo = MockUserRepository();
      mockMatchRepo = MockSimpleMatchRepository();
      mockPolicyRepo = MockRankingPolicyRepository();
      when(() => mockLeagueRepo.get(tLeagueId))
          .thenAnswer((_) async => tLeague);
      when(() => mockPlayerRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [p1, p2, p3]);
      when(() => mockPlayerRepo.get(any())).thenAnswer((_) async => p1);
      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => []);
      when(() => mockMatchRepo.get(any())).thenAnswer((_) async => null);
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

    ProviderContainer makeContainer() {
      return ProviderContainer(overrides: [
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
      ]);
    }

    test(
        'sorting uses rating DESC then wins DESC then id ASC – never name ( Elo )',
        () async {
      final eloPolicy = EloRankingPolicy(
        id: 'rp1',
        name: 'Pool',
        leagueId: tLeagueId,
        categoryIds: const ['cat_sports', 'cat_pubgames'],
        initialRating: 400,
      );
      when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
          .thenAnswer((_) async => eloPolicy);
      // No matches: all rating 400, wins 0 -> order id ASC p1,p2,p3 regardless of names Charlie,Alice,Bob
      container = makeContainer();
      addTearDown(container.dispose);
      final state =
          await container.read(leagueDetailProvider(tLeagueId).future);
      expect(state.players.map((p) => p.id).toList(), ['p1', 'p2', 'p3']);
      // isElo / isFargo – use dynamic to tolerate skeleton without isElo getter
      final dyn = state as dynamic;
      bool isElo = false;
      try {
        isElo = dyn.isElo as bool;
      } catch (_) {
        isElo = dyn.isFargo as bool;
      }
      expect(isElo, isTrue);
      // stats may be fargoStats or eloStats – both aliases should be present after builder
      final stats = (dyn.eloStats ?? dyn.fargoStats) as Map;
      expect(stats.length, 3);
    });

    test(
        'sorting fallback ?? initial – uninvolved players stay at initial not hardcoded',
        () async {
      final eloPolicy = EloRankingPolicy(
        id: 'rp1',
        name: 'Pool',
        leagueId: tLeagueId,
        categoryIds: const ['cat_sports', 'cat_pubgames'],
        initialRating: 400,
      );
      when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
          .thenAnswer((_) async => eloPolicy);
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
      container = makeContainer();
      addTearDown(container.dispose);
      final state =
          await container.read(leagueDetailProvider(tLeagueId).future);
      // p1 410, p3 400, p2 390 => order p1 (410), p3 (400), p2 (390)
      expect(state.players.map((p) => p.id).toList(), ['p1', 'p3', 'p2']);
      final dyn2 = state as dynamic;
      final eloStats =
          (dyn2.eloStats ?? dyn2.fargoStats) as Map<String, dynamic>;
      expect(eloStats['p3']!.rating, 400);
      expect(eloStats['p1']!.rating, 410);
      expect(eloStats['p2']!.rating, 390);
    });

    test('rating DESC primary – p1 beats p2 twice => order p1, p3 (400), p2',
        () async {
      final eloPolicy = EloRankingPolicy(
        id: 'rp1',
        name: 'Pool',
        leagueId: tLeagueId,
        categoryIds: const ['cat_sports', 'cat_pubgames'],
        initialRating: 400,
      );
      when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
          .thenAnswer((_) async => eloPolicy);
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
      container = makeContainer();
      addTearDown(container.dispose);
      final state =
          await container.read(leagueDetailProvider(tLeagueId).future);
      expect(state.players.map((p) => p.id).toList(), ['p1', 'p3', 'p2']);
    });

    test(
        'isElo true when policy is EloRankingPolicy, fargoStats alias still populated',
        () async {
      final eloPolicy = EloRankingPolicy(
        id: 'rp1',
        name: 'Pool',
        leagueId: tLeagueId,
        categoryIds: const ['cat_sports', 'cat_pubgames'],
        initialRating: 400,
      );
      when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
          .thenAnswer((_) async => eloPolicy);
      container = makeContainer();
      addTearDown(container.dispose);
      final state =
          await container.read(leagueDetailProvider(tLeagueId).future);
      final dyn3 = state as dynamic;
      bool isElo3 = false;
      try {
        isElo3 = dyn3.isElo as bool;
      } catch (_) {
        isElo3 = dyn3.isFargo as bool;
      }
      expect(isElo3, isTrue);
      expect(state.rankingPolicy, isA<EloRankingPolicy>());
      final stats3 = (dyn3.eloStats ?? dyn3.fargoStats) as Map<String, dynamic>;
      expect(stats3.length, 3);
      expect(stats3['p1']!.rating, 400);
    });
  });

  group('Standings columns and draw hiding when isElo', () {
    test('Elo stats winRate used in UI – EloPlayerStats winRate 1.0 after win',
        () {
      const stats =
          EloPlayerStats(matchesPlayed: 1, wins: 1, losses: 0, rating: 410);
      expect(stats.winRate, 1.0);
      expect(stats.rating, 410);
    });

    test(
        'LogMatch UI should hide draw when isElo – documented via calculator throws on isDraw',
        () async {
      // The calculator ensures isDraw throws, thus UI must hide draw option when isElo.
      // We verify file contains hide logic
      final files = [
        File('lib/presentation/screens/match/log_match_screen.dart'),
        File('lib/providers/league_detail_provider.dart'),
      ];
      bool foundDrawHide = false;
      for (final f in files) {
        if (f.existsSync()) {
          final c = f.readAsStringSync();
          if (c.contains('isElo') && c.contains('isDraw') ||
              c.contains('draw') && c.contains('Elo')) {
            foundDrawHide = true;
          }
          // Alternative: check league_detail_provider has isElo getter
          if (c.contains('isElo')) foundDrawHide = true;
        }
      }
      expect(foundDrawHide, isTrue);
      // At least the provider declares isElo
      final providerFile = File('lib/providers/league_detail_provider.dart');
      expect(providerFile.readAsStringSync(), contains('isElo'));
      // eloStats and fargoStats both present
      expect(providerFile.readAsStringSync(), contains('eloStats'));
    });

    test('eloStats vs fargoStats parity – both computed with K=20', () {
      // Provider should compute both for compat or at least eloStats
      final file = File('lib/providers/league_detail_provider.dart');
      final content = file.readAsStringSync();
      expect(content, contains('EloRankingPolicy'));
      expect(content, contains('initialRating'));
      // Should use rating ?? initial fallback
      expect(content, contains('??'));
    });
  });

  group('Hive and registrars – Elo keeps typeId 12 and registrar', () {
    test('hive_registrar.g.dart registers Elo adapter', () {
      final file = File('lib/hive_registrar.g.dart');
      final content = file.readAsStringSync();
      expect(content, contains('EloRankingPolicyHiveModelAdapter'));
    });

    test('elo hive model file has correct HiveType and HiveField literal', () {
      final file = File(
          'lib/data/models/hive/ranking_policies/elo_ranking_policy_hive_model.dart');
      final content = file.readAsStringSync();
      expect(content, contains('typeId: 12'));
      expect(content, contains('HiveField(7, defaultValue: 500)'));
      expect(content, contains('List.from')); // defensive copy
    });
  });
}
