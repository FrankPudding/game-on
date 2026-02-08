// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'league.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LeagueAdapter extends TypeAdapter<League> {
  @override
  final int typeId = 3;

  @override
  League read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return League(
      id: fields[0] as String,
      name: fields[1] as String,
      scoringSystem: fields[2] as ScoringSystem,
      createdAt: fields[3] as DateTime,
      isArchived: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, League obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.scoringSystem)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.isArchived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeagueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScoringSystemAdapter extends TypeAdapter<ScoringSystem> {
  @override
  final int typeId = 2;

  @override
  ScoringSystem read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScoringSystem.simple;
      case 1:
        return ScoringSystem.firstTo;
      case 2:
        return ScoringSystem.timed;
      case 3:
        return ScoringSystem.frames;
      case 4:
        return ScoringSystem.tennis;
      default:
        return ScoringSystem.simple;
    }
  }

  @override
  void write(BinaryWriter writer, ScoringSystem obj) {
    switch (obj) {
      case ScoringSystem.simple:
        writer.writeByte(0);
        break;
      case ScoringSystem.firstTo:
        writer.writeByte(1);
        break;
      case ScoringSystem.timed:
        writer.writeByte(2);
        break;
      case ScoringSystem.frames:
        writer.writeByte(3);
        break;
      case ScoringSystem.tennis:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoringSystemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

League _$LeagueFromJson(Map<String, dynamic> json) => League(
      id: json['id'] as String,
      name: json['name'] as String,
      scoringSystem: $enumDecode(_$ScoringSystemEnumMap, json['scoringSystem']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isArchived: json['isArchived'] as bool? ?? false,
    );

Map<String, dynamic> _$LeagueToJson(League instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'scoringSystem': _$ScoringSystemEnumMap[instance.scoringSystem]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'isArchived': instance.isArchived,
    };

const _$ScoringSystemEnumMap = {
  ScoringSystem.simple: 'simple',
  ScoringSystem.firstTo: 'firstTo',
  ScoringSystem.timed: 'timed',
  ScoringSystem.frames: 'frames',
  ScoringSystem.tennis: 'tennis',
};
