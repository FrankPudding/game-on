import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'timed_state.g.dart';

@HiveType(typeId: 13)
@JsonSerializable()
class TimedState extends HiveObject {
  @HiveField(0)
  final String matchId;

  @HiveField(1)
  final String teamId;

  @HiveField(2)
  final int finalScore;

  TimedState({
    required this.matchId,
    required this.teamId,
    this.finalScore = 0,
  });

  factory TimedState.fromJson(Map<String, dynamic> json) =>
      _$TimedStateFromJson(json);
  Map<String, dynamic> toJson() => _$TimedStateToJson(this);
}
