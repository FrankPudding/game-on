import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/ranking_policy.dart';
import '../../../../domain/entities/ranking_policies/simple_ranking_policy.dart';
import '../../../../domain/repositories/ranking_policy_repository.dart';
import '../../models/hive/ranking_policy_hive_model.dart';
import '../../models/hive/ranking_policies/simple_ranking_policy_hive_model.dart';

class HiveRankingPolicyRepository implements RankingPolicyRepository {
  HiveRankingPolicyRepository(this._box);
  final Box<RankingPolicyHiveModel> _box;

  @override
  Future<RankingPolicy?> get(String id) async {
    final model = _box.get(id);
    return model?.toDomain();
  }

  @override
  Future<List<RankingPolicy>> getAll() async {
    return _box.values.map((model) => model.toDomain()).toList();
  }

  @override
  Future<void> put(RankingPolicy item) async {
    final model = _convertToHiveModel(item);
    await _box.put(item.id, model);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  @override
  Future<RankingPolicy?> getByLeagueId(String leagueId) async {
    try {
      final model = _box.values.firstWhere(
        (model) => model.leagueId == leagueId,
      );
      return model.toDomain();
    } catch (_) {
      return null;
    }
  }

  RankingPolicyHiveModel _convertToHiveModel(RankingPolicy policy) {
    if (policy is SimpleRankingPolicy) {
      return SimpleRankingPolicyHiveModel.fromDomain(policy);
    }
    throw UnimplementedError(
        'Ranking policy type not supported: ${policy.runtimeType}');
  }
}
