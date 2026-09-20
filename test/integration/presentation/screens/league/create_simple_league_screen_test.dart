import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/domain/entities/league.dart';
import 'package:game_on/domain/entities/ranking_policies/simple_ranking_policy.dart';
import 'package:game_on/domain/entities/ranking_policy.dart';
import 'package:game_on/domain/repositories/league_repository.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/application/services/create_league_service.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/presentation/screens/league/create_simple_league_screen.dart';

class MockLeagueRepository extends Mock implements LeagueRepository {}

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

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
    registerFallbackValue(SimpleRankingPolicy(
      id: '',
      name: '',
      leagueId: '',
      pointsForWin: 3,
      pointsForDraw: 1,
      pointsForLoss: 0,
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
        )).thenAnswer((_) async => {});
    when(() => mockLeagueRepo.getAll()).thenAnswer((_) async => []);
  });

  tearDown(() {
    container.dispose();
  });

  Widget createWidget({List<League>? leagues}) {
    final notifier = leagues != null
        ? FakeLeaguesNotifier(leagues: leagues)
        : fakeLeaguesNotifier;
    return ProviderScope(
      retry: (_, __) => null,
      overrides: [
        leaguesProvider.overrideWith(() => notifier),
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
                    builder: (_) => const CreateSimpleLeagueScreen(),
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

  Widget createWidgetWithRealNotifier() {
    final testContainer = ProviderContainer(
      overrides: [
        leaguesProvider.overrideWith(() => LeaguesNotifier()),
        createLeagueServiceProvider.overrideWithValue(mockCreateService),
        leagueRepositoryProvider.overrideWithValue(mockLeagueRepo),
        rankingPolicyRepositoryProvider.overrideWithValue(mockPolicyRepo),
      ],
    );

    return UncontrolledProviderScope(
      container: testContainer,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await testContainer.read(leaguesProvider.future);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateSimpleLeagueScreen(),
                      ),
                    );
                  }
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openScreen(WidgetTester tester, {List<League>? leagues}) async {
    await tester.pumpWidget(createWidget(leagues: leagues));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> openScreenWithRealNotifier(WidgetTester tester) async {
    await tester.pumpWidget(createWidgetWithRealNotifier());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('CreateSimpleLeagueScreen', () {
    testWidgets('should show create simple league screen with form',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      expect(find.text('New Simple League'), findsOneWidget);
      expect(find.text('League Details'), findsOneWidget);
      expect(find.text('League Name'), findsOneWidget);
      expect(find.text('Scoring Rules'), findsOneWidget);
      expect(find.text('Win'), findsOneWidget);
      expect(find.text('Draw'), findsOneWidget);
      expect(find.text('Loss'), findsOneWidget);
      expect(find.text('Create League'), findsOneWidget);
    });

    testWidgets('should create league successfully with valid input',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      // Fill league name (first TextFormField)
      await tester.enterText(find.byType(TextFormField).first, 'Test League');
      await tester.pump();

      // Fill scoring rules (next 3 TextFormFields)
      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(3), '0');
      await tester.pump();

      // Tap create button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create League'));
      await tester.pumpAndSettle();

      // Verify addLeague was called with correct parameters
      expect(fakeLeaguesNotifier.addLeagueCalls, hasLength(1));
      final call = fakeLeaguesNotifier.addLeagueCalls.first;
      expect(call['name'], 'Test League');
      expect(call['rankingPolicy'], isA<SimpleRankingPolicy>());
      final policy = call['rankingPolicy'] as SimpleRankingPolicy;
      expect(policy.pointsForWin, 3);
      expect(policy.pointsForDraw, 1);
      expect(policy.pointsForLoss, 0);

      // Verify navigation popped to root and SnackBar shown
      expect(find.text('League created successfully!'), findsOneWidget);
    });

    testWidgets('should show validation error when league name is empty',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      // Don't enter name, just fill scoring
      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(3), '0');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create League'));
      await tester.pumpAndSettle();

      expect(fakeLeaguesNotifier.addLeagueCalls, isEmpty);
      expect(find.text('Please enter a name'), findsOneWidget);
    });

    testWidgets('should show validation error when win points is invalid',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test League');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), 'invalid');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(3), '0');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create League'));
      await tester.pumpAndSettle();

      expect(fakeLeaguesNotifier.addLeagueCalls, isEmpty);
      expect(find.text('Invalid'), findsOneWidget);
    });

    testWidgets('should show validation error when draw points is invalid',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test League');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), 'invalid');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(3), '0');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create League'));
      await tester.pumpAndSettle();

      expect(fakeLeaguesNotifier.addLeagueCalls, isEmpty);
      expect(find.text('Invalid'), findsOneWidget);
    });

    testWidgets('should show validation error when loss points is invalid',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test League');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(3), 'invalid');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create League'));
      await tester.pumpAndSettle();

      expect(fakeLeaguesNotifier.addLeagueCalls, isEmpty);
      expect(find.text('Invalid'), findsOneWidget);
    });

    testWidgets('should show error SnackBar when service throws',
        (tester) async {
      when(() => mockCreateService.execute(
            id: any(named: 'id'),
            name: any(named: 'name'),
            rankingPolicy: any(named: 'rankingPolicy'),
          )).thenThrow(Exception('Service error'));

      await openScreenWithRealNotifier(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test League');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(3), '0');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create League'));
      await tester.pumpAndSettle();

      // Exception.toString() returns "Exception: Service error"
      expect(find.textContaining('Error: Exception: Service error'),
          findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should show loading indicator while creating', (tester) async {
      final completer = Completer<void>();
      when(() => mockCreateService.execute(
            id: any(named: 'id'),
            name: any(named: 'name'),
            rankingPolicy: any(named: 'rankingPolicy'),
          )).thenAnswer((_) => completer.future);

      await openScreenWithRealNotifier(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test League');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(3), '0');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create League'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('should use default scoring values when not changed',
        (tester) async {
      await openScreen(tester);
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test League');
      await tester.pump();

      // Don't change scoring fields - they should default to 3, 1, 0
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create League'));
      await tester.pumpAndSettle();

      expect(fakeLeaguesNotifier.addLeagueCalls, hasLength(1));
      final policy = fakeLeaguesNotifier.addLeagueCalls.first['rankingPolicy']
          as SimpleRankingPolicy;
      expect(policy.pointsForWin, 3);
      expect(policy.pointsForDraw, 1);
      expect(policy.pointsForLoss, 0);
    });
  });
}
