// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tennis_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TennisConfigAdapter extends TypeAdapter<TennisConfig> {
  @override
  final int typeId = 17;

  @override
  TennisConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TennisConfig(
      leagueId: fields[0] as String,
      setsToWin: fields[1] as int,
      gamesPerSet: fields[2] as int,
      tiebreakAt: fields[3] as int,
      placementPoints: (fields[4] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, TennisConfig obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.leagueId)
      ..writeByte(1)
      ..write(obj.setsToWin)
      ..writeByte(2)
      ..write(obj.gamesPerSet)
      ..writeByte(3)
      ..write(obj.tiebreakAt)
      ..writeByte(4)
      ..write(obj.placementPoints);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TennisConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TennisConfig _$TennisConfigFromJson(Map<String, dynamic> json) => TennisConfig(
      leagueId: json['leagueId'] as String,
      setsToWin: (json['setsToWin'] as num).toInt(),
      gamesPerSet: (json['gamesPerSet'] as num).toInt(),
      tiebreakAt: (json['tiebreakAt'] as num).toInt(),
      placementPoints: (json['placementPoints'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$TennisConfigToJson(TennisConfig instance) =>
    <String, dynamic>{
      'leagueId': instance.leagueId,
      'setsToWin': instance.setsToWin,
      'gamesPerSet': instance.gamesPerSet,
      'tiebreakAt': instance.tiebreakAt,
      'placementPoints': instance.placementPoints,
    };
