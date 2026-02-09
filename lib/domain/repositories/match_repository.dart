import 'repository.dart';

abstract class MatchRepository<T> extends Repository<T, String> {
  Future<List<T>> getByLeague(String leagueId);
}
