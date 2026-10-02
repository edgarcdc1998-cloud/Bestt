abstract class StorageService {
  Future<void> setString(String key, String value);
  String? getString(String key);
  Future<void> remove(String key);
  Future<void> clear();
  bool containsKey(String key);
}
