import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'simple_config.g.dart';

@HiveType(typeId: 4)
@JsonSerializable()
class SimpleConfig extends HiveObject {
  @HiveField(0)
  final String leagueId;

  // Points awarded for each outcome
  @HiveField(1)
  final int pointsForWin;
  
  @HiveField(2)
  final int pointsForDraw;
  
  @HiveField(3)
  final int pointsForLoss;

  SimpleConfig({
    required this.leagueId,
    required this.pointsForWin,
    required this.pointsForDraw,
    required this.pointsForLoss,
  });

  factory SimpleConfig.fromJson(Map<String, dynamic> json) => _$SimpleConfigFromJson(json);
  Map<String, dynamic> toJson() => _$SimpleConfigToJson(this);

  SimpleConfig copyWith({
    String? leagueId,
    int? pointsForWin,
    int? pointsForDraw,
    int? pointsForLoss,
  }) {
    return SimpleConfig(
      leagueId: leagueId ?? this.leagueId,
      pointsForWin: pointsForWin ?? this.pointsForWin,
      pointsForDraw: pointsForDraw ?? this.pointsForDraw,
      pointsForLoss: pointsForLoss ?? this.pointsForLoss,
    );
  }
}
