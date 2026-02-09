import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/match_participant.dart';
import 'package:game_on/domain/entities/simple_match.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/simple_match_repository.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

void main() {
  late MockLeagueRepository mockLeagueRepo;
  late MockSimpleMatchRepository mockMatchRepo;
  late ProviderContainer container;

  final tLeagueId = 'l1';
  final tLeague =
      League(id: tLeagueId, name: 'Test League', createdAt: DateTime.now());
  final tPlayer1 = LeaguePlayer(
      id: 'p1',
      userId: 'u1',
      leagueId: tLeagueId,
      name: 'Player 1',
      avatarColorHex: 'FF0000');
  final tPlayer2 = LeaguePlayer(
      id: 'p2',
      userId: 'u2',
      leagueId: tLeagueId,
      name: 'Player 2',
      avatarColorHex: '00FF00');

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    mockMatchRepo = MockSimpleMatchRepository();

    container = ProviderContainer(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
      ],
    );

    // Default mocks
    when(() => mockLeagueRepo.get(tLeagueId)).thenAnswer((_) async => tLeague);
    when(() => mockLeagueRepo.getLeaguePlayers(tLeagueId))
        .thenReturn([tPlayer1, tPlayer2]);
    when(() => mockMatchRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => []);
    when(() => mockMatchRepo.getParticipantsForMatches(any()))
        .thenAnswer((_) async => []);
  });

  tearDown(() {
    container.dispose();
  });

  group('LeagueDetailNotifier', () {
    test('initial state should be loading and then data', () async {
      final notifier = container.listen(
          leagueDetailProvider(tLeagueId).notifier, (prev, next) {});

      expect(container.read(leagueDetailProvider(tLeagueId)).isLoading, true);

      await container.read(leagueDetailProvider(tLeagueId).future);

      final state = container.read(leagueDetailProvider(tLeagueId)).value;
      expect(state?.players.length, 2);
      expect(state?.matches.isEmpty, true);
    });

    test('should calculate stats correctly from matches', () async {
      final m1 = SimpleMatch(
          id: 'm1',
          leagueId: tLeagueId,
          playedAt: DateTime.now(),
          isComplete: true,
          winnerId: 'p1');
      final participants = [
        MatchParticipant(
            id: 'pt1', playerId: 'p1', matchId: 'm1', pointsEarned: 3),
        MatchParticipant(
            id: 'pt2', playerId: 'p2', matchId: 'm1', pointsEarned: 0),
      ];

      when(() => mockMatchRepo.getByLeague(tLeagueId))
          .thenAnswer((_) async => [m1]);
      when(() => mockMatchRepo.getParticipantsForMatches(['m1']))
          .thenAnswer((_) async => participants);

      await container.read(leagueDetailProvider(tLeagueId).future);
      final state = container.read(leagueDetailProvider(tLeagueId)).value!;

      expect(state.playerStats['p1']?.points, 3);
      expect(state.playerStats['p1']?.matchesPlayed, 1);
      expect(state.playerStats['p2']?.points, 0);
      expect(state.playerStats['p2']?.matchesPlayed, 1);

      // Player 1 should be first because they have more points
      expect(state.players.first.id, 'p1');
    });

    group('Edge Cases', () {
      test('should handle empty league with no players', () async {
        when(() => mockLeagueRepo.getLeaguePlayers(tLeagueId)).thenReturn([]);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        expect(state.players, isEmpty);
        expect(state.playerStats, isEmpty);
      });

      test(
          'should handle tied points with stable sorting (or at least not failing)',
          () async {
        final m1 = SimpleMatch(
            id: 'm1',
            leagueId: tLeagueId,
            playedAt: DateTime.now(),
            isComplete: true,
            isDraw: true);
        final participants = [
          MatchParticipant(
              id: 'pt1', playerId: 'p1', matchId: 'm1', pointsEarned: 1),
          MatchParticipant(
              id: 'pt2', playerId: 'p2', matchId: 'm1', pointsEarned: 1),
        ];

        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [m1]);
        when(() => mockMatchRepo.getParticipantsForMatches(['m1']))
            .thenAnswer((_) async => participants);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        expect(state.playerStats['p1']?.points, 1);
        expect(state.playerStats['p2']?.points, 1);
      });

      test(
          'should handle match with player not in league (e.g., deleted player)',
          () async {
        final m1 = SimpleMatch(
            id: 'm1',
            leagueId: tLeagueId,
            playedAt: DateTime.now(),
            isComplete: true,
            winnerId: 'p3');
        final participants = [
          MatchParticipant(
              id: 'pt1', playerId: 'p3', matchId: 'm1', pointsEarned: 3),
        ];

        when(() => mockMatchRepo.getByLeague(tLeagueId))
            .thenAnswer((_) async => [m1]);
        when(() => mockMatchRepo.getParticipantsForMatches(['m1']))
            .thenAnswer((_) async => participants);

        await container.read(leagueDetailProvider(tLeagueId).future);
        final state = container.read(leagueDetailProvider(tLeagueId)).value!;

        // Should not crash, and p3 statistics should be calculated (even if not in players list)
        expect(state.playerStats['p3']?.points, 3);
        expect(state.players.length, 2); // Still just p1 and p2
      });
    });

    test('addPlayer should call repository and refresh', () async {
      when(() => mockLeagueRepo.addPlayer(
            leagueId: any(named: 'leagueId'),
            name: any(named: 'name'),
            userId: any(named: 'userId'),
            icon: any(named: 'icon'),
          )).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.addPlayer(name: 'New Player');

      verify(() =>
              mockLeagueRepo.addPlayer(leagueId: tLeagueId, name: 'New Player'))
          .called(1);
    });

    test('logSimpleMatch should create match and participants and refresh',
        () async {
      when(() => mockMatchRepo.logSimpleMatch(
            match: any(named: 'match'),
            participants: any(named: 'participants'),
          )).thenAnswer((_) async => {});

      final notifier = container.read(leagueDetailProvider(tLeagueId).notifier);
      await notifier.logSimpleMatch(
          winnerId: 'p1', loserId: 'p2', isDraw: false);

      verify(() => mockMatchRepo.logSimpleMatch(
            match: any(named: 'match'),
            participants: any(named: 'participants'),
          )).called(1);
    });
  });

  setUpAll(() {
    registerFallbackValue(SimpleMatch(
        id: '', leagueId: '', playedAt: DateTime.now(), isComplete: false));
    registerFallbackValue(<MatchParticipant>[]);
  });
}
