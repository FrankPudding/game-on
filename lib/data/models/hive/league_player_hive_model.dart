import 'package:hive_ce/hive_ce.dart';
import '../../../../domain/entities/league_player.dart';

part 'league_player_hive_model.g.dart';

@HiveType(typeId: 1)
class LeaguePlayerHiveModel extends HiveObject {
  LeaguePlayerHiveModel({
    required this.id,
    required this.userId,
    required this.leagueId,
    required this.name,
    required this.avatarColorHex,
    this.icon,
  });

  factory LeaguePlayerHiveModel.fromDomain(LeaguePlayer player) {
    return LeaguePlayerHiveModel(
      id: player.id,
      userId: player.userId,
      leagueId: player.leagueId,
      name: player.name,
      avatarColorHex: player.avatarColorHex,
      icon: player.icon,
    );
  }
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String leagueId;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String avatarColorHex;

  @HiveField(5)
  final String? icon;

  LeaguePlayer toDomain() {
    return LeaguePlayer(
      id: id,
      userId: userId,
      leagueId: leagueId,
      name: name,
      avatarColorHex: avatarColorHex,
      icon: icon,
    );
  }
}
