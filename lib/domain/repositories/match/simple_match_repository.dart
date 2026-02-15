import '../../entities/matches/simple_match.dart';
import '../match_repository.dart';

abstract class SimpleMatchRepository extends MatchRepository<SimpleMatch> {
  Future<void> logSimpleMatch({
    required SimpleMatch match,
  });
}
