import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/league_player.dart';
import 'package:game_on/domain/entities/user.dart';
import 'package:game_on/domain/entities/matches/simple_match.dart';
import 'package:game_on/domain/entities/side.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/league_player_repository.dart';
import 'package:game_on/domain/repositories/user_repository.dart';
import 'package:game_on/domain/repositories/match/simple_match_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/providers/league_detail_provider.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/providers/user_detail_provider.dart';
import 'package:game_on/providers/users_provider.dart';
import 'package:game_on/presentation/widgets/player_edit_dialog.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockLeaguePlayerRepository extends Mock
    implements LeaguePlayerRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSimpleMatchRepository extends Mock implements SimpleMatchRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

class FakeLeagueDetailNotifier extends LeagueDetailNotifier {
  FakeLeagueDetailNotifier({required String leagueId, this.onBuild})
      : super(leagueId);
  final FutureOr<LeagueDetailState> Function()? onBuild;
  final List<Map<String, dynamic>> updatePlayerCalls = [];

  @override
  Future<LeagueDetailState> build() async {
    if (onBuild != null) return await onBuild!();
    return const LeagueDetailState(players: [], matches: [], playerStats: {});
  }

  @override
  Future<void> updatePlayer({
    required String playerId,
    required String name,
    String? icon,
  }) async {
    updatePlayerCalls.add({'playerId': playerId, 'name': name, 'icon': icon});
    final repo = ref.read(leaguePlayerRepositoryProvider);
    final player = await repo.get(playerId);
    if (player == null) throw Exception('Player not found');
    final updatedPlayer = player.copyWith(name: name, icon: icon);
    await repo.put(updatedPlayer);
    // Note: We don't invalidate userDetailProvider here because the dialog does it
    // Use the onBuild callback if available, otherwise trigger a rebuild
    if (onBuild != null) {
      state = AsyncValue.data(await onBuild!());
    }
  }
}

class FakeUserDetailNotifier extends UserDetailNotifier {
  FakeUserDetailNotifier(super.userId);
  int invalidateCount = 0;

  @override
  Future<List<UserLeagueInfo>> build() async => [];

  @override
  Future<void> refresh() async {
    invalidateCount++;
    await super.refresh();
  }
}

