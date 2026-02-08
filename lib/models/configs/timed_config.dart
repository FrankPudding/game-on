import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'timed_config.g.dart';

@HiveType(typeId: 11)
@JsonSerializable()
class TimedConfig extends HiveObject {
  @HiveField(0)
  final String leagueId;

  @HiveField(1)
  final bool lowerScoreWins;

  @HiveField(2)
  final List<int> placementPoints;

  TimedConfig({
    required this.leagueId,
    required this.lowerScoreWins,
    required this.placementPoints,
  });

  factory TimedConfig.fromJson(Map<String, dynamic> json) =>
      _$TimedConfigFromJson(json);
  Map<String, dynamic> toJson() => _$TimedConfigToJson(this);
}
