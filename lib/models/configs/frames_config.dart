import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'frames_config.g.dart';

@HiveType(typeId: 14)
@JsonSerializable()
class FramesConfig extends HiveObject {
  @HiveField(0)
  final String leagueId;

  @HiveField(1)
  final int framesToWin;

  @HiveField(2)
  final String frameType; // 'firstTo' or 'higherWins'

  @HiveField(3)
  final int? frameTargetScore;

  @HiveField(4)
  final List<int> placementPoints;

  FramesConfig({
    required this.leagueId,
    required this.framesToWin,
    required this.frameType,
    this.frameTargetScore,
    required this.placementPoints,
  });

  factory FramesConfig.fromJson(Map<String, dynamic> json) =>
      _$FramesConfigFromJson(json);
  Map<String, dynamic> toJson() => _$FramesConfigToJson(this);
}
