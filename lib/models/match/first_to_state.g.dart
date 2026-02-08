// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'first_to_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FirstToStateAdapter extends TypeAdapter<FirstToState> {
  @override
  final int typeId = 10;

  @override
  FirstToState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FirstToState(
      matchId: fields[0] as String,
      teamId: fields[1] as String,
      currentScore: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, FirstToState obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.matchId)
      ..writeByte(1)
      ..write(obj.teamId)
      ..writeByte(2)
      ..write(obj.currentScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirstToStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirstToState _$FirstToStateFromJson(Map<String, dynamic> json) => FirstToState(
      matchId: json['matchId'] as String,
      teamId: json['teamId'] as String,
      currentScore: (json['currentScore'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$FirstToStateToJson(FirstToState instance) =>
    <String, dynamic>{
      'matchId': instance.matchId,
      'teamId': instance.teamId,
      'currentScore': instance.currentScore,
    };
