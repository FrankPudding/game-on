import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:game_on/data/models/hive/ranking_policy_hive_model.dart';
import 'package:game_on/data/repositories/hive/hive_ranking_policy_repository.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/goal_difference_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/hive_registrar.g.dart';

class FakeRankingPolicy extends RankingPolicy<SimpleMatch> {
  FakeRankingPolicy({
    required super.id,
    required super.name,
    required super.leagueId,
    required super.categoryIds,
  });
}

/// Bypasses domain non-empty check to test repo empty guard.
/// Super is constructed with valid ids, but getter returns empty.
class EmptyCategoryFakePolicy extends SimpleRankingPolicy {
  EmptyCategoryFakePolicy({
    required super.id,
    required super.name,
    required super.leagueId,
  }) : super(categoryIds: const ['cat_custom_league_001']);

  @override
  List<String> get categoryIds => const [];
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('HiveRankingPolicyRepository (real box) - custom category enforcement',
      () {
    final nonCustomCases = {
      'cat_boardgames': ['cat_boardgames'],
      'cat_sports': ['cat_sports'],
      'cat_videogames': ['cat_videogames'],
      'cat_cardgames': ['cat_cardgames'],
    };

    for (final entry in nonCustomCases.entries) {
      test('Simple put with ${entry.key} should throw ArgumentError', () async {
        final box =
            await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
        final repo = HiveRankingPolicyRepository(box);
        final policy = SimpleRankingPolicy(
          id: 'rp_${entry.key}_simple',
          name: 'Standard',
          leagueId: 'l1',
          categoryIds: entry.value,
        );
        expect(() => repo.put(policy), throwsArgumentError);
        await box.close();
      });

      test('GoalDifference put with ${entry.key} should throw ArgumentError',
          () async {
        final box =
            await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
        final repo = HiveRankingPolicyRepository(box);
        final policy = GoalDifferenceRankingPolicy(
          id: 'rp_${entry.key}_gd',
          name: 'GD',
          leagueId: 'l1',
          categoryIds: entry.value,
        );
        expect(() => repo.put(policy), throwsArgumentError);
        await box.close();
      });
    }

    test('Simple with [custom, boardgames] should throw ArgumentError',
        () async {
      final box =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
      final repo = HiveRankingPolicyRepository(box);
      final policy = SimpleRankingPolicy(
        id: 'rp_mixed_simple',
        name: 'Standard',
        leagueId: 'l1',
        categoryIds: const ['cat_custom_league_001', 'cat_boardgames'],
      );
      expect(() => repo.put(policy), throwsArgumentError);
      await box.close();
    });

    test('GoalDifference with [custom, boardgames] should throw ArgumentError',
        () async {
      final box =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
      final repo = HiveRankingPolicyRepository(box);
      final policy = GoalDifferenceRankingPolicy(
        id: 'rp_mixed_gd',
        name: 'GD',
        leagueId: 'l1',
        categoryIds: const ['cat_custom_league_001', 'cat_boardgames'],
      );
      expect(() => repo.put(policy), throwsArgumentError);
      await box.close();
    });

    test('Simple with only custom should succeed (real Hive)', () async {
      final box =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
      final repo = HiveRankingPolicyRepository(box);
      final policy = SimpleRankingPolicy(
        id: 'rp_ok_simple',
        name: 'Standard',
        leagueId: 'l1',
        categoryIds: const ['cat_custom_league_001'],
      );
      await repo.put(policy);
      final fetched = await repo.get('rp_ok_simple');
      expect(fetched, isA<SimpleRankingPolicy>());
      expect(fetched!.categoryIds, ['cat_custom_league_001']);
      await box.close();
    });

    test('GoalDifference with only custom should succeed (real Hive)',
        () async {
      final box =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
      final repo = HiveRankingPolicyRepository(box);
      final policy = GoalDifferenceRankingPolicy(
        id: 'rp_ok_gd',
        name: 'GD',
        leagueId: 'l2',
        categoryIds: const ['cat_custom_league_001'],
      );
      await repo.put(policy);
      final fetched = await repo.get('rp_ok_gd');
      expect(fetched, isA<GoalDifferenceRankingPolicy>());
      expect(fetched!.categoryIds, ['cat_custom_league_001']);
      await box.close();
    });

    group('empty categoryIds boundary', () {
      test('domain ctor should throw for empty categoryIds', () {
        expect(
          () => SimpleRankingPolicy(
            id: 'rp_empty',
            name: 'Empty',
            leagueId: 'l1',
            categoryIds: const [],
          ),
          throwsArgumentError,
        );
        expect(
          () => GoalDifferenceRankingPolicy(
            id: 'rp_empty2',
            name: 'Empty',
            leagueId: 'l1',
            categoryIds: const [],
          ),
          throwsArgumentError,
        );
      });

      test(
          'repo put with empty categoryIds via fake should throw ArgumentError',
          () async {
        final box =
            await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
        final repo = HiveRankingPolicyRepository(box);
        final fakeEmpty = EmptyCategoryFakePolicy(
          id: 'rp_empty_fake',
          name: 'Fake',
          leagueId: 'l1',
        );
        // Verify fake returns empty
        expect(fakeEmpty.categoryIds, isEmpty);
        expect(() => repo.put(fakeEmpty), throwsArgumentError);
        await box.close();
      });

      test('repo put with FakeRankingPolicy empty should also be rejected',
          () async {
        // FakeRankingPolicy that overrides to return empty via constructor bypass is not possible
        // since super validates; instead test that creating Fake with empty throws at ctor
        expect(
          () => FakeRankingPolicy(
            id: 'f1',
            name: 'Fake',
            leagueId: 'l1',
            categoryIds: const [],
          ),
          throwsArgumentError,
        );
      });
    });

    test(
        'unsupported policy type still throws UnimplementedError when valid custom',
        () async {
      final box =
          await Hive.openBox<RankingPolicyHiveModel>('ranking_policies');
      final repo = HiveRankingPolicyRepository(box);
      final fake = FakeRankingPolicy(
        id: 'f1',
        name: 'Fake',
        leagueId: 'l1',
        categoryIds: const ['cat_custom_league_001'],
      );
      expect(() => repo.put(fake), throwsUnimplementedError);
      await box.close();
    });
  });
}
