import '../entities/league.dart';
import '../repository.dart';

abstract class LeagueRepository extends Repository<League, String> {
  Future<void> archiveLeague(String id);
}