void main() {
  late MockLeagueRepository mockLeagueRepo;
  late MockLeaguePlayerRepository mockPlayerRepo;
  late MockUserRepository mockUserRepo;
  late MockSimpleMatchRepository mockMatchRepo;
  late MockRankingPolicyRepository mockPolicyRepo;
  late ProviderContainer container;

  const tLeagueId = 'l1';
  const tPlayerId = 'p1';
  const tUserId = 'u1';

  final tPlayer = LeaguePlayer(
    id: tPlayerId,
    userId: tUserId,
    leagueId: tLeagueId,
    name: 'Test Player',
    avatarColorHex: 'FF0000',
    icon: '👤',
  );

  setUpAll(() {
    registerFallbackValue(SimpleMatch(
        id: '',
        leagueId: '',
        playedAt: DateTime.now(),
        isComplete: false,
        sides: []));
    registerFallbackValue(Side(id: '', playerIds: []));
    registerFallbackValue(
        User(id: '', name: '', avatarColorHex: '', icon: null));
    registerFallbackValue(LeaguePlayer(
        id: '', userId: '', leagueId: '', name: '', avatarColorHex: ''));
  });

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    mockPlayerRepo = MockLeaguePlayerRepository();
    mockUserRepo = MockUserRepository();
    mockMatchRepo = MockSimpleMatchRepository();
    mockPolicyRepo = MockRankingPolicyRepository();

    container = ProviderContainer(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
      ],
    );

    when(() => mockLeagueRepo.get(tLeagueId)).thenAnswer((_) async => League(
          id: tLeagueId,
          name: 'Test League',
          createdAt: DateTime.now(),
        ));
    when(() => mockPlayerRepo.get(tPlayerId)).thenAnswer((_) async => tPlayer);
    when(() => mockPlayerRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => [tPlayer]);
    when(() => mockMatchRepo.getByLeague(tLeagueId))
        .thenAnswer((_) async => []);
    when(() => mockPolicyRepo.getByLeagueId(tLeagueId))
        .thenAnswer((_) async => null);
  });

  tearDown(() {
    container.dispose();
  });

  Widget createDialogWidget({
    required FakeLeagueDetailNotifier fakeLeagueNotifier,
    required FakeUserDetailNotifier fakeUserDetailNotifier,
  }) {
    return ProviderScope(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        leaguePlayerRepositoryProvider.overrideWithValue(mockPlayerRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        simpleMatchRepositoryProvider.overrideWithValue(mockMatchRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
        leagueDetailProvider.overrideWith2((arg) => fakeLeagueNotifier),
        userDetailProvider.overrideWith2((arg) => fakeUserDetailNotifier),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => PlayerEditDialog.show(
                  context,
                  leagueId: tLeagueId,
                  player: tPlayer,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
  }

  group('PlayerEditDialog', () {
    late FakeLeagueDetailNotifier fakeLeagueNotifier;
    late FakeUserDetailNotifier fakeUserDetailNotifier;

    setUp(() {
      fakeLeagueNotifier = FakeLeagueDetailNotifier(
        leagueId: tLeagueId,
        onBuild: () async => LeagueDetailState(
          players: [tPlayer],
          matches: [],
          playerStats: {
            tPlayerId: const PlayerStats(points: 0, matchesPlayed: 0)
          },
        ),
      );
      fakeUserDetailNotifier = FakeUserDetailNotifier(tUserId);
    });

    testWidgets('should show edit dialog with player data pre-filled',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      expect(find.text('Edit League Participant'), findsOneWidget);
      expect(find.text('Test Player'), findsOneWidget);
      expect(find.text('👤'), findsOneWidget); // Default icon
    });

    testWidgets('should update player name and icon successfully',
        (WidgetTester tester) async {
      when(() => mockPlayerRepo.get(tPlayerId))
          .thenAnswer((_) async => tPlayer);
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId)).thenAnswer(
          (_) async => [tPlayer.copyWith(name: 'Updated Name', icon: '🎮')]);

      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.enterText(find.byType(TextField), 'Updated Name');
      await tester.tap(find.text('🎮'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(fakeLeagueNotifier.updatePlayerCalls, hasLength(1));
      expect(fakeLeagueNotifier.updatePlayerCalls.first['playerId'], tPlayerId);
      expect(
          fakeLeagueNotifier.updatePlayerCalls.first['name'], 'Updated Name');
      expect(fakeLeagueNotifier.updatePlayerCalls.first['icon'], '🎮');
    });

    testWidgets('should not submit when nickname is empty',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(fakeLeagueNotifier.updatePlayerCalls, isEmpty);
      expect(fakeUserDetailNotifier.invalidateCount, 0);
    });

    testWidgets('should show error snackbar when repository fails',
        (WidgetTester tester) async {
      when(() => mockPlayerRepo.get(tPlayerId))
          .thenAnswer((_) async => tPlayer);
      when(() => mockPlayerRepo.put(any()))
          .thenThrow(Exception('Repository error'));

      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.enterText(find.byType(TextField), 'Updated Name');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should select custom icon', (WidgetTester tester) async {
      when(() => mockPlayerRepo.get(tPlayerId))
          .thenAnswer((_) async => tPlayer);
      when(() => mockPlayerRepo.put(any())).thenAnswer((_) async => {});
      when(() => mockPlayerRepo.getByLeague(tLeagueId)).thenAnswer(
          (_) async => [tPlayer.copyWith(name: 'Test Player', icon: '⚽')]);

      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.tap(find.text('⚽'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(fakeLeagueNotifier.updatePlayerCalls, hasLength(1));
      expect(fakeLeagueNotifier.updatePlayerCalls.first['icon'], '⚽');
    });

    testWidgets('should cancel and not call updatePlayer',
        (WidgetTester tester) async {
      await openDialog(
          tester,
          createDialogWidget(
            fakeLeagueNotifier: fakeLeagueNotifier,
            fakeUserDetailNotifier: fakeUserDetailNotifier,
          ));

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(fakeLeagueNotifier.updatePlayerCalls, isEmpty);
      expect(fakeUserDetailNotifier.invalidateCount, 0);
    });
  });
}
