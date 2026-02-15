import 'package:hive_ce/hive_ce.dart';
import '../../../domain/entities/league_player.dart';
import '../../../domain/repositories/league_player_repository.dart';
import '../../models/hive/league_player_hive_model.dart';

class HiveLeaguePlayerRepository implements LeaguePlayerRepository {
  HiveLeaguePlayerRepository(this._box);
  final Box<LeaguePlayerHiveModel> _box;

  @override
  Future<LeaguePlayer?> get(String id) async {
    final model = _box.get(id);
    return model?.toDomain();
  }

  @override
  Future<List<LeaguePlayer>> getAll() async {
    return _box.values.map((model) => model.toDomain()).toList();
  }

  @override
  Future<void> put(LeaguePlayer item) async {
    final model = LeaguePlayerHiveModel.fromDomain(item);
    await _box.put(model.id, model);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  @override
  Future<List<LeaguePlayer>> getByLeague(String leagueId) async {
    return _box.values
        .where((p) => p.leagueId == leagueId)
        .map((m) => m.toDomain())
        .toList();
  }
}
