import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'frames_state.g.dart';

@HiveType(typeId: 16)
@JsonSerializable()
class FramesState extends HiveObject {
  @HiveField(0)
  final String matchId;

  @HiveField(1)
  final String teamId;

  @HiveField(2)
  final int framesWon;

  @HiveField(3)
  final List<int> individualFrameScores;

  FramesState({
    required this.matchId,
    required this.teamId,
    this.framesWon = 0,
    required this.individualFrameScores,
  });

  factory FramesState.fromJson(Map<String, dynamic> json) =>
      _$FramesStateFromJson(json);
  Map<String, dynamic> toJson() => _$FramesStateToJson(this);
}
