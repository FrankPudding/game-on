import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/data/repositories/hive/hive_simple_match_repository.dart';
import 'package:game_on/data/models/hive/simple_match_hive_model.dart';
import 'package:game_on/data/models/hive/match_participant_hive_model.dart';
import 'package:game_on/domain/entities/simple_match.dart';
import 'package:game_on/domain/entities/match_participant.dart';

class MockMatchBox extends Mock implements Box<SimpleMatchHiveModel> {}

class MockParticipantBox extends Mock
    implements Box<MatchParticipantHiveModel> {}

void main() {
  setUpAll(() {
    registerFallbackValue(SimpleMatchHiveModel(
        id: '',
        leagueId: '',
        playedAt: DateTime.now(),
        isComplete: false,
        isDraw: false));
    registerFallbackValue(
        MatchParticipantHiveModel(id: '', playerId: '', matchId: ''));
  });

  late HiveSimpleMatchRepository repository;
  late MockMatchBox mockMatchBox;
  late MockParticipantBox mockParticipantBox;

  setUp(() {
    mockMatchBox = MockMatchBox();
    mockParticipantBox = MockParticipantBox();
    repository = HiveSimpleMatchRepository(mockMatchBox, mockParticipantBox);
  });

  group('HiveSimpleMatchRepository', () {
    final tMatch = SimpleMatch(
      id: 'm1',
      leagueId: 'l1',
      playedAt: DateTime(2023),
      isComplete: true,
    );
    final tParticipant = MatchParticipant(
      id: 'p1',
      playerId: 'player1',
      matchId: 'm1',
      score: null,
    );

    test('logSimpleMatch should put match and participants', () async {
      when(() => mockMatchBox.put(any(), any())).thenAnswer((_) async => {});
      when(() => mockParticipantBox.put(any(), any()))
          .thenAnswer((_) async => {});

      await repository
          .logSimpleMatch(match: tMatch, participants: [tParticipant]);

      verify(() => mockMatchBox.put(tMatch.id, any())).called(1);
      verify(() => mockParticipantBox.put(tParticipant.id, any())).called(1);
    });

    test('getByLeague should return matches for league', () async {
      final m1 = SimpleMatchHiveModel(
          id: '1',
          leagueId: 'l1',
          playedAt: DateTime.now(),
          isComplete: true,
          isDraw: false);
      final m2 = SimpleMatchHiveModel(
          id: '2',
          leagueId: 'l2',
          playedAt: DateTime.now(),
          isComplete: true,
          isDraw: false);
      when(() => mockMatchBox.values).thenReturn([m1, m2]);

      final result = await repository.getByLeague('l1');

      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test(
        'getParticipantsForMatches should return participants for given match ids',
        () async {
      final p1 = MatchParticipantHiveModel(
          id: 'p1', playerId: 'pl1', matchId: 'm1', pointsEarned: 3);
      final p2 = MatchParticipantHiveModel(
          id: 'p2', playerId: 'pl2', matchId: 'm2', pointsEarned: 1);
      when(() => mockParticipantBox.values).thenReturn([p1, p2]);

      final result = await repository.getParticipantsForMatches(['m1']);

      expect(result.length, 1);
      expect(result.first.id, 'p1');
    });
  });
}
