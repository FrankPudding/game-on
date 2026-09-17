import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/core/sorting/name_sort.dart';

void main() {
  group('compareNames', () {
    test('should sort case-insensitively primary', () {
      expect(compareNames('alice', 'Bob') < 0, isTrue);
      expect(compareNames('Bob', 'alice') > 0, isTrue);
      expect(compareNames('Alice', 'alice') < 0,
          isTrue); // secondary case-sensitive
      expect(compareNames('alice', 'Alice') > 0, isTrue);
    });

    test('should trim whitespace before comparison', () {
      expect(compareNames('  Alice ', 'Alice'), 0);
      expect(compareNames(' Bob', 'Bob '), 0);
      expect(compareNames('  Alice', 'Bob'), compareNames('Alice', 'Bob'));
    });

    test('should sort empty / whitespace-only first', () {
      expect(compareNames('', 'Alice') < 0, isTrue);
      expect(compareNames('   ', 'Bob') < 0, isTrue);
      expect(compareNames('', '   '), 0);
      expect(compareNames('Alice', '') > 0, isTrue);
    });

    test('should handle lowerCase tie-break with case-sensitive secondary', () {
      // lowercases equal, case-sensitive determines order
      // 'Alice' < 'alice' because uppercase < lowercase in ASCII
      expect(compareNames('Alice', 'alice') < 0, isTrue);
      expect(compareNames('alice', 'Alice') > 0, isTrue);
      expect(compareNames('Alice', 'Alice'), 0);
    });

    test('should work for sorting a list', () {
      final names = ['bob', 'Alice', ' alice', '', 'Bob', '  '];
      names.sort(compareNames);
      // empty/whitespace first (stable among empties -> 0)
      // then Alice /  alice / Bob / bob ... with case-sensitive tie-break
      // Let's verify order: '' and '  ' first (both empty after trim), then 'Alice' before ' alice'??
      // 'Alice' trimmed = 'Alice', ' alice' trimmed = 'alice', lower same, so 'Alice' < 'alice'
      expect(names[0].trim(), '');
      expect(names[1].trim(), '');
      expect(names[2], 'Alice');
      expect(names[3], ' alice');
      // Bob vs bob: 'Bob' < 'bob'
      expect(names[4], 'Bob');
      expect(names[5], 'bob');
    });

    test('should document locale limitation - not locale aware', () {
      // This test documents current limitation: uses toLowerCase, not locale collator.
      // For ASCII it works, but e.g. 'ß' vs 'ss' not handled.
      // Just ensure no crash for non-ascii.
      expect(() => compareNames('éclair', 'Eclair'), returnsNormally);
    });
  });
}
