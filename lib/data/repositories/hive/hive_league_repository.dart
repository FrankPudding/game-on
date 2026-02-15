import 'package:hive_ce/hive_ce.dart';
import '../../../domain/entities/league.dart';
import '../../../domain/repositories/league_repository.dart';
import '../../models/hive/league_hive_model.dart';

class HiveLeagueRepository implements LeagueRepository {
  HiveLeagueRepository(this._box);
  final Box<LeagueHiveModel> _box;

  @override
  Future<League?> get(String id) async {
    final model = _box.get(id);
    return model?.toDomain();
  }

  @override
  Future<List<League>> getAll() async {
    return _box.values.map((model) => model.toDomain()).toList();
  }

  @override
  Future<void> put(League item) async {
    final model = LeagueHiveModel.fromDomain(item);
    await _box.put(model.id, model);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> archiveLeague(String id) async {
    final model = _box.get(id);
    if (model != null) {
      final updatedModel = LeagueHiveModel.fromDomain(
        model.toDomain().copyWith(isArchived: true),
      );
      await _box.put(id, updatedModel);
    }
  }
}
