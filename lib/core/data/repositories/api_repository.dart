abstract class ApiRepository<T> {
  Future<List<T>> fetchAll({Map<String, dynamic>? query});
  Future<T?> fetchById(String id);
  Future<T> create(T model);
  Future<T> update(T model);
  Future<void> delete(String id);

  // SaaS-ready sync placeholders.
  Future<void> pushLocalChanges() async {}
  Future<void> pullRemoteChanges() async {}
}
