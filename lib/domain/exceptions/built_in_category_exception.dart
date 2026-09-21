/// Thrown when attempting to delete or mutate an immutable built-in category.
class BuiltInCategoryException implements Exception {
  const BuiltInCategoryException(this.categoryId);

  final String categoryId;

  @override
  String toString() =>
      'BuiltInCategoryException: Built-in category $categoryId cannot be deleted or mutated';
}
