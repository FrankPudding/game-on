import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/core/sorting/date_sort.dart';

void main() {
  group('compareNullableDateNullLast (R1 null-last both directions)', () {
    final dOld = DateTime(2022, 12, 1);
    final dMid = DateTime(2023, 3, 5);
    final dNew = DateTime(2023, 6, 15);

    test('both null -> 0', () {
      expect(compareNullableDateNullLast(null, null, descending: true), 0);
      expect(compareNullableDateNullLast(null, null, descending: false), 0);
    });

    test('null always last regardless of descending', () {
      // a is null, b is non-null => a after b => positive
      expect(compareNullableDateNullLast(null, dNew, descending: true), greaterThan(0));
      expect(compareNullableDateNullLast(null, dNew, descending: false), greaterThan(0));
      // a non-null, b null => a before b => negative
      expect(compareNullableDateNullLast(dNew, null, descending: true), lessThan(0));
      expect(compareNullableDateNullLast(dNew, null, descending: false), lessThan(0));
    });

    test('descending true -> most recent first', () {
      // dNew vs dOld with descending true: dNew should sort before dOld => negative
      expect(compareNullableDateNullLast(dNew, dOld, descending: true), lessThan(0));
      expect(compareNullableDateNullLast(dOld, dNew, descending: true), greaterThan(0));
      expect(compareNullableDateNullLast(dMid, dMid, descending: true), 0);
    });

    test('descending false -> oldest first', () {
      expect(compareNullableDateNullLast(dOld, dNew, descending: false), lessThan(0));
      expect(compareNullableDateNullLast(dNew, dOld, descending: false), greaterThan(0));
      expect(compareNullableDateNullLast(dMid, dMid, descending: false), 0);
    });

    test('nulls last in list sort both directions', () {
      final dates = [null, dMid, null, dOld, dNew];
      final desc = List<DateTime?>.from(dates)..sort((a, b) => compareNullableDateNullLast(a, b, descending: true));
      expect(desc, [dNew, dMid, dOld, null, null]);

      final asc = List<DateTime?>.from(dates)..sort((a, b) => compareNullableDateNullLast(a, b, descending: false));
      expect(asc, [dOld, dMid, dNew, null, null]);
    });

    test('equal non-null dates -> 0 regardless direction', () {
      final a = DateTime(2023, 6, 15, 12, 0, 0);
      final b = DateTime(2023, 6, 15, 12, 0, 0);
      expect(compareNullableDateNullLast(a, b, descending: true), 0);
      expect(compareNullableDateNullLast(a, b, descending: false), 0);
    });
  });
}
