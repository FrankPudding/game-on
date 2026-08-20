import 'package:flutter_test/flutter_test.dart';
import 'package:game_on/domain/entities/league_player.dart';

void main() {
  group('LeaguePlayer', () {
    final tPlayer = LeaguePlayer(
      id: 'p1',
      userId: 'u1',
      leagueId: 'l1',
      name: 'Alice',
      avatarColorHex: 'AE0C00',
      icon: '🥇',
    );

    test('should create LeaguePlayer with provided values', () {
      expect(tPlayer.id, 'p1');
      expect(tPlayer.userId, 'u1');
      expect(tPlayer.leagueId, 'l1');
      expect(tPlayer.name, 'Alice');
      expect(tPlayer.avatarColorHex, 'AE0C00');
      expect(tPlayer.icon, '🥇');
    });

    test('icon should default to null', () {
      final player = LeaguePlayer(
        id: 'p2',
        userId: 'u2',
        leagueId: 'l2',
        name: 'Bob',
        avatarColorHex: '000000',
      );

      expect(player.icon, isNull);
    });

    test('copyWith should update provided fields', () {
      final updated = tPlayer.copyWith(
        name: 'Alicia',
        icon: '🥈',
        leagueId: 'l9',
      );

      expect(updated.id, tPlayer.id);
      expect(updated.userId, tPlayer.userId);
      expect(updated.avatarColorHex, tPlayer.avatarColorHex);
      expect(updated.name, 'Alicia');
      expect(updated.icon, '🥈');
      expect(updated.leagueId, 'l9');
    });

    test('copyWith without args should preserve all values', () {
      final updated = tPlayer.copyWith();

      expect(updated.id, tPlayer.id);
      expect(updated.userId, tPlayer.userId);
      expect(updated.leagueId, tPlayer.leagueId);
      expect(updated.name, tPlayer.name);
      expect(updated.avatarColorHex, tPlayer.avatarColorHex);
      expect(updated.icon, tPlayer.icon);
      expect(identical(updated, tPlayer), isFalse);
    });
  });
}
