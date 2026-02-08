import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'first_to_config.g.dart';

@HiveType(typeId: 8)
@JsonSerializable()
class FirstToConfig extends HiveObject {
  @HiveField(0)
  final String leagueId;

  @HiveField(1)
  final int targetScore;

  @HiveField(2)
  final int winByMargin;

  @HiveField(3)
  final List<int> placementPoints;

  FirstToConfig({
    required this.leagueId,
    required this.targetScore,
    required this.winByMargin,
    required this.placementPoints,
  });

  factory FirstToConfig.fromJson(Map<String, dynamic> json) =>
      _$FirstToConfigFromJson(json);
  Map<String, dynamic> toJson() => _$FirstToConfigToJson(this);
}
