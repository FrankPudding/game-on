import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:game_on/core/constants/hive_box_names.dart';
import 'package:game_on/domain/entities/ranking_policy_type.dart';
import 'package:game_on/domain/repositories/ranking_policy_repository.dart';
import 'package:game_on/providers/leagues_provider.dart';
import 'package:game_on/presentation/screens/league/select_scoring_system_screen.dart';

class MockRankingPolicyRepository extends Mock
    implements RankingPolicyRepository {}

void main() {
  late MockRankingPolicyRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockRankingPolicyRepository();
    container = ProviderContainer(
      overrides: [
        rankingPolicyRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('rankingPolicyTypesForCategoryProvider – Table Tennis whitelist', () {
    test('[cat_tabletennis] returns [RankingPolicyType.tableTennisElo] without repo query', () async {
      final result = await container
          .read(rankingPolicyTypesForCategoryProvider(kTableTennisCategoryId).future);
      expect(result, [RankingPolicyType.tableTennisElo]);
      verifyNever(() => mockRepo.getByCategory(any()));
      verifyNever(() => mockRepo.getAll());
    });
  });
}
