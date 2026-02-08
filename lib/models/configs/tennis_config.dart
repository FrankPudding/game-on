import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tennis_config.g.dart';

@HiveType(typeId: 17)
@JsonSerializable()
class TennisConfig extends HiveObject {
  @HiveField(0)
  final String leagueId;

  @HiveField(1)
  final int setsToWin;

  @HiveField(2)
  final int gamesPerSet;

  @HiveField(3)
  final int tiebreakAt;

  @HiveField(4)
  final List<int> placementPoints;

  TennisConfig({
    required this.leagueId,
    required this.setsToWin,
    required this.gamesPerSet,
    required this.tiebreakAt,
    required this.placementPoints,
  });

  factory TennisConfig.fromJson(Map<String, dynamic> json) =>
      _$TennisConfigFromJson(json);
  Map<String, dynamic> toJson() => _$TennisConfigToJson(this);
}
