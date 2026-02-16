// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simple_ranking_policy_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SimpleRankingPolicyHiveModelAdapter
    extends TypeAdapter<SimpleRankingPolicyHiveModel> {
  @override
  final typeId = 9;

  @override
  SimpleRankingPolicyHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SimpleRankingPolicyHiveModel(
      id: fields[0] as String,
      name: fields[1] as String,
      leagueId: fields[5] == null ? '' : fields[5] as String?,
      pointsForWin: fields[2] == null ? 3 : (fields[2] as num).toInt(),
      pointsForDraw: fields[3] == null ? 1 : (fields[3] as num).toInt(),
      pointsForLoss: fields[4] == null ? 0 : (fields[4] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, SimpleRankingPolicyHiveModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.pointsForWin)
      ..writeByte(3)
      ..write(obj.pointsForDraw)
      ..writeByte(4)
      ..write(obj.pointsForLoss)
      ..writeByte(5)
      ..write(obj.leagueId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleRankingPolicyHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
