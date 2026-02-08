import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'league.g.dart';

@HiveType(typeId: 2)
enum ScoringSystem {
  @HiveField(0)
  simple, // Win/Loss/Draw
  @HiveField(1)
  firstTo, // Ping Pong/Badminton
  @HiveField(2)
  timed, // Football/Uno
  @HiveField(3)
  frames, // Snooker/Darts
  @HiveField(4)
  tennis, // Tennis
}

@HiveType(typeId: 3)
@JsonSerializable()
class League extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final ScoringSystem scoringSystem;
  
  @HiveField(3)
  final DateTime createdAt;
  
  @HiveField(4)
  final bool isArchived;

  League({
    required this.id,
    required this.name,
    required this.scoringSystem,
    required this.createdAt,
    this.isArchived = false,
  });
  
  factory League.fromJson(Map<String, dynamic> json) => _$LeagueFromJson(json);
  Map<String, dynamic> toJson() => _$LeagueToJson(this);

  League copyWith({
    String? id,
    String? name,
    ScoringSystem? scoringSystem,
    DateTime? createdAt,
    bool? isArchived,
  }) {
    return League(
      id: id ?? this.id,
      name: name ?? this.name,
      scoringSystem: scoringSystem ?? this.scoringSystem,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
