// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_team.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MatchTeamAdapter extends TypeAdapter<MatchTeam> {
  @override
  final int typeId = 7;

  @override
  MatchTeam read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MatchTeam(
      id: fields[0] as String,
      playerIds: (fields[1] as List).cast<String>(),
      name: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MatchTeam obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.playerIds)
      ..writeByte(2)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchTeamAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchTeam _$MatchTeamFromJson(Map<String, dynamic> json) => MatchTeam(
      id: json['id'] as String,
      playerIds:
          (json['playerIds'] as List<dynamic>).map((e) => e as String).toList(),
      name: json['name'] as String?,
    );

Map<String, dynamic> _$MatchTeamToJson(MatchTeam instance) => <String, dynamic>{
      'id': instance.id,
      'playerIds': instance.playerIds,
      'name': instance.name,
    };
