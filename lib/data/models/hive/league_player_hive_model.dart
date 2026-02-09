import 'package:hive/hive.dart';
import '../../../../domain/entities/league_player.dart';

part 'league_player_hive_model.g.dart';

@HiveType(typeId: 1)
class LeaguePlayerHiveModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String playerId;

  @HiveField(2)
  final String leagueId;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String avatarColorHex;

  @HiveField(5)
  final String? icon;

  LeaguePlayerHiveModel({
    required this.id,
    required this.playerId,
    required this.leagueId,
    required this.name,
    required this.avatarColorHex,
    this.icon,
  });

  factory LeaguePlayerHiveModel.fromDomain(LeaguePlayer player) {
    return LeaguePlayerHiveModel(
      id: player.id,
      playerId: player.playerId,
      leagueId: player.leagueId,
      name: player.name,
      avatarColorHex: player.avatarColorHex,
      icon: player.icon,
    );
  }

  LeaguePlayer toDomain() {
    return LeaguePlayer(
      id: id,
      playerId: playerId,
      leagueId: leagueId,
      name: name,
      avatarColorHex: avatarColorHex,
      icon: icon,
    );
  }
}
