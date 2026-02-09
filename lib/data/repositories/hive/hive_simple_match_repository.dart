import 'package:hive/hive.dart';
import '../../../domain/entities/simple_match.dart';
import '../../../domain/entities/match_participant.dart';
import '../../../domain/repositories/simple_match_repository.dart';
import '../../models/hive/simple_match_hive_model.dart';
import '../../models/hive/match_participant_hive_model.dart';

class HiveSimpleMatchRepository implements SimpleMatchRepository {
  HiveSimpleMatchRepository(this._box, this._participantBox);
  final Box<SimpleMatchHiveModel> _box;
  final Box<MatchParticipantHiveModel> _participantBox;

  @override
  Future<SimpleMatch?> get(String id) async {
    final model = _box.get(id);
    return model?.toDomain();
  }

  @override
  Future<List<SimpleMatch>> getAll() async {
    return _box.values.map((m) => m.toDomain()).toList();
  }

  @override
  Future<void> put(SimpleMatch item) async {
    final model = SimpleMatchHiveModel.fromDomain(item);
    await _box.put(model.id, model);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  @override
  Future<List<SimpleMatch>> getByLeague(String leagueId) async {
    return _box.values
        .where((m) => m.leagueId == leagueId)
        .map((m) => m.toDomain())
        .toList();
  }

  @override
  Future<void> logSimpleMatch({
    required SimpleMatch match,
    required List<MatchParticipant> participants,
  }) async {
    await _box.put(match.id, SimpleMatchHiveModel.fromDomain(match));
    for (final participant in participants) {
      await _participantBox.put(
        participant.id,
        MatchParticipantHiveModel.fromDomain(participant),
      );
    }
  }

  @override
  Future<List<MatchParticipant>> getParticipantsForMatches(
      List<String> matchIds) async {
    final ids = matchIds.toSet();
    return _participantBox.values
        .where((p) => ids.contains(p.matchId))
        .map((m) => m.toDomain())
        .toList();
  }
}
