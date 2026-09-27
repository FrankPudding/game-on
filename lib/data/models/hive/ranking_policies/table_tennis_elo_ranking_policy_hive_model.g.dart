// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_tennis_elo_ranking_policy_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TableTennisEloRankingPolicyHiveModelAdapter
    extends TypeAdapter<TableTennisEloRankingPolicyHiveModel> {
  @override
  final typeId = 13;

  @override
  TableTennisEloRankingPolicyHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TableTennisEloRankingPolicyHiveModel(
      id: fields[0] as String,
      name: fields[1] as String,
      leagueId: fields[5] == null ? '' : fields[5] as String?,
      categoryIds:
          fields[6] == null ? [] : (fields[6] as List?)?.cast<String>(),
      initialRating: fields[7] == null ? 400 : (fields[7] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, TableTennisEloRankingPolicyHiveModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.leagueId)
      ..writeByte(6)
      ..write(obj.categoryIds)
      ..writeByte(7)
      ..write(obj.initialRating);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableTennisEloRankingPolicyHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
