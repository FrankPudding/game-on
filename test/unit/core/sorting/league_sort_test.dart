import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/application/preferences/sort_preference.dart';
import 'package:game_on/application/services/sorted_leagues_service.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/providers/sorted_leagues_provider.dart';

League _league(String id, String name) =>
    League(id: id, name: name, createdAt: DateTime(2023, 1, 1));
SortedLeague _sl(String id, String name, DateTime? lastPlayed) =>
    SortedLeague(league: _league(id, name), lastPlayed: lastPlayed);

void main() {
  group('compareLeagues / sortLeagues (R1,R2,R3)', () {
    group('lastPlayed mode', () {
      test('descending true -> most recent first, nulls last', () {
        final pref = LeagueSortPreference(
            mode: LeagueSortMode.lastPlayed, descending: true);
        final lRecent = _sl('l1', 'Alpha', DateTime(2023, 6, 15));
        final lOld = _sl('l2', 'Beta', DateTime(2022, 12, 1));
        final lNever = _sl('l3', 'Gamma', null);
        expect(compareLeagues(lRecent, lOld, pref), lessThan(0));
        expect(compareLeagues(lOld, lRecent, pref), greaterThan(0));
        expect(compareLeagues(lNever, lRecent, pref), greaterThan(0));
        expect(compareLeagues(lRecent, lNever, pref), lessThan(0));
        expect(compareLeagues(lNever, lNever, pref),
            0); // both null -> tie break via name/id? but null tie continues
      });

      test('descending false -> oldest first, nulls still last', () {
        final pref = LeagueSortPreference(
            mode: LeagueSortMode.lastPlayed, descending: false);
        final lRecent = _sl('l1', 'Alpha', DateTime(2023, 6, 15));
        final lOld = _sl('l2', 'Beta', DateTime(2022, 12, 1));
        final lNever = _sl('l3', 'Gamma', null);
        expect(compareLeagues(lOld, lRecent, pref), lessThan(0));
        expect(compareLeagues(lRecent, lOld, pref), greaterThan(0));
        expect(compareLeagues(lNever, lOld, pref), greaterThan(0));
        expect(compareLeagues(lNever, lNever, pref), 0);
      });

      test(
          'lastPlayed tie-break via compareNames then id, deterministic stable',
          () {
        final pref = LeagueSortPreference(
            mode: LeagueSortMode.lastPlayed, descending: true);
        final sameDate = DateTime(2023, 6, 15);
        final a = _sl('l1', 'Bob', sameDate);
        final b = _sl('l2', 'alice', sameDate);
        final c = _sl('l3', ' Alice ', sameDate); // trimmed same as alice lower
        // b 'alice' vs a 'Bob': alice before Bob (case-insensitive)
        expect(compareLeagues(b, a, pref), lessThan(0));
        // c ' Alice ' trimmed -> 'Alice' vs b 'alice' -> lower equal, case-sensitive tie: 'Alice' < 'alice'
        expect(compareLeagues(c, b, pref), lessThan(0));

        // identical name+date -> id tie break
        final d1 = _sl('l10', 'Same', sameDate);
        final d2 = _sl('l2', 'Same', sameDate);
        // Actually l10 vs l2 : 'l10'.compareTo('l2') => check sign
        final expected = 'l10'.compareTo('l2');
        expect(compareLeagues(d1, d2, pref), expected);
      });

      test('sortLeagues is stable and does not mutate input (descending)', () {
        final pref = LeagueSortPreference(
            mode: LeagueSortMode.lastPlayed, descending: true);
        final l1 = _sl('l1', 'Alpha', DateTime(2023, 1, 10));
        final l2 = _sl('l2', 'Beta', DateTime(2023, 6, 15));
        final l3 = _sl('l3', 'Gamma', null);
        final input = [l1, l2, l3];
        final sorted = sortLeagues(input, pref);
        expect(sorted.map((e) => e.league.id).toList(), ['l2', 'l1', 'l3']);
        expect(input.map((e) => e.league.id).toList(),
            ['l1', 'l2', 'l3']); // not mutated
      });
    });

    group('alphabetical mode (R2)', () {
      test(
          'ascending (descending false) -> A first, empty first, case-insensitive primary',
          () {
        final pref = LeagueSortPreference(
            mode: LeagueSortMode.alphabetical, descending: false);
        final empty = _sl('l0', '   ', null);
        final aliceLower = _sl('l1', 'alice', DateTime(2023, 1, 1));
        final aliceUpper = _sl('l2', 'Alice', DateTime(2023, 1, 1));
        final bob = _sl('l3', 'Bob', DateTime(2023, 1, 1));
        // empty before all
        expect(compareLeagues(empty, aliceLower, pref), lessThan(0));
        // Alice before alice? primary case-insensitive equal, secondary case-sensitive => 'Alice' < 'alice'
        expect(compareLeagues(aliceUpper, aliceLower, pref), lessThan(0));
        expect(compareLeagues(aliceLower, bob, pref), lessThan(0));
      });

      test('descending true reverses alphabetical', () {
        final asc = LeagueSortPreference(
            mode: LeagueSortMode.alphabetical, descending: false);
        final desc = LeagueSortPreference(
            mode: LeagueSortMode.alphabetical, descending: true);
        final a = _sl('l1', 'Alice', null);
        final b = _sl('l2', 'Bob', null);
        expect(compareLeagues(a, b, asc), lessThan(0));
        expect(compareLeagues(a, b, desc), greaterThan(0));
      });

      test(
          'alphabetical ascending sortLeagues order includes empty first and id tie-break',
          () {
        final pref = LeagueSortPreference(
            mode: LeagueSortMode.alphabetical, descending: false);
        final bob = _sl('l3', 'Bob', null);
        final alice = _sl('l2', 'alice', null);
        final aliceUpper = _sl('l1', 'Alice', null);
        final empty1 = _sl('l4', '', null);
        final empty2 = _sl('l5', '   ', null);
        final sorted =
            sortLeagues([bob, alice, aliceUpper, empty2, empty1], pref);
        // empties first ordered by id (since compareNames returns 0 for both empty)
        // then Alice, alice, Bob
        expect(sorted[0].league.id,
            'l4'); // '' vs '   ' -> compareNames 0 -> id l4 < l5
        expect(sorted[1].league.id, 'l5');
        expect(sorted[2].league.name, 'Alice');
        expect(sorted[3].league.name, 'alice');
        expect(sorted[4].league.name, 'Bob');
      });

      test('alphabetical descending sortLeagues reverses', () {
        final prefDesc = LeagueSortPreference(
            mode: LeagueSortMode.alphabetical, descending: true);
        final a = _sl('l1', 'Alice', null);
        final b = _sl('l2', 'Bob', null);
        final c = _sl('l3', 'Charlie', null);
        final sorted = sortLeagues([a, b, c], prefDesc);
        expect(sorted.map((e) => e.league.name).toList(),
            ['Charlie', 'Bob', 'Alice']);
      });

      test('trim handling - whitespace trimmed before compare', () {
        final pref = LeagueSortPreference(
            mode: LeagueSortMode.alphabetical, descending: false);
        final spaced = _sl('l1', '  Bob  ', null);
        final normal = _sl('l2', 'Bob', null);
        // Same trimmed name -> compareNames 0, then id tie-break l1 < l2
        expect(compareLeagues(spaced, normal, pref), lessThan(0));
      });

      test('id tie-break when names equal after trim/case (deterministic)', () {
        final pref = LeagueSortPreference(
            mode: LeagueSortMode.alphabetical, descending: false);
        final lA = _sl('id-a', 'Same', null);
        final lB = _sl('id-b', 'Same', null);
        expect(compareLeagues(lA, lB, pref), lessThan(0));
        expect(compareLeagues(lB, lA, pref), greaterThan(0));
      });
    });

    test('sortLeagues does not mutate input for alphabetical too', () {
      final pref = LeagueSortPreference(
          mode: LeagueSortMode.alphabetical, descending: false);
      final l1 = _sl('l1', 'Charlie', null);
      final l2 = _sl('l2', 'Alpha', null);
      final input = [l1, l2];
      final sorted = sortLeagues(input, pref);
      expect(sorted.map((e) => e.league.name).toList(), ['Alpha', 'Charlie']);
      expect(input.map((e) => e.league.name).toList(), ['Charlie', 'Alpha']);
    });

    test('4 states all distinct (R3)', () {
      final a = _sl('l1', 'Alpha', DateTime(2023, 1, 1));
      final b = _sl('l2', 'Beta', DateTime(2023, 6, 1));
      // lastPlayed asc vs desc should differ
      final lpAsc = LeagueSortPreference(
          mode: LeagueSortMode.lastPlayed, descending: false);
      final lpDesc = LeagueSortPreference(
          mode: LeagueSortMode.lastPlayed, descending: true);
      final alphaAsc = LeagueSortPreference(
          mode: LeagueSortMode.alphabetical, descending: false);
      final alphaDesc = LeagueSortPreference(
          mode: LeagueSortMode.alphabetical, descending: true);
      expect(
          compareLeagues(a, b, lpAsc) != compareLeagues(a, b, lpDesc), isTrue);
      expect(compareLeagues(a, b, alphaAsc) != compareLeagues(a, b, alphaDesc),
          isTrue);
    });
  });
}
