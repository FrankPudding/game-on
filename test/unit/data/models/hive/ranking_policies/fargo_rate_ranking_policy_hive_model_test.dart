import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/data/models/hive/ranking_policies/fargo_rate_ranking_policy_hive_model.dart';
import 'package:game_on/domain/entities/ranking_policies/fargo_rate_ranking_policy.dart';
import 'package:game_on/core/constants/hive_box_names.dart';

void main() {
  group('FargoRateRankingPolicyHiveModel', () {
    test('typeId is 12', () {
      final adapter = FargoRateRankingPolicyHiveModelAdapter();
      expect(adapter.typeId, 12);
    });

    test('fromDomain maps all fields with defensive List.from copy', () {
      final policy = FargoRateRankingPolicy(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
      );
      final model = FargoRateRankingPolicyHiveModel.fromDomain(policy);
      expect(model.id, 'rp1');
      expect(model.name, 'Pool');
      expect(model.leagueId, 'l1');
      expect(model.categoryIds, [kSportsCategoryId, kPubGamesCategoryId]);
      // defensive copy: mutating original list should not affect model
      final mutable = [kSportsCategoryId, kPubGamesCategoryId];
      final p2 = FargoRateRankingPolicy(id: 'rp2', name: 'Pool', leagueId: 'l1', categoryIds: mutable);
      final m2 = FargoRateRankingPolicyHiveModel.fromDomain(p2);
      mutable.add('extra');
      expect(m2.categoryIds, isNot(contains('extra')));
    });

    test('toDomain maps all fields and returns List.unmodifiable', () {
      final model = FargoRateRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
      );
      final policy = model.toDomain();
      expect(policy.id, 'rp1');
      expect(policy.name, 'Pool');
      expect(policy.leagueId, 'l1');
      expect(policy.categoryIds, [kSportsCategoryId, kPubGamesCategoryId]);
      expect(() => (policy.categoryIds as List).add('x'), throwsUnsupportedError);
    });

    test('toDomain throws StateError when categoryIds empty (corruption)', () {
      final model = FargoRateRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [],
      );
      expect(() => model.toDomain(), throwsStateError);
    });

    test('fromDomain with reversed order preserves order but toDomain validates set-equality still passes', () {
      final model = FargoRateRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: 'l1',
        categoryIds: const [kPubGamesCategoryId, kSportsCategoryId],
      );
      final policy = model.toDomain();
      expect(policy.categoryIds.toSet(), kFargoCategoryIds.toSet());
    });

    test('toDomain handles null leagueId as empty string', () {
      final model = FargoRateRankingPolicyHiveModel(
        id: 'rp1',
        name: 'Pool',
        leagueId: null,
        categoryIds: const [kSportsCategoryId, kPubGamesCategoryId],
      );
      final policy = model.toDomain();
      expect(policy.leagueId, isEmpty);
    });

    test('adapter has correct typeId 12 and equality', () {
      final adapter = FargoRateRankingPolicyHiveModelAdapter();
      expect(adapter.typeId, 12);
      final adapter2 = FargoRateRankingPolicyHiveModelAdapter();
      expect(adapter, equals(adapter2));
      expect(adapter.hashCode, adapter2.hashCode);
    });
  });
}
