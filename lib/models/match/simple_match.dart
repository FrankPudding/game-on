import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'simple_match.g.dart';

@HiveType(typeId: 6)
@JsonSerializable()
class SimpleMatch extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String leagueId;

  @HiveField(2)
  final DateTime playedAt;

  @HiveField(3)
  bool isComplete;

  @HiveField(4)
  bool isDraw; // True if it's a draw

  @HiveField(5)
  String?
      winnerId; // ID of the winning participant (nullable if draw/in-progress)

  SimpleMatch({
    required this.id,
    required this.leagueId,
    required this.playedAt,
    required this.isComplete,
    this.isDraw = false,
    this.winnerId,
  });

  factory SimpleMatch.fromJson(Map<String, dynamic> json) =>
      _$SimpleMatchFromJson(json);
  Map<String, dynamic> toJson() => _$SimpleMatchToJson(this);

  SimpleMatch copyWith({
    String? id,
    String? leagueId,
    DateTime? playedAt,
    bool? isComplete,
    bool? isDraw,
    String? winnerId,
  }) {
    return SimpleMatch(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      playedAt: playedAt ?? this.playedAt,
      isComplete: isComplete ?? this.isComplete,
      isDraw: isDraw ?? this.isDraw,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}
