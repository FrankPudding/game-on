import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/league_player.dart';
import '../../../domain/exceptions/duplicate_league_player_exception.dart';
import '../../../domain/repositories/league_player_repository.dart';
import '../../models/hive/league_player_hive_model.dart';

class HiveLeaguePlayerRepository implements LeaguePlayerRepository {
  HiveLeaguePlayerRepository(this._box, this._uniqueIndex);

  final Box<LeaguePlayerHiveModel> _box;
  final Box<String> _uniqueIndex;
  final _uuid = const Uuid();

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
    final model = _box.get(id);
    if (model != null) {
      await _uniqueIndex.delete(model.compositeKey);
    }
    await _box.delete(id);
  }

  @override
  Future<List<LeaguePlayer>> getByLeague(String leagueId) async {
    return _box.values
        .where((p) => p.leagueId == leagueId)
        .map((m) => m.toDomain())
        .toList();
  }

  @override
  Future<List<LeaguePlayer>> getByUserId(String userId) async {
    return _box.values
        .where((p) => p.userId == userId)
        .map((m) => m.toDomain())
        .toList();
  }

  @override
  Future<LeaguePlayer> addPlayerIfUnique({
    required String userId,
    required String leagueId,
    required String name,
    required String avatarColorHex,
    String? icon,
  }) async {
    final compositeKey = '${userId}_$leagueId';

    // Check if player already exists in this league
    if (_uniqueIndex.containsKey(compositeKey)) {
      throw DuplicateLeaguePlayerException(userId: userId, leagueId: leagueId);
    }

    // Create new player
    final player = LeaguePlayer(
      id: _uuid.v4(),
      userId: userId,
      leagueId: leagueId,
      name: name,
      avatarColorHex: avatarColorHex,
      icon: icon,
    );

    final model = LeaguePlayerHiveModel.fromDomain(player);

    // Write to both boxes atomically (as close as possible)
    await _box.put(model.id, model);
    await _uniqueIndex.put(compositeKey, model.id);

    // Verify the write succeeded
    final savedModel = _box.get(model.id);
    if (savedModel == null) {
      // Rollback index on failure
      await _uniqueIndex.delete(compositeKey);
      throw StateError('Failed to save league player');
    }

    final savedIndex = _uniqueIndex.get(compositeKey);
    if (savedIndex != model.id) {
      // Rollback player on index failure
      await _box.delete(model.id);
      throw StateError('Failed to save uniqueness index');
    }

    return player;
  }
}
