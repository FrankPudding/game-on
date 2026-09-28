import '../entities/category.dart';

abstract class CategoryRepository {
  Future<Category?> get(String id);
  Future<Category?> getBySlug(String slug);
  Future<List<Category>> getAllOrdered();
  Future<List<Category>> getByIds(List<String> ids);
  Future<List<Category>> getChildren(String parentId);
  Future<List<Category>> getRoots();
  Future<void> put(Category category);
  Future<void> delete(String id);

  /// Returns true if all [ids] exist.
  /// Throws [ArgumentError] if [ids] is empty.
  Future<bool> existsAll(List<String> ids);
  Future<void> rebuildIndexes();
}
