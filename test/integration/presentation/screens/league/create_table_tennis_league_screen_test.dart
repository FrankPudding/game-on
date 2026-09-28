import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/ranking_policies/table_tennis_elo_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/application/services/create_league_service.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/presentation/screens/league/create_table_tennis_league_screen.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}
class MockRankingPolicyRepository extends Mock implements RankingPolicyRepository {}
class MockCreateLeagueService extends Mock implements CreateLeagueService {}

class FakeLeaguesNotifier extends LeaguesNotifier {
  FakeLeaguesNotifier({this.leagues = const []});
  final List<League> leagues;
  final List<Map<String, dynamic>> addLeagueCalls = [];

  @override
  Future<List<League>> build() async => leagues;

  @override
  Future<void> addLeague({
    required String id,
    required String name,
    required RankingPolicy rankingPolicy,
    List<String>? categoryIds,
  }) async {
    addLeagueCalls.add({
      'id': id,
      'name': name,
      'rankingPolicy': rankingPolicy,
    });
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final newLeague = League(
        id: id,
        name: name,
        createdAt: DateTime.now(),
      );
      return [...leagues, newLeague];
    });
  }
}

void main() {
  late MockLeagueRepository mockLeagueRepo;
  late MockRankingPolicyRepository mockPolicyRepo;
  late MockCreateLeagueService mockCreateService;
  late FakeLeaguesNotifier fakeLeaguesNotifier;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(TableTennisEloRankingPolicy(
      id: '',
      name: '',
      leagueId: '',
      categoryIds: const ['cat_tabletennis'],
      initialRating: 400,
    ));
    registerFallbackValue(League(id: '', name: '', createdAt: DateTime.now()));
  });

  setUp(() {
    mockLeagueRepo = MockLeagueRepository();
    mockPolicyRepo = MockRankingPolicyRepository();
    mockCreateService = MockCreateLeagueService();
    fakeLeaguesNotifier = FakeLeaguesNotifier(leagues: []);

    container = ProviderContainer(
      overrides: [
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
        createLeagueServiceProvider.overrideWithValue(mockCreateService),
        leaguesProvider.overrideWith(() => fakeLeaguesNotifier),
      ],
    );

    when(() => mockCreateService.execute(
          id: any(named: 'id'),
          name: any(named: 'name'),
          rankingPolicy: any(named: 'rankingPolicy'),
          categoryIds: any(named: 'categoryIds'),
        )).thenAnswer((_) async => {});
    when(() => mockLeagueRepo.getAll()).thenAnswer((_) async => []);
  });

  tearDown(() {
    container.dispose();
  });

  Widget createWidget() {
    return ProviderScope(
      overrides: [
        leaguesProvider.overrideWith(() => fakeLeaguesNotifier),
        createLeagueServiceProvider.overrideWithValue(mockCreateService),
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateTableTennisLeagueScreen(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('CreateTableTennisLeagueScreen', () {
    testWidgets('should show create table tennis league screen with form', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('New Table Tennis League'), findsOneWidget);
      expect(find.text('League Details'), findsOneWidget);
      expect(find.text('League Name'), findsOneWidget);
      expect(find.text('Starting Elo Rating'), findsOneWidget);
      expect(find.text('Create League'), findsOneWidget);
    });

    testWidgets('should show validation error when initial rating is invalid', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'TT League');
      await tester.enterText(find.byType(TextFormField).at(1), '99'); // below 100
      await tester.tap(find.text('Create League'));
      await tester.pumpAndSettle();

      expect(find.textContaining('100..500'), findsOneWidget);
    });

    testWidgets('should create table tennis league successfully with valid input', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Pro TT League');
      await tester.enterText(find.byType(TextFormField).at(1), '400');
      await tester.tap(find.text('Create League'));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget); // Verify navigation back to the initial screen
      expect(fakeLeaguesNotifier.addLeagueCalls.length, 1);

      expect(fakeLeaguesNotifier.addLeagueCalls[0]['name'], 'Pro TT League');
      expect(fakeLeaguesNotifier.addLeagueCalls[0]['rankingPolicy'], isA<TableTennisEloRankingPolicy>());
    });
  });
}
