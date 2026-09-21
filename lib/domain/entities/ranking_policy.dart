import 'package:game_on/domain/entities/match.dart';

abstract class RankingPolicy<M extends Match> {
  RankingPolicy({
    required this.id,
    required this.name,
    required this.leagueId,
    required List<String> categoryIds,
  }) : _categoryIds = List.unmodifiable(_validateCategoryIds(categoryIds));

  final String id;
  final String name;
  final String leagueId;
  final List<String> _categoryIds;

  List<String> get categoryIds => _categoryIds;

  static List<String> _validateCategoryIds(List<String> ids) {
    if (ids.isEmpty) {
      throw ArgumentError('categoryIds must not be empty');
    }
    final set = ids.toSet();
    if (set.length != ids.length) {
      throw ArgumentError('categoryIds must not contain duplicates');
    }
    return List<String>.from(ids);
  }
}
