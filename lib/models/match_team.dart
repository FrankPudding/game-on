import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'match_team.g.dart';

@HiveType(typeId: 7)
@JsonSerializable()
class MatchTeam extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final List<String> playerIds;

  @HiveField(2)
  final String? name;

  MatchTeam({
    required this.id,
    required this.playerIds,
    this.name,
  });

  factory MatchTeam.fromJson(Map<String, dynamic> json) =>
      _$MatchTeamFromJson(json);
  Map<String, dynamic> toJson() => _$MatchTeamToJson(this);
}
