abstract class Repository<T, ID> {
  Future<T?> get(ID id);
  Future<List<T>> getAll();
  Future<void> put(T item);
  Future<void> delete(ID id);
}
