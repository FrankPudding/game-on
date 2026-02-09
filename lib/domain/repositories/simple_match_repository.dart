import '../entities/simple_match.dart';
import '../entities/match_participant.dart';
import 'match_repository.dart';

abstract class SimpleMatchRepository extends MatchRepository<SimpleMatch> {
  Future<void> logSimpleMatch({
    required SimpleMatch match,
    required List<MatchParticipant> participants,
  });

  Future<List<MatchParticipant>> getParticipantsForMatches(
      List<String> matchIds);
}
