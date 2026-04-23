abstract interface class SettingsRepository {
  Future<T?> readJsonValue<T>(String key);
  Future<void> writeJsonValue(String key, Object? value);
}
