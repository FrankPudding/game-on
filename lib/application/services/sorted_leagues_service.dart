// ignore_for_file: public_member_api_docs

import '../../core/sorting/date_sort.dart';
import '../../core/sorting/name_sort.dart';
import '../preferences/sort_preference.dart';
import '../../providers/sorted_leagues_provider.dart';

/// Pure comparator/service for sorting leagues.
///
/// Located in `application/services` to avoid importing [League] into `core`
/// (core must remain domain-free per DDD boundary). Pure: no I/O, no Hive,
/// delegated to by `SortedLeaguesNotifier`.
///
/// - Uses [compareNames] for alphabetical mode (R2)
/// - Uses [compareNullableDateNullLast] for lastPlayed descending (R1)
/// - Honors [LeagueSortPreference.descending] reversal (R3)
int compareLeagues(
  SortedLeague a,
  SortedLeague b,
  LeagueSortPreference preference,
) {
  if (preference.mode == LeagueSortMode.lastPlayed) {
    final dateCmp = compareNullableDateNullLast(
      a.lastPlayed,
      b.lastPlayed,
      descending: preference.descending,
    );
    if (dateCmp != 0) return dateCmp;
    final nameCmp = compareNames(a.league.name, b.league.name);
    if (nameCmp != 0) return nameCmp;
    return a.league.id.compareTo(b.league.id);
  } else {
    // alphabetical
    final nameCmp = compareNames(a.league.name, b.league.name);
    if (nameCmp != 0) {
      return preference.descending ? -nameCmp : nameCmp;
    }
    final idCmp = a.league.id.compareTo(b.league.id);
    return preference.descending ? -idCmp : idCmp;
  }
}

/// Returns a new sorted list without mutating input.
List<SortedLeague> sortLeagues(
  List<SortedLeague> leagues,
  LeagueSortPreference preference,
) {
  final copy = List<SortedLeague>.from(leagues);
  copy.sort((a, b) => compareLeagues(a, b, preference));
  return copy;
}
