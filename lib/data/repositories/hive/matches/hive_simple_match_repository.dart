import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/matches/simple_match.dart';
import '../../../../domain/repositories/match/simple_match_repository.dart';
import '../../../models/hive/matches/simple_match_hive_model.dart';

class HiveSimpleMatchRepository implements SimpleMatchRepository {
  HiveSimpleMatchRepository(this._box);
  final Box<SimpleMatchHiveModel> _box;

  @override
  Future<SimpleMatch?> get(String id) async {
    final model = _box.get(id);
    return model?.toDomain();
  }

  @override
  Future<List<SimpleMatch>> getAll() async {
    return _box.values.map((m) => m.toDomain()).toList();
  }

  @override
  Future<void> put(SimpleMatch item) async {
    final model = SimpleMatchHiveModel.fromDomain(item);
    await _box.put(model.id, model);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  @override
  Future<List<SimpleMatch>> getByLeague(String leagueId) async {
    return _box.values
        .where((m) => m.leagueId == leagueId)
        .map((m) => m.toDomain())
        .toList();
  }

  @override
  Future<void> logSimpleMatch({
    required SimpleMatch match,
  }) async {
    await _box.put(match.id, SimpleMatchHiveModel.fromDomain(match));
  }
}
