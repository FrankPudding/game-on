// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'first_to_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FirstToConfigAdapter extends TypeAdapter<FirstToConfig> {
  @override
  final int typeId = 8;

  @override
  FirstToConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FirstToConfig(
      leagueId: fields[0] as String,
      targetScore: fields[1] as int,
      winByMargin: fields[2] as int,
      placementPoints: (fields[3] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, FirstToConfig obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.leagueId)
      ..writeByte(1)
      ..write(obj.targetScore)
      ..writeByte(2)
      ..write(obj.winByMargin)
      ..writeByte(3)
      ..write(obj.placementPoints);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirstToConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirstToConfig _$FirstToConfigFromJson(Map<String, dynamic> json) =>
    FirstToConfig(
      leagueId: json['leagueId'] as String,
      targetScore: (json['targetScore'] as num).toInt(),
      winByMargin: (json['winByMargin'] as num).toInt(),
      placementPoints: (json['placementPoints'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$FirstToConfigToJson(FirstToConfig instance) =>
    <String, dynamic>{
      'leagueId': instance.leagueId,
      'targetScore': instance.targetScore,
      'winByMargin': instance.winByMargin,
      'placementPoints': instance.placementPoints,
    };
