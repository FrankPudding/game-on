import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'league_player.g.dart';

@HiveType(typeId: 1)
@JsonSerializable()
class LeaguePlayer extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String playerId; // Use 'id' for JSON key if matching User ID

  @HiveField(2)
  final String leagueId;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String avatarColorHex;

  LeaguePlayer({
    required this.id,
    required this.playerId,
    required this.leagueId,
    required this.name,
    required this.avatarColorHex,
  });

  factory LeaguePlayer.fromJson(Map<String, dynamic> json) =>
      _$LeaguePlayerFromJson(json);
  Map<String, dynamic> toJson() => _$LeaguePlayerToJson(this);

  LeaguePlayer copyWith({
    String? id,
    String? playerId,
    String? leagueId,
    String? name,
    String? avatarColorHex,
  }) {
    return LeaguePlayer(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      leagueId: leagueId ?? this.leagueId,
      name: name ?? this.name,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
    );
  }
}
