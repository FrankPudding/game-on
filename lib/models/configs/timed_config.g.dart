// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timed_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimedConfigAdapter extends TypeAdapter<TimedConfig> {
  @override
  final int typeId = 11;

  @override
  TimedConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimedConfig(
      leagueId: fields[0] as String,
      lowerScoreWins: fields[1] as bool,
      placementPoints: (fields[2] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, TimedConfig obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.leagueId)
      ..writeByte(1)
      ..write(obj.lowerScoreWins)
      ..writeByte(2)
      ..write(obj.placementPoints);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimedConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimedConfig _$TimedConfigFromJson(Map<String, dynamic> json) => TimedConfig(
      leagueId: json['leagueId'] as String,
      lowerScoreWins: json['lowerScoreWins'] as bool,
      placementPoints: (json['placementPoints'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$TimedConfigToJson(TimedConfig instance) =>
    <String, dynamic>{
      'leagueId': instance.leagueId,
      'lowerScoreWins': instance.lowerScoreWins,
      'placementPoints': instance.placementPoints,
    };
