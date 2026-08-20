import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:game_on/data/models/hive/league_hive_model.dart';
import 'package:game_on/data/models/hive/league_player_hive_model.dart';
import 'package:game_on/data/models/hive/ranking_policy_hive_model.dart';
import 'package:game_on/data/models/hive/ranking_policies/goal_difference_ranking_policy_hive_model.dart';
import 'package:game_on/data/models/hive/ranking_policies/simple_ranking_policy_hive_model.dart';
import 'package:game_on/data/models/hive/matches/simple_match_hive_model.dart';
import 'package:game_on/data/models/hive/side_hive_model.dart';
import 'package:game_on/data/models/hive/user_hive_model.dart';
import 'package:game_on/data/repositories/hive/hive_league_player_repository.dart';
import 'package:game_on/data/repositories/hive/hive_league_repository.dart';
import 'package:game_on/data/repositories/hive/hive_ranking_policy_repository.dart';
import 'package:game_on/data/repositories/hive/hive_user_repository.dart';
import 'package:game_on/data/repositories/hive/matches/hive_simple_match_repository.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/hive_registrar.g.dart';

class FakeRankingPolicy extends RankingPolicy<SimpleMatch> {
  FakeRankingPolicy(
      {required super.id, required super.name, required super.leagueId});
}

void main() {
  late Directory tempDir;

  void registerAdapterIfNeeded<T>(int typeId, TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(typeId)) {
      Hive.registerAdapter<T>(adapter);
    }
  }

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      registerAdapterIfNeeded(0, UserHiveModelAdapter());
      registerAdapterIfNeeded(3, LeagueHiveModelAdapter());
      registerAdapterIfNeeded(1, LeaguePlayerHiveModelAdapter());
      registerAdapterIfNeeded(6, SimpleMatchHiveModelAdapter());
      registerAdapterIfNeeded(8, SideHiveModelAdapter());
      registerAdapterIfNeeded(9, SimpleRankingPolicyHiveModelAdapter());
      registerAdapterIfNeeded(
          10, GoalDifferenceRankingPolicyHiveModelAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('Real Hive boxes', () {
    test('should round-trip serialization for all models', () async {
      final userBox = await Hive.openBox<UserHiveModel>('users');
      final leagueBox = await Hive.openBox<LeagueHiveModel>('leagues');
      final playerBox =
          await Hive.openBox<LeaguePlayerHiveModel>('league_players');
      final matchBox = await Hive.openBox<SimpleMatchHiveModel>('matches');
      final policyBox =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');

      await userBox.put(
          'u1',
          UserHiveModel(
              id: 'u1', name: 'Alice', avatarColorHex: 'AE0C00', icon: '🥇'));
      await leagueBox.put(
          'l1',
          LeagueHiveModel(
              id: 'l1',
              name: 'League',
              createdAt: DateTime(2023, 1, 1),
              isArchived: false));
      await playerBox.put(
          'p1',
          LeaguePlayerHiveModel(
              id: 'p1',
              userId: 'u1',
              leagueId: 'l1',
              name: 'Alice',
              avatarColorHex: 'AE0C00',
              icon: '🥇'));
      await matchBox.put(
          'm1',
          SimpleMatchHiveModel(
              id: 'm1',
              leagueId: 'l1',
              playedAt: DateTime(2023, 1, 1),
              isComplete: true,
              isDraw: false,
              winnerSideId: 's1',
              sides: [
                SideHiveModel(id: 's1', playerIds: ['u1'])
              ]));
      await policyBox.put(
          'rp1',
          SimpleRankingPolicyHiveModel(
              id: 'rp1',
              name: 'Standard',
              leagueId: 'l1',
              pointsForWin: 3,
              pointsForDraw: 1,
              pointsForLoss: 0));
      await policyBox.put(
          'rp2',
          GoalDifferenceRankingPolicyHiveModel(
              id: 'rp2', name: 'GD', leagueId: 'l2'));

      // Close and reopen boxes to force deserialization from disk.
      await userBox.close();
      await leagueBox.close();
      await playerBox.close();
      await matchBox.close();
      await policyBox.close();

      final userBox2 = await Hive.openBox<UserHiveModel>('users');
      final leagueBox2 = await Hive.openBox<LeagueHiveModel>('leagues');
      final playerBox2 =
          await Hive.openBox<LeaguePlayerHiveModel>('league_players');
      final matchBox2 = await Hive.openBox<SimpleMatchHiveModel>('matches');
      final policyBox2 =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');

      final user = (userBox2.get('u1'))!.toDomain();
      final league = (leagueBox2.get('l1'))!.toDomain();
      final player = (playerBox2.get('p1'))!.toDomain();
      final match = (matchBox2.get('m1'))!.toDomain();
      final simplePolicy = (policyBox2.get('rp1'))!.toDomain();
      final gdPolicy = (policyBox2.get('rp2'))!.toDomain();

      expect(user.name, 'Alice');
      expect(user.icon, '🥇');
      expect(league.createdAt, DateTime(2023, 1, 1));
      expect(player.leagueId, 'l1');
      expect(match.sides.single.playerIds, ['u1']);
      expect(match.winnerSideId, 's1');
      expect(simplePolicy, isA<SimpleRankingPolicy>());
      expect((simplePolicy as SimpleRankingPolicy).pointsForWin, 3);
      expect(gdPolicy, isA<GoalDifferenceRankingPolicy>());
      expect((gdPolicy as GoalDifferenceRankingPolicy).pointsForWin, 3);

      await userBox2.close();
      await leagueBox2.close();
      await playerBox2.close();
      await matchBox2.close();
      await policyBox2.close();
    });

    test('generated adapters should implement equality and hashCode', () {
      final userAdapter1 = UserHiveModelAdapter();
      final userAdapter2 = UserHiveModelAdapter();
      final leagueAdapter = LeagueHiveModelAdapter();
      final playerAdapter = LeaguePlayerHiveModelAdapter();
      final matchAdapter = SimpleMatchHiveModelAdapter();
      final sideAdapter = SideHiveModelAdapter();
      final simpleAdapter = SimpleRankingPolicyHiveModelAdapter();
      final gdAdapter = GoalDifferenceRankingPolicyHiveModelAdapter();

      expect(userAdapter1 == userAdapter2, isTrue);
      expect(userAdapter1.hashCode, userAdapter2.hashCode);

      void expectAdapterEquality(TypeAdapter a, TypeAdapter b) {
        expect(identical(a, b), isFalse);
        expect(a == b, isTrue);
        expect(a.hashCode, b.hashCode);
      }

      expectAdapterEquality(userAdapter1, userAdapter2);
      expectAdapterEquality(LeagueHiveModelAdapter(), leagueAdapter);
      expectAdapterEquality(LeaguePlayerHiveModelAdapter(), playerAdapter);
      expectAdapterEquality(SimpleMatchHiveModelAdapter(), matchAdapter);
      expectAdapterEquality(SideHiveModelAdapter(), sideAdapter);
      expectAdapterEquality(
          SimpleRankingPolicyHiveModelAdapter(), simpleAdapter);
      expectAdapterEquality(
          GoalDifferenceRankingPolicyHiveModelAdapter(), gdAdapter);

      expect(matchAdapter.typeId, 6);
      expect(sideAdapter.typeId, 8);
      expect(simpleAdapter.typeId, 9);
      expect(gdAdapter.typeId, 10);
    });
  });

  group('HiveUserRepository (real box)', () {
    test('should put, get, getAll and delete', () async {
      final box = await Hive.openBox<UserHiveModel>('users');
      final repo = HiveUserRepository(box);
      final user = User(id: 'u1', name: 'Alice', avatarColorHex: 'AE0C00');

      expect(await repo.get('u1'), isNull);

      await repo.put(user);
      final fetched = await repo.get('u1');
      expect(fetched?.name, 'Alice');

      final all = await repo.getAll();
      expect(all.single.id, 'u1');

      await repo.delete('u1');
      expect(await repo.get('u1'), isNull);
    });
  });

  group('HiveLeaguePlayerRepository (real box)', () {
    test('should put, get, filter by league/user and delete', () async {
      final box = await Hive.openBox<LeaguePlayerHiveModel>('league_players');
      final repo = HiveLeaguePlayerRepository(box);
      final p1 = LeaguePlayer(
          id: 'p1',
          userId: 'u1',
          leagueId: 'l1',
          name: 'Alice',
          avatarColorHex: 'AE0C00');
      final p2 = LeaguePlayer(
          id: 'p2',
          userId: 'u2',
          leagueId: 'l1',
          name: 'Bob',
          avatarColorHex: '000000');
      final p3 = LeaguePlayer(
          id: 'p3',
          userId: 'u1',
          leagueId: 'l2',
          name: 'Carol',
          avatarColorHex: 'FFFFFF');

      await repo.put(p1);
      await repo.put(p2);
      await repo.put(p3);

      expect((await repo.get('p1'))?.name, 'Alice');
      expect((await repo.get('missing')), isNull);

      final inLeague = await repo.getByLeague('l1');
      expect(inLeague.map((p) => p.id), ['p1', 'p2']);

      final byUser = await repo.getByUserId('u1');
      expect(byUser.map((p) => p.id), ['p1', 'p3']);

      final all = await repo.getAll();
      expect(all.length, 3);

      await repo.delete('p3');
      expect((await repo.getByUserId('u1')).length, 1);
    });
  });

  group('HiveSimpleMatchRepository (real box)', () {
    test('should put, get, getAll, filter by league, log and delete', () async {
      final box = await Hive.openBox<SimpleMatchHiveModel>('simple_matches');
      final repo = HiveSimpleMatchRepository(box);
      final m1 = SimpleMatch(
          id: 'm1',
          leagueId: 'l1',
          playedAt: DateTime(2023),
          isComplete: true,
          sides: [
            Side(id: 's1', playerIds: ['p1'])
          ],
          winnerSideId: 's1');
      final m2 = SimpleMatch(
          id: 'm2',
          leagueId: 'l2',
          playedAt: DateTime(2023),
          isComplete: true,
          sides: [
            Side(id: 's2', playerIds: ['p2'])
          ]);

      await repo.put(m1);
      await repo.logSimpleMatch(match: m2);

      expect((await repo.get('m1'))?.winnerSideId, 's1');
      expect(await repo.get('missing'), isNull);

      final byLeague = await repo.getByLeague('l1');
      expect(byLeague.single.id, 'm1');

      final all = await repo.getAll();
      expect(all.length, 2);

      await repo.delete('m2');
      expect(await repo.get('m2'), isNull);
    });
  });

  group('HiveLeagueRepository (real box)', () {
    test('should archive a league and persist the change', () async {
      final box = await Hive.openBox<LeagueHiveModel>('leagues');
      final repo = HiveLeagueRepository(box);
      final league =
          League(id: 'l1', name: 'League', createdAt: DateTime(2023));

      await repo.put(league);
      await repo.archiveLeague('l1');

      final archived = await repo.get('l1');
      expect(archived?.isArchived, isTrue);

      await repo.delete('l1');
      expect(await repo.get('l1'), isNull);
    });
  });

  group('HiveRankingPolicyRepository (real box)', () {
    test('should put and get simple and goal difference policies', () async {
      final box =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
      final repo = HiveRankingPolicyRepository(box);
      final simple =
          SimpleRankingPolicy(id: 'rp1', name: 'Standard', leagueId: 'l1');
      final gd =
          GoalDifferenceRankingPolicy(id: 'rp2', name: 'GD', leagueId: 'l2');

      await repo.put(simple);
      await repo.put(gd);

      final fetchedSimple = await repo.get('rp1');
      expect(fetchedSimple, isA<SimpleRankingPolicy>());

      final byLeague = await repo.getByLeagueId('l2');
      expect(byLeague, isA<GoalDifferenceRankingPolicy>());

      final all = await repo.getAll();
      expect(all.length, 2);

      await repo.delete('rp1');
      expect(await repo.get('rp1'), isNull);
    });

    test('getByLeagueId should return null when no policy matches', () async {
      final box =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
      final repo = HiveRankingPolicyRepository(box);
      await repo.put(
          SimpleRankingPolicy(id: 'rp1', name: 'Standard', leagueId: 'l1'));

      expect(await repo.getByLeagueId('missing'), isNull);
    });

    test('put should throw for unsupported policy types', () async {
      final box =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
      final repo = HiveRankingPolicyRepository(box);
      final fake = FakeRankingPolicy(id: 'f1', name: 'Fake', leagueId: 'l1');

      expect(() => repo.put(fake), throwsUnimplementedError);
    });
  });
}
