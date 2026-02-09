import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/league.dart';
import '../../../domain/entities/league_player.dart';
import '../../../domain/repositories/league_repository.dart';
import '../../models/hive/league_hive_model.dart';
import '../../models/hive/user_hive_model.dart';
import '../../models/hive/league_player_hive_model.dart';

class HiveLeagueRepository implements LeagueRepository {
  HiveLeagueRepository(this._box, this._userBox, this._playerBox);
  final Box<LeagueHiveModel> _box;
  final Box<UserHiveModel> _userBox;
  final Box<LeaguePlayerHiveModel> _playerBox;
  final _uuid = const Uuid();

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

  @override
  Future<void> addPlayer({
    required String leagueId,
    required String name,
    String? userId,
    String? icon,
  }) async {
    String finalUserId;
    String finalName = name;
    String? finalIcon = icon;

    if (userId != null) {
      finalUserId = userId;
      final user = _userBox.get(userId);
      if (user != null) {
        if (finalName.isEmpty) finalName = user.name;
        finalIcon ??= user.icon;
      }
    } else {
      finalUserId = _uuid.v4();
      final userModel = UserHiveModel(
        id: finalUserId,
        name: name,
        avatarColorHex: 'AE0C00', // Brand Red
        icon: icon,
      );
      await _userBox.put(finalUserId, userModel);
    }

    final leaguePlayerId = _uuid.v4();
    final leaguePlayerModel = LeaguePlayerHiveModel(
      id: leaguePlayerId,
      userId: finalUserId,
      leagueId: leagueId,
      name: finalName,
      avatarColorHex: 'AE0C00',
      icon: finalIcon,
    );
    await _playerBox.put(leaguePlayerId, leaguePlayerModel);
  }

  @override
  List<LeaguePlayer> getLeaguePlayers(String leagueId) {
    return _playerBox.values
        .where((p) => p.leagueId == leagueId)
        .map((m) => m.toDomain())
        .toList();
  }
}
