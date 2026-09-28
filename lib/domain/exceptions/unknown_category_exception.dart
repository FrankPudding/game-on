/// Thrown when a RankingPolicy references non-existent categoryIds.
class UnknownCategoryException implements Exception {
  const UnknownCategoryException(this.categoryIds);

  final List<String> categoryIds;

  @override
  String toString() =>
      'UnknownCategoryException: One or more categoryIds do not exist: $categoryIds';
}
